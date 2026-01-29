/**
 * Document Summary Functions (Slice 14 - AI Summarization)
 *
 * One-click document summaries. Requires extracted text.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { canUserAccessCase } from '../utils/case-access';
import { createAuditEvent } from '../utils/audit';
import { summarizeDocument } from '../services/ai-service';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface DocumentSummaryDocument {
  id: string;
  orgId: string;
  documentId: string;
  caseId?: string | null;
  summary: string;
  createdAt: FirestoreTimestamp;
  createdBy: string;
  model: string;
  tokensUsed?: number | null;
  processingTimeMs?: number | null;
}

interface DocumentDocument {
  id: string;
  orgId: string;
  caseId?: string | null;
  name: string;
  extractedText?: string | null;
  extractionStatus?: string | null;
  deletedAt?: FirestoreTimestamp | null;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

/**
 * Summarize a document
 * Function Name (Export): summarizeDocument
 */
export const summarizeDocumentCallable = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const uid = context.auth.uid;
    const { orgId, documentId, options } = data || {};

    if (!orgId || typeof orgId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
    }

    if (!documentId || typeof documentId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'documentId is required');
    }

    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'DOCUMENT_SUMMARY',
      requiredPermission: 'document.summarize',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'Document Summarization requires a BASIC plan or higher. Please upgrade to continue.');
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to summarize documents');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
    }

    const docRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .doc(documentId);

    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    const docData = docSnap.data() as DocumentDocument;

    if (docData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    if (!docData.extractedText || docData.extractionStatus !== 'completed') {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Document must have extracted text before summarization. Please extract text first.'
      );
    }

    if (docData.caseId) {
      const caseAccess = await canUserAccessCase(orgId, docData.caseId, uid);
      if (!caseAccess.allowed) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          caseAccess.reason || 'You do not have access to this document'
        );
      }
    }

    const summaryRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('document_summaries')
      .doc();

    const now = admin.firestore.Timestamp.now();
    const model = (options?.model as 'gpt-4o-mini' | 'gpt-4o') || 'gpt-4o-mini';

    try {
      const aiResult = await summarizeDocument(docData.extractedText!, docData.name, {
        model,
        maxLength: options?.maxLength,
      });

      const summaryData: DocumentSummaryDocument = {
        id: summaryRef.id,
        orgId,
        documentId,
        caseId: docData.caseId || null,
        summary: aiResult.summary,
        createdAt: now,
        createdBy: uid,
        model: aiResult.model,
        tokensUsed: aiResult.tokensUsed ?? null,
        processingTimeMs: aiResult.processingTimeMs ?? null,
      };

      await summaryRef.set(summaryData);

      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'document.summarized',
        entityType: 'document_summary',
        entityId: summaryRef.id,
        caseId: docData.caseId || undefined,
        metadata: { documentId, documentName: docData.name, tokensUsed: aiResult.tokensUsed },
      });

      return successResponse({
        summaryId: summaryRef.id,
        documentId,
        caseId: docData.caseId || null,
        summary: aiResult.summary,
        createdAt: toIso(now),
        createdBy: uid,
        model: aiResult.model,
        tokensUsed: aiResult.tokensUsed ?? null,
        processingTimeMs: aiResult.processingTimeMs ?? null,
      });
    } catch (error) {
      functions.logger.error('Document summarization error:', error);

      const errorMessage = error instanceof Error ? error.message : 'Failed to summarize document';

      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'document.summarize_failed',
        entityType: 'document_summary',
        entityId: summaryRef.id,
        caseId: docData.caseId || undefined,
        metadata: { documentId, documentName: docData.name, error: errorMessage },
      });

      return errorResponse(ErrorCode.INTERNAL_ERROR, errorMessage);
    }
  });

/**
 * Get a document summary
 * Function Name (Export): documentSummaryGet
 */
export const documentSummaryGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, summaryId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!summaryId || typeof summaryId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'summaryId is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'document.summarize',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to view document summaries');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const summaryRef = db
    .collection('organizations')
    .doc(orgId)
    .collection('document_summaries')
    .doc(summaryId);

  const summarySnap = await summaryRef.get();

  if (!summarySnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Summary not found');
  }

  const summaryData = summarySnap.data() as DocumentSummaryDocument;

  if (summaryData.caseId) {
    const caseAccess = await canUserAccessCase(orgId, summaryData.caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You do not have access to this summary'
      );
    }
  }

  return successResponse({
    summaryId: summaryData.id,
    documentId: summaryData.documentId,
    caseId: summaryData.caseId || null,
    summary: summaryData.summary,
    createdAt: toIso(summaryData.createdAt),
    createdBy: summaryData.createdBy,
    model: summaryData.model,
    tokensUsed: summaryData.tokensUsed ?? null,
    processingTimeMs: summaryData.processingTimeMs ?? null,
  });
});

/**
 * List document summaries
 * Function Name (Export): documentSummaryList
 */
export const documentSummaryList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId, caseId, limit = 20, offset = 0 } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  const parsedLimit = typeof limit === 'number' && limit > 0 && limit <= 100 ? limit : 20;
  const parsedOffset = typeof offset === 'number' && offset >= 0 ? offset : 0;

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'document.summarize',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to view document summaries');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  let query: admin.firestore.Query = db
    .collection('organizations')
    .doc(orgId)
    .collection('document_summaries');

  if (documentId && typeof documentId === 'string') {
    query = query.where('documentId', '==', documentId);
  }

  if (caseId && typeof caseId === 'string') {
    const caseAccess = await canUserAccessCase(orgId, caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You do not have access to this case'
      );
    }
    query = query.where('caseId', '==', caseId);
  }

  query = query.orderBy('createdAt', 'desc');
  query = query.limit(parsedLimit + 1);

  if (parsedOffset > 0) {
    const offsetSnapshot = await query.limit(parsedOffset).get();
    if (offsetSnapshot.empty) {
      return successResponse({
        summaries: [],
        total: 0,
        hasMore: false,
      });
    }
    const lastDoc = offsetSnapshot.docs[offsetSnapshot.docs.length - 1];
    query = query.startAfter(lastDoc).limit(parsedLimit + 1);
  }

  const snapshot = await query.get();

  const hasMore = snapshot.docs.length > parsedLimit;
  const summaries = snapshot.docs.slice(0, parsedLimit).map((doc) => {
    const data = doc.data() as DocumentSummaryDocument;
    return {
      summaryId: data.id,
      documentId: data.documentId,
      caseId: data.caseId || null,
      summary: data.summary,
      createdAt: toIso(data.createdAt),
      createdBy: data.createdBy,
      model: data.model,
      tokensUsed: data.tokensUsed ?? null,
      processingTimeMs: data.processingTimeMs ?? null,
    };
  });

  let filteredSummaries = summaries;
  if (!(caseId && typeof caseId === 'string')) {
    const accessible = [];
    for (const s of summaries) {
      if (!s.caseId) {
        accessible.push(s);
      } else {
        const caseAccess = await canUserAccessCase(orgId, s.caseId, uid);
        if (caseAccess.allowed) accessible.push(s);
      }
    }
    filteredSummaries = accessible;
  }

  return successResponse({
    summaries: filteredSummaries,
    total: filteredSummaries.length,
    hasMore,
  });
});
