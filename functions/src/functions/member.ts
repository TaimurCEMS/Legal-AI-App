/**
 * Membership Management Functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { Role } from '../constants/permissions';

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

/**
 * List all members of an organization
 * Function Name (Export): memberListMembers
 * Callable Name (Internal): member.list
 */
export const memberListMembers = functions.https.onCall(async (data, context) => {
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
      ErrorCode.ORG_REQUIRED,
      'Organization ID is required'
    );
  }

  try {
    // Check entitlement: ADMIN only, TEAM_MEMBERS feature required
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TEAM_MEMBERS',
      requiredPermission: 'admin.manage_users',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          "You don't have permission to manage team members"
        );
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(
          ErrorCode.PLAN_LIMIT,
          'TEAM_MEMBERS feature not available in current plan'
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to list members'
      );
    }

    // Verify organization exists
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Organization does not exist'
      );
    }

    // Get all members
    const membersSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .get();

    if (membersSnapshot.empty) {
      return successResponse({
        members: [],
        totalCount: 0,
      });
    }

    // Extract all UIDs for batch lookup
    const uids = membersSnapshot.docs.map((doc) => doc.id);

    // Batch lookup user information from Firebase Auth
    const userInfoMap: Map<string, { email: string | null; displayName: string | null }> = new Map();
    try {
      const getUsersResult = await admin.auth().getUsers(uids.map((uid) => ({ uid })));
      getUsersResult.users.forEach((user) => {
        userInfoMap.set(user.uid, {
          email: user.email || null,
          displayName: user.displayName || null,
        });
      });
      // Handle deleted users (they won't be in the result)
      uids.forEach((uid) => {
        if (!userInfoMap.has(uid)) {
          userInfoMap.set(uid, { email: null, displayName: null });
        }
      });
    } catch (authError: any) {
      functions.logger.warn('Error fetching user info from Auth, continuing with null values:', authError);
      // Continue with null values if Auth lookup fails
      uids.forEach((uid) => {
        if (!userInfoMap.has(uid)) {
          userInfoMap.set(uid, { email: null, displayName: null });
        }
      });
    }

    // Build members array
    const members = membersSnapshot.docs.map((doc) => {
      const memberData = doc.data();
      const userInfo = userInfoMap.get(doc.id) || { email: null, displayName: null };
      
      return {
        uid: doc.id,
        email: userInfo.email,
        displayName: userInfo.displayName,
        role: memberData.role || 'VIEWER',
        joinedAt: memberData.joinedAt?.toDate()?.toISOString() || new Date().toISOString(),
        isCurrentUser: doc.id === uid,
      };
    });

    // Sort by role priority (ADMIN first, then LAWYER, PARALEGAL, VIEWER)
    // Within same role, sort by joinedAt (oldest first)
    const rolePriority: Record<Role, number> = {
      ADMIN: 1,
      LAWYER: 2,
      PARALEGAL: 3,
      VIEWER: 4,
    };

    members.sort((a, b) => {
      const roleA = (a.role as Role) || 'VIEWER';
      const roleB = (b.role as Role) || 'VIEWER';
      const priorityA = rolePriority[roleA] || 4;
      const priorityB = rolePriority[roleB] || 4;

      if (priorityA !== priorityB) {
        return priorityA - priorityB;
      }

      // Same role, sort by joinedAt (oldest first)
      return a.joinedAt.localeCompare(b.joinedAt);
    });

    return successResponse({
      members,
      totalCount: members.length,
    });
  } catch (error: any) {
    functions.logger.error('Error listing members:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to list members'
    );
  }
});

/**
 * Update a member's role
 * Function Name (Export): memberUpdateRole
 * Callable Name (Internal): member.update
 */
