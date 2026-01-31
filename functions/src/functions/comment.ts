/**
 * Slice 16 - Comments on matters, tasks, and documents
 * Comment CRUD with case access; emit comment.added for P2 notifications.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { canUserAccessCase } from '../utils/case-access';
import { emitDomainEventWithOutbox } from '../utils/domain-events';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

interface CommentDocument {
  commentId: string;
  orgId: string;
  matterId: string;
  taskId?: string | null;
  documentId?: string | null;
  authorUid: string;
  body: string;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  deletedAt?: FirestoreTimestamp | null;
}

const MAX_BODY_LENGTH = 5000;

function parseBody(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length > MAX_BODY_LENGTH) return null;
  return trimmed;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

function commentsRef(orgId: string) {
  return db.collection('organizations').doc(orgId).collection('comments');
}

/** Ensure user is org member (has membership doc). */
async function requireOrgMember(orgId: string, uid: string): Promise<boolean> {
  const memberRef = db.collection('organizations').doc(orgId).collection('members').doc(uid);
  const memberDoc = await memberRef.get();
  return memberDoc.exists;
}

/** Check if user is ADMIN or OWNER in org. */
async function isOrgAdmin(orgId: string, uid: string): Promise<boolean> {
  const memberRef = db.collection('organizations').doc(orgId).collection('members').doc(uid);
  const memberDoc = await memberRef.get();
  if (!memberDoc.exists) return false;
  const data = memberDoc.data() as { role?: string };
  return data?.role === 'ADMIN' || data?.role === 'OWNER';
}

/**
 * commentCreate – Create comment on a matter, task, or document.
 * Request: { orgId, matterId, taskId?, documentId?, body }
 * matterId required; exactly one of taskId or documentId optional (comment on matter = neither; on task = taskId; on document = documentId).
 */
export const commentCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, matterId, taskId, documentId, body: rawBody } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!matterId || typeof matterId !== 'string' || matterId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'matterId is required');
  }

  const body = parseBody(rawBody);
  if (!body) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `Body must be 1-${MAX_BODY_LENGTH} characters`
    );
  }

  // Exactly one of taskId or documentId: either both absent (comment on matter) or exactly one set
  const hasTask = taskId != null && typeof taskId === 'string' && taskId.trim().length > 0;
  const hasDoc = documentId != null && typeof documentId === 'string' && documentId.trim().length > 0;
  if (hasTask && hasDoc) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Provide either taskId or documentId, not both');
  }

  const isMember = await requireOrgMember(orgId, uid);
  if (!isMember) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
  }

  const caseAccess = await canUserAccessCase(orgId, matterId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Case not found or access denied');
  }

  const now = admin.firestore.Timestamp.now();
  const commentRef = commentsRef(orgId).doc();
  const commentId = commentRef.id;

  const commentData: CommentDocument = {
    commentId,
    orgId,
    matterId,
    ...(hasTask && { taskId: taskId!.trim() }),
    ...(hasDoc && { documentId: documentId!.trim() }),
    authorUid: uid,
    body,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  };

  await commentRef.set(commentData);

  const eventPayload: Record<string, unknown> = {
    body: body.slice(0, 200),
    matterId,
  };
  if (hasTask) eventPayload.taskId = taskId!.trim();
  if (hasDoc) eventPayload.documentId = documentId!.trim();
  try {
    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'comment.added',
      entityType: 'comment',
      entityId: commentId,
      actor: { actorType: 'user', actorId: uid },
      payload: eventPayload,
      matterId,
    });
  } catch (err) {
    functions.logger.warn('commentCreate: emitDomainEventWithOutbox failed', { commentId, err });
    // Comment is already saved; return success so client sees the comment
  }

  return successResponse({
    commentId,
    orgId,
    matterId,
    ...(hasTask && { taskId: taskId!.trim() }),
    ...(hasDoc && { documentId: documentId!.trim() }),
    authorUid: uid,
    body,
    createdAt: toIso(now),
    updatedAt: toIso(now),
  });
});

/**
 * commentGet – Get single comment (with case access check).
 */
export const commentGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, commentId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!commentId || typeof commentId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'commentId is required');
  }

  const isMember = await requireOrgMember(orgId, uid);
  if (!isMember) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const commentRef = commentsRef(orgId).doc(commentId);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const comment = commentSnap.data() as CommentDocument;
  if (comment.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const caseAccess = await canUserAccessCase(orgId, comment.matterId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  return successResponse({
    commentId: comment.commentId,
    orgId: comment.orgId,
    matterId: comment.matterId,
    taskId: comment.taskId ?? null,
    documentId: comment.documentId ?? null,
    authorUid: comment.authorUid,
    body: comment.body,
    createdAt: toIso(comment.createdAt),
    updatedAt: toIso(comment.updatedAt),
  });
});

/**
 * commentList – List comments by matterId, taskId, or documentId (one required). Paginated.
 */
