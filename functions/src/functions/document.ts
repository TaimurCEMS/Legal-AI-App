/**
 * Document Management Functions (Slice 4 - Document Hub)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { canUserAccessCase } from '../utils/case-access';

const db = admin.firestore();
const storage = admin.storage();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface DocumentDocument {
  id: string;
  orgId: string;
  caseId?: string | null;
  name: string;
  description?: string | null;
  fileType: string;
  fileSize: number;
  storagePath: string;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

const ALLOWED_FILE_TYPES = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB for MVP
const STORAGE_QUOTA = 1 * 1024 * 1024 * 1024; // 1GB for MVP (all plans)

function parseName(rawName: unknown): string | null {
  if (typeof rawName !== 'string') return null;
  const trimmed = rawName.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function parseDescription(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 1000) return null;
  return trimmed;
}

function parseFileType(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const lower = raw.toLowerCase().trim();
  if (ALLOWED_FILE_TYPES.includes(lower)) return lower;
  return null;
}

function parseFileSize(raw: unknown): number | null {
  if (typeof raw !== 'number') return null;
  if (raw <= 0 || raw > MAX_FILE_SIZE) return null;
  return raw;
}

function parseStoragePath(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length === 0) return null;
  // Verify path matches expected pattern: organizations/{orgId}/documents/{documentId}/{filename}
  const pathPattern = /^organizations\/[^/]+\/documents\/[^/]+\/[^/]+$/;
  if (!pathPattern.test(trimmed)) return null;
  return trimmed;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

// Case access checks for documents now delegate to the shared helper in utils/case-access.ts

/**
 * Generate signed download URL for Storage file
 */
async function generateDownloadUrl(storagePath: string): Promise<string> {
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);
  
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + 60 * 60 * 1000, // 1 hour
  });
  
  return url;
}

/**
 * Check if file exists in Storage
 */
async function verifyFileExists(storagePath: string): Promise<boolean> {
  try {
    const bucket = storage.bucket();
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    return exists;
  } catch (error) {
    functions.logger.error('Error checking file existence:', error);
    return false;
  }
}

/**
 * Calculate total storage used by organization
 */
async function calculateStorageUsed(orgId: string): Promise<number> {
  try {
    const snapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .where('deletedAt', '==', null)
      .get();
    
    let totalSize = 0;
    snapshot.forEach((doc) => {
      const data = doc.data() as DocumentDocument;
      totalSize += data.fileSize || 0;
    });
    
    return totalSize;
  } catch (error) {
    functions.logger.error('Error calculating storage used:', error);
    return 0;
  }
}

/**
 * Create a new document (metadata only - file must be uploaded first)
 * Function Name (Export): documentCreate
 * Callable Name (Internal): document.create
 */
export const documentCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, name, description, storagePath, fileType, fileSize } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const sanitizedName = parseName(name);
  if (!sanitizedName) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Document name must be 1-200 characters'
    );
  }

  const sanitizedDescription = parseDescription(description);
  if (description !== undefined && description !== null && sanitizedDescription === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Description must be 1000 characters or less'
    );
  }

  const parsedFileType = parseFileType(fileType);
  if (!parsedFileType) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `File type must be one of: ${ALLOWED_FILE_TYPES.join(', ')}`
    );
  }

  const parsedFileSize = parseFileSize(fileSize);
  if (!parsedFileSize) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `File size must be between 1 byte and ${MAX_FILE_SIZE / (1024 * 1024)}MB`
    );
  }

  const parsedStoragePath = parseStoragePath(storagePath);
  if (!parsedStoragePath) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Invalid storage path format'
    );
  }

  // Verify file exists in Storage
  const fileExists = await verifyFileExists(parsedStoragePath);
  if (!fileExists) {
    return errorResponse(
      ErrorCode.NOT_FOUND,
      'File not found in Storage. Please upload the file first.'
    );
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'DOCUMENTS',
    requiredPermission: 'document.create',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to create documents');
    }
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'DOCUMENTS feature not available in current plan');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to create document');
  }

  // Check storage quota
  const currentStorage = await calculateStorageUsed(orgId);
  if (currentStorage + parsedFileSize > STORAGE_QUOTA) {
    return errorResponse(
      ErrorCode.PLAN_LIMIT,
      `Storage quota exceeded. Current: ${(currentStorage / (1024 * 1024)).toFixed(2)}MB, Limit: ${(STORAGE_QUOTA / (1024 * 1024)).toFixed(2)}MB`
    );
  }

  // If caseId provided, verify case exists and user can access it
  if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
    const caseAccess = await canUserAccessCase(orgId, caseId.trim(), uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You are not allowed to link documents to this case'
      );
    }
  }

  try {
    const now = admin.firestore.Timestamp.now();
    const documentRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .doc();

    const documentId = documentRef.id;

    const documentData: DocumentDocument = {
      id: documentId,
      orgId,
      caseId: caseId && typeof caseId === 'string' && caseId.trim().length > 0 ? caseId.trim() : null,
      name: sanitizedName,
      description: sanitizedDescription,
      fileType: parsedFileType,
      fileSize: parsedFileSize,
      storagePath: parsedStoragePath,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      updatedBy: uid,
      deletedAt: null,
    };

    await documentRef.set(documentData);

    // Generate download URL (may fail if service account lacks permissions)
    let downloadUrl: string | null = null;
    try {
      downloadUrl = await generateDownloadUrl(parsedStoragePath);
    } catch (error: any) {
      functions.logger.warn('Could not generate download URL (will be generated on-demand):', error.message);
      // Download URL will be generated on-demand in documentGet
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'document.created',
      entityType: 'document',
      entityId: documentId,
      metadata: {
        name: sanitizedName,
        fileType: parsedFileType,
        fileSize: parsedFileSize,
        caseId: documentData.caseId || null,
      },
    });

    return successResponse({
      documentId,
      orgId,
      caseId: documentData.caseId,
      name: sanitizedName,
      description: sanitizedDescription,
      fileType: parsedFileType,
      fileSize: parsedFileSize,
      storagePath: parsedStoragePath,
      downloadUrl,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      updatedBy: uid,
    });
  } catch (error: any) {
    functions.logger.error('Error creating document:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to create document');
  }
});

