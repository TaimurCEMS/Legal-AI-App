/**
 * P2 Notification routing – event → recipients, permissions, preferences, create notifications + outbox
 */

import * as crypto from 'crypto';
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { canUserAccessCase } from '../utils/case-access';
import { buildDeepLink } from './deep-link';
import { getEffectivePreferences } from './preferences';
import type { NotificationRecord, RoutedEventType } from './types';
import { eventTypeToCategory, ROUTED_EVENT_TYPES } from './types';

const db = admin.firestore();

interface DomainEventData {
  eventId: string;
  orgId: string;
  matterId?: string | null;
  eventType: string;
  entityType: string;
  entityId: string;
  actor: { actorType: string; actorId: string };
  payload: Record<string, unknown>;
}

const MAX_ATTEMPTS = 5;

/** Context for building notification content. */
interface NotificationContext {
  actorName?: string;
  matterTitle?: string;
  clientName?: string;
}

/** Fetch actor's display name from Firebase Auth (where it's stored). */
async function getActorDisplayName(orgId: string, actorId: string): Promise<string | null> {
  try {
    // Display names are stored in Firebase Auth, not in member documents
    const userRecord = await admin.auth().getUser(actorId);
    if (userRecord.displayName) {
      return userRecord.displayName;
    }
    // Fallback to email username if no display name
    if (userRecord.email) {
      return userRecord.email.split('@')[0];
    }
  } catch {
    // User might not exist or auth lookup failed
  }
  return null;
}

/** Fetch matter title and client name. */
async function getMatterContext(
  orgId: string,
  matterId: string
): Promise<{ matterTitle?: string; clientName?: string }> {
  try {
    const matterDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(matterId)
      .get();
    if (!matterDoc.exists) return {};
    const data = matterDoc.data() as { title?: string; clientId?: string };
    const result: { matterTitle?: string; clientName?: string } = {};
    if (data?.title) result.matterTitle = data.title;
    
    // Try to get client name
    if (data?.clientId) {
      const clientDoc = await db
        .collection('organizations')
        .doc(orgId)
        .collection('clients')
        .doc(data.clientId)
        .get();
      if (clientDoc.exists) {
        const clientData = clientDoc.data() as { name?: string; displayName?: string };
        result.clientName = clientData?.displayName || clientData?.name;
      }
    }
    return result;
  } catch {
    return {};
  }
}

/** Human-readable labels for matter status and visibility */
const MATTER_STATUS_LABEL: Record<string, string> = {
  OPEN: 'Open',
  CLOSED: 'Closed',
  ARCHIVED: 'Archived',
};
const MATTER_VISIBILITY_LABEL: Record<string, string> = {
  ORG_WIDE: 'Org-wide',
  PRIVATE: 'Private',
};

/** Human-readable labels for task status and priority */
const TASK_STATUS_LABEL: Record<string, string> = {
  PENDING: 'Pending',
  IN_PROGRESS: 'In progress',
  COMPLETED: 'Completed',
  CANCELLED: 'Cancelled',
};
const TASK_PRIORITY_LABEL: Record<string, string> = {
  LOW: 'Low',
  MEDIUM: 'Medium',
  HIGH: 'High',
};

function label(v: unknown, labels: Record<string, string>): string {
  return (labels[String(v)] ?? String(v)) as string;
}

/** Format "what changed" for matter.updated from payload.changes */
function formatMatterChanges(payload: Record<string, unknown>): string | null {
  const changes = payload.changes as Record<string, { from?: unknown; to?: unknown }> | undefined;
  if (!changes || typeof changes !== 'object') return null;
  const parts: string[] = [];
  if (changes.status?.from !== undefined && changes.status?.to !== undefined && String(changes.status.from) !== String(changes.status.to)) {
    parts.push(`status was changed from ${label(changes.status.from, MATTER_STATUS_LABEL)} to ${label(changes.status.to, MATTER_STATUS_LABEL)}`);
  }
  if (changes.visibility?.from !== undefined && changes.visibility?.to !== undefined && String(changes.visibility.from) !== String(changes.visibility.to)) {
    parts.push(`visibility was changed from ${label(changes.visibility.from, MATTER_VISIBILITY_LABEL)} to ${label(changes.visibility.to, MATTER_VISIBILITY_LABEL)}`);
  }
  if (changes.title?.from !== undefined && changes.title?.to !== undefined && String(changes.title.from) !== String(changes.title.to)) {
    parts.push('title was updated');
  }
  if (changes.clientId && String((changes.clientId as { from?: unknown }).from) !== String((changes.clientId as { to?: unknown }).to)) parts.push('client was updated');
  if (parts.length === 0) return null;
  return parts.join('; ');
}

