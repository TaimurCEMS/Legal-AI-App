/**
 * Billing & Invoicing Functions (Slice 11)
 *
 * MVP goals:
 * - Create invoices from unbilled time entries (case-scoped)
 * - Store invoice + line items + payments
 * - Export invoice to PDF and save as a Document Hub document
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { canUserAccessCase } from '../utils/case-access';
import { createAuditEvent } from '../utils/audit';
import { emitDomainEventWithOutbox } from '../utils/domain-events';

const db = admin.firestore();
const storage = admin.storage();

type FirestoreTimestamp = admin.firestore.Timestamp;
type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'void';

interface InvoiceDocument {
  invoiceId: string;
  orgId: string;
  caseId: string;
  clientId?: string | null;
  status: InvoiceStatus;
  invoiceNumber?: string | null;
  currency: string;
  subtotalCents: number;
  paidCents: number;
  totalCents: number;
  issuedAt: FirestoreTimestamp;
  dueAt?: FirestoreTimestamp | null;
  note?: string | null;
  lineItemCount: number;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

interface InvoiceLineItemDocument {
  lineItemId: string;
  orgId: string;
  invoiceId: string;
  description: string;
  timeEntryId?: string | null;
  startAt?: FirestoreTimestamp | null;
  endAt?: FirestoreTimestamp | null;
  durationSeconds?: number | null;
  rateCents: number;
  amountCents: number;
  createdAt: FirestoreTimestamp;
  createdBy: string;
}

interface InvoicePaymentDocument {
  paymentId: string;
  orgId: string;
  invoiceId: string;
  amountCents: number;
  paidAt: FirestoreTimestamp;
  note?: string | null;
  createdAt: FirestoreTimestamp;
  createdBy: string;
}

interface TimeEntryDocument {
  timeEntryId: string;
  orgId: string;
  caseId?: string | null;
  description: string;
  billable: boolean;
  status: 'running' | 'stopped';
  startAt: FirestoreTimestamp;
  endAt?: FirestoreTimestamp | null;
  durationSeconds: number;
  deletedAt?: FirestoreTimestamp | null;
  invoiceId?: string | null;
  invoicedAt?: FirestoreTimestamp | null;
  createdBy: string;
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
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.length > maxLen) return null;
  return trimmed;
}

function parseIsoDateTime(raw: unknown): Date | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const d = new Date(trimmed);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function parseIntInRange(raw: unknown, min: number, max: number): number | null {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null;
  const v = Math.floor(raw);
  if (v < min || v > max) return null;
  return v;
}

function normalizeCurrency(raw: unknown): string | null {
  const s = parseOptionalString(raw, 8);
  const c = (s ?? 'USD').toUpperCase();
  if (!/^[A-Z]{3}$/.test(c)) return null;
  return c;
}

function computeAmountCents(durationSeconds: number, rateCents: number): number {
  const hours = durationSeconds / 3600;
  return Math.max(0, Math.round(hours * rateCents));
}

function sanitizeExportFilename(name: string): string {
  const safe = name
    .replace(/[\\/:*?"<>|]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return safe.length > 0 ? safe.substring(0, 120) : 'Invoice';
}

function sanitizeCaseFolderSegment(caseTitle: string): string {
  // Folder segments should be stable-ish and safe for URLs.
  // We still suffix with caseId to avoid collisions and handle renames safely.
  const safe = sanitizeExportFilename(caseTitle).replace(/\s+/g, '_');
  return safe.length > 0 ? safe.substring(0, 80) : 'Case';
}

function formatMoney(cents: number, currency: string): string {
  const sign = cents < 0 ? '-' : '';
  const abs = Math.abs(cents);
  const major = Math.floor(abs / 100);
  const minor = abs % 100;
  return `${sign}${currency} ${major.toString()}.${minor.toString().padStart(2, '0')}`;
}

async function verifyCaseAccessOrNotFound(orgId: string, caseId: string, uid: string) {
  const access = await canUserAccessCase(orgId, caseId, uid);
  if (!access.allowed) {
    return { ok: false as const, response: errorResponse(ErrorCode.NOT_FOUND, 'Case not found') };
  }
  return { ok: true as const };
}

function invoicesRef(orgId: string) {
  return db.collection('organizations').doc(orgId).collection('invoices');
}

function timeEntriesRef(orgId: string) {
  return db.collection('organizations').doc(orgId).collection('timeEntries');
}

/**
 * Create invoice from time entries (case-scoped).
 * Export name: invoiceCreate
 */
