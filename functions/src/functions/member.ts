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

/**
 * List all organizations the current user is a member of
 * Callable Name: memberListMyOrgs
 */
export const memberListMyOrgs = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;

  try {
    functions.logger.info(`memberListMyOrgs: Starting query for uid: ${uid}`);
    
    // Use collection group query to find all memberships for this user
    // This queries across all organizations/{orgId}/members collections
    let membershipsSnapshot;
    try {
      membershipsSnapshot = await db
        .collectionGroup('members')
        .where('uid', '==', uid)
        .get();
      functions.logger.info(`memberListMyOrgs: Query completed, found ${membershipsSnapshot.size} memberships`);
    } catch (queryError: any) {
      functions.logger.error('memberListMyOrgs: Collection group query failed:', queryError);
      // If collection group query fails due to missing index, return helpful error
      if (queryError.code === 9 || queryError.message?.includes('index') || queryError.message?.includes('FAILED_PRECONDITION')) {
        functions.logger.error('memberListMyOrgs: Index required. Error code:', queryError.code);
        return errorResponse(
          ErrorCode.INTERNAL_ERROR,
          'Collection group index required. Please create an index in Firebase Console: Collection Group "members", Field "uid" (Ascending). The index will be created automatically when you first run the query from the console.'
        );
      }
      throw queryError;
    }

    if (membershipsSnapshot.empty) {
      functions.logger.info(`memberListMyOrgs: No memberships found for uid: ${uid}`);
      return successResponse({
        orgs: [],
      });
    }

    // Extract org IDs from membership documents
    // The path is: organizations/{orgId}/members/{uid}
    const orgIds = new Set<string>();
    membershipsSnapshot.forEach((doc) => {
      // Extract orgId from document path: organizations/{orgId}/members/{uid}
      const pathParts = doc.ref.path.split('/');
      if (pathParts.length >= 2 && pathParts[0] === 'organizations') {
        orgIds.add(pathParts[1]);
      }
    });

    // Fetch org details for each orgId
    const orgPromises = Array.from(orgIds).map(async (orgId) => {
      try {
        const orgDoc = await db.collection('organizations').doc(orgId).get();
        if (!orgDoc.exists) {
          return null;
        }

        const orgData = orgDoc.data()!;
        const memberDoc = membershipsSnapshot.docs.find((doc) => {
          const pathParts = doc.ref.path.split('/');
          return pathParts.length >= 2 && pathParts[1] === orgId;
        });

        const memberData = memberDoc?.data();

        return {
          orgId,
          name: orgData.name,
          description: orgData.description || null,
          plan: orgData.plan || 'FREE',
          role: memberData?.role || 'VIEWER',
          joinedAt: memberData?.joinedAt?.toDate()?.toISOString() || null,
        };
      } catch (error) {
        functions.logger.error(`Error fetching org ${orgId}:`, error);
        return null;
      }
    });

    const orgs = (await Promise.all(orgPromises)).filter(
      (org) => org !== null
    ) as Array<{
      orgId: string;
      name: string;
      description: string | null;
      plan: string;
      role: string;
      joinedAt: string | null;
    }>;

    // Sort by joinedAt (most recent first) or by name
    orgs.sort((a, b) => {
      if (a.joinedAt && b.joinedAt) {
        return b.joinedAt.localeCompare(a.joinedAt);
      }
      return a.name.localeCompare(b.name);
    });

    return successResponse({
      orgs,
    });
  } catch (error: any) {
    functions.logger.error('Error listing user orgs:', error);
    functions.logger.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack,
    });
    
    // Return more specific error message
    const errorMessage = error.message || 'Failed to retrieve organizations';
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      `Failed to retrieve organizations: ${errorMessage}`
    );
  }
});
