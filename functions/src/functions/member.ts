/**
 * Membership Management Functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';

const db = admin.firestore();

/**
 * Get current user's membership information
 * Callable Name: member.getMyMembership
 */
export const memberGetMyMembership = functions.https.onCall(async (data, context) => {
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
    // Lookup membership document
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(uid);

    const memberDoc = await memberRef.get();

    if (!memberDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'You are not a member of this organization'
      );
    }

    // Lookup org document to get plan and name
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Organization does not exist'
      );
    }

    const memberData = memberDoc.data()!;
    const orgData = orgDoc.data()!;

    return successResponse({
      orgId,
      uid,
      role: memberData.role,
      plan: orgData.plan,
      joinedAt: memberData.joinedAt.toDate().toISOString(),
      orgName: orgData.name,
    });
  } catch (error) {
    functions.logger.error('Error getting membership:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to retrieve membership information'
    );
  }
});