export const invoiceCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, from, to, timeEntryIds, rateCents, currency, dueAt, note } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  if (!caseId || typeof caseId !== 'string' || caseId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'BILLING_INVOICING',
    requiredPermission: 'billing.manage',
  });
  if (!entitlement.allowed) {
    if (entitlement.reason === 'PLAN_LIMIT') {
      return errorResponse(ErrorCode.PLAN_LIMIT, 'Billing/Invoicing is not available in the current plan.');
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const access = await verifyCaseAccessOrNotFound(orgId, caseId.trim(), uid);
  if (!access.ok) return access.response;

  const parsedRateCents = parseIntInRange(rateCents, 1, 10_000_000);
  if (parsedRateCents === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'rateCents is required (positive integer)');
  }

  const parsedCurrency = normalizeCurrency(currency);
  if (!parsedCurrency) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'currency must be a 3-letter code (e.g. USD)');
  }

  const fromDate = from ? parseIsoDateTime(from) : null;
  const toDate = to ? parseIsoDateTime(to) : null;
  if ((from && !fromDate) || (to && !toDate)) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'from/to must be valid ISO timestamps');
  }
  if (fromDate && toDate && toDate.getTime() < fromDate.getTime()) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'to must be after from');
  }

  const parsedDueAt = dueAt ? parseIsoDateTime(dueAt) : null;
  if (dueAt && !parsedDueAt) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'dueAt must be a valid ISO timestamp');
  }

  let parsedNote: string | null = null;
  if (note !== undefined) {
    if (note === null) {
      parsedNote = '';
    } else if (typeof note === 'string') {
      const t = note.trim();
      if (t.length > 4000) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid note');
      }
      parsedNote = t; // may be ''
    } else {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid note');
    }
  }

  // Resolve candidate entries
  let entries: TimeEntryDocument[] = [];

  // If explicit list is provided, load those entries; otherwise, load by case + date range.
  if (Array.isArray(timeEntryIds) && timeEntryIds.length > 0) {
    const ids = Array.from(
      new Set(
        timeEntryIds
          .map((x: unknown) => (typeof x === 'string' ? x.trim() : ''))
          .filter((x: string) => x.length > 0 && x.length <= 120)
      )
    );
    if (ids.length === 0) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid timeEntryIds');
    }
    if (ids.length > 200) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Too many time entries selected (max 200)');
    }

    const refs = ids.map((id) => timeEntriesRef(orgId).doc(id));
    // Firestore getAll accepts a spread list of refs
    const snaps = await (db as any).getAll(...refs);

    entries = snaps
      .filter((s: admin.firestore.DocumentSnapshot) => s.exists)
      .map((s: admin.firestore.DocumentSnapshot) => s.data() as TimeEntryDocument);
  } else {
    // Use an index-friendly query (we already have timeEntries: caseId+deletedAt+startAt).
    let query: admin.firestore.Query = timeEntriesRef(orgId)
      .where('deletedAt', '==', null)
      .where('caseId', '==', caseId.trim())
      .orderBy('startAt', 'desc')
      .limit(500);

    // Apply date range on startAt if supplied (may require additional index depending on Firebase).
    if (fromDate) query = query.where('startAt', '>=', admin.firestore.Timestamp.fromDate(fromDate));
    if (toDate) query = query.where('startAt', '<=', admin.firestore.Timestamp.fromDate(toDate));

    let snap: admin.firestore.QuerySnapshot;
    try {
      snap = await query.get();
    } catch (queryError: unknown) {
      const qe = queryError as { code?: unknown; message?: unknown };
      const qeMessage = typeof qe?.message === 'string' ? qe.message : '';
      const qeCode = typeof qe?.code === 'number' ? qe.code : null;
      if (qeCode === 9 || qeMessage.includes('index') || qeMessage.includes('FAILED_PRECONDITION')) {
        functions.logger.error('invoiceCreate: index required', { orgId, caseId, from, to });
        return errorResponse(
          ErrorCode.INTERNAL_ERROR,
          'Firestore index required. Please create the required index in Firebase Console.'
        );
      }
      throw queryError;
    }

    entries = snap.docs.map((d) => d.data() as TimeEntryDocument);
  }

  // Filter to only billable + stopped + unbilled entries for this case (defense-in-depth).
  entries = entries.filter((e) => {
    if (e.deletedAt) return false;
    if ((e.caseId ?? null) !== caseId.trim()) return false;
    if (e.billable !== true) return false;
    if (e.status !== 'stopped') return false;
    if (!e.endAt) return false;
    if (!Number.isFinite(e.durationSeconds) || e.durationSeconds <= 0) return false;
    const alreadyBilled = (e.invoiceId ?? null) !== null || (e.invoicedAt ?? null) !== null;
    if (alreadyBilled) return false;
    // If range provided and we didn't query with it (explicit IDs path), enforce it here.
    if (fromDate && e.startAt.toDate().getTime() < fromDate.getTime()) return false;
    if (toDate && e.startAt.toDate().getTime() > toDate.getTime()) return false;
    return true;
  });

  if (entries.length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'No unbilled billable time entries found for the selected range.');
  }
  if (entries.length > 200) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Too many unbilled entries in range (max 200). Narrow the range.');
  }

  // Create invoice + line items + update time entries in a single batch.
  const now = admin.firestore.Timestamp.now();
  const invoiceRef = invoicesRef(orgId).doc();
  const invoiceId = invoiceRef.id;
  const lineItemsCol = invoiceRef.collection('lineItems');

  // Resolve basic case metadata (best-effort)
  const caseTitle = await db
    .collection('organizations')
    .doc(orgId)
    .collection('cases')
    .doc(caseId.trim())
    .get()
    .then((s) => (s.exists ? ((s.data() as any)?.title as string | undefined) : undefined))
    .then((t) => (typeof t === 'string' && t.trim().length > 0 ? t.trim() : 'Case'))
    .catch(() => 'Case');

  const dateStamp = `${now.toDate().getFullYear()}-${String(now.toDate().getMonth() + 1).padStart(2, '0')}-${String(
    now.toDate().getDate()
  ).padStart(2, '0')}`;
  const invoiceNumber = `INV-${dateStamp}-${invoiceId.substring(0, 6).toUpperCase()}`;

  const lineItems: InvoiceLineItemDocument[] = entries.map((e) => {
    const amountCents = computeAmountCents(e.durationSeconds, parsedRateCents);
    const desc = (e.description ?? '').trim();
    const description = desc.length > 0 ? desc : 'Time entry';
    return {
      lineItemId: lineItemsCol.doc().id,
      orgId,
      invoiceId,
      description,
      timeEntryId: e.timeEntryId,
      startAt: e.startAt,
      endAt: e.endAt ?? null,
      durationSeconds: e.durationSeconds,
      rateCents: parsedRateCents,
      amountCents,
      createdAt: now,
      createdBy: uid,
    };
  });

  const subtotalCents = lineItems.reduce((sum, li) => sum + li.amountCents, 0);

  const invoiceDoc: InvoiceDocument = {
    invoiceId,
    orgId,
    caseId: caseId.trim(),
    clientId: null,
    status: 'draft',
    invoiceNumber,
    currency: parsedCurrency,
    subtotalCents,
    paidCents: 0,
    totalCents: subtotalCents,
    issuedAt: now,
    dueAt: parsedDueAt ? admin.firestore.Timestamp.fromDate(parsedDueAt) : null,
    note: parsedNote ?? null,
    lineItemCount: lineItems.length,
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
    updatedBy: uid,
    deletedAt: null,
  };

  const batch = db.batch();
  batch.set(invoiceRef, invoiceDoc);

  for (const li of lineItems) {
    batch.set(lineItemsCol.doc(li.lineItemId), li);
  }

  for (const e of entries) {
    batch.update(timeEntriesRef(orgId).doc(e.timeEntryId), {
      invoiceId,
      invoicedAt: now,
      updatedAt: now,
      updatedBy: uid,
    });
  }

  await batch.commit();

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'invoice.created',
    entityType: 'invoice',
    entityId: invoiceId,
    metadata: {
      caseId: caseId.trim(),
      caseTitle,
      invoiceNumber,
      lineItemCount: lineItems.length,
      subtotalCents,
      currency: parsedCurrency,
    },
  });

  await emitDomainEventWithOutbox({
    orgId,
    eventType: 'invoice.created',
    entityType: 'invoice',
    entityId: invoiceId,
    actor: { actorType: 'user', actorId: uid },
    payload: { caseId: caseId.trim(), invoiceNumber, subtotalCents, currency: parsedCurrency },
    matterId: caseId.trim(),
  });

  return successResponse({
    invoice: {
      invoiceId,
      orgId,
      caseId: caseId.trim(),
      status: invoiceDoc.status,
      invoiceNumber,
      currency: parsedCurrency,
      subtotalCents,
      paidCents: 0,
      totalCents: subtotalCents,
      issuedAt: toIso(now),
      dueAt: invoiceDoc.dueAt ? toIso(invoiceDoc.dueAt) : null,
      note: invoiceDoc.note ?? null,
      lineItemCount: lineItems.length,
    },
  });
});

