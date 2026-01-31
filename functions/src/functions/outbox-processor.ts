/**
 * P1 Outbox Processor + P2 email dispatch
 * Scheduled function to drain outbox jobs (notification_dispatch). P2: per-recipient email send.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getBackoffMs } from '../utils/domain-events';
import { isSuppressed } from '../notifications/suppression';
import { sendEmail } from '../notifications/email-provider';
import { renderTemplate, getDefaultTemplate } from '../notifications/templates';

const db = admin.firestore();
const auth = admin.auth();

type OutboxStatus = 'pending' | 'processing' | 'sent' | 'failed' | 'dead';

interface OutboxDoc {
  id: string;
  orgId: string;
  eventId: string;
  jobType: string;
  recipientUid?: string | null;
  status: OutboxStatus;
  attempts: number;
  maxAttempts: number;
  nextAttemptAt: admin.firestore.Timestamp;
  lockedAt?: admin.firestore.Timestamp | null;
  lockOwner?: string | null;
  lastError?: { code?: string; message: string; at: admin.firestore.Timestamp } | null;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

/** P2: load email notification by eventId + recipientUid, send email, update notification + outbox. */
async function processEmailDispatch(
  orgId: string,
  eventId: string,
  recipientUid: string,
  outboxId: string
): Promise<{ success: boolean; errorMessage: string }> {
  const notificationsSnap = await db
    .collection('notifications')
    .where('eventId', '==', eventId)
    .where('recipientUid', '==', recipientUid)
    .where('channel', '==', 'email')
    .limit(1)
    .get();

  if (notificationsSnap.empty) {
    return { success: false, errorMessage: 'Notification record not found' };
  }

  const notifDoc = notificationsSnap.docs[0];
  const notifData = notifDoc.data() as {
    status: string;
    title: string;
    bodyPreview: string;
    templateId?: string | null;
    templateVersion?: number | null;
  };

  if (notifData.status !== 'pending' && notifData.status !== 'failed') {
    return { success: true, errorMessage: '' }; // already sent/suppressed
  }

  let email: string;
  try {
    const userRecord = await auth.getUser(recipientUid);
    email = userRecord.email ?? '';
    if (!email) {
      return { success: false, errorMessage: 'User has no email' };
    }
  } catch (e) {
    return { success: false, errorMessage: (e as Error).message ?? 'Failed to get user email' };
  }

  const suppressed = await isSuppressed(orgId, email);
  if (suppressed) {
    const now = admin.firestore.Timestamp.now();
    await notifDoc.ref.update({
      status: 'suppressed',
      updatedAt: now,
    });
    return { success: true, errorMessage: '' }; // treat as success for outbox
  }

  const template = getDefaultTemplate(notifData.templateId ?? 'matter.created');
  const rendered = renderTemplate(template, {
    title: notifData.title ?? notifData.bodyPreview ?? 'Update',
  });

  if (!rendered.ok) {
    return { success: false, errorMessage: rendered.error };
  }

  const sendResult = await sendEmail({
    to: email,
    subject: rendered.subject,
    html: rendered.html,
    text: rendered.text ?? null,
    idempotencyKey: outboxId,
  });

  const now = admin.firestore.Timestamp.now();
  if (sendResult.ok) {
    await notifDoc.ref.update({
      status: 'sent',
      sentAt: now,
      updatedAt: now,
    });
    return { success: true, errorMessage: '' };
  }
  await notifDoc.ref.update({
    status: 'failed',
    errorMessage: sendResult.error ?? 'Send failed',
    updatedAt: now,
  });
  return { success: false, errorMessage: sendResult.error ?? 'Send failed' };
}

/**
 * Process a single outbox record. P2: if recipientUid present, dispatch email; else legacy no-op.
 */
async function processOutboxRecord(doc: admin.firestore.DocumentSnapshot): Promise<boolean> {
  const data = doc.data() as OutboxDoc | undefined;
  if (!data || data.jobType !== 'notification_dispatch') return false;

  const now = admin.firestore.Timestamp.now();
  const instanceId = `processor-${now.toMillis()}-${Math.random().toString(36).slice(2, 9)}`;

  const outboxRef = doc.ref;
  try {
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(outboxRef);
      const freshData = fresh.data() as OutboxDoc | undefined;
      if (!freshData || freshData.status !== 'pending') {
        return;
      }
      if (freshData.nextAttemptAt.toMillis() > now.toMillis()) {
        return;
      }
      tx.update(outboxRef, {
        status: 'processing',
        lockedAt: now,
        lockOwner: instanceId,
        updatedAt: now,
      });
    });
  } catch (e) {
    functions.logger.warn('Outbox lock failed', { id: doc.id, error: (e as Error).message });
    return false;
  }

  let success = true;
  let sendErrorMessage = 'Unknown';

  if (data.recipientUid) {
    const result = await processEmailDispatch(
      data.orgId,
      data.eventId,
      data.recipientUid,
      doc.id
    );
    success = result.success;
    sendErrorMessage = result.errorMessage;
  } else {
    functions.logger.info('Outbox process (legacy no-op)', {
      outboxId: doc.id,
      eventId: data.eventId,
      orgId: data.orgId,
    });
  }

  const updatedAt = admin.firestore.Timestamp.now();

  if (success) {
    await outboxRef.update({
      status: 'sent',
      sentAt: updatedAt,
      updatedAt,
      lockedAt: admin.firestore.FieldValue.delete(),
      lockOwner: admin.firestore.FieldValue.delete(),
    });
    return true;
  }

  const attempts = (data.attempts ?? 0) + 1;
  const maxAttempts = data.maxAttempts ?? 5;
  const lastError = {
    code: 'SEND_FAILED',
    message: sendErrorMessage,
    at: updatedAt,
  };

  if (attempts >= maxAttempts) {
    await outboxRef.update({
      status: 'dead',
      attempts,
      lastError,
      updatedAt,
      lockedAt: admin.firestore.FieldValue.delete(),
      lockOwner: admin.firestore.FieldValue.delete(),
    });
  } else {
    const backoffMs = getBackoffMs(attempts);
    const nextAttemptAt = admin.firestore.Timestamp.fromMillis(updatedAt.toMillis() + backoffMs);
    await outboxRef.update({
      status: 'pending',
      attempts,
      nextAttemptAt,
      lastError,
      updatedAt,
      lockedAt: admin.firestore.FieldValue.delete(),
      lockOwner: admin.firestore.FieldValue.delete(),
    });
  }
  return false;
}

/**
 * Scheduled every 1 minute: query outbox where status=pending and nextAttemptAt <= now, lock and process.
 */
export const outboxProcessorSchedule = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('UTC')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
  const snapshot = await db
    .collection('outbox')
    .where('status', '==', 'pending')
    .where('nextAttemptAt', '<=', now)
    .limit(50)
    .get();

  let processed = 0;
  for (const doc of snapshot.docs) {
    const ok = await processOutboxRecord(doc);
    if (ok) processed++;
  }

  functions.logger.info('Outbox processor run', {
    queried: snapshot.size,
    processed,
  });
  });