export const memberUpdateRole = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, memberUid, role } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(
      ErrorCode.ORG_REQUIRED,
      'Organization ID is required'
    );
  }

  // Validate memberUid
  if (!memberUid || typeof memberUid !== 'string' || memberUid.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Member UID is required'
    );
  }

  // Validate role
  const validRoles: Role[] = ['ADMIN', 'LAWYER', 'PARALEGAL', 'VIEWER'];
  if (!role || typeof role !== 'string' || !validRoles.includes(role as Role)) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Invalid role value. Must be one of: ADMIN, LAWYER, PARALEGAL, VIEWER'
    );
  }

  const newRole = role as Role;

  try {
    // Check entitlement: ADMIN only, TEAM_MEMBERS feature required
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TEAM_MEMBERS',
      requiredPermission: 'admin.manage_users',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          "You don't have permission to manage team members"
        );
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(
          ErrorCode.PLAN_LIMIT,
          'TEAM_MEMBERS feature not available in current plan'
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to update member roles'
      );
    }

    // Verify organization exists
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Organization does not exist'
      );
    }

    // Safety Check 1: Cannot change own role (prevent lockout)
    if (memberUid === uid) {
      return errorResponse(
        ErrorCode.SAFETY_ERROR,
        'You cannot change your own role'
      );
    }

    // Get target member document
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(memberUid);

    // Fetch current member data and all members (for admin count check)
    const [memberDoc, allMembersSnapshot] = await Promise.all([
      memberRef.get(),
      db.collection('organizations').doc(orgId).collection('members').get(),
    ]);

    if (!memberDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Member not found in this organization'
      );
    }

    const memberData = memberDoc.data()!;
    const currentRole = (memberData.role || 'VIEWER') as Role;

    // Safety Check 2: Role unchanged
    if (currentRole === newRole) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Role cannot be changed to the same value'
      );
    }

    // Safety Check 3: If changing from ADMIN, verify at least one other ADMIN exists
    if (currentRole === 'ADMIN') {
      let adminCount = 0;
      allMembersSnapshot.forEach((doc) => {
        const data = doc.data();
        if ((data.role || 'VIEWER') === 'ADMIN') {
          adminCount++;
        }
      });

      if (adminCount <= 1) {
        return errorResponse(
          ErrorCode.SAFETY_ERROR,
          'Cannot remove the last administrator. Please assign another member as administrator first.'
        );
      }
    }

    // Safety Check 4: Only ADMIN can assign ADMIN role
    if (newRole === 'ADMIN' && entitlement.role !== 'ADMIN') {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can assign the administrator role'
      );
    }

    // Use transaction for atomic update
    const result = await db.runTransaction(async (transaction) => {
      // Re-fetch member document in transaction to ensure it still exists and hasn't changed
      const memberDocInTransaction = await transaction.get(memberRef);

      if (!memberDocInTransaction.exists) {
        throw new Error('NOT_FOUND');
      }

      const memberDataInTransaction = memberDocInTransaction.data()!;
      const currentRoleInTransaction = (memberDataInTransaction.role || 'VIEWER') as Role;

      // Verify role hasn't changed since we checked
      if (currentRoleInTransaction !== currentRole) {
        throw new Error('VALIDATION_ERROR: Member role has changed. Please refresh and try again.');
      }

      // Update membership document
      const now = admin.firestore.Timestamp.now();
      transaction.update(memberRef, {
        role: newRole,
        updatedAt: now,
        updatedBy: uid,
      });

      return {
        previousRole: currentRole,
        newRole,
      };
    });

    // Get updated member data for response
    const updatedMemberDoc = await memberRef.get();
    const updatedMemberData = updatedMemberDoc.data()!;

    // Get user email for audit log
    let memberEmail: string | null = null;
    try {
      const userRecord = await admin.auth().getUser(memberUid);
      memberEmail = userRecord.email || null;
    } catch (authError) {
      functions.logger.warn('Could not fetch user email for audit log:', authError);
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'member.role.updated',
      entityType: 'membership',
      entityId: memberUid,
      metadata: {
        memberUid,
        previousRole: result.previousRole,
        newRole: result.newRole,
        memberEmail,
      },
    });

    return successResponse({
      uid: memberUid,
      orgId,
      role: result.newRole,
      previousRole: result.previousRole,
      updatedAt: updatedMemberData.updatedAt?.toDate()?.toISOString() || new Date().toISOString(),
      updatedBy: uid,
    });
  } catch (error: any) {
    functions.logger.error('Error updating member role:', error);

    // Handle transaction errors
    if (error.message?.startsWith('NOT_FOUND')) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Member not found in this organization'
      );
    }
    if (error.message?.startsWith('VALIDATION_ERROR')) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        error.message.split(': ')[1] || 'Invalid input'
      );
    }
    if (error.message?.startsWith('SAFETY_ERROR')) {
      return errorResponse(
        ErrorCode.SAFETY_ERROR,
        error.message.split(': ')[1] || 'Safety check failed'
      );
    }
    if (error.message?.startsWith('NOT_AUTHORIZED')) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        error.message.split(': ')[1] || 'Not authorized'
      );
    }

    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to update member role'
    );
  }
});
