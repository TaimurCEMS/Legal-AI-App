/**
 * Case Management Functions (Slice 2 - Case Hub)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { canUserAccessCase } from '../utils/case-access';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface CaseDocument {
  id: string;
  orgId: string;
  title: string;
  description?: string | null;
  clientId?: string | null;
  visibility: 'ORG_WIDE' | 'PRIVATE';
  status: 'OPEN' | 'CLOSED' | 'ARCHIVED';
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

function parseTitle(rawTitle: unknown): string | null {
  if (typeof rawTitle !== 'string') return null;
  const trimmed = rawTitle.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function parseDescription(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length > 2000) return null;
  return trimmed || null;
}

function parseVisibility(raw: unknown): 'ORG_WIDE' | 'PRIVATE' | null {
  if (raw == null) return 'ORG_WIDE';
  if (raw === 'ORG_WIDE' || raw === 'PRIVATE') return raw;
  return null;
}

function parseStatus(raw: unknown): 'OPEN' | 'CLOSED' | 'ARCHIVED' | null {
  if (raw == null) return 'OPEN';
  if (raw === 'OPEN' || raw === 'CLOSED' || raw === 'ARCHIVED') return raw;
  return null;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

async function getClientName(orgId: string, clientId?: string | null): Promise<string | null> {
  if (!clientId) return null;
  const clientRef = db
    .collection('organizations')
    .doc(orgId)
    .collection('clients')
    .doc(clientId);

  const clientDoc = await clientRef.get();
  if (!clientDoc.exists) {
    return null;
  }
  const data = clientDoc.data() as { name?: string };
  return data?.name || null;
}

/**
 * Create a new case
 * Callable Name: case.create
 */
export const caseCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, title, description, clientId, visibility, status } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const sanitizedTitle = parseTitle(title);
  if (!sanitizedTitle) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case title must be 1-200 characters'
    );
  }

  const sanitizedDescription = parseDescription(description);
  if (description && sanitizedDescription === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case description must be 2000 characters or less'
    );
  }

  const parsedVisibility = parseVisibility(visibility);
  if (!parsedVisibility) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Visibility must be ORG_WIDE or PRIVATE'
    );
  }

  const parsedStatus = parseStatus(status);
  if (!parsedStatus) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Status must be OPEN, CLOSED, or ARCHIVED'
    );
  }

  try {
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CASES',
      requiredPermission: 'case.create',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to create cases for this organization'
      );
    }

    // Validate client if provided
    let validatedClientId: string | null = null;
    if (clientId) {
      if (typeof clientId !== 'string' || clientId.trim().length === 0) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Client ID must be a non-empty string'
        );
      }

      const clientRef = db
        .collection('organizations')
        .doc(orgId)
        .collection('clients')
        .doc(clientId);
      const clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        return errorResponse(
          ErrorCode.NOT_FOUND,
          'Client does not exist for this organization'
        );
      }
      validatedClientId = clientId;
    }

    const now = admin.firestore.Timestamp.now();
    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc();

    const caseId = caseRef.id;

    const caseDoc: CaseDocument = {
      id: caseId,
      orgId,
      title: sanitizedTitle,
      ...(sanitizedDescription && { description: sanitizedDescription }),
      ...(validatedClientId && { clientId: validatedClientId }),
      visibility: parsedVisibility,
      status: parsedStatus,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      updatedBy: uid,
      deletedAt: null,
    };

    await caseRef.set(caseDoc);

    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'case.created',
      entityType: 'case',
      entityId: caseId,
      metadata: {
        title: sanitizedTitle,
        visibility: parsedVisibility,
        clientId: validatedClientId || null,
      },
    });

    const clientName = await getClientName(orgId, validatedClientId);

    return successResponse({
      caseId,
      orgId,
      title: sanitizedTitle,
      description: sanitizedDescription ?? null,
      clientId: validatedClientId,
      clientName,
      visibility: parsedVisibility,
      status: parsedStatus,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      updatedBy: uid,
      deletedAt: null,
    });
  } catch (error) {
    functions.logger.error('Error creating case:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to create case'
    );
  }
});

/**
 * Get case details
 * Callable Name: case.get
 */