/**
 * List invoices (filtered server-side by case access).
 * Export name: invoiceList
 */
export const invoiceList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, status, limit = 50, offset = 0 } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'BILLING_INVOICING',
    requiredPermission: 'billing.manage',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const parsedCaseId = parseOptionalString(caseId, 120);
  if (caseId !== undefined && caseId !== null && parsedCaseId === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid caseId');
  }
  if (parsedCaseId) {
    const access = await verifyCaseAccessOrNotFound(orgId, parsedCaseId, uid);
    if (!access.ok) return access.response;
  }

  const parsedStatus: InvoiceStatus | null =
    status === 'draft' || status === 'sent' || status === 'paid' || status === 'void' ? status : null;
  if (status !== undefined && status !== null && parsedStatus === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid status');
  }

  const pageSize = typeof limit === 'number' ? Math.min(Math.max(1, limit), 100) : 50;
  const pageOffset = typeof offset === 'number' ? Math.max(0, offset) : 0;

  let snap: admin.firestore.QuerySnapshot;
  try {
    snap = await invoicesRef(orgId).orderBy('issuedAt', 'desc').limit(500).get();
  } catch (queryError: unknown) {
    const qe = queryError as { code?: unknown; message?: unknown };
    const qeMessage = typeof qe?.message === 'string' ? qe.message : '';
    const qeCode = typeof qe?.code === 'number' ? qe.code : null;
    if (qeCode === 9 || qeMessage.includes('index') || qeMessage.includes('FAILED_PRECONDITION')) {
      functions.logger.error('invoiceList: index required', { orgId });
      return errorResponse(
        ErrorCode.INTERNAL_ERROR,
        'Firestore index required. Please create the required index in Firebase Console.'
      );
    }
    throw queryError;
  }

  let invoices = snap.docs.map((d) => d.data() as InvoiceDocument);
  invoices = invoices.filter((inv) => !inv.deletedAt);
  if (parsedCaseId) invoices = invoices.filter((inv) => inv.caseId === parsedCaseId);
  if (parsedStatus) invoices = invoices.filter((inv) => inv.status === parsedStatus);

  // Case access filtering (defense-in-depth)
  const caseAccessCache = new Map<string, boolean>();
  const filtered: InvoiceDocument[] = [];
  for (const inv of invoices) {
    const cid = inv.caseId;
    const cached = caseAccessCache.get(cid);
    let allowed = cached;
    if (allowed === undefined) {
      allowed = (await canUserAccessCase(orgId, cid, uid)).allowed;
      caseAccessCache.set(cid, allowed);
    }
    if (allowed) filtered.push(inv);
  }

  const total = filtered.length;
  const paged = filtered.slice(pageOffset, pageOffset + pageSize);
  const hasMore = pageOffset + pageSize < total;

  return successResponse({
    invoices: paged.map((inv) => ({
      invoiceId: inv.invoiceId,
      orgId: inv.orgId,
      caseId: inv.caseId,
      status: inv.status,
      invoiceNumber: inv.invoiceNumber ?? null,
      currency: inv.currency,
      subtotalCents: inv.subtotalCents,
      paidCents: inv.paidCents,
      totalCents: inv.totalCents,
      issuedAt: toIso(inv.issuedAt),
      dueAt: inv.dueAt ? toIso(inv.dueAt) : null,
      lineItemCount: inv.lineItemCount,
    })),
    total,
    hasMore,
  });
});

