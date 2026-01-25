/**
 * Document Text Extraction Functions (Slice 6a)
 * 
 * Provides text extraction capabilities for documents stored in Cloud Storage.
 * Uses a job queue pattern for async processing.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { extractTextWithTimeout, isExtractable } from '../services/extraction-service';

const db = admin.firestore();
const storage = admin.storage();

type FirestoreTimestamp = admin.firestore.Timestamp;

// Job types for the job queue
type JobType = 'EXTRACTION' | 'AI_RESEARCH' | 'AI_DRAFT';
type JobStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

interface JobDocument {
  jobId: string;
  orgId: string;
  type: JobType;
  status: JobStatus;
  targetId: string;
  targetType: 'document';
  input?: Record<string, unknown>;
  output?: Record<string, unknown>;
  error?: string | null;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  completedAt?: FirestoreTimestamp | null;
}

// Extraction status values
type ExtractionStatus = 'none' | 'pending' | 'processing' | 'completed' | 'failed';

interface DocumentWithExtraction {
  id: string;
  orgId: string;
  name: string;
  fileType: string;
  fileSize: number;
  storagePath: string;
  deletedAt?: FirestoreTimestamp | null;
  // Extraction fields
  extractedText?: string | null;
  extractionStatus?: ExtractionStatus;
  extractionError?: string | null;
  extractedAt?: FirestoreTimestamp | null;
  pageCount?: number | null;
  wordCount?: number | null;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

/**
 * Trigger text extraction for a document
 * Function Name (Export): documentExtract
 */
export const documentExtract = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId, forceReExtract } = data || {};

  // Validate required fields
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!documentId || typeof documentId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document ID is required');
  }

  // Check entitlement - OCR_EXTRACTION feature required
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'OCR_EXTRACTION',
    requiredPermission: 'document.read',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have permission to extract documents');
    }
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'Text extraction requires a BASIC plan or higher. Please upgrade to continue.');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Load document
  const docRef = db.collection('organizations').doc(orgId).collection('documents').doc(documentId);
  const docSnap = await docRef.get();

  if (!docSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
  }

  const docData = docSnap.data() as DocumentWithExtraction;

  // Check if document is deleted
  if (docData.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document has been deleted');
  }

  // Check if file type is extractable
  if (!isExtractable(docData.fileType)) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `File type '${docData.fileType}' is not supported for text extraction. Supported types: pdf, docx, txt, rtf`
    );
  }

  // Check if already extracted (unless forceReExtract)
  const currentStatus = docData.extractionStatus || 'none';
  if (currentStatus === 'completed' && !forceReExtract) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Document already has extracted text. Use forceReExtract: true to re-extract.'
    );
  }

  // Check if extraction is already in progress
  if (currentStatus === 'pending' || currentStatus === 'processing') {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Extraction is already in progress for this document'
    );
  }

  // Create job document
  const jobRef = db.collection('organizations').doc(orgId).collection('jobs').doc();
  const jobId = jobRef.id;
  const now = admin.firestore.Timestamp.now();

  const jobData: JobDocument = {
    jobId,
    orgId,
    type: 'EXTRACTION',
    status: 'PENDING',
    targetId: documentId,
    targetType: 'document',
    input: {
      forceReExtract: forceReExtract || false,
      fileType: docData.fileType,
      storagePath: docData.storagePath,
    },
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
  };

  // Update document status and create job in a transaction
  await db.runTransaction(async (transaction) => {
    // Update document extraction status
    transaction.update(docRef, {
      extractionStatus: 'pending',
      extractionError: null,
      updatedAt: now,
      updatedBy: uid,
    });

    // Create job
    transaction.set(jobRef, jobData);
  });

  // Create audit event
  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'document.extraction_started',
    entityType: 'document',
    entityId: documentId,
    metadata: {
      jobId,
      fileType: docData.fileType,
      forceReExtract: forceReExtract || false,
    },
  });

  functions.logger.info(`Extraction job created: ${jobId} for document ${documentId}`);

  return successResponse({
    jobId,
    documentId,
    status: 'PENDING',
  });
});

/**
 * Get extraction status for a document
 * Function Name (Export): documentGetExtractionStatus
 */