export const commentList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, matterId, taskId, documentId, limit: rawLimit, offset: rawOffset } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const hasMatter = matterId != null && typeof matterId === 'string' && matterId.trim().length > 0;
  const hasTask = taskId != null && typeof taskId === 'string' && taskId.trim().length > 0;
  const hasDoc = documentId != null && typeof documentId === 'string' && documentId.trim().length > 0;

  if (!hasMatter && !hasTask && !hasDoc) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'One of matterId, taskId, or documentId is required');
  }
  if ([hasMatter, hasTask, hasDoc].filter(Boolean).length > 1) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Provide only one of matterId, taskId, or documentId');
  }

  let listMatterId: string;
  if (hasMatter) {
    listMatterId = matterId!.trim();
  } else if (hasTask) {
    const taskRef = db.collection('organizations').doc(orgId).collection('tasks').doc(taskId!.trim());
    const taskSnap = await taskRef.get();
    if (!taskSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Task not found');
    listMatterId = (taskSnap.data() as { caseId?: string }).caseId ?? '';
    if (!listMatterId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Task is not linked to a case');
  } else {
    const docRef = db.collection('organizations').doc(orgId).collection('documents').doc(documentId!.trim());
    const docSnap = await docRef.get();
    if (!docSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
    listMatterId = (docSnap.data() as { caseId?: string }).caseId ?? '';
    if (!listMatterId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Document is not linked to a case');
  }

  const caseAccess = await canUserAccessCase(orgId, listMatterId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Case not found or access denied');
  }

  const isMember = await requireOrgMember(orgId, uid);
  if (!isMember) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const limit = Math.min(Math.max(parseInt(String(rawLimit), 10) || 50, 1), 100);
  const offset = Math.max(parseInt(String(rawOffset), 10) || 0, 0);

  let query: admin.firestore.Query;
  if (hasMatter && !hasTask && !hasDoc) {
    query = commentsRef(orgId)
      .where('matterId', '==', matterId!.trim())
      .orderBy('createdAt', 'desc')
      .limit(offset + limit + 30);
  } else if (hasTask) {
    query = commentsRef(orgId)
      .where('taskId', '==', taskId!.trim())
      .orderBy('createdAt', 'desc')
      .limit(offset + limit + 30);
  } else {
    query = commentsRef(orgId)
      .where('documentId', '==', documentId!.trim())
      .orderBy('createdAt', 'desc')
      .limit(offset + limit + 30);
  }

  const snapshot = await query.get();
  const nonDeleted = snapshot.docs.filter((d) => !(d.data() as CommentDocument).deletedAt);
  const docs = nonDeleted.slice(offset, offset + limit);
  const hasMore = nonDeleted.length > offset + limit;

  const comments = docs.map((d) => {
    const c = d.data() as CommentDocument;
    return {
      commentId: c.commentId,
      orgId: c.orgId,
      matterId: c.matterId,
      taskId: c.taskId ?? null,
      documentId: c.documentId ?? null,
      authorUid: c.authorUid,
      body: c.body,
      createdAt: toIso(c.createdAt),
      updatedAt: toIso(c.updatedAt),
    };
  });

  return successResponse({
    comments,
    total: comments.length,
    hasMore,
  });
});

/**
 * commentUpdate – Update own comment (body only). Author or ADMIN.
 */
export const commentUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, commentId, body: rawBody } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!commentId || typeof commentId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'commentId is required');
  }

  const body = parseBody(rawBody);
  if (!body) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `Body must be 1-${MAX_BODY_LENGTH} characters`
    );
  }

  const commentRef = commentsRef(orgId).doc(commentId);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const comment = commentSnap.data() as CommentDocument;
  if (comment.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const caseAccess = await canUserAccessCase(orgId, comment.matterId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const isAdmin = await isOrgAdmin(orgId, uid);
  if (comment.authorUid !== uid && !isAdmin) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Only the author or an admin can update this comment');
  }

  const now = admin.firestore.Timestamp.now();
  await commentRef.update({
    body,
    updatedAt: now,
  });

  // Emit comment.updated domain event for audit trail
  const updateEventPayload: Record<string, unknown> = {
    body: body.slice(0, 200),
    matterId: comment.matterId,
  };
  if (comment.taskId) updateEventPayload.taskId = comment.taskId;
  if (comment.documentId) updateEventPayload.documentId = comment.documentId;
  try {
    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'comment.updated',
      entityType: 'comment',
      entityId: commentId,
      actor: { actorType: 'user', actorId: uid },
      payload: updateEventPayload,
      matterId: comment.matterId,
    });
  } catch (err) {
    functions.logger.warn('commentUpdate: emitDomainEventWithOutbox failed', { commentId, err });
  }

  return successResponse({
    commentId: comment.commentId,
    orgId: comment.orgId,
    matterId: comment.matterId,
    taskId: comment.taskId ?? null,
    documentId: comment.documentId ?? null,
    authorUid: comment.authorUid,
    body,
    createdAt: toIso(comment.createdAt),
    updatedAt: toIso(now),
  });
});

/**
 * commentDelete – Soft delete own comment (or ADMIN).
 */
export const commentDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, commentId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!commentId || typeof commentId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'commentId is required');
  }

  const commentRef = commentsRef(orgId).doc(commentId);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const comment = commentSnap.data() as CommentDocument;
  if (comment.deletedAt) {
    return successResponse({ deleted: true });
  }

  const caseAccess = await canUserAccessCase(orgId, comment.matterId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Comment not found');
  }

  const isAdmin = await isOrgAdmin(orgId, uid);
  if (comment.authorUid !== uid && !isAdmin) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Only the author or an admin can delete this comment');
  }

  const now = admin.firestore.Timestamp.now();
  await commentRef.update({
    deletedAt: now,
    updatedAt: now,
  });

  // Emit comment.deleted domain event for audit trail
  const deleteEventPayload: Record<string, unknown> = {
    matterId: comment.matterId,
  };
  if (comment.taskId) deleteEventPayload.taskId = comment.taskId;
  if (comment.documentId) deleteEventPayload.documentId = comment.documentId;
  try {
    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'comment.deleted',
      entityType: 'comment',
      entityId: commentId,
      actor: { actorType: 'user', actorId: uid },
      payload: deleteEventPayload,
      matterId: comment.matterId,
    });
  } catch (err) {
    functions.logger.warn('commentDelete: emitDomainEventWithOutbox failed', { commentId, err });
  }

  return successResponse({ deleted: true });
});
