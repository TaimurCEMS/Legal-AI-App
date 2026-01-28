/**
 * Time Tracking Functions (Slice 10 - Time Tracking)
 *
 * MVP goals:
 * - Manual time entry CRUD
 * - Server-side timer start/stop (resilient across refresh)
 * - One running timer per user enforced server-side
 * - Optional case/client linking with case access enforcement
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { canUserAccessCase } from '../utils/case-access';
import { createAuditEvent } from '../utils/audit';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;
type TimeEntryStatus = 'running' | 'stopped';

interface TimeEntryDocument {
  timeEntryId: string;
  orgId: string;
  caseId?: string | null;
  clientId?: string | null;
  description: string;
  billable: boolean;
  status: TimeEntryStatus;
  startAt: FirestoreTimestamp;
  endAt?: FirestoreTimestamp | null;
  durationSeconds: number;
  rateCents?: number | null;
  currency?: string | null;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

interface RunningTimerDocument {
  orgId: string;
  uid: string;
  timeEntryId: string;
  startedAt: FirestoreTimestamp;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

function parseNonEmptyString(raw: unknown, maxLen: number): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.length > maxLen) return null;
  return trimmed;
}

function parseOptionalString(raw: unknown, maxLen: number): string | null {
  if (raw === undefined) return null;
  if (raw === null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.length > maxLen) return null;
  return trimmed;
}

function parseBoolean(raw: unknown, defaultValue: boolean): boolean {
  return typeof raw === 'boolean' ? raw : defaultValue;
}

function parseIsoDateTime(raw: unknown): Date | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const d = new Date(trimmed);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function secondsBetween(start: Date, end: Date): number {
  return Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
}

async function verifyClientExists(orgId: string, clientId: string): Promise<boolean> {
  const ref = db.collection('organizations').doc(orgId).collection('clients').doc(clientId);
  const snap = await ref.get();
  if (!snap.exists) return false;
  const data = snap.data() as { deletedAt?: FirestoreTimestamp | null };
  if (data?.deletedAt) return false;
  return true;
}

async function verifyCaseAccess(orgId: string, caseId: string, uid: string): Promise<boolean> {
  const access = await canUserAccessCase(orgId, caseId, uid);
  return access.allowed;
}

async function findRunningEntry(orgId: string, uid: string): Promise<admin.firestore.QueryDocumentSnapshot | null> {
  const snap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('timeEntries')
    .where('deletedAt', '==', null)
    .where('createdBy', '==', uid)
    .where('status', '==', 'running')
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
}

function runningTimerRef(orgId: string, uid: string) {
  return db.collection('organizations').doc(orgId).collection('runningTimers').doc(uid);
}

/**
 * Create a manual time entry (stopped).
 * Export name: timeEntryCreate
 */
