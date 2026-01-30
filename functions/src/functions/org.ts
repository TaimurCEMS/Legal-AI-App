/**
 * Organization Management Functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { createAuditEvent } from '../utils/audit';
import { checkEntitlement } from '../utils/entitlements';

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

/**
 * Update organization settings (Slice 15)
 * Callable Name: orgUpdate
 */
export const orgUpdate = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const {
    orgId,
    name,
    description,
    timezone,
    businessHours,
    defaultCaseVisibility,
    defaultTaskVisibility,
    website,
    address,
  } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.manage_org',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can update organization settings'
      );
    }

    // Check if organization exists
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Organization does not exist');
    }

    // Build update object
    const updates: any = {
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: uid,
    };

    // Validate and add name
    if (name !== undefined) {
      const sanitizedName = name?.trim();
      if (!sanitizedName || sanitizedName.length < 1 || sanitizedName.length > 100) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Organization name must be 1-100 characters'
        );
      }
      if (!/^[a-zA-Z0-9\s\-_&.,()]+$/.test(sanitizedName)) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Organization name contains invalid characters'
        );
      }
      updates.name = sanitizedName;
    }

    // Validate and add description
    if (description !== undefined) {
      if (description === null || description === '') {
        updates.description = admin.firestore.FieldValue.delete();
      } else if (description.length > 500) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Organization description must be 500 characters or less'
        );
      } else {
        updates.description = description.trim();
      }
    }

    // Add timezone
    if (timezone !== undefined) {
      if (timezone === null || timezone === '') {
        updates.timezone = admin.firestore.FieldValue.delete();
      } else {
        updates.timezone = timezone;
      }
    }

    // Add business hours
    if (businessHours !== undefined) {
      if (businessHours === null) {
        updates.businessHours = admin.firestore.FieldValue.delete();
      } else if (typeof businessHours === 'object' && businessHours.start && businessHours.end) {
        updates.businessHours = businessHours;
      } else {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Business hours must include start and end times'
        );
      }
    }

    // Add default case visibility
    if (defaultCaseVisibility !== undefined) {
      if (defaultCaseVisibility === null) {
        updates.defaultCaseVisibility = admin.firestore.FieldValue.delete();
      } else if (['ORG_WIDE', 'PRIVATE'].includes(defaultCaseVisibility)) {
        updates.defaultCaseVisibility = defaultCaseVisibility;
      } else {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Default case visibility must be ORG_WIDE or PRIVATE'
        );
      }
    }

    // Add default task visibility
    if (defaultTaskVisibility !== undefined) {
      if (defaultTaskVisibility === null) {
        updates.defaultTaskVisibility = admin.firestore.FieldValue.delete();
      } else {
        updates.defaultTaskVisibility = !!defaultTaskVisibility;
      }
    }

    // Add website
    if (website !== undefined) {
      if (website === null || website === '') {
        updates.website = admin.firestore.FieldValue.delete();
      } else {
        updates.website = website.trim();
      }
    }

    // Add address
    if (address !== undefined) {
      if (address === null) {
        updates.address = admin.firestore.FieldValue.delete();
      } else if (typeof address === 'object') {
        updates.address = address;
      }
    }

    // Update organization document
    await orgRef.update(updates);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'org.updated',
      entityType: 'organization',
      entityId: orgId,
      metadata: {
        updatedFields: Object.keys(updates).filter((key) => key !== 'updatedAt' && key !== 'updatedBy'),
      },
    });

    // Get updated organization data
    const updatedOrgDoc = await orgRef.get();
    const updatedOrgData = updatedOrgDoc.data()!;

    functions.logger.info(`Organization updated: ${orgId} by ${uid}`);

    return successResponse({
      orgId,
      name: updatedOrgData.name,
      description: updatedOrgData.description || null,
      timezone: updatedOrgData.timezone || null,
      businessHours: updatedOrgData.businessHours || null,
      defaultCaseVisibility: updatedOrgData.defaultCaseVisibility || null,
      defaultTaskVisibility: updatedOrgData.defaultTaskVisibility || null,
      website: updatedOrgData.website || null,
      address: updatedOrgData.address || null,
      updatedAt: updatedOrgData.updatedAt?.toDate()?.toISOString() || null,
    });
  } catch (error: any) {
    functions.logger.error('Error updating organization:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to update organization');
  }
});

/**
 * Get organization settings with defaults (Slice 15)
 * Callable Name: orgGetSettings
 */
export const orgGetSettings = functions.https.onCall(async (data, context) => {
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
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  try {
    // Check if user is a member of the organization
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(uid);

    const memberDoc = await memberRef.get();

    if (!memberDoc.exists) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'You are not a member of this organization'
      );
    }

    // Get organization document
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Organization does not exist');
    }

    const orgData = orgDoc.data()!;

    // Return settings with defaults
    return successResponse({
      orgId,
      name: orgData.name,
      description: orgData.description || null,
      plan: orgData.plan || 'FREE',
      timezone: orgData.timezone || 'UTC',
      businessHours: orgData.businessHours || { start: '09:00', end: '17:00' },
      defaultCaseVisibility: orgData.defaultCaseVisibility || 'ORG_WIDE',
      defaultTaskVisibility: orgData.defaultTaskVisibility || false,
      website: orgData.website || null,
      address: orgData.address || null,
      createdAt: orgData.createdAt?.toDate()?.toISOString() || null,
      updatedAt: orgData.updatedAt?.toDate()?.toISOString() || null,
    });
  } catch (error: any) {
    functions.logger.error('Error getting organization settings:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to get organization settings');
  }
});
