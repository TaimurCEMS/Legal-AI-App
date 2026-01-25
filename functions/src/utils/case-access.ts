import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface CaseAccessResult {
  allowed: boolean;
  reason?: string;
  caseData?: {
    visibility?: 'ORG_WIDE' | 'PRIVATE';
    createdBy?: string;
    deletedAt?: FirestoreTimestamp | null;
  };
}

/**
 * Centralized helper for determining whether a user can access a case.
 *
 * IMPORTANT:
 * - This helper is used by multiple slices (cases, documents, tasks).
 * - All PRIVATE case access decisions must go through this helper to avoid divergence.
 */
export async function canUserAccessCase(
  orgId: string,
  caseId: string,
  uid: string
): Promise<CaseAccessResult> {
  try {
    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);

    const caseDoc = await caseRef.get();

    if (!caseDoc.exists) {
      return { allowed: false, reason: 'Case not found' };
    }

    const rawData = caseDoc.data() as {
      visibility?: 'ORG_WIDE' | 'PRIVATE';
      createdBy?: string;
      deletedAt?: FirestoreTimestamp | null;
    };

    if (rawData?.deletedAt) {
      return { allowed: false, reason: 'Case not found' };
    }

    // Default: ORG_WIDE cases are accessible to all org members (org membership is checked elsewhere)
    if (rawData?.visibility !== 'PRIVATE') {
      return {
        allowed: true,
        caseData: {
          visibility: rawData?.visibility ?? 'ORG_WIDE',
          createdBy: rawData?.createdBy,
          deletedAt: rawData?.deletedAt ?? null,
        },
      };
    }

    // PRIVATE case: creator always has access
    if (rawData.createdBy === uid) {
      return {
        allowed: true,
        caseData: {
          visibility: 'PRIVATE',
          createdBy: rawData.createdBy,
          deletedAt: rawData.deletedAt ?? null,
        },
      };
    }

    // For PRIVATE cases, also allow explicit participants
    const participantRef = caseRef.collection('participants').doc(uid);
    const participantDoc = await participantRef.get();

    if (participantDoc.exists) {
      return {
        allowed: true,
        caseData: {
          visibility: 'PRIVATE',
          createdBy: rawData.createdBy,
          deletedAt: rawData.deletedAt ?? null,
        },
      };
    }

    return {
      allowed: false,
      reason: 'You are not allowed to access this private case',
      caseData: {
        visibility: 'PRIVATE',
        createdBy: rawData.createdBy,
        deletedAt: rawData.deletedAt ?? null,
      },
    };
  } catch (error) {
    functions.logger.error('Error checking case access:', error);
    return { allowed: false, reason: 'Failed to verify case access' };
  }
}