/**
 * Get document details by ID
 * Function Name (Export): documentGet
 * Callable Name (Internal): document.get
 */
export const documentGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!documentId || typeof documentId !== 'string' || documentId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document ID is required');
  }

  // Check org membership (all org members can read documents)
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'DOCUMENTS',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view document');
  }

  try {
    const documentRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .doc(documentId);

    const documentDoc = await documentRef.get();

    if (!documentDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    const documentData = documentDoc.data() as DocumentDocument;

    // Check if soft-deleted
    if (documentData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    // Verify document belongs to org
    if (documentData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Document does not belong to this organization');
    }

    // If document is linked to a case, verify user can access that case
    if (documentData.caseId) {
      const caseAccess = await canUserAccessCase(orgId, documentData.caseId, uid);
      if (!caseAccess.allowed) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          caseAccess.reason || 'You are not allowed to access documents linked to this case'
        );
      }
    }

    // Generate fresh download URL (may fail if service account lacks permissions)
    let downloadUrl: string | null = null;
    try {
      downloadUrl = await generateDownloadUrl(documentData.storagePath);
    } catch (error: any) {
      functions.logger.warn('Could not generate download URL:', error.message);
      // Continue without download URL - user can still view metadata
    }

    return successResponse({
      documentId: documentData.id,
      orgId: documentData.orgId,
      caseId: documentData.caseId || null,
      name: documentData.name,
      description: documentData.description || null,
      fileType: documentData.fileType,
      fileSize: documentData.fileSize,
      storagePath: documentData.storagePath,
      downloadUrl: downloadUrl || null, // May be null if URL generation failed
      createdAt: toIso(documentData.createdAt),
      updatedAt: toIso(documentData.updatedAt),
      createdBy: documentData.createdBy,
      updatedBy: documentData.updatedBy,
    });
  } catch (error: any) {
    functions.logger.error('Error getting document:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to get document');
  }
});

/**
 * List documents for an organization
 * Function Name (Export): documentList
 * Callable Name (Internal): document.list
 */
