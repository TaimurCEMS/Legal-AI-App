/**
 * P2 Notification preferences – read defaults and per-user settings
 */

import * as admin from 'firebase-admin';
import type { NotificationCategory, NotificationPreference } from './types';

const db = admin.firestore();

const DEFAULT_IN_APP = true;
const DEFAULT_EMAIL = true;

/** Get effective preference for a user/org/category: in_app and email toggles. */
export async function getEffectivePreferences(
  orgId: string,
  uid: string,
  category: NotificationCategory
): Promise<{ inApp: boolean; email: boolean }> {
  const prefRef = db
    .collection('notification_preferences')
    .doc(`${orgId}_${uid}_${category}`);

  const snap = await prefRef.get();
  if (!snap.exists) {
    return { inApp: DEFAULT_IN_APP, email: DEFAULT_EMAIL };
  }

  const data = snap.data() as NotificationPreference;
  return {
    inApp: data.inApp ?? DEFAULT_IN_APP,
    email: data.email ?? DEFAULT_EMAIL,
  };
}

/** Get all preferences for a user in an org (for UI). */
export async function getAllPreferences(
  orgId: string,
  uid: string
): Promise<Record<NotificationCategory, { inApp: boolean; email: boolean }>> {
  const categories: NotificationCategory[] = [
    'matter',
    'task',
    'document',
    'invoice',
    'payment',
    'comment',
    'user',
  ];
  const out: Record<string, { inApp: boolean; email: boolean }> = {};
  await Promise.all(
    categories.map(async (cat) => {
      out[cat] = await getEffectivePreferences(orgId, uid, cat);
    })
  );
  return out as Record<NotificationCategory, { inApp: boolean; email: boolean }>;
}