export const timeEntryCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, clientId, description, billable, startAt, endAt } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const parsedDescription = parseNonEmptyString(description, 2000);
  if (!parsedDescription) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Description is required (max 2000 characters)');
  }

  const startDate = parseIsoDateTime(startAt);
  const endDate = parseIsoDateTime(endAt);
  if (!startDate || !endDate) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'startAt and endAt must be valid ISO timestamps');
  }
  if (endDate.getTime() < startDate.getTime()) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'endAt must be after startAt');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.create',
  });
  if (!entitlement.allowed) {
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'TIME_TRACKING is not available in the current plan.');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const parsedCaseId = parseOptionalString(caseId, 120);
  if (caseId !== undefined && caseId !== null && parsedCaseId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
  }
  if (parsedCaseId) {
    const allowed = await verifyCaseAccess(orgId, parsedCaseId, uid);
    if (!allowed) return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
  }

  const parsedClientId = parseOptionalString(clientId, 120);
  if (clientId !== undefined && clientId !== null && parsedClientId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid clientId');
  }
  if (parsedClientId) {
    const exists = await verifyClientExists(orgId, parsedClientId);
    if (!exists) return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
  }

  const now = admin.firestore.Timestamp.now();
  const ref = db.collection('organizations').doc(orgId).collection('timeEntries').doc();

  const durationSeconds = secondsBetween(startDate, endDate);
  if (durationSeconds > 60 * 60 * 24 * 7) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Time entry duration too large');
  }

  const doc: TimeEntryDocument = {
    timeEntryId: ref.id,
    orgId,
    caseId: parsedCaseId ?? null,
    clientId: parsedClientId ?? null,
    description: parsedDescription,
    billable: parseBoolean(billable, true),
    status: 'stopped',
    startAt: admin.firestore.Timestamp.fromDate(startDate),
    endAt: admin.firestore.Timestamp.fromDate(endDate),
    durationSeconds,
    rateCents: null,
    currency: null,
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
    updatedBy: uid,
    deletedAt: null,
  };

  await ref.set(doc);

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'time.created',
    entityType: 'timeEntry',
    entityId: ref.id,
    metadata: {
      caseId: doc.caseId,
      clientId: doc.clientId,
      billable: doc.billable,
      durationSeconds,
    },
  });

  return successResponse({
    timeEntry: {
      timeEntryId: doc.timeEntryId,
      orgId: doc.orgId,
      caseId: doc.caseId ?? null,
      clientId: doc.clientId ?? null,
      description: doc.description,
      billable: doc.billable,
      status: doc.status,
      startAt: toIso(doc.startAt),
      endAt: doc.endAt ? toIso(doc.endAt) : null,
      durationSeconds: doc.durationSeconds,
      createdAt: toIso(doc.createdAt),
      updatedAt: toIso(doc.updatedAt),
      createdBy: doc.createdBy,
      updatedBy: doc.updatedBy,
    },
  });
});

/**
 * Start a timer (creates a running time entry).
 * Export name: timeEntryStartTimer
 */
export const timeEntryStartTimer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, clientId, description, billable } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.create',
  });
  if (!entitlement.allowed) {
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'TIME_TRACKING is not available in the current plan.');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const parsedCaseId = parseOptionalString(caseId, 120);
  if (caseId !== undefined && caseId !== null && parsedCaseId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
  }
  if (parsedCaseId) {
    const allowed = await verifyCaseAccess(orgId, parsedCaseId, uid);
    if (!allowed) return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
  }

  const parsedClientId = parseOptionalString(clientId, 120);
  if (clientId !== undefined && clientId !== null && parsedClientId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid clientId');
  }
  if (parsedClientId) {
    const exists = await verifyClientExists(orgId, parsedClientId);
    if (!exists) return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
  }

  const parsedDescription = parseOptionalString(description, 2000) || '';

  /**
   * Enforce one running timer per user.
   *
   * IMPORTANT: A query-only check can race (two concurrent starts can both see "no running entry").
   * We use a per-user lock doc at:
   *   organizations/{orgId}/runningTimers/{uid}
   *
   * This doc is server-only and prevents multiple concurrent timers reliably.
   */
  const now = admin.firestore.Timestamp.now();
  const timerLockRef = runningTimerRef(orgId, uid);
  const timeEntryRef = db.collection('organizations').doc(orgId).collection('timeEntries').doc();

  const doc: TimeEntryDocument = {
    timeEntryId: timeEntryRef.id,
    orgId,
    caseId: parsedCaseId ?? null,
    clientId: parsedClientId ?? null,
    description: parsedDescription,
    billable: parseBoolean(billable, true),
    status: 'running',
    startAt: now,
    endAt: null,
    durationSeconds: 0,
    rateCents: null,
    currency: null,
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
    updatedBy: uid,
    deletedAt: null,
  };

  try {
    await db.runTransaction(async (tx) => {
      const lockSnap = await tx.get(timerLockRef);
      if (lockSnap.exists) {
        throw new Error('TIMER_ALREADY_RUNNING');
      }

      const lockDoc: RunningTimerDocument = {
        orgId,
        uid,
        timeEntryId: timeEntryRef.id,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      };

      tx.set(timeEntryRef, doc);
      tx.set(timerLockRef, lockDoc);
    });
  } catch (e: unknown) {
    const msg = typeof (e as { message?: unknown })?.message === 'string' ? (e as { message: string }).message : '';
    if (msg.includes('TIMER_ALREADY_RUNNING')) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'A timer is already running. Stop it before starting a new one.'
      );
    }
    throw e;
  }

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'time.timer_started',
    entityType: 'timeEntry',
    entityId: timeEntryRef.id,
    metadata: { caseId: doc.caseId, clientId: doc.clientId, billable: doc.billable },
  });

  return successResponse({
    timeEntry: {
      timeEntryId: doc.timeEntryId,
      orgId: doc.orgId,
      caseId: doc.caseId ?? null,
      clientId: doc.clientId ?? null,
      description: doc.description,
      billable: doc.billable,
      status: doc.status,
      startAt: toIso(doc.startAt),
      endAt: null,
      durationSeconds: 0,
      createdAt: toIso(doc.createdAt),
      updatedAt: toIso(doc.updatedAt),
      createdBy: doc.createdBy,
      updatedBy: doc.updatedBy,
    },
  });
});