/** Format "what changed" for task.updated from payload.changes */
function formatTaskChanges(payload: Record<string, unknown>): string | null {
  const changes = payload.changes as Record<string, { from?: unknown; to?: unknown }> | undefined;
  if (!changes || typeof changes !== 'object') return null;
  const parts: string[] = [];
  if (changes.status?.from !== undefined && changes.status?.to !== undefined && changes.status.from !== changes.status.to) {
    parts.push(`status was changed from ${label(changes.status.from, TASK_STATUS_LABEL)} to ${label(changes.status.to, TASK_STATUS_LABEL)}`);
  }
  if (changes.priority?.from !== undefined && changes.priority?.to !== undefined && changes.priority.from !== changes.priority.to) {
    parts.push(`priority was changed from ${label(changes.priority.from, TASK_PRIORITY_LABEL)} to ${label(changes.priority.to, TASK_PRIORITY_LABEL)}`);
  }
  if (changes.title?.from !== undefined && changes.title?.to !== undefined && changes.title.from !== changes.title.to) {
    parts.push('title was updated');
  }
  const aid = changes.assigneeId as { from?: unknown; to?: unknown } | undefined;
  if (aid && aid.from !== aid.to) parts.push('assignee was updated');
  if (changes.dueDate !== undefined) parts.push('due date was updated');
  if (parts.length === 0) return null;
  return parts.join('; ');
}

/** Build title and bodyPreview for in-app/email from event with context. */
function buildTitleAndBody(
  eventType: string,
  payload: Record<string, unknown>,
  ctx: NotificationContext
): { title: string; bodyPreview: string } {
  const payloadTitle = payload.title as string | undefined;
  const t = payloadTitle || 'Item';
  // For matter.updated, payload often has updatedFields only; use matterTitle from context
  const matterDisplayName = ctx.matterTitle || t;
  const actor = ctx.actorName || 'Someone';
  const matter = ctx.matterTitle ? ` in "${ctx.matterTitle}"` : '';
  const client = ctx.clientName ? ` for ${ctx.clientName}` : '';
  
  switch (eventType) {
    case 'matter.created':
      return { 
        title: `New matter: ${t}`,
        bodyPreview: `${actor} created "${t}"${client}.`
      };
    case 'matter.updated': {
      const changeText = formatMatterChanges(payload);
      const body = changeText
        ? `${actor}: In matter "${matterDisplayName}", ${changeText}.`
        : `${actor} updated "${matterDisplayName}".`;
      return { 
        title: `Matter updated: ${matterDisplayName}`,
        bodyPreview: body
      };
    }
    case 'task.created':
      return { 
        title: `New task: ${t}`,
        bodyPreview: `${actor} created task "${t}"${matter}.`
      };
    case 'task.updated': {
      const changeText = formatTaskChanges(payload);
      const body = changeText
        ? `${actor}: In task "${t}"${matter}, ${changeText}.`
        : `${actor} updated task "${t}"${matter}.`;
      return { 
        title: `Task updated: ${t}`,
        bodyPreview: body
      };
    }
    case 'task.assigned':
      return { 
        title: `Task assigned to you: ${t}`,
        bodyPreview: `${actor} assigned you to "${t}"${matter}.`
      };
    case 'task.completed':
      return { 
        title: `Task completed: ${t}`,
        bodyPreview: `${actor} completed "${t}"${matter}.`
      };
    case 'document.uploaded':
      return { 
        title: `New document: ${t}`,
        bodyPreview: `${actor} uploaded "${t}"${matter}.`
      };
    case 'invoice.created':
      return { 
        title: 'New invoice',
        bodyPreview: `${actor} created an invoice${matter}${client}.`
      };
    case 'invoice.sent':
      return { 
        title: 'Invoice sent',
        bodyPreview: `${actor} sent an invoice${matter}${client}.`
      };
    case 'payment.received':
      return { 
        title: 'Payment received',
        bodyPreview: `${actor} recorded a payment${matter}${client}.`
      };
    case 'user.joined':
      return { 
        title: 'New team member',
        bodyPreview: `${actor} joined your firm.`
      };
    case 'client.created':
      return { 
        title: `New client: ${t}`,
        bodyPreview: `${actor} added client "${t}".`
      };
    case 'comment.added':
      return { 
        title: 'New comment',
        bodyPreview: `${actor} added a comment${matter}.`
      };
    case 'comment.updated':
      return { 
        title: 'Comment updated',
        bodyPreview: `${actor} updated a comment${matter}.`
      };
    case 'comment.deleted':
      return { 
        title: 'Comment deleted',
        bodyPreview: `${actor} deleted a comment${matter}.`
      };
    default:
      return { title: 'Update', bodyPreview: `${actor} made an update for "${t}".` };
  }
}