export const documentList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, limit = 50, offset = 0, search, caseId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  // Validate limit
  const parsedLimit = typeof limit === 'number' ? Math.min(Math.max(1, limit), 100) : 50;
  const parsedOffset = typeof offset === 'number' ? Math.max(0, offset) : 0;

  // Check org membership (all org members can read documents)
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'DOCUMENTS',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to list documents');
  }

  // If caseId provided, verify case exists and user can access it
  if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
    const caseAccess = await canUserAccessCase(orgId, caseId.trim(), uid);
    if (!caseAccess.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        caseAccess.reason || 'You are not allowed to access this case'
      );
    }
  }

  try {
    // For MVP: Fetch all non-deleted documents and filter in-memory
    // This avoids index requirements and works immediately
    let query: admin.firestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .where('deletedAt', '==', null);

    // Add case filter if provided
    if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
      query = query.where('caseId', '==', caseId.trim());
    }

    // Order by updatedAt descending
    query = query.orderBy('updatedAt', 'desc');

    // Fetch all documents (with reasonable limit for MVP)
    const snapshot = await query.limit(1000).get();

    let allDocuments = snapshot.docs.map((doc) => {
      const data = doc.data() as DocumentDocument;
      return {
        documentId: data.id,
        orgId: data.orgId,
        caseId: data.caseId || null,
        name: data.name,
        description: data.description || null,
        fileType: data.fileType,
        fileSize: data.fileSize,
        storagePath: data.storagePath,
        createdAt: toIso(data.createdAt),
        updatedAt: toIso(data.updatedAt),
        createdBy: data.createdBy,
        updatedBy: data.updatedBy,
      };
    });

    // Apply in-memory search filter if provided (case-insensitive contains on name)
    if (search && typeof search === 'string' && search.trim().length > 0) {
      const searchTerm = search.trim().toLowerCase();
      allDocuments = allDocuments.filter((doc) =>
        doc.name.toLowerCase().includes(searchTerm)
      );
    }

    // Filter out documents linked to cases the user cannot access
    const accessibleDocuments = [];
    for (const doc of allDocuments) {
      if (doc.caseId) {
        const caseAccess = await canUserAccessCase(orgId, doc.caseId, uid);
        if (!caseAccess.allowed) {
          // Skip documents linked to inaccessible cases
          continue;
        }
      }
      accessibleDocuments.push(doc);
    }

    // Apply pagination
    const total = accessibleDocuments.length;
    const pagedDocuments = accessibleDocuments.slice(parsedOffset, parsedOffset + parsedLimit);
    const hasMore = parsedOffset + parsedLimit < total;

    // Generate download URLs for each document
    const documentsWithUrls = await Promise.all(
      pagedDocuments.map(async (doc) => {
        try {
          const downloadUrl = await generateDownloadUrl(doc.storagePath);
          return {
            ...doc,
            downloadUrl,
          };
        } catch (error) {
          functions.logger.error(`Error generating download URL for ${doc.documentId}:`, error);
          return {
            ...doc,
            downloadUrl: null,
          };
        }
      })
    );

    return successResponse({
      documents: documentsWithUrls,
      total,
      hasMore,
    });
  } catch (error: any) {
    functions.logger.error('Error listing documents:', error);
    functions.logger.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack,
      orgId,
      uid,
    });
    
    // Provide more specific error message
    let errorMessage = 'Failed to list documents';
    if (error.code === 9 || error.message?.includes('index') || error.message?.includes('FAILED_PRECONDITION')) {
      errorMessage = 'Firestore index required. Please check Firebase Console → Firestore → Indexes and ensure all indexes are enabled.';
    } else if (error.code === 7 || error.message?.includes('permission') || error.message?.includes('PERMISSION_DENIED')) {
      errorMessage = 'Permission denied. Please check Firestore security rules.';
    } else if (error.message) {
      errorMessage = `Failed to list documents: ${error.message}`;
    }
    
    return errorResponse(ErrorCode.INTERNAL_ERROR, errorMessage);
  }
});

/**
 * Update document metadata
 * Function Name (Export): documentUpdate
 * Callable Name (Internal): document.update
 */
