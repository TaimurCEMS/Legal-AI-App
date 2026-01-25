/**
 * Case Participants Functions (Slice 5.5 - Case Hub)
 *
 * These functions manage explicit participants on PRIVATE cases.
 * They build on the centralized case access helper to ensure that:
 * - Only users who can access the case can list participants
 * - Only the case creator can add/remove participants
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

interface CaseParticipantDocument {
  uid: string;
  displayName?: string | null;
  email?: string | null;
  role: 'PARTICIPANT';
  addedAt: FirestoreTimestamp;
  addedBy: string;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

/**
 * List participants for a PRIVATE case.
 * Callable name: caseListParticipants
 */
export const caseListParticipants = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
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
    // Basic entitlement: user must be allowed to read cases
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

    // Check case access (handles PRIVATE vs ORG_WIDE as well as deleted cases)
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
        access.reason || 'You are not allowed to view participants for this case'
      );
    }

    // Participants are only defined for PRIVATE cases; for ORG_WIDE just return empty list
    if (access.caseData?.visibility !== 'PRIVATE') {
      return successResponse({
        participants: [],
      });
    }

    const participantsRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId)
      .collection('participants');

    const snapshot = await participantsRef
      .orderBy('addedAt', 'asc')
      .get();

    if (snapshot.empty) {
      return successResponse({
        participants: [],
      });
    }

    const participants = snapshot.docs.map((doc) => {
      const data = doc.data() as CaseParticipantDocument;
      return {
        uid: data.uid,
        displayName: data.displayName ?? null,
        email: data.email ?? null,
        role: data.role || 'PARTICIPANT',
        addedAt: toIso(data.addedAt),
        addedBy: data.addedBy,
      };
    });

    return successResponse({
      participants,
    });
  } catch (error) {
    functions.logger.error('Error listing case participants:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to list case participants'
    );
  }
});

/**
 * Add a participant to a PRIVATE case.
 * Callable name: caseAddParticipant
 */
export const caseAddParticipant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, caseId, participantUid } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case ID is required'
    );
  }

  if (
    !participantUid ||
    typeof participantUid !== 'string' ||
    participantUid.trim().length === 0
  ) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Participant UID is required'
    );
  }

  try {
    // User must be allowed to update cases
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

    // Check case access / ownership
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
        access.reason || 'You are not allowed to modify this case'
      );
    }

    // Only the creator can manage participants for PRIVATE cases
    if (
      access.caseData?.visibility !== 'PRIVATE' ||
      !access.caseData.createdBy ||
      access.caseData.createdBy !== uid
    ) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only the case creator can manage participants for this case'
      );
    }

    // Participant must be a member of the organization
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(participantUid);

    const memberDoc = await memberRef.get();
    if (!memberDoc.exists) {
      return errorResponse(
        ErrorCode.ASSIGNEE_NOT_MEMBER,
        'Participant must be a member of the organization'
      );
    }

    // Look up basic user info for display
    let displayName: string | null = null;
    let email: string | null = null;
    try {
      const userRecord = await admin.auth().getUser(participantUid);
      displayName = userRecord.displayName || null;
      email = userRecord.email || null;
    } catch (authError) {
      functions.logger.warn(
        'caseAddParticipant: Failed to fetch user from Auth, continuing with null display fields',
        authError
      );
    }

    const now = admin.firestore.Timestamp.now();

    const participantRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId)
      .collection('participants')
      .doc(participantUid);

    const participantDoc: CaseParticipantDocument = {
      uid: participantUid,
      displayName,
      email,
      role: 'PARTICIPANT',
      addedAt: now,
      addedBy: uid,
    };

    await participantRef.set(participantDoc, { merge: true });

    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'case.participant.added',
      entityType: 'case',
      entityId: caseId,
      metadata: {
        participantUid,
        participantEmail: email,
        participantDisplayName: displayName,
      },
    });

    return successResponse({
      uid: participantUid,
      addedAt: toIso(now),
      addedBy: uid,
    });
  } catch (error) {
    functions.logger.error('Error adding case participant:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to add participant'
    );
  }
});

/**
 * Remove a participant from a PRIVATE case.
 * Callable name: caseRemoveParticipant
 */
export const caseRemoveParticipant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId, caseId, participantUid } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Case ID is required'
    );
  }

  if (
    !participantUid ||
    typeof participantUid !== 'string' ||
    participantUid.trim().length === 0
  ) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Participant UID is required'
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
        access.reason || 'You are not allowed to modify this case'
      );
    }

    // Only the creator can remove participants
    if (
      access.caseData?.visibility !== 'PRIVATE' ||
      !access.caseData.createdBy ||
      access.caseData.createdBy !== uid
    ) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only the case creator can manage participants for this case'
      );
    }

    const participantRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId)
      .collection('participants')
      .doc(participantUid);

    const participantSnap = await participantRef.get();
    if (!participantSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Participant not found on this case'
      );
    }

    const participantData = participantSnap.data() as CaseParticipantDocument;

    await participantRef.delete();

    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'case.participant.removed',
      entityType: 'case',
      entityId: caseId,
      metadata: {
        participantUid,
        participantEmail: participantData.email ?? null,
        participantDisplayName: participantData.displayName ?? null,
      },
    });

    return successResponse({
      uid: participantUid,
      removed: true,
    });
  } catch (error) {
    functions.logger.error('Error removing case participant:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to remove participant'
    );
  }
});