/** Event types for which we also notify org admins/owners (so someone always gets notified). */
const ORG_ACTIVITY_EVENT_TYPES = [
  'matter.created',
  'matter.updated',
  'task.created',
  'task.updated',
  'task.completed',
  'document.uploaded',
  'invoice.created',
  'invoice.sent',
  'payment.received',
  'client.created',
  'comment.added',
  'comment.updated',
  'comment.deleted',
] as const;

/** Fetch org admin/owner UIDs (member doc id is the uid). */
async function getOrgAdminUids(orgId: string): Promise<Set<string>> {
  const membersSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('members')
    .get();
  const uids = new Set<string>();
  membersSnap.docs.forEach((d) => {
    const data = d.data() as { role?: string };
    if (data.role === 'ADMIN' || data.role === 'OWNER') uids.add(d.id);
  });
  return uids;
}

/** Get candidate recipient UIDs for an event (from payload + matter participants + case creator + org admins). */
async function getCandidateRecipients(
  orgId: string,
  event: DomainEventData
): Promise<Set<string>> {
  const uids = new Set<string>();
  const payload = event.payload;
  const actorId = event.actor?.actorId;

  const add = (uid: string | null | undefined) => {
    if (uid && typeof uid === 'string' && uid !== actorId) uids.add(uid);
  };

  add(payload.assigneeId as string);
  add(payload.createdBy as string);
  add(payload.uploadedBy as string);

  const matterId = event.matterId ?? (payload.caseId as string) ?? (payload.matterId as string);
  if (matterId && typeof matterId === 'string') {
    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(matterId);
    const caseDoc = await caseRef.get();
    if (caseDoc.exists) {
      const caseData = caseDoc.data() as { createdBy?: string };
      add(caseData?.createdBy);
    }
    const participantsSnap = await caseRef.collection('participants').get();
    participantsSnap.docs.forEach((d) => add(d.id));
  }

  if (event.eventType === 'user.joined') {
    const adminUids = await getOrgAdminUids(orgId);
    adminUids.forEach((uid) => add(uid));
  }

  // For matter/task/document/invoice activity, also notify org admins so someone sees it (e.g. small firms).
  if (ORG_ACTIVITY_EVENT_TYPES.includes(event.eventType as (typeof ORG_ACTIVITY_EVENT_TYPES)[number])) {
    const adminUids = await getOrgAdminUids(orgId);
    adminUids.forEach((uid) => add(uid));
  }

  return uids;
}

/** Filter recipients by matter access when matterId is present. */
async function filterByAccess(
  orgId: string,
  matterId: string | null | undefined,
  uids: Set<string>
): Promise<Set<string>> {
  if (!matterId) return uids;
  const allowed = new Set<string>();
  await Promise.all(
    Array.from(uids).map(async (uid) => {
      const result = await canUserAccessCase(orgId, matterId, uid);
      if (result.allowed) allowed.add(uid);
    })
  );
  return allowed;
}

