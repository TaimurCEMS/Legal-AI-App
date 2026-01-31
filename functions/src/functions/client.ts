/**
 * Client Management Functions (Slice 3 - Client Hub)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { emitDomainEventWithOutbox } from '../utils/domain-events';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface ClientDocument {
  id: string;
  orgId: string;
  name: string;
  email?: string | null;
  phone?: string | null;
  notes?: string | null;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

function parseName(rawName: unknown): string | null {
  if (typeof rawName !== 'string') return null;
  const trimmed = rawName.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function parseEmail(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 255) return null;
  // Basic email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(trimmed)) return null;
  return trimmed;
}

function parsePhone(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 50) return null;
  return trimmed;
}

function parseNotes(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 1000) return null;
  return trimmed;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

/**
 * Create a new client
 * Function Name (Export): clientCreate
 * Callable Name (Internal): client.create
 */
export const clientCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, name, email, phone, notes } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const sanitizedName = parseName(name);
  if (!sanitizedName) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Client name must be 1-200 characters'
    );
  }

  const sanitizedEmail = parseEmail(email);
  if (email !== undefined && email !== null && sanitizedEmail === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Invalid email format'
    );
  }

  const sanitizedPhone = parsePhone(phone);
  if (phone !== undefined && phone !== null && sanitizedPhone === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Phone must be 50 characters or less'
    );
  }

  const sanitizedNotes = parseNotes(notes);
  if (notes !== undefined && notes !== null && sanitizedNotes === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Notes must be 1000 characters or less'
    );
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'CLIENTS',
    requiredPermission: 'client.create',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to create clients');
    }
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'CLIENTS feature not available in current plan');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to create client');
  }

  try {
    const now = admin.firestore.Timestamp.now();
    const clientRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .doc();

    const clientId = clientRef.id;

    const clientData: ClientDocument = {
      id: clientId,
      orgId,
      name: sanitizedName,
      email: sanitizedEmail,
      phone: sanitizedPhone,
      notes: sanitizedNotes,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      updatedBy: uid,
      deletedAt: null,
    };

    await clientRef.set(clientData);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'client.created',
      entityType: 'client',
      entityId: clientId,
      metadata: {
        name: sanitizedName,
        email: sanitizedEmail || null,
      },
    });

    // Emit domain event for notifications
    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'client.created',
      entityType: 'client',
      entityId: clientId,
      actor: { actorType: 'user', actorId: uid },
      payload: { title: sanitizedName, email: sanitizedEmail },
    });

    return successResponse({
      clientId,
      orgId,
      name: sanitizedName,
      email: sanitizedEmail,
      phone: sanitizedPhone,
      notes: sanitizedNotes,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      updatedBy: uid,
    });
  } catch (error: any) {
    functions.logger.error('Error creating client:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to create client');
  }
});

/**
 * Get client details by ID
 * Function Name (Export): clientGet
 * Callable Name (Internal): client.get
 */
export const clientGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, clientId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!clientId || typeof clientId !== 'string' || clientId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Client ID is required');
  }

  // Check org membership (all org members can read clients)
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'CLIENTS',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view client');
  }

  try {
    const clientRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .doc(clientId);

    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    const clientData = clientDoc.data() as ClientDocument;

    // Check if soft-deleted
    if (clientData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    // Verify client belongs to org
    if (clientData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Client does not belong to this organization');
    }

    return successResponse({
      clientId: clientData.id,
      orgId: clientData.orgId,
      name: clientData.name,
      email: clientData.email || null,
      phone: clientData.phone || null,
      notes: clientData.notes || null,
      createdAt: toIso(clientData.createdAt),
      updatedAt: toIso(clientData.updatedAt),
      createdBy: clientData.createdBy,
      updatedBy: clientData.updatedBy,
      deletedAt: clientData.deletedAt ? toIso(clientData.deletedAt) : null,
    });
  } catch (error: any) {
    functions.logger.error('Error getting client:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to get client');
  }
});

/**
 * List clients for an organization
 * Function Name (Export): clientList
 * Callable Name (Internal): client.list
 */
export const clientList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, limit = 50, offset = 0, search } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  // Validate limit
  const parsedLimit = typeof limit === 'number' ? Math.min(Math.max(1, limit), 100) : 50;
  const parsedOffset = typeof offset === 'number' ? Math.max(0, offset) : 0;

  // Check org membership (all org members can read clients)
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'CLIENTS',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to list clients');
  }

  try {
    // For MVP: Fetch all non-deleted clients and filter in-memory
    // This avoids index requirements and works immediately
    const query: admin.firestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .where('deletedAt', '==', null)
      .orderBy('updatedAt', 'desc');

    // Fetch all clients (with reasonable limit for MVP)
    const snapshot = await query.limit(1000).get();

    let allClients = snapshot.docs.map((doc) => {
      const data = doc.data() as ClientDocument;
      return {
        clientId: data.id,
        orgId: data.orgId,
        name: data.name,
        email: data.email || null,
        phone: data.phone || null,
        notes: data.notes || null,
        createdAt: toIso(data.createdAt),
        updatedAt: toIso(data.updatedAt),
        createdBy: data.createdBy,
        updatedBy: data.updatedBy,
      };
    });

    // Apply in-memory search filter if provided (case-insensitive contains on name)
    if (search && typeof search === 'string' && search.trim().length > 0) {
      const searchTerm = search.trim().toLowerCase();
      allClients = allClients.filter((client) =>
        client.name.toLowerCase().includes(searchTerm)
      );
    }

    // Apply pagination
    const total = allClients.length;
    const pagedClients = allClients.slice(parsedOffset, parsedOffset + parsedLimit);
    const hasMore = parsedOffset + parsedLimit < total;

    return successResponse({
      clients: pagedClients,
      total,
      hasMore,
    });
  } catch (error: any) {
    functions.logger.error('Error listing clients:', error);
    functions.logger.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack,
      orgId,
      uid,
    });
    
    // Provide more specific error message
    let errorMessage = 'Failed to list clients';
    if (error.code === 9 || error.message?.includes('index') || error.message?.includes('FAILED_PRECONDITION')) {
      errorMessage = 'Firestore index required. Please check Firebase Console → Firestore → Indexes and ensure all indexes are enabled.';
    } else if (error.code === 7 || error.message?.includes('permission') || error.message?.includes('PERMISSION_DENIED')) {
      errorMessage = 'Permission denied. Please check Firestore security rules.';
    } else if (error.message) {
      errorMessage = `Failed to list clients: ${error.message}`;
    }
    
    return errorResponse(ErrorCode.INTERNAL_ERROR, errorMessage);
  }
});