export const documentUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId, name, description, caseId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!documentId || typeof documentId !== 'string' || documentId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'DOCUMENTS',
    requiredPermission: 'document.update',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to update documents');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to update document');
  }

  try {
    const documentRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .doc(documentId);

    const documentDoc = await documentRef.get();

    if (!documentDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    const existingData = documentDoc.data() as DocumentDocument;

    // Check if soft-deleted
    if (existingData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    // Verify document belongs to org
    if (existingData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Document does not belong to this organization');
    }

    // Validate and prepare updates
    const updates: Partial<DocumentDocument> = {
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: uid,
    };

    if (name !== undefined) {
      const sanitizedName = parseName(name);
      if (!sanitizedName) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Document name must be 1-200 characters'
        );
      }
      updates.name = sanitizedName;
    }

    if (description !== undefined) {
      const sanitizedDescription = parseDescription(description);
      if (description !== null && sanitizedDescription === null) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Description must be 1000 characters or less'
        );
      }
      updates.description = sanitizedDescription;
    }

    if (caseId !== undefined) {
      if (caseId === null) {
        // Remove case association
        updates.caseId = null;
      } else if (typeof caseId === 'string' && caseId.trim().length > 0) {
        // Verify case exists and user can access it
        const caseAccess = await canUserAccessCase(orgId, caseId.trim(), uid);
        if (!caseAccess.allowed) {
          return errorResponse(
            ErrorCode.NOT_AUTHORIZED,
            caseAccess.reason || 'You are not allowed to access this case'
          );
        }
        
        updates.caseId = caseId.trim();
      } else {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
      }
    }

    // If document is already linked to a case, verify user can still access that case
    if (existingData.caseId && !updates.caseId) {
      const caseAccess = await canUserAccessCase(orgId, existingData.caseId, uid);
      if (!caseAccess.allowed) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          caseAccess.reason || 'You are not allowed to update documents linked to this case'
        );
      }
    }

    // Update document
    await documentRef.update(updates);

    // Fetch updated document
    const updatedDoc = await documentRef.get();
    const updatedData = updatedDoc.data() as DocumentDocument;

    // Generate fresh download URL (may fail if service account lacks permissions)
    let downloadUrl: string | null = null;
    try {
      downloadUrl = await generateDownloadUrl(updatedData.storagePath);
    } catch (error: any) {
      functions.logger.warn('Could not generate download URL:', error.message);
      // Continue without download URL
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'document.updated',
      entityType: 'document',
      entityId: documentId,
      metadata: {
        name: updatedData.name,
        fileType: updatedData.fileType,
        changes: Object.keys(updates).filter(k => k !== 'updatedAt' && k !== 'updatedBy'),
      },
    });

    return successResponse({
      documentId: updatedData.id,
      orgId: updatedData.orgId,
      caseId: updatedData.caseId || null,
      name: updatedData.name,
      description: updatedData.description || null,
      fileType: updatedData.fileType,
      fileSize: updatedData.fileSize,
      storagePath: updatedData.storagePath,
      downloadUrl: downloadUrl || null, // May be null if URL generation failed
      createdAt: toIso(updatedData.createdAt),
      updatedAt: toIso(updatedData.updatedAt),
      createdBy: updatedData.createdBy,
      updatedBy: updatedData.updatedBy,
    });
  } catch (error: any) {
    functions.logger.error('Error updating document:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to update document');
  }
});

/**
 * Soft delete document
 * Function Name (Export): documentDelete
 * Callable Name (Internal): document.delete
 */
export const documentDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, documentId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!documentId || typeof documentId !== 'string' || documentId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'DOCUMENTS',
    requiredPermission: 'document.delete',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User is not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'User role does not have permission to delete documents');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to delete document');
  }

  try {
    const documentRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .doc(documentId);

    const documentDoc = await documentRef.get();

    if (!documentDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    }

    const existingData = documentDoc.data() as DocumentDocument;

    // Check if already deleted
    if (existingData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Document already deleted');
    }

    // Verify document belongs to org
    if (existingData.orgId !== orgId) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Document does not belong to this organization');
    }

    // If document is linked to a case, verify user can access that case
    if (existingData.caseId) {
      const caseAccess = await canUserAccessCase(orgId, existingData.caseId, uid);
      if (!caseAccess.allowed) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          caseAccess.reason || 'You are not allowed to delete documents linked to this case'
        );
      }
    }

    // Check role permissions for delete
    // ADMIN: Can delete any document
    // LAWYER: Can delete documents they created
    // PARALEGAL/VIEWER: Cannot delete
    if (entitlement.role !== 'ADMIN') {
      if (entitlement.role === 'LAWYER' && existingData.createdBy !== uid) {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You can only delete documents you created');
      }
      if (entitlement.role !== 'LAWYER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have permission to delete documents');
      }
    }

    const now = admin.firestore.Timestamp.now();

    // Soft delete: set deletedAt timestamp
    await documentRef.update({
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
    } as Partial<DocumentDocument>);

    // Mark Storage file for deletion (future: background job will delete after 30 days)
    // For MVP: Just mark in Firestore, Storage cleanup can be manual
    try {
      const bucket = storage.bucket();
      const file = bucket.file(existingData.storagePath);
      // Set metadata to mark for deletion (or add to deletion queue)
      await file.setMetadata({
        metadata: {
          deletedAt: now.toMillis().toString(),
          markedForDeletion: 'true',
        },
      });
    } catch (storageError) {
      // Log but don't fail - Firestore soft delete is the important part
      functions.logger.warn('Error marking Storage file for deletion:', storageError);
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'document.deleted',
      entityType: 'document',
      entityId: documentId,
      metadata: {
        name: existingData.name,
        fileType: existingData.fileType,
        fileSize: existingData.fileSize,
      },
    });

    return successResponse({
      documentId,
      deletedAt: toIso(now),
    });
  } catch (error: any) {
    functions.logger.error('Error deleting document:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to delete document');
  }
});