export const documentGetExtractionStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId } = data || {};

  // Validate required fields
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!documentId || typeof documentId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document ID is required');
  }

  // Check entitlement - only document.read required
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'document.read',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Load document
  const docRef = db.collection('organizations').doc(orgId).collection('documents').doc(documentId);
  const docSnap = await docRef.get();

  if (!docSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
  }

  const docData = docSnap.data() as DocumentWithExtraction;

  if (docData.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document has been deleted');
  }

  return successResponse({
    documentId,
    extractionStatus: docData.extractionStatus || 'none',
    extractedAt: docData.extractedAt ? toIso(docData.extractedAt) : null,
    extractionError: docData.extractionError || null,
    pageCount: docData.pageCount || null,
    wordCount: docData.wordCount || null,
    hasExtractedText: !!(docData.extractedText && docData.extractedText.length > 0),
  });
});

/**
 * Process extraction jobs - Firestore trigger on job creation
 * Function Name (Export): extractionProcessJob
 */
export const extractionProcessJob = functions.firestore
  .document('organizations/{orgId}/jobs/{jobId}')
  .onCreate(async (snapshot, context) => {
    const { orgId, jobId } = context.params;
    const jobData = snapshot.data() as JobDocument;

    // Only process EXTRACTION jobs
    if (jobData.type !== 'EXTRACTION' || jobData.status !== 'PENDING') {
      functions.logger.info(`Skipping job ${jobId}: type=${jobData.type}, status=${jobData.status}`);
      return;
    }

    const jobRef = snapshot.ref;
    const now = admin.firestore.Timestamp.now();

    functions.logger.info(`Processing extraction job ${jobId} for document ${jobData.targetId}`);

    // Update job status to PROCESSING
    await jobRef.update({
      status: 'PROCESSING',
      updatedAt: now,
    });

    // Get document reference
    const docRef = db.collection('organizations').doc(orgId).collection('documents').doc(jobData.targetId);

    try {
      // Update document status to processing
      await docRef.update({
        extractionStatus: 'processing',
        updatedAt: now,
      });

      // Get document data
      const docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw new Error('Document not found');
      }

      const docData = docSnap.data() as DocumentWithExtraction;
      const storagePath = docData.storagePath;

      // Download file from Storage
      functions.logger.info(`Downloading file from ${storagePath}`);
      const bucket = storage.bucket();
      const file = bucket.file(storagePath);

      const [exists] = await file.exists();
      if (!exists) {
        throw new Error('File not found in storage');
      }

      const [buffer] = await file.download();
      functions.logger.info(`Downloaded ${buffer.length} bytes`);

      // Extract text with timeout (60 seconds)
      const result = await extractTextWithTimeout(buffer, docData.fileType, 60000);

      if (!result.success) {
        throw new Error(result.error || 'Extraction failed');
      }

      // Update document with extracted text
      const completedAt = admin.firestore.Timestamp.now();
      await docRef.update({
        extractedText: result.text || '',
        extractionStatus: 'completed',
        extractionError: null,
        extractedAt: completedAt,
        pageCount: result.pageCount || null,
        wordCount: result.wordCount || 0,
        updatedAt: completedAt,
      });

      // Update job as completed
      await jobRef.update({
        status: 'COMPLETED',
        completedAt,
        updatedAt: completedAt,
        output: {
          pageCount: result.pageCount || null,
          wordCount: result.wordCount || 0,
          textLength: result.text?.length || 0,
          truncated: result.truncated || false,
        },
      });

      // Create audit event
      await createAuditEvent({
        orgId,
        actorUid: jobData.createdBy,
        action: 'document.extraction_completed',
        entityType: 'document',
        entityId: jobData.targetId,
        metadata: {
          jobId,
          pageCount: result.pageCount,
          wordCount: result.wordCount,
          textLength: result.text?.length || 0,
        },
      });

      functions.logger.info(`Extraction completed for job ${jobId}: ${result.wordCount} words extracted`);

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown extraction error';
      functions.logger.error(`Extraction failed for job ${jobId}:`, error);

      const failedAt = admin.firestore.Timestamp.now();

      // Update document as failed
      await docRef.update({
        extractionStatus: 'failed',
        extractionError: errorMessage,
        updatedAt: failedAt,
      });

      // Update job as failed
      await jobRef.update({
        status: 'FAILED',
        error: errorMessage,
        completedAt: failedAt,
        updatedAt: failedAt,
      });

      // Create audit event for failure
      await createAuditEvent({
        orgId,
        actorUid: jobData.createdBy,
        action: 'document.extraction_failed',
        entityType: 'document',
        entityId: jobData.targetId,
        metadata: {
          jobId,
          error: errorMessage,
        },
      });
    }
  });
