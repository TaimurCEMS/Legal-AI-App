/**
 * Member Invitation Functions (Slice 15)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { Role } from '../constants/permissions';
import { emitDomainEventWithOutbox } from '../utils/domain-events';

const db = admin.firestore();

/**
 * Generate a unique 8-character invite code
 */
function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Remove ambiguous characters
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Create a new invitation
 * Callable Name: invitationCreate
 */
export const invitationCreate = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, email, role } = data;

  // Validate inputs
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Valid email is required');
  }

  // Validate role - cannot invite as ADMIN
  const validRoles: Role[] = ['LAWYER', 'PARALEGAL', 'VIEWER'];
  if (!role || typeof role !== 'string' || !validRoles.includes(role as Role)) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Invalid role. Must be one of: LAWYER, PARALEGAL, VIEWER'
    );
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.manage_users',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can send invitations'
      );
    }

    // Check if organization exists
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Organization does not exist');
    }

    // Check for duplicate pending invitation
    const existingInvitesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('invitations')
      .where('email', '==', email.toLowerCase())
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (!existingInvitesSnapshot.empty) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'An invitation is already pending for this email'
      );
    }

    // Check if user already a member
    try {
      const authUser = await admin.auth().getUserByEmail(email);
      const memberRef = db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(authUser.uid);
      const memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'This user is already a member of the organization'
        );
      }
    } catch (authError: any) {
      // User doesn't exist in Firebase Auth, which is fine for invitations
      functions.logger.info(`User with email ${email} not found in Auth, continuing with invitation`);
    }

    // Generate unique invite code (simple random, collision very unlikely with 8 chars)
    const inviteCode = generateInviteCode();
    
    // Note: We skip collectionGroup uniqueness check to avoid index requirement.
    // With 8-char alphanumeric code from 32 chars, collision is extremely rare.

    // Create invitation document
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 7 * 24 * 60 * 60 * 1000 // 7 days
    );

    const invitationRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('invitations')
      .doc();

    const invitationData = {
      invitationId: invitationRef.id,
      orgId,
      email: email.toLowerCase(),
      role,
      inviteCode,
      status: 'pending',
      invitedBy: uid,
      invitedAt: now,
      expiresAt,
    };

    await invitationRef.set(invitationData);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'invitation.created',
      entityType: 'invitation',
      entityId: invitationRef.id,
      metadata: {
        email: email.toLowerCase(),
        role,
        inviteCode,
      },
    });

    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'user.invited',
      entityType: 'invitation',
      entityId: invitationRef.id,
      actor: { actorType: 'user', actorId: uid },
      payload: { email: email.toLowerCase(), role },
    });

    functions.logger.info(`Invitation created: ${invitationRef.id} for ${email}`);

    return successResponse({
      invitationId: invitationRef.id,
      orgId,
      email: email.toLowerCase(),
      role,
      inviteCode,
      status: 'pending',
      invitedAt: now.toDate().toISOString(),
      expiresAt: expiresAt.toDate().toISOString(),
    });
  } catch (error: any) {
    const msg = error?.message ?? String(error);
    functions.logger.error('Error creating invitation:', error);
    if (msg.includes('index') || msg.includes('Index')) {
      return errorResponse(
        ErrorCode.INTERNAL_ERROR,
        'Invitation creation requires a Firestore index. Deploy indexes with: firebase deploy --only firestore:indexes'
      );
    }
    if (msg.includes('permission') || msg.includes('PERMISSION')) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Permission denied creating invitation. Verify you have ADMIN role.'
      );
    }
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      `Failed to create invitation: ${msg.substring(0, 100)}`
    );
  }
});

/**
 * Accept an invitation using invite code
 * Callable Name: invitationAccept
 */
export const invitationAccept = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { inviteCode } = data;

  // Validate invite code
  if (!inviteCode || typeof inviteCode !== 'string' || inviteCode.length !== 8) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Valid 8-character invite code is required');
  }

  try {
    // Find invitation by code (collection group query)
    const invitationSnapshot = await db
      .collectionGroup('invitations')
      .where('inviteCode', '==', inviteCode.toUpperCase())
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (invitationSnapshot.empty) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Invalid or expired invitation code'
      );
    }

    const invitationDoc = invitationSnapshot.docs[0];
    const invitationData = invitationDoc.data();
    const invitationRef = invitationDoc.ref;

    // Extract orgId from path: organizations/{orgId}/invitations/{invitationId}
    const pathParts = invitationRef.path.split('/');
    const orgId = pathParts[1];

    // Check if invitation has expired
    const now = admin.firestore.Timestamp.now();
    if (invitationData.expiresAt.toMillis() < now.toMillis()) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'This invitation has expired'
      );
    }

    // Get user email from Firebase Auth
    const userRecord = await admin.auth().getUser(uid);
    const userEmail = userRecord.email?.toLowerCase() || '';

    // Verify email matches invitation
    if (userEmail !== invitationData.email) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'This invitation is for a different email address'
      );
    }

    // Check if user is already a member
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(uid);

    const memberDoc = await memberRef.get();

    if (memberDoc.exists) {
      // Mark invitation as accepted even though user was already a member
      await invitationRef.update({
        status: 'accepted',
        acceptedAt: now,
        acceptedBy: uid,
      });

      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'You are already a member of this organization'
      );
    }

    // Use transaction to add member and update invitation
    await db.runTransaction(async (transaction) => {
      // Re-check invitation status
      const inviteDocInTransaction = await transaction.get(invitationRef);
      if (!inviteDocInTransaction.exists || inviteDocInTransaction.data()?.status !== 'pending') {
        throw new Error('VALIDATION_ERROR: Invitation is no longer valid');
      }

      // Create membership
      transaction.set(memberRef, {
        uid,
        role: invitationData.role,
        joinedAt: now,
      });

      // Update invitation status
      transaction.update(invitationRef, {
        status: 'accepted',
        acceptedAt: now,
        acceptedBy: uid,
      });
    });

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'invitation.accepted',
      entityType: 'invitation',
      entityId: invitationDoc.id,
      metadata: {
        email: invitationData.email,
        role: invitationData.role,
        inviteCode,
      },
    });

    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'user.joined',
      entityType: 'invitation',
      entityId: invitationDoc.id,
      actor: { actorType: 'user', actorId: uid },
      payload: { email: invitationData.email, role: invitationData.role },
    });

    // Get org details for response
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();

    functions.logger.info(`Invitation accepted: ${invitationDoc.id} by ${uid}`);

    return successResponse({
      orgId,
      orgName: orgData?.name || '',
      role: invitationData.role,
      joinedAt: now.toDate().toISOString(),
    });
  } catch (error: any) {
    functions.logger.error('Error accepting invitation:', error);

    if (error.message?.startsWith('VALIDATION_ERROR')) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        error.message.split(': ')[1] || 'Invitation is no longer valid'
      );
    }

    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to accept invitation');
  }
});