/**
 * Get invoice + line items + payments.
 * Export name: invoiceGet
 */
export const invoiceGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, invoiceId } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  const parsedInvoiceId = parseNonEmptyString(invoiceId, 120);
  if (!parsedInvoiceId) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'invoiceId is required');
  }

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'BILLING_INVOICING',
    requiredPermission: 'billing.manage',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const invRef = invoicesRef(orgId).doc(parsedInvoiceId);
  const invSnap = await invRef.get();
  if (!invSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
  const inv = invSnap.data() as InvoiceDocument;
  if (inv.deletedAt) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');

  const access = await verifyCaseAccessOrNotFound(orgId, inv.caseId, uid);
  if (!access.ok) return access.response;

  const [itemsSnap, paymentsSnap] = await Promise.all([
    invRef.collection('lineItems').orderBy('createdAt', 'asc').limit(500).get(),
    invRef.collection('payments').orderBy('paidAt', 'asc').limit(500).get(),
  ]);
  const items = itemsSnap.docs.map((d) => d.data() as InvoiceLineItemDocument);
  const payments = paymentsSnap.docs.map((d) => d.data() as InvoicePaymentDocument);

  return successResponse({
    invoice: {
      invoiceId: inv.invoiceId,
      orgId: inv.orgId,
      caseId: inv.caseId,
      status: inv.status,
      invoiceNumber: inv.invoiceNumber ?? null,
      currency: inv.currency,
      subtotalCents: inv.subtotalCents,
      paidCents: inv.paidCents,
      totalCents: inv.totalCents,
      issuedAt: toIso(inv.issuedAt),
      dueAt: inv.dueAt ? toIso(inv.dueAt) : null,
      note: inv.note ?? null,
      lineItemCount: inv.lineItemCount,
      createdAt: toIso(inv.createdAt),
      updatedAt: toIso(inv.updatedAt),
      createdBy: inv.createdBy,
      updatedBy: inv.updatedBy,
      lineItems: items.map((li) => ({
        lineItemId: li.lineItemId,
        description: li.description,
        timeEntryId: li.timeEntryId ?? null,
        startAt: li.startAt ? toIso(li.startAt) : null,
        endAt: li.endAt ? toIso(li.endAt) : null,
        durationSeconds: li.durationSeconds ?? null,
        rateCents: li.rateCents,
        amountCents: li.amountCents,
      })),
      payments: payments.map((p) => ({
        paymentId: p.paymentId,
        amountCents: p.amountCents,
        paidAt: toIso(p.paidAt),
        note: p.note ?? null,
        createdAt: toIso(p.createdAt),
        createdBy: p.createdBy,
      })),
    },
  });
});

