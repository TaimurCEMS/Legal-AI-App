/**
 * P1 Domain Events + Outbox
 * Durable event emission and outbox records for notification dispatch (P2) and activity feed.
 */

import * as crypto from 'crypto';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export type ActorType = 'user' | 'system';

export interface DomainEventActor {
  actorType: ActorType;
  actorId: string;
}

export interface DomainEventVisibility {
  audience: 'internal' | 'client' | 'both';
  rolesAllowed?: string[];
}

export interface DomainEventPayload {
  eventId: string;
  orgId: string;
  matterId?: string | null;
  eventType: string;
  entityType: string;
  entityId: string;
  actor: DomainEventActor;
  timestamp: string; // ISO
  visibility: DomainEventVisibility;
  payload: Record<string, unknown>;
}

const DEFAULT_VISIBILITY: DomainEventVisibility = {
  audience: 'internal',
};

/**
 * Backoff delay in milliseconds for attempt N (1-based).
 * P1: 1 min, 5 min, 15 min, 60 min, then dead.
 */
export function getBackoffMs(attempt: number): number {
  const minutes = [1, 5, 15, 60];
  const idx = Math.min(attempt - 1, minutes.length - 1);
  return minutes[idx] * 60 * 1000;
}

const MAX_ATTEMPTS = 5;

/**
 * Write a domain event and optionally create one outbox record per event (P1: one job per event).
 * Uses a batch: if outbox write is used for idempotency, we skip creating duplicate outbox.
 */
export async function emitDomainEvent(params: {
  orgId: string;
  eventType: string;
  entityType: string;
  entityId: string;
  actor: DomainEventActor;
  payload: Record<string, unknown>;
  visibility?: DomainEventVisibility;
  matterId?: string | null;
}): Promise<{ eventId: string }> {
  const eventId = crypto.randomUUID();
  const now = admin.firestore.Timestamp.now();
  const timestampIso = now.toDate().toISOString();

  const visibility = params.visibility ?? DEFAULT_VISIBILITY;

  const eventsRef = db.collection('domain_events').doc(eventId);
  await eventsRef.set({
    eventId,
    orgId: params.orgId,
    ...(params.matterId && { matterId: params.matterId }),
    eventType: params.eventType,
    entityType: params.entityType,
    entityId: params.entityId,
    actor: params.actor,
    timestamp: now,
    timestampIso,
    visibility,
    payload: params.payload,
  });

  return { eventId };
}

/**
 * Create an outbox record for notification_dispatch (P1: one job per event; P2 will add per-recipient).
 * Idempotent: if a document with the same id already exists, skip create.
 */
export async function createOutboxForEvent(params: {
  orgId: string;
  eventId: string;
  idempotencyKey: string;
}): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const outboxRef = db.collection('outbox').doc(params.idempotencyKey);

  const existing = await outboxRef.get();
  if (existing.exists) {
    return; // idempotent
  }

  await outboxRef.set({
    id: params.idempotencyKey,
    orgId: params.orgId,
    eventId: params.eventId,
    jobType: 'notification_dispatch',
    status: 'pending',
    attempts: 0,
    maxAttempts: MAX_ATTEMPTS,
    nextAttemptAt: now,
    createdAt: now,
    updatedAt: now,
  });
}

/**
 * Build idempotency key for notification_dispatch (P1: one per event).
 * Format: notif:<orgId>:<eventId> for single job per event.
 */
export function outboxIdempotencyKeyForEvent(orgId: string, eventId: string): string {
  return `notif:${orgId}:${eventId}`;
}

/**
 * Emit domain event and create one outbox record in the same batch (P1: same logical flow).
 * P2 trigger on domain_events will create per-recipient outbox jobs; this ensures at least
 * one outbox record per event for processor visibility and at-most-once semantics.
 */
export async function emitDomainEventWithOutbox(params: {
  orgId: string;
  eventType: string;
  entityType: string;
  entityId: string;
  actor: DomainEventActor;
  payload: Record<string, unknown>;
  visibility?: DomainEventVisibility;
  matterId?: string | null;
}): Promise<{ eventId: string }> {
  const eventId = crypto.randomUUID();
  const now = admin.firestore.Timestamp.now();
  const timestampIso = now.toDate().toISOString();
  const visibility = params.visibility ?? DEFAULT_VISIBILITY;

  const eventsRef = db.collection('domain_events').doc(eventId);
  const eventDoc = {
    eventId,
    orgId: params.orgId,
    ...(params.matterId && { matterId: params.matterId }),
    eventType: params.eventType,
    entityType: params.entityType,
    entityId: params.entityId,
    actor: params.actor,
    timestamp: now,
    timestampIso,
    visibility,
    payload: params.payload,
  };

  const idempotencyKey = outboxIdempotencyKeyForEvent(params.orgId, eventId);
  const outboxRef = db.collection('outbox').doc(idempotencyKey);
  const outboxDoc = {
    id: idempotencyKey,
    orgId: params.orgId,
    eventId,
    jobType: 'notification_dispatch',
    status: 'pending',
    attempts: 0,
    maxAttempts: MAX_ATTEMPTS,
    nextAttemptAt: now,
    createdAt: now,
    updatedAt: now,
  };

  const batch = db.batch();
  batch.set(eventsRef, eventDoc);
  batch.set(outboxRef, outboxDoc);
  await batch.commit();

  return { eventId };
}
