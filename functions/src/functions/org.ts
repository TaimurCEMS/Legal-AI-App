/**
 * Organization Management Functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { createAuditEvent } from '../utils/audit';

const db = admin.firestore();

/**
 * Create a new organization
 * Callable Name: org.create
 */
export const orgCreate = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { name, description } = data;

  // Validate orgName
  const sanitizedName = name?.trim();
  if (!sanitizedName || sanitizedName.length < 1 || sanitizedName.length > 100) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Organization name must be 1-100 characters'
    );
  }

  // Validate name pattern
  if (!/^[a-zA-Z0-9\s\-_&.,()]+$/.test(sanitizedName)) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Organization name contains invalid characters'
    );
  }

  // Validate description (optional)
  if (description && description.length > 500) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Organization description must be 500 characters or less'
    );
  }

  try {
    // Generate orgId using Firestore auto-ID
    const orgRef = db.collection('organizations').doc();
    const orgId = orgRef.id;
    const now = admin.firestore.Timestamp.now();

    // Create organization document
    await orgRef.set({
      id: orgId,
      name: sanitizedName,
      ...(description && { description: description.trim() }),
      plan: 'FREE',
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    });

    // Create membership document (user as ADMIN)
    const memberRef = orgRef.collection('members').doc(uid);
    await memberRef.set({
      uid,
      orgId,
      role: 'ADMIN',
      joinedAt: now,
      updatedAt: now,
      createdBy: uid,
    });

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'org.created',
      entityType: 'organization',
      entityId: orgId,
      metadata: {
        orgName: sanitizedName,
      },
    });

    return successResponse({
      orgId,
      name: sanitizedName,
      plan: 'FREE',
      createdAt: now.toDate().toISOString(),
      createdBy: uid,
    });
  } catch (error) {
    functions.logger.error('Error creating organization:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to create organization'
    );
  }
});

/**
 * Join an existing organization
 * Callable Name: org.join
 * Uses Firestore transaction for concurrency protection and idempotent behavior
 */
export const orgJoin = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Organization ID is required'
    );
  }

  try {
    // Check if org exists
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Organization does not exist'
      );
    }

    // Use Firestore transaction for concurrency protection
    const memberRef = orgRef.collection('members').doc(uid);
    const now = admin.firestore.Timestamp.now();

    const result = await db.runTransaction(async (transaction) => {
      const memberDoc = await transaction.get(memberRef);

      if (memberDoc.exists) {
        // Already a member - return success (idempotent)
        const memberData = memberDoc.data()!;
        return {
          success: true,
          data: {
            orgId,
            role: memberData.role,
            joinedAt: memberData.joinedAt.toDate().toISOString(),
            message: 'Already a member',
          },
        };
      }

      // Create new membership
      transaction.set(memberRef, {
        uid,
        orgId,
        role: 'VIEWER',
        joinedAt: now,
        updatedAt: now,
        createdBy: uid,
      });

      return {
        success: true,
        data: {
          orgId,
          role: 'VIEWER',
          joinedAt: now.toDate().toISOString(),
        },
      };
    });

    // Create audit event only if new membership was created
    const memberDoc = await memberRef.get();
    if (memberDoc.exists) {
      const memberData = memberDoc.data()!;
      // Only log if this is a new membership (check if joinedAt matches now)
      const joinedAt = memberData.joinedAt;
      if (joinedAt && Math.abs(joinedAt.toMillis() - now.toMillis()) < 1000) {
        await createAuditEvent({
          orgId,
          actorUid: uid,
          action: 'member.added',
          entityType: 'membership',
          entityId: uid,
          metadata: {
            role: 'VIEWER',
          },
        });
      }
    }

    return successResponse(result.data);
  } catch (error) {
    functions.logger.error('Error joining organization:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to join organization'
    );
  }
});