/**
 * Update invoice metadata/status (MVP).
 * Export name: invoiceUpdate
 */
export const invoiceUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, invoiceId, status, dueAt, note } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  const parsedInvoiceId = parseNonEmptyString(invoiceId, 120);
  if (!parsedInvoiceId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'invoiceId is required');

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'BILLING_INVOICING',
    requiredPermission: 'billing.manage',
  });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  const invRef = invoicesRef(orgId).doc(parsedInvoiceId);
  const invSnap = await invRef.get();
  if (!invSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
  const inv = invSnap.data() as InvoiceDocument;
  if (inv.deletedAt) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');

  const access = await verifyCaseAccessOrNotFound(orgId, inv.caseId, uid);
  if (!access.ok) return access.response;

  const updates: Partial<InvoiceDocument> = {
    updatedAt: admin.firestore.Timestamp.now(),
    updatedBy: uid,
  };

  if (status !== undefined) {
    const parsedStatus: InvoiceStatus | null =
      status === 'draft' || status === 'sent' || status === 'void' ? status : null;
    if (status !== null && parsedStatus === null) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid status. Use draft/sent/void.');
    }
    if (inv.status === 'paid' && parsedStatus && parsedStatus !== 'paid') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Paid invoices cannot be changed to another status.');
    }
    if (parsedStatus) updates.status = parsedStatus;
  }

  if (dueAt !== undefined) {
    if (dueAt === null) {
      updates.dueAt = null;
    } else {
      const d = parseIsoDateTime(dueAt);
      if (!d) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid dueAt');
      updates.dueAt = admin.firestore.Timestamp.fromDate(d);
    }
  }

  if (note !== undefined) {
    if (note === null) updates.note = '';
    else {
      const n = parseOptionalString(note, 4000);
      if (note !== '' && n === null) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid note');
      updates.note = (note as string).trim();
    }
  }

  await invRef.update(updates);

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'invoice.updated',
    entityType: 'invoice',
    entityId: parsedInvoiceId,
    metadata: { updatedFields: Object.keys(updates).filter((k) => k !== 'updatedAt' && k !== 'updatedBy') },
  });

  if (updates.status === 'sent' && inv.status !== 'sent') {
    await emitDomainEventWithOutbox({
      orgId,
      eventType: 'invoice.sent',
      entityType: 'invoice',
      entityId: parsedInvoiceId,
      actor: { actorType: 'user', actorId: uid },
      payload: { invoiceNumber: inv.invoiceNumber ?? null, caseId: inv.caseId },
      matterId: inv.caseId ?? undefined,
    });
  }

  const updated = (await invRef.get()).data() as InvoiceDocument;

  return successResponse({
    invoice: {
      invoiceId: updated.invoiceId,
      orgId: updated.orgId,
      caseId: updated.caseId,
      status: updated.status,
      invoiceNumber: updated.invoiceNumber ?? null,
      currency: updated.currency,
      subtotalCents: updated.subtotalCents,
      paidCents: updated.paidCents,
      totalCents: updated.totalCents,
      issuedAt: toIso(updated.issuedAt),
      dueAt: updated.dueAt ? toIso(updated.dueAt) : null,
      note: updated.note ?? null,
      lineItemCount: updated.lineItemCount,
      updatedAt: toIso(updated.updatedAt),
      updatedBy: updated.updatedBy,
    },
  });
});

/**
 * Record a payment against an invoice (MVP).
 * Export name: invoiceRecordPayment
 */