/**
 * Stop a running timer.
 * Export name: timeEntryStopTimer
 */
export const timeEntryStopTimer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, timeEntryId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.update',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const parsedId = parseOptionalString(timeEntryId, 120);

  const entriesRef = db.collection('organizations').doc(orgId).collection('timeEntries');
  const timerLockRef = runningTimerRef(orgId, uid);

  // Resolve target entry ID: explicit timeEntryId OR current lock doc OR fallback query.
  let targetId = parsedId ?? null;
  if (!targetId) {
    const lockSnap = await timerLockRef.get();
    if (lockSnap.exists) {
      const lock = lockSnap.data() as RunningTimerDocument;
      targetId = lock.timeEntryId;
    } else {
      const running = await findRunningEntry(orgId, uid);
      if (!running) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'No running timer found.');
      }
      targetId = (running.data() as TimeEntryDocument).timeEntryId;
    }
  }

  const stopAt = admin.firestore.Timestamp.now();
  let durationSeconds = 0;
  let stoppedEntry: TimeEntryDocument | null = null;

  try {
    const result = await db.runTransaction(async (tx) => {
      const entryRef = entriesRef.doc(targetId!);
      const snap = await tx.get(entryRef);
      if (!snap.exists) {
        throw new Error('NOT_FOUND');
      }

      const entry = snap.data() as TimeEntryDocument;
      if (entry.deletedAt) {
        throw new Error('NOT_FOUND');
      }

      const isAdmin = entitlement.role === 'ADMIN';
      if (!isAdmin && entry.createdBy !== uid) {
        throw new Error('NOT_AUTHORIZED');
      }

      if (entry.status !== 'running') {
        throw new Error('NOT_RUNNING');
      }

      const computedDurationSeconds = secondsBetween(entry.startAt.toDate(), stopAt.toDate());

      // Firestore rule: all reads must happen before any writes in a transaction.
      const lockSnap = await tx.get(timerLockRef);
      const shouldDeleteLock =
        lockSnap.exists && (lockSnap.data() as RunningTimerDocument).timeEntryId === targetId;

      tx.update(entryRef, {
        status: 'stopped',
        endAt: stopAt,
        durationSeconds: computedDurationSeconds,
        updatedAt: stopAt,
        updatedBy: uid,
      } as Partial<TimeEntryDocument>);

      // Release lock if it still points at this entry (prevents clobbering a newer timer).
      if (shouldDeleteLock) {
        tx.delete(timerLockRef);
      }

      const nextEntry: TimeEntryDocument = {
        ...entry,
        status: 'stopped',
        endAt: stopAt,
        durationSeconds: computedDurationSeconds,
        updatedAt: stopAt,
        updatedBy: uid,
      };
      return { stoppedEntry: nextEntry, durationSeconds: computedDurationSeconds };
    });
    stoppedEntry = result.stoppedEntry;
    durationSeconds = result.durationSeconds;
  } catch (e: unknown) {
    const msg = typeof (e as { message?: unknown })?.message === 'string' ? (e as { message: string }).message : '';
    if (msg.includes('NOT_FOUND')) return errorResponse(ErrorCode.NOT_FOUND, 'Time entry not found');
    if (msg.includes('NOT_AUTHORIZED')) return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
    if (msg.includes('NOT_RUNNING')) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Time entry is not running');
    throw e;
  }

  if (!stoppedEntry) {
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to stop timer');
  }

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'time.timer_stopped',
    entityType: 'timeEntry',
    entityId: stoppedEntry.timeEntryId,
    metadata: { durationSeconds, caseId: stoppedEntry.caseId ?? null },
  });

  return successResponse({
    timeEntry: {
      timeEntryId: stoppedEntry.timeEntryId,
      orgId,
      caseId: stoppedEntry.caseId ?? null,
      clientId: stoppedEntry.clientId ?? null,
      description: stoppedEntry.description,
      billable: stoppedEntry.billable,
      status: 'stopped',
      startAt: toIso(stoppedEntry.startAt),
      endAt: toIso(stopAt),
      durationSeconds,
      createdAt: toIso(stoppedEntry.createdAt),
      updatedAt: toIso(stopAt),
      createdBy: stoppedEntry.createdBy,
      updatedBy: uid,
    },
  });
});

