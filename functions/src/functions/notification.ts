/**
 * P2 Notification Engine – callables: list, mark read, preferences
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { getAllPreferences, getEffectivePreferences } from '../notifications/preferences';
import type { NotificationCategory } from '../notifications/types';

const db = admin.firestore();

/** Valid notification categories for filtering. */
const VALID_CATEGORIES = ['matter', 'task', 'document', 'invoice', 'payment', 'comment', 'user', 'client'];

/** List in-app notifications for current user (org-scoped), newest first.
 *  Supports optional filters: category, readStatus ('all' | 'read' | 'unread')
 */
export const notificationList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId, limit: rawLimit, channel, category, categories: categoriesRaw, readStatus } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not a member of this organization');
  }

  const limit = Math.min(Math.max(1, parseInt(String(rawLimit), 10) || 50), 100);
  const chan = channel === 'email' ? 'email' : 'in_app';

  // Build query with required filters
  let query: admin.firestore.Query = db
    .collection('notifications')
    .where('recipientUid', '==', uid)
    .where('orgId', '==', orgId)
    .where('channel', '==', chan);

  // Optional category filter: single category (legacy) or multiple (categories array, max 10 for Firestore 'in')
  const categoriesArr = Array.isArray(categoriesRaw)
    ? (categoriesRaw as string[]).filter((c) => typeof c === 'string' && VALID_CATEGORIES.includes(c)).slice(0, 10)
    : [];
  if (categoriesArr.length > 0) {
    query = query.where('category', 'in', categoriesArr);
  } else if (category && typeof category === 'string' && VALID_CATEGORIES.includes(category)) {
    query = query.where('category', '==', category);
  }

  // Optional read status filter. For inequality (readAt != null), Firestore requires orderBy on that field first.
  if (readStatus === 'read') {
    query = query.where('readAt', '!=', null);
    query = query.orderBy('readAt', 'desc').orderBy('createdAt', 'desc').limit(limit);
  } else if (readStatus === 'unread') {
    query = query.where('readAt', '==', null);
    query = query.orderBy('createdAt', 'desc').limit(limit);
  } else {
    query = query.orderBy('createdAt', 'desc').limit(limit);
  }

  const snapshot = await query.get();

  const notifications = snapshot.docs.map((doc) => {
    const d = doc.data();
    const createdAt = d.createdAt?.toDate?.()?.toISOString?.() ?? null;
    const readAt = d.readAt?.toDate?.()?.toISOString?.() ?? null;
    return {
      id: doc.id,
      orgId: d.orgId,
      eventId: d.eventId,
      channel: d.channel,
      category: d.category,
      title: d.title,
      bodyPreview: d.bodyPreview,
      deepLink: d.deepLink,
      readAt,
      status: d.status,
      createdAt,
    };
  });

  return successResponse({ notifications });
});

/** Mark a single notification as read. */
export const notificationMarkRead = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId, notificationId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!notificationId || typeof notificationId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Notification ID is required');
  }

  const ref = db.collection('notifications').doc(notificationId);
  const snap = await ref.get();
  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Notification not found');
  }
  const docData = snap.data()!;
  if (docData.recipientUid !== uid || docData.orgId !== orgId) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to update this notification');
  }

  const now = admin.firestore.Timestamp.now();
  await ref.update({ readAt: now, updatedAt: now });
  return successResponse({ ok: true });
});

/** Mark all in-app notifications for user in org as read. */
export const notificationMarkAllRead = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const snapshot = await db
    .collection('notifications')
    .where('recipientUid', '==', uid)
    .where('orgId', '==', orgId)
    .where('channel', '==', 'in_app')
    .where('readAt', '==', null)
    .get();

  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { readAt: now, updatedAt: now });
  });
  await batch.commit();
  return successResponse({ marked: snapshot.size });
});

/** Get unread count for in-app notifications (org-scoped). */
export const notificationUnreadCount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const snapshot = await db
    .collection('notifications')
    .where('recipientUid', '==', uid)
    .where('orgId', '==', orgId)
    .where('channel', '==', 'in_app')
    .where('readAt', '==', null)
    .count()
    .get();

  return successResponse({ count: snapshot.data().count });
});

/** Get notification preferences for current user in org. */
export const notificationPreferencesGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not a member of this organization');
  }

  const prefs = await getAllPreferences(orgId, uid);
  return successResponse({ preferences: prefs });
});

/** Update a single category preference. */
export const notificationPreferencesUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { orgId, category, inApp, email } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  const categories: NotificationCategory[] = [
    'matter',
    'task',
    'document',
    'invoice',
    'payment',
    'comment',
    'user',
    'client',
  ];
  if (!category || typeof category !== 'string' || !categories.includes(category as NotificationCategory)) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Valid category is required');
  }

  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not a member of this organization');
  }

  const docId = `${orgId}_${uid}_${category}`;
  const now = admin.firestore.Timestamp.now();
  const ref = db.collection('notification_preferences').doc(docId);
  await ref.set(
    {
      orgId,
      uid,
      category,
      inApp: typeof inApp === 'boolean' ? inApp : (await getEffectivePreferences(orgId, uid, category as NotificationCategory)).inApp,
      email: typeof email === 'boolean' ? email : (await getEffectivePreferences(orgId, uid, category as NotificationCategory)).email,
      updatedAt: now,
    },
    { merge: true }
  );
  const updated = await getAllPreferences(orgId, uid);
  return successResponse({ preferences: updated });
});