export const invoiceRecordPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, invoiceId, amountCents, paidAt, note } = data || {};

  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }
  const parsedInvoiceId = parseNonEmptyString(invoiceId, 120);
  if (!parsedInvoiceId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'invoiceId is required');

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredFeature: 'BILLING_INVOICING',
    requiredPermission: 'billing.manage',
  });
  if (!entitlement.allowed) return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');

  const amt = parseIntInRange(amountCents, 1, 1_000_000_000);
  if (amt === null) return errorResponse(ErrorCode.VALIDATION_ERROR, 'amountCents must be a positive integer');

  const paidDate = paidAt ? parseIsoDateTime(paidAt) : null;
  if (paidAt && !paidDate) return errorResponse(ErrorCode.VALIDATION_ERROR, 'paidAt must be a valid ISO timestamp');

  let parsedNote: string | null = null;
  if (note !== undefined) {
    if (note === null) {
      parsedNote = '';
    } else if (typeof note === 'string') {
      const t = note.trim();
      if (t.length > 4000) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid note');
      }
      parsedNote = t; // may be ''
    } else {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid note');
    }
  }

  const invRef = invoicesRef(orgId).doc(parsedInvoiceId);
  // Pre-check (outside transaction) for UX-friendly errors and case access.
  const preSnap = await invRef.get();
  if (!preSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
  const preInv = preSnap.data() as InvoiceDocument;
  if (preInv.deletedAt) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
  if (preInv.status === 'void') return errorResponse(ErrorCode.VALIDATION_ERROR, 'Cannot record payment for a void invoice');

  const access = await verifyCaseAccessOrNotFound(orgId, preInv.caseId, uid);
  if (!access.ok) return access.response;

  const now = admin.firestore.Timestamp.now();
  const paymentId = invRef.collection('payments').doc().id;

  let result: { invoiceId: string; status: InvoiceStatus; paidCents: number; totalCents: number };
  try {
    result = await db.runTransaction(async (tx) => {
      const invSnap = await tx.get(invRef);
      if (!invSnap.exists) throw new Error('NOT_FOUND');
      const inv = invSnap.data() as InvoiceDocument;
      if (inv.deletedAt) throw new Error('NOT_FOUND');
      if (inv.status === 'void') throw new Error('VOID');

      const paymentRef = invRef.collection('payments').doc(paymentId);
      const paymentDoc: InvoicePaymentDocument = {
        paymentId,
        orgId,
        invoiceId: parsedInvoiceId,
        amountCents: amt,
        paidAt: paidDate ? admin.firestore.Timestamp.fromDate(paidDate) : now,
        note: parsedNote ?? null,
        createdAt: now,
        createdBy: uid,
      };

      const nextPaid = Math.min(inv.totalCents, Math.max(0, (inv.paidCents ?? 0) + amt));
      const nextStatus: InvoiceStatus =
        nextPaid >= inv.totalCents ? 'paid' : inv.status === 'draft' ? 'sent' : inv.status;

      tx.set(paymentRef, paymentDoc);
      tx.update(invRef, {
        paidCents: nextPaid,
        status: nextStatus,
        updatedAt: now,
        updatedBy: uid,
      } as Partial<InvoiceDocument>);

      return { invoiceId: inv.invoiceId, status: nextStatus, paidCents: nextPaid, totalCents: inv.totalCents };
    });
  } catch (e: unknown) {
    const msg = typeof (e as { message?: unknown })?.message === 'string' ? (e as { message: string }).message : '';
    if (msg.includes('NOT_FOUND')) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
    if (msg.includes('VOID')) return errorResponse(ErrorCode.VALIDATION_ERROR, 'Cannot record payment for a void invoice');
    throw e;
  }

  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'invoice.payment_recorded',
    entityType: 'invoice',
    entityId: parsedInvoiceId,
    metadata: { amountCents: amt, paymentId },
  });

  await emitDomainEventWithOutbox({
    orgId,
    eventType: 'payment.received',
    entityType: 'invoice',
    entityId: parsedInvoiceId,
    actor: { actorType: 'user', actorId: uid },
    payload: { amountCents: amt, paymentId },
    matterId: preInv.caseId ?? undefined,
  });

  return successResponse({
    payment: { paymentId, amountCents: amt },
    invoice: {
      invoiceId: result.invoiceId,
      status: result.status,
      paidCents: result.paidCents,
      totalCents: result.totalCents,
    },
  });
});

/**
 * Export an invoice to PDF and save as Document Hub document.
 * Export name: invoiceExport
 */