/** Idempotency key for per-recipient email outbox job. */
export function outboxIdempotencyKeyForEmail(
  orgId: string,
  eventId: string,
  recipientUid: string
): string {
  return `notif_email:${orgId}:${eventId}:${recipientUid}`;
}

/**
 * Run P2 routing for a domain event: create in-app + email notifications and outbox jobs.
 * Call this from a Firestore trigger on domain_events onCreate.
 */
export async function runNotificationRouting(eventDoc: admin.firestore.DocumentSnapshot): Promise<void> {
  const data = eventDoc.data() as DomainEventData | undefined;
  if (!data?.eventId || !data?.orgId || !data?.eventType) return;

  const eventType = data.eventType as string;
  if (!ROUTED_EVENT_TYPES.includes(eventType as RoutedEventType)) return;

  const category = eventTypeToCategory(eventType);
  
  // Fetch context for richer notifications
  const actorName = data.actor?.actorId 
    ? await getActorDisplayName(data.orgId, data.actor.actorId) 
    : null;
  const matterId = data.matterId ?? (data.payload.caseId as string) ?? (data.payload.matterId as string);
  const matterCtx = matterId ? await getMatterContext(data.orgId, matterId) : {};
  
  const notifContext: NotificationContext = {
    actorName: actorName || undefined,
    matterTitle: matterCtx.matterTitle,
    clientName: matterCtx.clientName,
  };
  
  const { title, bodyPreview } = buildTitleAndBody(eventType, data.payload, notifContext);
  const deepLink = buildDeepLink(
    data.orgId,
    eventType,
    data.entityType,
    data.entityId,
    data.matterId
  );

  let candidateUids = await getCandidateRecipients(data.orgId, data);
  candidateUids = await filterByAccess(data.orgId, data.matterId ?? null, candidateUids);

  if (candidateUids.size === 0) return;

  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  const notificationsRef = db.collection('notifications');
  const outboxRef = db.collection('outbox');

  for (const recipientUid of candidateUids) {
    const prefs = await getEffectivePreferences(data.orgId, recipientUid, category);

    if (prefs.inApp) {
      const notifId = crypto.randomUUID();
      const inAppRef = notificationsRef.doc(notifId);
      const inAppRecord: Omit<NotificationRecord, 'id'> & { id: string } = {
        id: notifId,
        orgId: data.orgId,
        recipientUid,
        eventId: data.eventId,
        channel: 'in_app',
        status: 'pending',
        category,
        title,
        bodyPreview,
        deepLink,
        readAt: null,
        createdAt: now,
        updatedAt: now,
      };
      batch.set(inAppRef, inAppRecord);
    }

    if (prefs.email) {
      const emailNotifId = crypto.randomUUID();
      const emailRef = notificationsRef.doc(emailNotifId);
      const emailRecord: Omit<NotificationRecord, 'id'> & { id: string } = {
        id: emailNotifId,
        orgId: data.orgId,
        recipientUid,
        eventId: data.eventId,
        channel: 'email',
        status: 'pending',
        category,
        title,
        bodyPreview,
        deepLink,
        templateId: eventType,
        templateVersion: 1,
        createdAt: now,
        updatedAt: now,
      };
      batch.set(emailRef, emailRecord);
      const outboxId = outboxIdempotencyKeyForEmail(data.orgId, data.eventId, recipientUid);
      batch.set(outboxRef.doc(outboxId), {
        id: outboxId,
        orgId: data.orgId,
        eventId: data.eventId,
        recipientUid,
        jobType: 'notification_dispatch',
        status: 'pending',
        attempts: 0,
        maxAttempts: MAX_ATTEMPTS,
        nextAttemptAt: now,
        createdAt: now,
        updatedAt: now,
      });
    }
  }

  await batch.commit();
  functions.logger.info('P2 routing completed', {
    eventId: data.eventId,
    eventType,
    recipientCount: candidateUids.size,
  });
}