export const caseGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case ID is required'
    );
  }

  try {
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CASES',
      requiredPermission: 'case.read',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to view cases for this organization'
      );
    }

    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);

    const caseSnap = await caseRef.get();
    if (!caseSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case not found'
      );
    }

    const caseData = caseSnap.data() as CaseDocument;

    if (caseData.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case not found'
      );
    }

    // Visibility and access check (supports PRIVATE case participants)
    if (caseData.visibility === 'PRIVATE') {
      const access = await canUserAccessCase(orgId, caseId, uid);
      if (!access.allowed) {
        if (access.reason === 'Case not found') {
          return errorResponse(
            ErrorCode.NOT_FOUND,
            'Case not found'
          );
        }

        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          access.reason || 'You are not allowed to view this private case'
        );
      }
    }

    const clientName = await getClientName(orgId, caseData.clientId);

    return successResponse({
      caseId: caseData.id,
      orgId: caseData.orgId,
      title: caseData.title,
      description: caseData.description ?? null,
      clientId: caseData.clientId ?? null,
      clientName,
      visibility: caseData.visibility,
      status: caseData.status,
      createdAt: toIso(caseData.createdAt),
      updatedAt: toIso(caseData.updatedAt),
      createdBy: caseData.createdBy,
      updatedBy: caseData.updatedBy,
      deletedAt: null,
    });
  } catch (error) {
    functions.logger.error('Error getting case:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to get case'
    );
  }
});

/**
 * List cases for an organization with basic filtering and pagination.
 * Callable Name: case.list
 *
 * NOTE: For MVP this uses offset-based pagination and in-memory merge.
 */
