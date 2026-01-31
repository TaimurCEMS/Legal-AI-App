/**
 * P2 Suppression list – check before sending email
 */

import * as admin from 'firebase-admin';

const db = admin.firestore();

/** Returns true if email is suppressed for this org (do not send). */
export async function isSuppressed(orgId: string, email: string): Promise<boolean> {
  const normalized = email.trim().toLowerCase();
  const ref = db.collection('suppression_list').doc(`${orgId}_${normalized}`);
  const snap = await ref.get();
  return snap.exists;
}