/**
 * List time entries for an organization with filters (MVP).
 * Export name: timeEntryList
 */
export const timeEntryList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    limit = 50,
    offset = 0,
    caseId,
    clientId,
    userId,
    billable,
    from,
    to,
    status,
  } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.read',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }
  const isAdmin = entitlement.role === 'ADMIN';
  const isViewer = entitlement.role === 'VIEWER';

  const pageSize = typeof limit === 'number' ? Math.min(Math.max(1, limit), 100) : 50;
  const pageOffset = typeof offset === 'number' ? Math.max(0, offset) : 0;

  const parsedCaseId = parseOptionalString(caseId, 120);
  if (caseId !== undefined && caseId !== null && parsedCaseId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
  }
  if (parsedCaseId) {
    const allowed = await verifyCaseAccess(orgId, parsedCaseId, uid);
    if (!allowed) return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
  }

  const parsedClientId = parseOptionalString(clientId, 120);
  if (clientId !== undefined && clientId !== null && parsedClientId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid clientId');
  }

  const parsedUserId = parseOptionalString(userId, 120);
  if (userId !== undefined && userId !== null && parsedUserId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid userId');
  }
  // Only admins can list other users' time entries.
  if (parsedUserId && parsedUserId !== uid && !isAdmin) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }
  // Viewers are restricted to their own entries only (defense-in-depth).
  if (!parsedUserId && isViewer) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const fromDate = from ? parseIsoDateTime(from) : null;
  const toDate = to ? parseIsoDateTime(to) : null;
  if ((from && !fromDate) || (to && !toDate)) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'from/to must be valid ISO timestamps');
  }

  let query: admin.firestore.Query = db
    .collection('organizations')
    .doc(orgId)
    .collection('timeEntries')
    .where('deletedAt', '==', null)
    .orderBy('startAt', 'desc');

  if (parsedCaseId) query = query.where('caseId', '==', parsedCaseId);
  if (parsedClientId) query = query.where('clientId', '==', parsedClientId);
  if (parsedUserId) query = query.where('createdBy', '==', parsedUserId);
  if (typeof billable === 'boolean') query = query.where('billable', '==', billable);
  if (status === 'running' || status === 'stopped') query = query.where('status', '==', status);

  if (fromDate) query = query.where('startAt', '>=', admin.firestore.Timestamp.fromDate(fromDate));
  if (toDate) query = query.where('startAt', '<=', admin.firestore.Timestamp.fromDate(toDate));

  let snap: admin.firestore.QuerySnapshot;
  try {
    snap = await query.limit(500).get();
  } catch (queryError: unknown) {
    const qe = queryError as { code?: unknown; message?: unknown };
    const qeMessage = typeof qe?.message === 'string' ? qe.message : '';
    const qeCode = typeof qe?.code === 'number' ? qe.code : null;
    // Handle Firestore index errors gracefully (like other slices)
    if (
      qeCode === 9 ||
      qeMessage.includes('index') ||
      qeMessage.includes('FAILED_PRECONDITION')
    ) {
      functions.logger.error('TimeEntryList: Index required.', {
        orgId,
        caseId: parsedCaseId ?? null,
        clientId: parsedClientId ?? null,
        userId: parsedUserId ?? null,
        billable: typeof billable === 'boolean' ? billable : null,
        from: from ?? null,
        to: to ?? null,
        status: status ?? null,
      });
      return errorResponse(
        ErrorCode.INTERNAL_ERROR,
        'Firestore index required. Please create the required index in Firebase Console.'
      );
    }
    throw queryError;
  }

  let entries = snap.docs.map((d) => d.data() as TimeEntryDocument);
  entries.sort((a, b) => b.startAt.toMillis() - a.startAt.toMillis());

  // Defense-in-depth: if entry is case-linked, ensure user can still access the case.
  // (Case participants may change after time entry creation.)
  const caseIds = Array.from(new Set(entries.map((e) => e.caseId).filter((v): v is string => !!v)));
  if (caseIds.length > 0) {
    const accessPairs = await Promise.all(
      caseIds.map(async (cid) => {
        const allowed = await verifyCaseAccess(orgId, cid, uid);
        return [cid, allowed] as const;
      })
    );
    const accessMap = new Map<string, boolean>(accessPairs);
    entries = entries.filter((e) => !e.caseId || accessMap.get(e.caseId) === true);
  }

  // If listing across users (no user filter), do not expose "unassigned" (no-case) entries
  // unless the caller is admin or the creator. This matches case-scoped visibility expectations.
  if (!isAdmin && !parsedUserId) {
    entries = entries.filter((e) => !!e.caseId || e.createdBy === uid);
  }

  const total = entries.length;
  const paged = entries.slice(pageOffset, pageOffset + pageSize);
  const hasMore = pageOffset + pageSize < total;

  return successResponse({
    timeEntries: paged.map((e) => ({
      timeEntryId: e.timeEntryId,
      orgId: e.orgId,
      caseId: e.caseId ?? null,
      clientId: e.clientId ?? null,
      description: e.description,
      billable: e.billable,
      status: e.status,
      startAt: toIso(e.startAt),
      endAt: e.endAt ? toIso(e.endAt) : null,
      durationSeconds: e.durationSeconds,
      createdAt: toIso(e.createdAt),
      updatedAt: toIso(e.updatedAt),
      createdBy: e.createdBy,
      updatedBy: e.updatedBy,
    })),
    total,
    hasMore,
  });
});