export const invoiceExport = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const uid = context.auth.uid;
    const { orgId, invoiceId } = data || {};

    if (!orgId || typeof orgId !== 'string') {
      return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
    }
    const parsedInvoiceId = parseNonEmptyString(invoiceId, 120);
    if (!parsedInvoiceId) return errorResponse(ErrorCode.VALIDATION_ERROR, 'invoiceId is required');

    const billingEntitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'BILLING_INVOICING',
      requiredPermission: 'billing.manage',
    });
    if (!billingEntitlement.allowed) return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');

    const exportEntitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'EXPORTS',
      requiredPermission: 'document.create',
    });
    if (!exportEntitlement.allowed) {
      if (exportEntitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'Export requires a BASIC plan or higher. Please upgrade to continue.');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to export');
    }

    const invRef = invoicesRef(orgId).doc(parsedInvoiceId);
    const invSnap = await invRef.get();
    if (!invSnap.exists) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');
    const inv = invSnap.data() as InvoiceDocument;
    if (inv.deletedAt) return errorResponse(ErrorCode.NOT_FOUND, 'Invoice not found');

    const access = await verifyCaseAccessOrNotFound(orgId, inv.caseId, uid);
    if (!access.ok) return access.response;

    const itemsSnap = await invRef.collection('lineItems').orderBy('createdAt', 'asc').limit(500).get();
    const items = itemsSnap.docs.map((d) => d.data() as InvoiceLineItemDocument);

    // Best-effort metadata
    const caseTitle = await db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(inv.caseId)
      .get()
      .then((s) => (s.exists ? ((s.data() as any)?.title as string | undefined) : undefined))
      .then((t) => (typeof t === 'string' && t.trim().length > 0 ? t.trim() : 'Case'))
      .catch(() => 'Case');

    const orgName = await db
      .collection('organizations')
      .doc(orgId)
      .get()
      .then((s) => (s.exists ? ((s.data() as any)?.name as string | undefined) : undefined))
      .then((n) => (typeof n === 'string' && n.trim().length > 0 ? n.trim() : 'Organization'))
      .catch(() => 'Organization');

    try {
      const pdfDoc = await PDFDocument.create();
      const font = await pdfDoc.embedFont(StandardFonts.TimesRoman);
      const fontBold = await pdfDoc.embedFont(StandardFonts.TimesRomanBold);

      const pageWidth = 612; // Letter
      const pageHeight = 792;
      const margin = 72;
      const lineHeight = 16;
      const maxWidth = pageWidth - margin * 2;

      function newPage() {
        return pdfDoc.addPage([pageWidth, pageHeight]);
      }

      function drawText(p: any, text: string, x: number, y: number, size: number, bold = false) {
        p.drawText(text, { x, y, size, font: bold ? fontBold : font, color: rgb(0, 0, 0) });
      }

      const invoiceTitle = inv.invoiceNumber ? `Invoice ${inv.invoiceNumber}` : `Invoice ${inv.invoiceId}`;
      const safeBase = sanitizeExportFilename(inv.invoiceNumber ?? `Invoice ${inv.invoiceId.substring(0, 6)}`);
      const now = new Date();
      const dateStamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
      const filename = `${safeBase} - ${dateStamp}.pdf`;

      let p = newPage();
      let y = pageHeight - margin;

      drawText(p, orgName, margin, y, 18, true);
      y -= lineHeight + 6;
      drawText(p, invoiceTitle, margin, y, 14, true);
      y -= lineHeight;
      drawText(p, `Case: ${caseTitle}`, margin, y, 11);
      y -= lineHeight;
      drawText(p, `Issued: ${inv.issuedAt.toDate().toISOString().substring(0, 10)}`, margin, y, 11);
      y -= lineHeight;
      if (inv.dueAt) {
        drawText(p, `Due: ${inv.dueAt.toDate().toISOString().substring(0, 10)}`, margin, y, 11);
        y -= lineHeight;
      }
      y -= 8;

      // Table header
      drawText(p, 'Description', margin, y, 11, true);
      drawText(p, 'Amount', margin + maxWidth - 80, y, 11, true);
      y -= lineHeight;
      p.drawLine({
        start: { x: margin, y },
        end: { x: margin + maxWidth, y },
        thickness: 1,
        color: rgb(0.8, 0.8, 0.8),
      });
      y -= 10;

      function ensureSpace(required: number) {
        if (y - required < margin + 60) {
          p = newPage();
          y = pageHeight - margin;
        }
      }

      function wrapWords(text: string, activeFont: any, size: number, width: number): string[] {
        const words = text.split(/\s+/).filter(Boolean);
        const lines: string[] = [];
        let current = '';
        for (const w of words) {
          const candidate = current ? `${current} ${w}` : w;
          const wWidth = activeFont.widthOfTextAtSize(candidate, size);
          if (wWidth > width) {
            if (current) lines.push(current);
            current = w;
          } else {
            current = candidate;
          }
        }
        if (current) lines.push(current);
        return lines.length > 0 ? lines : [''];
      }

      for (const li of items) {
        const amount = formatMoney(li.amountCents, inv.currency);
        const descLines = wrapWords(li.description ?? 'Line item', font, 11, maxWidth - 90);
        const rowHeight = Math.max(1, descLines.length) * lineHeight;
        ensureSpace(rowHeight + 6);

        for (let i = 0; i < descLines.length; i++) {
          drawText(p, descLines[i], margin, y - i * lineHeight, 11);
        }
        // Amount on first line
        const amtWidth = font.widthOfTextAtSize(amount, 11);
        drawText(p, amount, margin + maxWidth - amtWidth, y, 11);
        y -= rowHeight + 6;
      }

      ensureSpace(80);
      y -= 6;
      p.drawLine({
        start: { x: margin, y },
        end: { x: margin + maxWidth, y },
        thickness: 1,
        color: rgb(0.8, 0.8, 0.8),
      });
      y -= 18;

      const subtotal = formatMoney(inv.subtotalCents, inv.currency);
      const paid = formatMoney(inv.paidCents, inv.currency);
      const balance = formatMoney(Math.max(0, inv.totalCents - inv.paidCents), inv.currency);

      const rightX = margin + maxWidth;
      const labelX = rightX - 180;

      drawText(p, 'Subtotal', labelX, y, 11, true);
      drawText(p, subtotal, rightX - font.widthOfTextAtSize(subtotal, 11), y, 11);
      y -= lineHeight;
      drawText(p, 'Paid', labelX, y, 11, true);
      drawText(p, paid, rightX - font.widthOfTextAtSize(paid, 11), y, 11);
      y -= lineHeight;
      drawText(p, 'Balance', labelX, y, 11, true);
      drawText(p, balance, rightX - font.widthOfTextAtSize(balance, 11), y, 11);
      y -= lineHeight;

      if (inv.note && inv.note.trim().length > 0) {
        ensureSpace(80);
        y -= 10;
        drawText(p, 'Note', margin, y, 11, true);
        y -= lineHeight;
        const lines = wrapWords(inv.note.trim(), font, 11, maxWidth);
        for (const line of lines) {
          ensureSpace(lineHeight);
          drawText(p, line, margin, y, 11);
          y -= lineHeight;
        }
      }

      const bytes = await pdfDoc.save();
      const fileBytes = Buffer.from(bytes);

      // Save to Document Hub (same pattern as draftExport)
      const documentRef = db.collection('organizations').doc(orgId).collection('documents').doc();
      const documentId = documentRef.id;
      const caseFolder = `${sanitizeCaseFolderSegment(caseTitle)}__${inv.caseId}`;
      const storagePath = `organizations/${orgId}/documents/invoices/${caseFolder}/${documentId}/${filename}`;

      const bucket = storage.bucket();
      const file = bucket.file(storagePath);
      await file.save(fileBytes, {
        contentType: 'application/pdf',
        metadata: {
          metadata: {
            source: 'invoice_export',
            invoiceId: parsedInvoiceId,
            caseId: inv.caseId,
          },
        },
      });

      const nowTs = admin.firestore.Timestamp.now();
      await documentRef.set({
        id: documentId,
        orgId,
        caseId: inv.caseId,
        category: 'invoice',
        folderPath: `Invoices/${sanitizeExportFilename(caseTitle)}`,
        name: filename,
        description: `Exported invoice: ${inv.invoiceNumber ?? inv.invoiceId}`,
        fileType: 'pdf',
        fileSize: fileBytes.length,
        storagePath,
        createdAt: nowTs,
        updatedAt: nowTs,
        createdBy: uid,
        updatedBy: uid,
        deletedAt: null,
        sourceInvoiceId: parsedInvoiceId,
        exportedAt: nowTs,
      });

      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'invoice.exported',
        entityType: 'document',
        entityId: documentId,
        metadata: { invoiceId: parsedInvoiceId, caseId: inv.caseId, format: 'pdf' },
      });

      return successResponse({
        documentId,
        storagePath,
        fileType: 'pdf',
        fileSize: fileBytes.length,
        name: filename,
      });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown export error';
      functions.logger.error('invoiceExport failed', {
        orgId,
        invoiceId: parsedInvoiceId,
        errorMessage,
      });
      return errorResponse(ErrorCode.INTERNAL_ERROR, `Invoice export failed: ${errorMessage}`);
    }
  });