/**
 * Revoke a pending invitation
 * Callable Name: invitationRevoke
 */
export const invitationRevoke = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, invitationId } = data;

  // Validate inputs
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!invitationId || typeof invitationId !== 'string' || invitationId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invitation ID is required');
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.manage_users',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can revoke invitations'
      );
    }

    // Get invitation document
    const invitationRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('invitations')
      .doc(invitationId);

    const invitationDoc = await invitationRef.get();

    if (!invitationDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Invitation not found');
    }

    const invitationData = invitationDoc.data()!;

    // Check if invitation is already revoked or accepted
    if (invitationData.status === 'revoked') {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Invitation is already revoked'
      );
    }

    if (invitationData.status === 'accepted') {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Cannot revoke an accepted invitation'
      );
    }

    // Update invitation status
    const now = admin.firestore.Timestamp.now();
    await invitationRef.update({
      status: 'revoked',
      revokedAt: now,
      revokedBy: uid,
    });

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'invitation.revoked',
      entityType: 'invitation',
      entityId: invitationId,
      metadata: {
        email: invitationData.email,
        role: invitationData.role,
        inviteCode: invitationData.inviteCode,
      },
    });

    functions.logger.info(`Invitation revoked: ${invitationId} by ${uid}`);

    return successResponse({
      invitationId,
      status: 'revoked',
      revokedAt: now.toDate().toISOString(),
    });
  } catch (error: any) {
    functions.logger.error('Error revoking invitation:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to revoke invitation');
  }
});

/**
 * List invitations for an organization
 * Callable Name: invitationList
 */
export const invitationList = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, status, limit = 50, offset = 0 } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.manage_users',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can view invitations'
      );
    }

    // Validate status if provided (filter applied in memory to avoid composite index)
    if (status && typeof status === 'string') {
      const validStatuses = ['pending', 'accepted', 'revoked', 'expired'];
      if (!validStatuses.includes(status)) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Invalid status. Must be one of: pending, accepted, revoked, expired'
        );
      }
    }

    // Query: orderBy only (no status where) so no composite index required
    const fetchLimit = status ? Math.min(200, limit + offset + 50) : limit + offset;
    const snapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('invitations')
      .orderBy('invitedAt', 'desc')
      .limit(fetchLimit)
      .get();

    const now = admin.firestore.Timestamp.now();

    // Build invitations with optional expiresAt (avoid throw on missing field)
    let list = snapshot.docs.map((doc) => {
      const data = doc.data();
      const expiresAtTs = data.expiresAt?.toMillis?.() ?? 0;
      let currentStatus = data.status;
      if (currentStatus === 'pending' && expiresAtTs > 0 && expiresAtTs < now.toMillis()) {
        currentStatus = 'expired';
      }
      return {
        invitationId: doc.id,
        email: data.email,
        role: data.role,
        status: currentStatus,
        inviteCode: data.inviteCode,
        invitedBy: data.invitedBy,
        invitedAt: data.invitedAt?.toDate()?.toISOString() || null,
        expiresAt: data.expiresAt?.toDate()?.toISOString() || null,
        acceptedAt: data.acceptedAt?.toDate()?.toISOString() || null,
        acceptedBy: data.acceptedBy || null,
        revokedAt: data.revokedAt?.toDate()?.toISOString() || null,
        revokedBy: data.revokedBy || null,
      };
    });

    // Filter by status in memory when provided
    if (status && typeof status === 'string') {
      list = list.filter((inv) => inv.status === status);
    }

    const totalCount = list.length;
    const invitations = list.slice(offset, offset + limit);
    const hasMore = offset + limit < totalCount;

    return successResponse({
      invitations,
      totalCount,
      hasMore,
    });
  } catch (error: any) {
    const msg = error?.message ?? String(error);
    functions.logger.error('Error listing invitations:', error);
    if (msg.includes('index') || msg.includes('CREATE INDEX')) {
      return errorResponse(
        ErrorCode.INTERNAL_ERROR,
        'Invitation list requires a Firestore index. Deploy with: firebase deploy --only firestore:indexes'
      );
    }
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to list invitations');
  }
});