/**
 * Update a time entry (MVP).
 * Export name: timeEntryUpdate
 */
export const timeEntryUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, timeEntryId, description, billable, caseId, clientId, startAt, endAt } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  const parsedId = parseNonEmptyString(timeEntryId, 120);
  if (!parsedId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'timeEntryId is required');

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.update',
  });
  if (!entitlement.allowed) return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');

  const ref = db.collection('organizations').doc(orgId).collection('timeEntries').doc(parsedId);
  const snap = await ref.get();
  if (!snap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Time entry not found');

  const entry = snap.data() as TimeEntryDocument;
  if (entry.deletedAt) return errorResponse(ErrorCode.NOT_FOUND, 'Time entry not found');

  const isAdmin = entitlement.role === 'ADMIN';
  if (!isAdmin && entry.createdBy !== uid) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const updates: Partial<TimeEntryDocument> = {
    updatedAt: admin.firestore.Timestamp.now(),
    updatedBy: uid,
  };

  if (description !== undefined) {
    // Allow clearing description to empty string on update.
    // (Create requires non-empty; update can set empty.)
    if (description === null) {
      updates.description = '';
    } else if (typeof description === 'string') {
      const trimmed = description.trim();
      if (trimmed.length > 2000) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid description');
      }
      updates.description = trimmed; // may be '' => allowed
    } else {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid description');
    }
  }

  if (billable !== undefined) {
    if (typeof billable !== 'boolean') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'billable must be boolean');
    }
    updates.billable = billable;
  }

  if (caseId !== undefined) {
    const c = caseId === null ? null : parseOptionalString(caseId, 120);
    if (caseId !== null && c === null) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
    if (c) {
      const allowed = await verifyCaseAccess(orgId, c, uid);
      if (!allowed) return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
    }
    updates.caseId = c ?? null;
  }

  if (clientId !== undefined) {
    const c = clientId === null ? null : parseOptionalString(clientId, 120);
    if (clientId !== null && c === null) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid clientId');
    if (c) {
      const exists = await verifyClientExists(orgId, c);
      if (!exists) return errorResponse(ErrorCode.NOT_FOUND, 'Client not found');
    }
    updates.clientId = c ?? null;
  }

  // Only allow time edits when stopped (MVP).
  if (entry.status === 'running' && (startAt !== undefined || endAt !== undefined)) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Cannot edit start/end while timer is running');
  }

  if (startAt !== undefined || endAt !== undefined) {
    const startDate = startAt === undefined ? entry.startAt.toDate() : parseIsoDateTime(startAt);
    const endDate = endAt === undefined
      ? (entry.endAt ? entry.endAt.toDate() : null)
      : (endAt === null ? null : parseIsoDateTime(endAt));

    if (!startDate) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid startAt');
    if (!endDate) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid endAt');
    if (endDate.getTime() < startDate.getTime()) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'endAt must be after startAt');
    }

    updates.startAt = admin.firestore.Timestamp.fromDate(startDate);
    updates.endAt = admin.firestore.Timestamp.fromDate(endDate);
    updates.durationSeconds = secondsBetween(startDate, endDate);
    updates.status = 'stopped';
  }

  await ref.update(updates);

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'time.updated',
    entityType: 'timeEntry',
    entityId: parsedId,
    metadata: { updatedFields: Object.keys(updates).filter((k) => k !== 'updatedAt' && k !== 'updatedBy') },
  });

  const updatedSnap = await ref.get();
  const u = updatedSnap.data() as TimeEntryDocument;

  return successResponse({
    timeEntry: {
      timeEntryId: u.timeEntryId,
      orgId: u.orgId,
      caseId: u.caseId ?? null,
      clientId: u.clientId ?? null,
      description: u.description,
      billable: u.billable,
      status: u.status,
      startAt: toIso(u.startAt),
      endAt: u.endAt ? toIso(u.endAt) : null,
      durationSeconds: u.durationSeconds,
      createdAt: toIso(u.createdAt),
      updatedAt: toIso(u.updatedAt),
      createdBy: u.createdBy,
      updatedBy: u.updatedBy,
    },
  });
});

