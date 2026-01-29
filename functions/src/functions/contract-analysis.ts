/**
 * Contract Analysis Functions (Slice 13 - AI Contract Analysis)
 * 
 * Provides AI-powered contract analysis functionality.
 * Analyzes contracts to identify clauses and flag risks.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { canUserAccessCase } from '../utils/case-access';
import { createAuditEvent } from '../utils/audit';
import {
  analyzeContract,
  Clause,
  Risk,
} from '../services/ai-service';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

// Types
interface ContractAnalysisDocument {
  id: string;
  orgId: string;
  documentId: string;
  caseId?: string | null;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  error?: string | null;
  summary?: string | null;
  clauses?: Clause[] | null;
  risks?: Risk[] | null;
  createdAt: FirestoreTimestamp;
  completedAt?: FirestoreTimestamp | null;
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
 * Analyze a contract document
 * Function Name (Export): contractAnalyze
 */
export const contractAnalyze = functions
  .runWith({
    timeoutSeconds: 120, // Allow time for AI processing
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const uid = context.auth.uid;
    const { orgId, documentId, options } = data || {};

    // Validate inputs
    if (!orgId || typeof orgId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
    }

    if (!documentId || typeof documentId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'documentId is required');
    }

    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CONTRACT_ANALYSIS',
      requiredPermission: 'contract.analyze',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'Contract Analysis requires a BASIC plan or higher. Please upgrade to continue.');
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to analyze contracts');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
    }

    // Get document
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

    // Check if document is deleted
    if (docData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    // Verify document has extracted text
    if (!docData.extractedText || docData.extractionStatus !== 'completed') {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Document must have extracted text before analysis. Please extract text first.'
      );
    }

    // Check case access if document is linked to a case
    if (docData.caseId) {
      const caseAccess = await canUserAccessCase(orgId, docData.caseId, uid);
      if (!caseAccess.allowed) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          caseAccess.reason || 'You do not have access to this document'
        );
      }
    }

    // Create analysis record
    const analysisRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('contract_analyses')
      .doc();

    const now = admin.firestore.Timestamp.now();
    const model = (options?.model as 'gpt-4o-mini' | 'gpt-4o') || 'gpt-4o-mini';

    // Set initial status
    const analysisData: ContractAnalysisDocument = {
      id: analysisRef.id,
      orgId,
      documentId,
      caseId: docData.caseId || null,
      status: 'processing',
      createdAt: now,
      createdBy: uid,
      model,
    };

    await analysisRef.set(analysisData);

    // Create audit event for analysis start
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'contract.analyzed',
      entityType: 'contract_analysis',
      entityId: analysisRef.id,
      caseId: docData.caseId || undefined,
      metadata: { documentId, documentName: docData.name },
    });

    try {
      // Analyze contract with AI
      const aiResult = await analyzeContract(docData.extractedText, docData.name, {
        model,
        // TODO: Add jurisdiction support if needed
      });

      // Update analysis with results
      const completedAt = admin.firestore.Timestamp.now();
      await analysisRef.update({
        status: 'completed',
        summary: aiResult.result.summary,
        clauses: aiResult.result.clauses,
        risks: aiResult.result.risks,
        completedAt,
        tokensUsed: aiResult.tokensUsed,
        processingTimeMs: aiResult.processingTimeMs,
      });

      // Create audit event for completion
      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'contract.analysis_completed',
        entityType: 'contract_analysis',
        entityId: analysisRef.id,
        caseId: docData.caseId || undefined,
        metadata: {
          documentId,
          documentName: docData.name,
          clausesCount: aiResult.result.clauses.length,
          risksCount: aiResult.result.risks.length,
          tokensUsed: aiResult.tokensUsed,
        },
      });

      // Return same shape as contractAnalysisGet so client can parse with ContractAnalysisModel.fromJson
      return successResponse({
        analysisId: analysisRef.id,
        documentId,
        caseId: docData.caseId || null,
        status: 'completed',
        error: null,
        summary: aiResult.result.summary,
        clauses: aiResult.result.clauses,
        risks: aiResult.result.risks,
        createdAt: toIso(now),
        completedAt: toIso(completedAt),
        createdBy: uid,
        model: aiResult.model,
        tokensUsed: aiResult.tokensUsed ?? null,
        processingTimeMs: aiResult.processingTimeMs ?? null,
      });
    } catch (error) {
      functions.logger.error('Contract analysis error:', error);

      const errorMessage = error instanceof Error ? error.message : 'Failed to analyze contract';

      // Update analysis with error
      await analysisRef.update({
        status: 'failed',
        error: errorMessage,
      });

      // Create audit event for failure
      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'contract.analysis_failed',
        entityType: 'contract_analysis',
        entityId: analysisRef.id,
        caseId: docData.caseId || undefined,
        metadata: {
          documentId,
          documentName: docData.name,
          error: errorMessage,
        },
      });

      return errorResponse(ErrorCode.INTERNAL_ERROR, errorMessage);
    }
  });