export const caseList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, limit, offset, status, clientId, search } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const pageSize = typeof limit === 'number' ? limit : 50;
  if (pageSize < 1 || pageSize > 100) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Limit must be between 1 and 100'
    );
  }

  const pageOffset = typeof offset === 'number' ? offset : 0;
  if (pageOffset < 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Offset must be greater than or equal to 0'
    );
  }

  const parsedStatus = status ? parseStatus(status) : null;
  if (status && !parsedStatus) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Status filter must be OPEN, CLOSED, or ARCHIVED'
    );
  }

  try {
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CASES',
      requiredPermission: 'case.read',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to view cases for this organization'
      );
    }

    // Build base queries for ORG_WIDE and PRIVATE cases where the user is the creator.
    // PRIVATE cases where the user is an explicit participant are added below via
    // a collection group query on the "participants" subcollection.
    let orgWideQuery: FirebaseFirestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .where('visibility', '==', 'ORG_WIDE')
      .where('deletedAt', '==', null);

    let privateQuery: FirebaseFirestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .where('visibility', '==', 'PRIVATE')
      .where('createdBy', '==', uid)
      .where('deletedAt', '==', null);

    if (parsedStatus) {
      orgWideQuery = orgWideQuery.where('status', '==', parsedStatus);
      privateQuery = privateQuery.where('status', '==', parsedStatus);
    }

    if (clientId) {
      orgWideQuery = orgWideQuery.where('clientId', '==', clientId);
      privateQuery = privateQuery.where('clientId', '==', clientId);
    }

    // For MVP, do search in memory (contains on title, case-insensitive)
    // to avoid complex Firestore range + index constraints.

    orgWideQuery = orgWideQuery.orderBy('updatedAt', 'desc');
    privateQuery = privateQuery.orderBy('updatedAt', 'desc');

    const [orgWideSnap, privateSnap] = await Promise.all([
      orgWideQuery.get(),
      privateQuery.get(),
    ]);

    const allCases: CaseDocument[] = [];

    orgWideSnap.forEach((doc) => {
      allCases.push(doc.data() as CaseDocument);
    });

    privateSnap.forEach((doc) => {
      allCases.push(doc.data() as CaseDocument);
    });

    // Also include PRIVATE cases where the user is an explicit participant.
    // This allows participants (not just creators) to see private cases.
    const existingCaseIds = new Set(allCases.map((c) => c.id));

    const participantsSnap = await db
      .collectionGroup('participants')
      .where('uid', '==', uid)
      .get();

    const participantCaseIds = new Set<string>();
    participantsSnap.forEach((doc) => {
      // Path: organizations/{orgId}/cases/{caseId}/participants/{uid}
      const parts = doc.ref.path.split('/');
      if (
        parts.length >= 6 &&
        parts[0] === 'organizations' &&
        parts[1] === orgId &&
        parts[2] === 'cases'
      ) {
        const caseId = parts[3];
        if (!existingCaseIds.has(caseId)) {
          participantCaseIds.add(caseId);
        }
      }
    });

    if (participantCaseIds.size > 0) {
      const caseRefs = Array.from(participantCaseIds).map((caseId) =>
        db
          .collection('organizations')
          .doc(orgId)
          .collection('cases')
          .doc(caseId)
      );
      const caseSnaps = await db.getAll(...caseRefs);

      caseSnaps.forEach((snap) => {
        if (!snap.exists) return;
        const data = snap.data() as CaseDocument;
        // Only include non-deleted PRIVATE cases
        if (!data.deletedAt && data.visibility === 'PRIVATE') {
          allCases.push(data);
          existingCaseIds.add(data.id);
        }
      });
    }

    // Sort merged results by updatedAt desc (defensive, queries already sorted)
    allCases.sort(
      (a, b) => b.updatedAt.toMillis() - a.updatedAt.toMillis()
    );

    // In-memory search filter on title if search provided
    let filteredCases = allCases;
    if (typeof search === 'string' && search.trim().length > 0) {
      const term = search.trim().toLowerCase();
      filteredCases = allCases.filter((c) =>
        c.title.toLowerCase().includes(term)
      );
    }

    const total = filteredCases.length;
    const pagedCases = filteredCases.slice(
      pageOffset,
      pageOffset + pageSize
    );
    const hasMore = pageOffset + pageSize < total;

    // Batch client name lookup
    const clientIds = Array.from(
      new Set(
        pagedCases
          .map((c) => c.clientId)
          .filter((id): id is string => !!id)
      )
    );

    const clientNames = new Map<string, string>();
    if (clientIds.length > 0) {
      const clientRefs = clientIds.map((id) =>
        db
          .collection('organizations')
          .doc(orgId)
          .collection('clients')
          .doc(id)
      );
      const clientSnaps = await db.getAll(...clientRefs);
      clientSnaps.forEach((snap) => {
        if (snap.exists) {
          const data = snap.data() as { name?: string; id?: string };
          const id = snap.id;
          if (data?.name) {
            clientNames.set(id, data.name);
          }
        }
      });
    }

    const cases = pagedCases.map((c) => ({
      caseId: c.id,
      orgId: c.orgId,
      title: c.title,
      description: c.description ?? null,
      clientId: c.clientId ?? null,
      clientName: c.clientId ? clientNames.get(c.clientId) ?? null : null,
      visibility: c.visibility,
      status: c.status,
      createdAt: toIso(c.createdAt),
      updatedAt: toIso(c.updatedAt),
      createdBy: c.createdBy,
    }));

    return successResponse({
      cases,
      total,
      hasMore,
    });
  } catch (error: any) {
    functions.logger.error('Error listing cases:', error);
    functions.logger.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack,
      orgId,
      uid,
    });
    
    // Provide more specific error message
    let errorMessage = 'Failed to list cases';
    if (error.code === 9 || error.message?.includes('index') || error.message?.includes('FAILED_PRECONDITION')) {
      errorMessage = 'Firestore index required. Please check Firebase Console → Firestore → Indexes and ensure all indexes are enabled.';
    } else if (error.code === 7 || error.message?.includes('permission') || error.message?.includes('PERMISSION_DENIED')) {
      errorMessage = 'Permission denied. Please check Firestore security rules.';
    } else if (error.message) {
      errorMessage = `Failed to list cases: ${error.message}`;
    }
    
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      errorMessage
    );
  }
});

/**
 * Update case
 * Callable Name: case.update
 */