/**
 * Soft delete a time entry (idempotent).
 * Export name: timeEntryDelete
 */
export const timeEntryDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, timeEntryId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const parsedId = parseNonEmptyString(timeEntryId, 120);
  if (!parsedId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'timeEntryId is required');

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'TIME_TRACKING',
    requiredPermission: 'time.delete',
  });
  if (!entitlement.allowed) return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');

  const ref = db.collection('organizations').doc(orgId).collection('timeEntries').doc(parsedId);
  const snap = await ref.get();
  if (!snap.exists) return successResponse({ deleted: true });

  const entry = snap.data() as TimeEntryDocument;
  if (entry.deletedAt) return successResponse({ deleted: true });

  const isAdmin = entitlement.role === 'ADMIN';
  if (!isAdmin && entry.createdBy !== uid) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const now = admin.firestore.Timestamp.now();
  const timerLockRef = runningTimerRef(orgId, entry.createdBy);

  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!current.exists) return;
    const currentEntry = current.data() as TimeEntryDocument;
    if (currentEntry.deletedAt) return;

    // Firestore rule: all reads must happen before any writes in a transaction.
    const lockSnap = await tx.get(timerLockRef);
    const shouldDeleteLock =
      lockSnap.exists && (lockSnap.data() as RunningTimerDocument).timeEntryId === parsedId;

    tx.update(ref, {
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
      status: 'stopped',
    } as Partial<TimeEntryDocument>);

    // If this entry was the running timer, release the lock.
    if (shouldDeleteLock) {
      tx.delete(timerLockRef);
    }
  });

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'time.deleted',
    entityType: 'timeEntry',
    entityId: parsedId,
    metadata: { caseId: entry.caseId ?? null, durationSeconds: entry.durationSeconds },
  });

  return successResponse({ deleted: true });
});