/**
 * Update client information
 * Function Name (Export): clientUpdate
 * Callable Name (Internal): client.update
 */
export const clientUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, clientId, name, email, phone, notes } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!clientId || typeof clientId !== 'string' || clientId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Client ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'CLIENTS',
    requiredPermission: 'client.update',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to update clients');
    }
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'CLIENTS feature not available in current plan');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to update client');
  }

  try {
    const clientRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .doc(clientId);

    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    const existingData = clientDoc.data() as ClientDocument;

    // Check if soft-deleted
    if (existingData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    // Verify client belongs to org
    if (existingData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Client does not belong to this organization');
    }

    // Build update data (only include provided fields)
    const updateData: Partial<ClientDocument> = {
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: uid,
    };

    const updatedFields: string[] = [];

    if (name !== undefined) {
      const sanitizedName = parseName(name);
      if (sanitizedName === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Client name must be 1-200 characters');
      }
      updateData.name = sanitizedName;
      updatedFields.push('name');
    }

    if (email !== undefined) {
      const sanitizedEmail = parseEmail(email);
      if (email !== null && sanitizedEmail === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid email format');
      }
      updateData.email = sanitizedEmail;
      updatedFields.push('email');
    }

    if (phone !== undefined) {
      const sanitizedPhone = parsePhone(phone);
      if (phone !== null && sanitizedPhone === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Phone must be 50 characters or less');
      }
      updateData.phone = sanitizedPhone;
      updatedFields.push('phone');
    }

    if (notes !== undefined) {
      const sanitizedNotes = parseNotes(notes);
      if (notes !== null && sanitizedNotes === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Notes must be 1000 characters or less');
      }
      updateData.notes = sanitizedNotes;
      updatedFields.push('notes');
    }

    // If no fields to update, return existing data
    if (updatedFields.length === 0) {
      return successResponse({
        clientId: existingData.id,
        orgId: existingData.orgId,
        name: existingData.name,
        email: existingData.email || null,
        phone: existingData.phone || null,
        notes: existingData.notes || null,
        createdAt: toIso(existingData.createdAt),
        updatedAt: toIso(existingData.updatedAt),
        createdBy: existingData.createdBy,
        updatedBy: existingData.updatedBy,
      });
    }

    await clientRef.update(updateData);

    // Get updated data
    const updatedDoc = await clientRef.get();
    const updatedData = updatedDoc.data() as ClientDocument;

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'client.updated',
      entityType: 'client',
      entityId: clientId,
      metadata: {
        updatedFields,
      },
    });

    return successResponse({
      clientId: updatedData.id,
      orgId: updatedData.orgId,
      name: updatedData.name,
      email: updatedData.email || null,
      phone: updatedData.phone || null,
      notes: updatedData.notes || null,
      createdAt: toIso(updatedData.createdAt),
      updatedAt: toIso(updatedData.updatedAt),
      createdBy: updatedData.createdBy,
      updatedBy: updatedData.updatedBy,
    });
  } catch (error: any) {
    functions.logger.error('Error updating client:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to update client');
  }
});

/**
 * Delete a client (soft delete)
 * Function Name (Export): clientDelete
 * Callable Name (Internal): client.delete
 */
export const clientDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, clientId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!clientId || typeof clientId !== 'string' || clientId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Client ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'CLIENTS',
    requiredPermission: 'client.delete',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to delete clients');
    }
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'CLIENTS feature not available in current plan');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to delete client');
  }

  try {
    const clientRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .doc(clientId);

    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    const clientData = clientDoc.data() as ClientDocument;

    // Check if already soft-deleted
    if (clientData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }

    // Verify client belongs to org
    if (clientData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Client does not belong to this organization');
    }

    // Check for associated cases (conflict check)
    const casesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .where('clientId', '==', clientId)
      .where('deletedAt', '==', null)
      .limit(1)
      .get();

    if (!casesSnapshot.empty) {
      return errorResponse(ErrorCode.CONFLICT, 'Cannot delete client with associated cases. Please remove client from all cases first.');
    }

    // Soft delete
    const now = admin.firestore.Timestamp.now();
    await clientRef.update({
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
    });

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'client.deleted',
      entityType: 'client',
      entityId: clientId,
      metadata: {
        name: clientData.name,
      },
    });

    return successResponse({
      clientId,
      message: 'Client deleted successfully',
    });
  } catch (error: any) {
    functions.logger.error('Error deleting client:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to delete client');
  }
});