/**
 * Get a contract analysis
 * Function Name (Export): contractAnalysisGet
 */
export const contractAnalysisGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, analysisId } = data || {};

  // Validate inputs
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!analysisId || typeof analysisId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'analysisId is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'contract.analyze',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to view contract analyses');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Get analysis
  const analysisRef = db
    .collection('organizations')
    .doc(orgId)
    .collection('contract_analyses')
    .doc(analysisId);

  const analysisSnap = await analysisRef.get();

  if (!analysisSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Analysis not found');
  }

  const analysisData = analysisSnap.data() as ContractAnalysisDocument;

  // Check case access if analysis is linked to a case
  if (analysisData.caseId) {
    const caseAccess = await canUserAccessCase(orgId, analysisData.caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You do not have access to this analysis'
      );
    }
  }

  return successResponse({
    analysisId: analysisData.id,
    documentId: analysisData.documentId,
    caseId: analysisData.caseId || null,
    status: analysisData.status,
    error: analysisData.error || null,
    summary: analysisData.summary || null,
    clauses: analysisData.clauses || [],
    risks: analysisData.risks || [],
    createdAt: toIso(analysisData.createdAt),
    completedAt: analysisData.completedAt ? toIso(analysisData.completedAt) : null,
    createdBy: analysisData.createdBy,
    model: analysisData.model,
    tokensUsed: analysisData.tokensUsed || null,
    processingTimeMs: analysisData.processingTimeMs || null,
  });
});

/**
 * List contract analyses
 * Function Name (Export): contractAnalysisList
 */
export const contractAnalysisList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId, caseId, limit = 20, offset = 0 } = data || {};

  // Validate inputs
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  const parsedLimit = typeof limit === 'number' && limit > 0 && limit <= 100 ? limit : 20;
  const parsedOffset = typeof offset === 'number' && offset >= 0 ? offset : 0;

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'contract.analyze',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Your role does not have permission to view contract analyses');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Build query
  let query: admin.firestore.Query = db
    .collection('organizations')
    .doc(orgId)
    .collection('contract_analyses');

  // Filter by documentId if provided
  if (documentId && typeof documentId === 'string') {
    query = query.where('documentId', '==', documentId);
  }

  // Filter by caseId if provided
  if (caseId && typeof caseId === 'string') {
    // Verify case access first
    const caseAccess = await canUserAccessCase(orgId, caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You do not have access to this case'
      );
    }
    query = query.where('caseId', '==', caseId);
  }

  // Order by createdAt descending (newest first)
  query = query.orderBy('createdAt', 'desc');

  // Apply pagination
  query = query.limit(parsedLimit + 1); // Fetch one extra to check if there are more

  // Apply offset
  if (parsedOffset > 0) {
    // For offset, we need to skip documents
    // Note: This is inefficient for large offsets, but acceptable for MVP
    const offsetSnapshot = await query.limit(parsedOffset).get();
    if (offsetSnapshot.empty) {
      return successResponse({
        analyses: [],
        total: 0,
        hasMore: false,
      });
    }
    const lastDoc = offsetSnapshot.docs[offsetSnapshot.docs.length - 1];
    query = query.startAfter(lastDoc).limit(parsedLimit + 1);
  }

  const snapshot = await query.get();

  // Check if there are more results
  const hasMore = snapshot.docs.length > parsedLimit;
  const analyses = snapshot.docs.slice(0, parsedLimit).map((doc) => {
    const data = doc.data() as ContractAnalysisDocument;
    return {
      analysisId: data.id,
      documentId: data.documentId,
      caseId: data.caseId || null,
      status: data.status,
      error: data.error || null,
      summary: data.summary || null,
      clausesCount: data.clauses?.length || 0,
      risksCount: data.risks?.length || 0,
      createdAt: toIso(data.createdAt),
      completedAt: data.completedAt ? toIso(data.completedAt) : null,
      createdBy: data.createdBy,
      model: data.model,
    };
  });

  // For caseId filter, we need to filter out PRIVATE case analyses the user can't access
  // This is a simplified approach - for production, consider using collection group queries
  // with proper indexes and filtering
  let filteredAnalyses = analyses;
  if (caseId && typeof caseId === 'string') {
    // Already checked case access above, so all results are accessible
    filteredAnalyses = analyses;
  } else {
    // Filter by case access for analyses linked to cases
    const accessibleAnalyses = [];
    for (const analysis of analyses) {
      if (!analysis.caseId) {
        // No case link, accessible to all org members
        accessibleAnalyses.push(analysis);
      } else {
        // Check case access
        const caseAccess = await canUserAccessCase(orgId, analysis.caseId, uid);
        if (caseAccess.allowed) {
          accessibleAnalyses.push(analysis);
        }
      }
    }
    filteredAnalyses = accessibleAnalyses;
  }

  return successResponse({
    analyses: filteredAnalyses,
    total: filteredAnalyses.length, // Approximate total (for MVP)
    hasMore,
  });
});
