/**
 * Note Management Functions (Slice 8 - Notes/Memos on Cases)
 * 
 * Notes inherit visibility from their case:
 * - If case is ORG_WIDE: all org members can see notes
 * - If case is PRIVATE: only case creator + participants can see notes
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

type NoteCategory = 'CLIENT_MEETING' | 'RESEARCH' | 'STRATEGY' | 'INTERNAL' | 'OTHER';

interface NoteDocument {
  noteId: string;
  orgId: string;
  caseId: string;
  title: string;
  content: string;
  category: NoteCategory;
  isPinned: boolean;
  isPrivate: boolean; // If true, only the creator can see this note
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

// ============================================================================
// Validation Helpers
// ============================================================================

function parseTitle(rawTitle: unknown): string | null {
  if (typeof rawTitle !== 'string') return null;
  const trimmed = rawTitle.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function parseContent(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 10000) return null;
  return trimmed;
}

function parseCategory(raw: unknown): NoteCategory | null {
  if (raw == null) return 'OTHER';
  if (
    raw === 'CLIENT_MEETING' ||
    raw === 'RESEARCH' ||
    raw === 'STRATEGY' ||
    raw === 'INTERNAL' ||
    raw === 'OTHER'
  ) {
    return raw;
  }
  return null;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

// ============================================================================
// noteCreate
// ============================================================================
export const noteCreate = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Authentication required');
  }
  const uid = context.auth.uid;

  // Extract and validate input
  const { orgId, caseId, title: rawTitle, content: rawContent, category: rawCategory, isPinned, isPrivate } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!caseId || typeof caseId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'caseId is required');
  }

  const title = parseTitle(rawTitle);
  if (!title) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Title must be 1-200 characters');
  }

  const content = parseContent(rawContent);
  if (!content) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Content must be 1-10000 characters');
  }

  const category = parseCategory(rawCategory);
  if (!category) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid category');
  }

  const pinned = isPinned === true;
  const privateNote = isPrivate === true;

  // Check case access (inherits case visibility)
  const caseAccess = await canUserAccessCase(orgId, caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'NOTES',
    requiredPermission: 'note.create',
  });
  if (!entitlement.allowed) {
    return errorResponse(
      entitlement.reason === 'PLAN_LIMIT' ? ErrorCode.PLAN_LIMIT : ErrorCode.NOT_AUTHORIZED,
      entitlement.reason === 'PLAN_LIMIT' ? 'Notes feature requires a higher plan' : 'Not allowed to create notes'
    );
  }

  // Create note
  const now = admin.firestore.Timestamp.now();
  const noteRef = db.collection(`organizations/${orgId}/notes`).doc();

  const noteData: NoteDocument = {
    noteId: noteRef.id,
    orgId,
    caseId,
    title,
    content,
    category,
    isPinned: pinned,
    isPrivate: privateNote,
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
    updatedBy: uid,
    deletedAt: null,
  };

  await noteRef.set(noteData);

  // Audit log
  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'note.created',
    entityType: 'note',
    entityId: noteRef.id,
    metadata: { caseId, title, category },
  });

  return successResponse({
    noteId: noteRef.id,
    orgId,
    caseId,
    title,
    content,
    category,
    isPinned: pinned,
    isPrivate: privateNote,
    createdAt: toIso(now),
    updatedAt: toIso(now),
    createdBy: uid,
    updatedBy: uid,
  });
});

// ============================================================================
// noteGet
// ============================================================================
export const noteGet = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Authentication required');
  }
  const uid = context.auth.uid;

  const { orgId, noteId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!noteId || typeof noteId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'noteId is required');
  }

  // Get note
  const noteDoc = await db
    .collection(`organizations/${orgId}/notes`)
    .doc(noteId)
    .get();

  if (!noteDoc.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  const noteData = noteDoc.data() as NoteDocument;

  if (noteData.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check case access (notes inherit case visibility)
  const caseAccess = await canUserAccessCase(orgId, noteData.caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check private note access - only creator can see private notes
  if (noteData.isPrivate && noteData.createdBy !== uid) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'NOTES',
    requiredPermission: 'note.read',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not allowed to read notes');
  }

  return successResponse({
    noteId: noteData.noteId,
    orgId,
    caseId: noteData.caseId,
    title: noteData.title,
    content: noteData.content,
    category: noteData.category,
    isPinned: noteData.isPinned,
    isPrivate: noteData.isPrivate || false,
    createdAt: toIso(noteData.createdAt),
    updatedAt: toIso(noteData.updatedAt),
    createdBy: noteData.createdBy,
    updatedBy: noteData.updatedBy,
  });
});

// ============================================================================
// noteList
// ============================================================================
export const noteList = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Authentication required');
  }
  const uid = context.auth.uid;

  const {
    orgId,
    caseId,
    category,
    pinnedOnly,
    search,
    limit: rawLimit,
    offset: rawOffset,
  } = data || {};

  functions.logger.info('noteList called', { uid, orgId, caseId, category, pinnedOnly, search });

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  const limit = Math.min(Math.max(parseInt(rawLimit, 10) || 50, 1), 100);
  const offset = Math.max(parseInt(rawOffset, 10) || 0, 0);

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'NOTES',
    requiredPermission: 'note.read',
  });
  
  functions.logger.info('noteList entitlement check', { allowed: entitlement.allowed, reason: entitlement.reason });
  
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not allowed to read notes');
  }

  // If caseId provided, list notes for that specific case
  if (caseId && typeof caseId === 'string') {
    // Check case access (notes inherit case visibility)
    const caseAccess = await canUserAccessCase(orgId, caseId, uid);
    functions.logger.info('noteList case access check', { caseId, allowed: caseAccess.allowed, reason: caseAccess.reason });
    
    if (!caseAccess.allowed) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
    }

    // Query notes for this case
    let query: admin.firestore.Query = db
      .collection(`organizations/${orgId}/notes`)
      .where('caseId', '==', caseId)
      .where('deletedAt', '==', null);

    if (category && typeof category === 'string') {
      query = query.where('category', '==', category);
    }

    if (pinnedOnly === true) {
      query = query.where('isPinned', '==', true);
    }

    const snapshot = await query.orderBy('updatedAt', 'desc').get();
    functions.logger.info('noteList query result (with caseId)', { 
      caseId, 
      rawCount: snapshot.docs.length,
      noteIds: snapshot.docs.map(d => d.id).slice(0, 5),
    });

    let notes: NoteDocument[] = snapshot.docs.map((doc) => doc.data() as NoteDocument);

    // Filter out private notes that don't belong to the user
    // Handle isPrivate - default to false if not set (for backward compatibility)
    const beforePrivateFilter = notes.length;
    notes = notes.filter((note) => {
      const isPrivate = note.isPrivate === true;
      return !isPrivate || note.createdBy === uid;
    });
    functions.logger.info('noteList after private filter', { 
      before: beforePrivateFilter, 
      after: notes.length,
      privateNotes: beforePrivateFilter - notes.length,
    });

    // In-memory search
    if (search && typeof search === 'string') {
      const searchLower = search.toLowerCase().trim();
      notes = notes.filter(
        (note) =>
          note.title.toLowerCase().includes(searchLower) ||
          note.content.toLowerCase().includes(searchLower)
      );
    }

    // Sort: pinned first, then by updatedAt desc
    notes.sort((a, b) => {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.toMillis() - a.updatedAt.toMillis();
    });

    const total = notes.length;
    const paginatedNotes = notes.slice(offset, offset + limit);

    return successResponse({
      notes: paginatedNotes.map((note) => ({
        noteId: note.noteId,
        orgId,
        caseId: note.caseId,
        title: note.title,
        content: note.content.substring(0, 200) + (note.content.length > 200 ? '...' : ''),
        category: note.category,
        isPinned: note.isPinned,
        isPrivate: note.isPrivate || false,
        createdAt: toIso(note.createdAt),
        updatedAt: toIso(note.updatedAt),
        createdBy: note.createdBy,
      })),
      total,
      hasMore: offset + limit < total,
    });
  }

  // No caseId - list notes from all accessible cases in this org
  // Get all notes, then filter by case access
  functions.logger.info('noteList without caseId - querying all notes');
  
  let query: admin.firestore.Query = db
    .collection(`organizations/${orgId}/notes`)
    .where('deletedAt', '==', null);

  if (category && typeof category === 'string') {
    query = query.where('category', '==', category);
  }

  if (pinnedOnly === true) {
    query = query.where('isPinned', '==', true);
  }

  const snapshot = await query.orderBy('updatedAt', 'desc').limit(200).get();
  functions.logger.info('noteList raw query result', { 
    rawCount: snapshot.docs.length,
    noteIds: snapshot.docs.map(d => d.id).slice(0, 5),
  });

  // Filter notes by case access
  const accessibleNotes: NoteDocument[] = [];
  const caseAccessCache: Record<string, boolean> = {};
  let skippedPrivate = 0;
  let skippedCaseAccess = 0;

  for (const doc of snapshot.docs) {
    const noteData = doc.data();
    const note = noteData as NoteDocument;
    
    // Handle isPrivate - default to false if not set (for backward compatibility)
    const isPrivate = note.isPrivate === true;
    
    // Skip private notes that don't belong to the user
    if (isPrivate && note.createdBy !== uid) {
      skippedPrivate++;
      functions.logger.debug('noteList: Skipping private note', { 
        noteId: note.noteId, 
        createdBy: note.createdBy, 
        currentUser: uid,
        isPrivate: note.isPrivate,
      });
      continue;
    }
    
    // Check case access (with caching to avoid repeated checks)
    if (caseAccessCache[note.caseId] === undefined) {
      const caseAccess = await canUserAccessCase(orgId, note.caseId, uid);
      caseAccessCache[note.caseId] = caseAccess.allowed;
      functions.logger.debug('noteList: Case access check', { 
        caseId: note.caseId, 
        allowed: caseAccess.allowed, 
        reason: caseAccess.reason,
      });
    }
    
    if (caseAccessCache[note.caseId]) {
      accessibleNotes.push(note);
      functions.logger.debug('noteList: Note accessible', { 
        noteId: note.noteId, 
        caseId: note.caseId,
        createdBy: note.createdBy,
        isPrivate,
      });
    } else {
      skippedCaseAccess++;
      functions.logger.debug('noteList: Skipping note - no case access', { 
        noteId: note.noteId, 
        caseId: note.caseId,
        createdBy: note.createdBy,
      });
    }
  }

  functions.logger.info('noteList after filtering', { 
    rawCount: snapshot.docs.length,
    skippedPrivate,
    skippedCaseAccess,
    accessibleCount: accessibleNotes.length,
    caseAccessCache,
  });

  let notes = accessibleNotes;

  // In-memory search
  if (search && typeof search === 'string') {
    const searchLower = search.toLowerCase().trim();
    notes = notes.filter(
      (note) =>
        note.title.toLowerCase().includes(searchLower) ||
        note.content.toLowerCase().includes(searchLower)
    );
  }

  // Sort: pinned first, then by updatedAt desc
  notes.sort((a, b) => {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return b.updatedAt.toMillis() - a.updatedAt.toMillis();
  });

  const total = notes.length;
  const paginatedNotes = notes.slice(offset, offset + limit);

  return successResponse({
    notes: paginatedNotes.map((note) => ({
      noteId: note.noteId,
      orgId,
      caseId: note.caseId,
      title: note.title,
      content: note.content.substring(0, 200) + (note.content.length > 200 ? '...' : ''),
      category: note.category,
      isPinned: note.isPinned,
      isPrivate: note.isPrivate || false,
      createdAt: toIso(note.createdAt),
      updatedAt: toIso(note.updatedAt),
      createdBy: note.createdBy,
    })),
    total,
    hasMore: offset + limit < total,
  });
});

// ============================================================================
// noteUpdate
// ============================================================================
export const noteUpdate = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Authentication required');
  }
  const uid = context.auth.uid;

  const {
    orgId,
    noteId,
    caseId: rawCaseId,
    title: rawTitle,
    content: rawContent,
    category: rawCategory,
    isPinned,
    isPrivate,
  } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!noteId || typeof noteId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'noteId is required');
  }

  // Check if at least one field is being updated
  if (
    rawCaseId === undefined &&
    rawTitle === undefined &&
    rawContent === undefined &&
    rawCategory === undefined &&
    isPinned === undefined &&
    isPrivate === undefined
  ) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'At least one field must be provided for update');
  }

  // Get note
  const noteRef = db.collection(`organizations/${orgId}/notes`).doc(noteId);
  const noteDoc = await noteRef.get();

  if (!noteDoc.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  const noteData = noteDoc.data() as NoteDocument;

  if (noteData.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check case access (notes inherit case visibility)
  const caseAccess = await canUserAccessCase(orgId, noteData.caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check private note access - only creator can update private notes
  if (noteData.isPrivate && noteData.createdBy !== uid) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'NOTES',
    requiredPermission: 'note.update',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not allowed to update notes');
  }

  // Prepare update
  const updates: Partial<NoteDocument> = {
    updatedAt: admin.firestore.Timestamp.now(),
    updatedBy: uid,
  };

  if (rawCaseId !== undefined) {
    if (typeof rawCaseId !== 'string' || rawCaseId.trim().length === 0) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'caseId must be a non-empty string');
    }
    const newCaseId = rawCaseId.trim();

    // If changing case, verify access to the target case (notes inherit case visibility)
    if (newCaseId !== noteData.caseId) {
      const targetCaseAccess = await canUserAccessCase(orgId, newCaseId, uid);
      if (!targetCaseAccess.allowed) {
        return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
      }
      updates.caseId = newCaseId;
    }
  }

  if (rawTitle !== undefined) {
    const title = parseTitle(rawTitle);
    if (!title) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Title must be 1-200 characters');
    }
    updates.title = title;
  }

  if (rawContent !== undefined) {
    const content = parseContent(rawContent);
    if (!content) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Content must be 1-10000 characters');
    }
    updates.content = content;
  }

  if (rawCategory !== undefined) {
    const parsedCategory = parseCategory(rawCategory);
    if (!parsedCategory) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid category');
    }
    updates.category = parsedCategory;
  }

  if (isPinned !== undefined) {
    updates.isPinned = isPinned === true;
  }

  if (isPrivate !== undefined) {
    updates.isPrivate = isPrivate === true;
  }

  await noteRef.update(updates);

  // Audit log
  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'note.updated',
    entityType: 'note',
    entityId: noteId,
    metadata: { updatedFields: Object.keys(updates).filter((k) => k !== 'updatedAt' && k !== 'updatedBy') },
  });

  // Return updated note
  const updatedNoteSnap = await noteRef.get();
  const updatedNote = updatedNoteSnap.data() as NoteDocument;

  return successResponse({
    noteId: updatedNote.noteId,
    orgId,
    caseId: updatedNote.caseId,
    title: updatedNote.title,
    content: updatedNote.content,
    category: updatedNote.category,
    isPinned: updatedNote.isPinned,
    isPrivate: updatedNote.isPrivate || false,
    createdAt: toIso(updatedNote.createdAt),
    updatedAt: toIso(updatedNote.updatedAt),
    createdBy: updatedNote.createdBy,
    updatedBy: updatedNote.updatedBy,
  });
});

// ============================================================================
// noteDelete
// ============================================================================
export const noteDelete = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Authentication required');
  }
  const uid = context.auth.uid;

  const { orgId, noteId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'orgId is required');
  }

  if (!noteId || typeof noteId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'noteId is required');
  }

  // Get note
  const noteRef = db.collection(`organizations/${orgId}/notes`).doc(noteId);
  const noteDoc = await noteRef.get();

  if (!noteDoc.exists) {
    // Idempotent - if not found, consider it deleted
    return successResponse({ deleted: true });
  }

  const noteData = noteDoc.data() as NoteDocument;

  if (noteData.deletedAt) {
    // Already deleted - idempotent
    return successResponse({ deleted: true });
  }

  // Check case access (notes inherit case visibility)
  const caseAccess = await canUserAccessCase(orgId, noteData.caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check private note access - only creator can delete private notes
  if (noteData.isPrivate && noteData.createdBy !== uid) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Note not found');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'NOTES',
    requiredPermission: 'note.delete',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not allowed to delete notes');
  }

  // Soft delete
  await noteRef.update({
    deletedAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
    updatedBy: uid,
  });

  // Audit log
  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'note.deleted',
    entityType: 'note',
    entityId: noteId,
    metadata: { caseId: noteData.caseId },
  });

  return successResponse({ deleted: true });
});