export const caseUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    caseId,
    title,
    description,
    clientId,
    visibility,
    status,
  } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case ID is required'
    );
  }

  try {
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CASES',
      requiredPermission: 'case.update',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to update cases for this organization'
      );
    }

    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);

    const caseSnap = await caseRef.get();
    if (!caseSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case not found'
      );
    }

    const existing = caseSnap.data() as CaseDocument;
    if (existing.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case not found'
      );
    }

    // Visibility: only creator can update PRIVATE case in Slice 2
    if (
      existing.visibility === 'PRIVATE' &&
      existing.createdBy !== uid
    ) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to update this private case'
      );
    }

    const updates: Partial<CaseDocument> = {};

    if (title !== undefined) {
      const sanitizedTitle = parseTitle(title);
      if (!sanitizedTitle) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Case title must be 1-200 characters'
        );
      }
      updates.title = sanitizedTitle;
    }

    if (description !== undefined) {
      const sanitizedDescription = parseDescription(description);
      if (description && sanitizedDescription === null) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Case description must be 2000 characters or less'
        );
      }
      if (sanitizedDescription === null) {
        updates.description = admin.firestore.FieldValue.delete() as any;
      } else {
        updates.description = sanitizedDescription;
      }
    }

    if (visibility !== undefined) {
      const parsedVisibility = parseVisibility(visibility);
      if (!parsedVisibility) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Visibility must be ORG_WIDE or PRIVATE'
        );
      }
      updates.visibility = parsedVisibility;
    }

    if (status !== undefined) {
      const parsedStatus = parseStatus(status);
      if (!parsedStatus) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Status must be OPEN, CLOSED, or ARCHIVED'
        );
      }
      updates.status = parsedStatus;
    }

    if (clientId !== undefined) {
      if (clientId === null) {
        updates.clientId = admin.firestore.FieldValue.delete() as any;
      } else {
        if (typeof clientId !== 'string' || clientId.trim().length === 0) {
          return errorResponse(
            ErrorCode.VALIDATION_ERROR,
            'Client ID must be a non-empty string or null'
          );
        }

        const clientRef = db
          .collection('organizations')
          .doc(orgId)
          .collection('clients')
          .doc(clientId);
        const clientDoc = await clientRef.get();
        if (!clientDoc.exists) {
          return errorResponse(
            ErrorCode.NOT_FOUND,
            'Client does not exist for this organization'
          );
        }
        updates.clientId = clientId;
      }
    }

    if (Object.keys(updates).length === 0) {
      // Nothing to update
      return successResponse({ updated: false });
    }

    const now = admin.firestore.Timestamp.now();
    updates.updatedAt = now;
    updates.updatedBy = uid;

    await caseRef.update(updates);

    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'case.updated',
      entityType: 'case',
      entityId: caseId,
      metadata: {
        updatedFields: Object.keys(updates),
      },
    });

    const updatedSnap = await caseRef.get();
    const updated = updatedSnap.data() as CaseDocument;
    const clientName = await getClientName(orgId, updated.clientId);

    return successResponse({
      caseId: updated.id,
      orgId: updated.orgId,
      title: updated.title,
      description: updated.description ?? null,
      clientId: updated.clientId ?? null,
      clientName,
      visibility: updated.visibility,
      status: updated.status,
      createdAt: toIso(updated.createdAt),
      updatedAt: toIso(updated.updatedAt),
      createdBy: updated.createdBy,
      updatedBy: updated.updatedBy,
    });
  } catch (error) {
    functions.logger.error('Error updating case:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to update case'
    );
  }
});

/**
 * Soft delete case
 * Callable Name: case.delete
 */
export const caseDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case ID is required'
    );
  }

  try {
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CASES',
      requiredPermission: 'case.delete',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to delete cases for this organization'
      );
    }

    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);

    const caseSnap = await caseRef.get();
    if (!caseSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case not found'
      );
    }

    const existing = caseSnap.data() as CaseDocument;

    if (existing.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Case already deleted'
      );
    }

    // Visibility: only creator can delete PRIVATE case in Slice 2
    if (
      existing.visibility === 'PRIVATE' &&
      existing.createdBy !== uid
    ) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not allowed to delete this private case'
      );
    }

    const now = admin.firestore.Timestamp.now();

    await caseRef.update({
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
    } as Partial<CaseDocument>);

    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'case.deleted',
      entityType: 'case',
      entityId: caseId,
      metadata: {
        softDelete: true,
      },
    });

    return successResponse({
      caseId,
      deletedAt: toIso(now),
    });
  } catch (error) {
    functions.logger.error('Error deleting case:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to delete case'
    );
  }
});


