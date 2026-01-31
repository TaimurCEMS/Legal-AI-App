/**
 * Slice 16 - Activity Feed from domain_events
 * List recent activity for org or matter; filter by canUserAccessCase; map to summary + deepLink.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { canUserAccessCase } from '../utils/case-access';
import { buildDeepLink } from '../notifications/deep-link';

const db = admin.firestore();
const auth = admin.auth();

interface DomainEventDoc {
  eventId: string;
  orgId: string;
  matterId?: string | null;
  eventType: string;
  entityType: string;
  entityId: string;
  actor: { actorType: string; actorId: string };
  timestamp: admin.firestore.Timestamp;
  payload: Record<string, unknown>;
}

/** Human-readable summary for eventType */
const EVENT_SUMMARY: Record<string, string> = {
  'matter.created': 'Matter created',
  'matter.updated': 'Matter updated',
  'task.created': 'Task created',
  'task.updated': 'Task updated',
  'task.assigned': 'Task assigned',
  'task.completed': 'Task completed',
  'document.uploaded': 'Document uploaded',
  'invoice.created': 'Invoice created',
  'invoice.sent': 'Invoice sent',
  'payment.received': 'Payment received',
  'payment.failed': 'Payment failed',
  'user.invited': 'User invited',
  'user.joined': 'User joined',
  'client.created': 'Client added',
  'comment.added': 'Comment added',
  'comment.updated': 'Comment updated',
  'comment.deleted': 'Comment deleted',
};

function summaryForEvent(eventType: string): string {
  return EVENT_SUMMARY[eventType] ?? 'Activity';
}

async function getActorDisplayName(actorId: string): Promise<string | null> {
  try {
    const userRecord = await auth.getUser(actorId);
    if (userRecord.displayName) return userRecord.displayName;
    if (userRecord.email) return userRecord.email.split('@')[0];
  } catch {
    // ignore
  }
  return null;
}

/** Ensure user is org member. */
async function requireOrgMember(orgId: string, uid: string): Promise<boolean> {
  const memberRef = db.collection('organizations').doc(orgId).collection('members').doc(uid);
  const memberDoc = await memberRef.get();
  return memberDoc.exists;
}

/**
 * activityFeedList – List recent activity for org or single matter; filter by case access.
 * Request: { orgId, matterId?, limit?, offset?, fromAt?, toAt? }
 * Success: { items: [{ eventId, eventType, entityType, entityId, matterId, actorUid, actorDisplayName?, timestamp, summary, deepLink }], hasMore }
 */
export const activityFeedList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const uid = context.auth.uid;
  const { orgId, matterId, limit: rawLimit, offset: rawOffset } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const isMember = await requireOrgMember(orgId, uid);
  if (!isMember) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const limit = Math.min(Math.max(parseInt(String(rawLimit), 10) || 50, 1), 100);
  const offset = Math.max(parseInt(String(rawOffset), 10) || 0, 0);

  let query: admin.firestore.Query = db
    .collection('domain_events')
    .where('orgId', '==', orgId)
    .orderBy('timestamp', 'desc')
    .limit(offset + limit + 20);

  if (matterId != null && typeof matterId === 'string' && matterId.trim().length > 0) {
    const caseAccess = await canUserAccessCase(orgId, matterId.trim(), uid);
    if (!caseAccess.allowed) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Matter not found or access denied');
    }
    query = db
      .collection('domain_events')
      .where('orgId', '==', orgId)
      .where('matterId', '==', matterId.trim())
      .orderBy('timestamp', 'desc')
      .limit(offset + limit + 20);
  }

  const snapshot = await query.get();
  const actorIds = new Set<string>();
  const events: DomainEventDoc[] = [];
  for (const doc of snapshot.docs) {
    const ev = doc.data() as DomainEventDoc;
    if (ev.matterId) {
      const access = await canUserAccessCase(orgId, ev.matterId, uid);
      if (!access.allowed) continue;
    }
    events.push(ev);
    if (ev.actor?.actorId) actorIds.add(ev.actor.actorId);
  }

  const sliced = events.slice(offset, offset + limit);
  const hasMore = events.length > offset + limit;

  const displayNames: Record<string, string> = {};
  await Promise.all(
    Array.from(actorIds).map(async (actorId) => {
      const name = await getActorDisplayName(actorId);
      if (name) displayNames[actorId] = name;
    })
  );

  const items = sliced.map((ev) => {
    const actorUid = ev.actor?.actorId ?? '';
    let deepLink: string;
    if (ev.entityType === 'comment' && ev.matterId) {
      deepLink = buildDeepLink(ev.orgId, 'matter.updated', 'matter', ev.matterId, null);
    } else {
      deepLink = buildDeepLink(
        ev.orgId,
        ev.eventType,
        ev.entityType,
        ev.entityId,
        ev.matterId ?? null
      );
    }
    return {
      eventId: ev.eventId,
      eventType: ev.eventType,
      entityType: ev.entityType,
      entityId: ev.entityId,
      matterId: ev.matterId ?? null,
      actorUid,
      actorDisplayName: displayNames[actorUid] ?? null,
      timestamp: ev.timestamp.toDate().toISOString(),
      summary: summaryForEvent(ev.eventType),
      deepLink,
    };
  });

  return successResponse({
    items,
    hasMore,
  });
});
