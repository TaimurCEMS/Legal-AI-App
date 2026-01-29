/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Slice 12: Audit Trail UI (Backend)
 * Callable Functions:
 * - auditList
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { errorResponse, successResponse } from '../utils/response';
import { canUserAccessCase } from '../utils/case-access';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

function parseIsoDateTime(raw: unknown): Date | null {
  if (!raw || typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const d = new Date(trimmed);
  return isNaN(d.getTime()) ? null : d;
}

function getEventCaseId(event: any): string | null {
  // Case entity events: entityId is the caseId
  if (event?.entityType === 'case' && typeof event?.entityId === 'string') {
    const fromEntity = event.entityId.trim();
    if (fromEntity) return fromEntity;
  }

  const direct = typeof event?.caseId === 'string' ? event.caseId.trim() : '';
  if (direct) return direct;
  const fromMetadata =
    typeof event?.metadata?.caseId === 'string' ? event.metadata.caseId.trim() : '';
  return fromMetadata || null;
}

/**
 * List audit events for an organization (MVP).
 * Notes:
 * - Uses in-memory filtering to avoid immediate index requirements.
 * - Filters out events tied to PRIVATE cases the user cannot access (no existence leakage).
 *
 * Function Name (Export): auditList
 */
export const auditList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    limit = 50,
    offset = 0,
    actorUid,
    action,
    entityType,
    entityId,
    caseId,
    fromAt,
    toAt,
    search,
    includeMetadata = true,
    includeActorDetails = true,
  } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const parsedLimit = typeof limit === 'number' ? Math.min(Math.max(1, limit), 100) : 50;
  const parsedOffset = typeof offset === 'number' ? Math.max(0, offset) : 0;

  // Permission gating (view audit trail)
  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'audit.view',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, "You don't have permission to view audit logs");
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view audit logs');
  }

  const parsedFrom = parseIsoDateTime(fromAt);
  const parsedTo = parseIsoDateTime(toAt);
  const actorFilter = typeof actorUid === 'string' && actorUid.trim().length > 0 ? actorUid.trim() : null;
  const actionFilter = typeof action === 'string' && action.trim().length > 0 ? action.trim() : null;
  const entityTypeFilter = typeof entityType === 'string' && entityType.trim().length > 0 ? entityType.trim() : null;
  const entityIdFilter = typeof entityId === 'string' && entityId.trim().length > 0 ? entityId.trim() : null;
  const caseIdFilter = typeof caseId === 'string' && caseId.trim().length > 0 ? caseId.trim() : null;
  const searchFilter = typeof search === 'string' && search.trim().length > 0 ? search.trim().toLowerCase() : null;

  try {
    // Fetch recent audit events (cap for MVP)
    const snapshot = await db
      .collection('organizations')
      .doc(orgId.trim())
      .collection('audit_events')
      .orderBy('timestamp', 'desc')
      .limit(1000)
      .get();

    const rawEvents = snapshot.docs.map((doc) => doc.data() as any);

    // In-memory filtering
    const filtered = rawEvents.filter((e) => {
      // Defensive: must have required core fields
      if (!e || typeof e !== 'object') return false;
      if (!e.timestamp) return false;

      const ts: Date = (e.timestamp as FirestoreTimestamp).toDate?.() ?? new Date(0);
      if (parsedFrom && ts < parsedFrom) return false;
      if (parsedTo && ts > parsedTo) return false;

      if (actorFilter && e.actorUid !== actorFilter) return false;
      if (actionFilter && typeof e.action === 'string' && e.action !== actionFilter) return false;
      if (actionFilter && typeof e.action !== 'string') return false;
      if (entityTypeFilter && e.entityType !== entityTypeFilter) return false;
      if (entityIdFilter && e.entityId !== entityIdFilter) return false;

      const eCaseId = getEventCaseId(e);
      if (caseIdFilter && eCaseId !== caseIdFilter) return false;

      if (searchFilter) {
        const a = typeof e.action === 'string' ? e.action.toLowerCase() : '';
        const et = typeof e.entityType === 'string' ? e.entityType.toLowerCase() : '';
        const eid = typeof e.entityId === 'string' ? e.entityId.toLowerCase() : '';
        if (!a.includes(searchFilter) && !et.includes(searchFilter) && !eid.includes(searchFilter)) {
          return false;
        }
      }

      return true;
    });

    // Filter out case-tied events the user should not see (PRIVATE case access).
    const caseAccessCache: Record<string, boolean> = {};
    const accessible: any[] = [];
    for (const e of filtered) {
      const eCaseId = getEventCaseId(e);
      if (!eCaseId) {
        accessible.push(e);
        continue;
      }

      if (caseAccessCache[eCaseId] === undefined) {
        const access = await canUserAccessCase(orgId.trim(), eCaseId, uid);
        caseAccessCache[eCaseId] = access.allowed;
      }

      if (caseAccessCache[eCaseId]) {
        accessible.push(e);
      }
    }

    const totalCount = accessible.length;
    const page = accessible.slice(parsedOffset, parsedOffset + parsedLimit);

    // Optional: enrich actor details (email/displayName) from Firebase Auth for this page
    const actorDetailsMap: Map<string, { email: string | null; displayName: string | null }> = new Map();
    if (includeActorDetails === true) {
      const uniqueActorUids = Array.from(new Set(page.map((e) => e.actorUid).filter((x) => typeof x === 'string')));
      const capped = uniqueActorUids.slice(0, 50);
      try {
        const res = await admin.auth().getUsers(capped.map((u) => ({ uid: u })));
        res.users.forEach((u) => {
          actorDetailsMap.set(u.uid, { email: u.email || null, displayName: u.displayName || null });
        });
        capped.forEach((u) => {
          if (!actorDetailsMap.has(u)) actorDetailsMap.set(u, { email: null, displayName: null });
        });
      } catch {
        // Non-fatal; continue without actor details
        capped.forEach((u) => {
          if (!actorDetailsMap.has(u)) actorDetailsMap.set(u, { email: null, displayName: null });
        });
      }
    }

    const events = page.map((e) => {
      const eCaseId = getEventCaseId(e);
      const actorInfo = includeActorDetails === true ? actorDetailsMap.get(e.actorUid) : undefined;
      return {
        auditEventId: e.id ?? null,
        orgId: e.orgId ?? orgId.trim(),
        actorUid: e.actorUid,
        actorEmail: actorInfo?.email ?? null,
        actorDisplayName: actorInfo?.displayName ?? null,
        action: e.action,
        entityType: e.entityType,
        entityId: e.entityId,
        caseId: eCaseId,
        timestamp: toIso(e.timestamp as FirestoreTimestamp),
        metadata: includeMetadata === true ? (e.metadata ?? null) : null,
      };
    });

    return successResponse({
      events,
      totalCount,
      limit: parsedLimit,
      offset: parsedOffset,
      hasMore: parsedOffset + events.length < totalCount,
    });
  } catch (error) {
    functions.logger.error('auditList failed', { orgId, error });
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to list audit events');
  }
});

/**
 * Export audit events as CSV (same filters and access control as auditList).
 * Function Name (Export): auditExport
 */
export const auditExport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    limit = 2000,
    actorUid,
    action,
    entityType,
    entityId,
    caseId,
    fromAt,
    toAt,
    search,
  } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const parsedLimit = typeof limit === 'number' ? Math.min(Math.max(1, limit), 5000) : 2000;

  const entitlement = await checkEntitlement({
    uid,
    orgId,
    requiredPermission: 'audit.view',
  });

  if (!entitlement.allowed) {
    if (entitlement.reason === 'ORG_MEMBER') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
    }
    if (entitlement.reason === 'ROLE_BLOCKED') {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, "You don't have permission to view audit logs");
    }
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view audit logs');
  }

  const parsedFrom = parseIsoDateTime(fromAt);
  const parsedTo = parseIsoDateTime(toAt);
  const actorFilter = typeof actorUid === 'string' && actorUid.trim().length > 0 ? actorUid.trim() : null;
  const actionFilter = typeof action === 'string' && action.trim().length > 0 ? action.trim() : null;
  const entityTypeFilter = typeof entityType === 'string' && entityType.trim().length > 0 ? entityType.trim() : null;
  const entityIdFilter = typeof entityId === 'string' && entityId.trim().length > 0 ? entityId.trim() : null;
  const caseIdFilter = typeof caseId === 'string' && caseId.trim().length > 0 ? caseId.trim() : null;
  const searchFilter = typeof search === 'string' && search.trim().length > 0 ? search.trim().toLowerCase() : null;

  try {
    const snapshot = await db
      .collection('organizations')
      .doc(orgId.trim())
      .collection('audit_events')
      .orderBy('timestamp', 'desc')
      .limit(5000)
      .get();

    const rawEvents = snapshot.docs.map((doc) => doc.data() as any);

    const filtered = rawEvents.filter((e) => {
      if (!e || typeof e !== 'object' || !e.timestamp) return false;
      const ts: Date = (e.timestamp as FirestoreTimestamp).toDate?.() ?? new Date(0);
      if (parsedFrom && ts < parsedFrom) return false;
      if (parsedTo && ts > parsedTo) return false;
      if (actorFilter && e.actorUid !== actorFilter) return false;
      if (actionFilter && (typeof e.action !== 'string' || e.action !== actionFilter)) return false;
      if (entityTypeFilter && e.entityType !== entityTypeFilter) return false;
      if (entityIdFilter && e.entityId !== entityIdFilter) return false;
      const eCaseId = getEventCaseId(e);
      if (caseIdFilter && eCaseId !== caseIdFilter) return false;
      if (searchFilter) {
        const a = typeof e.action === 'string' ? e.action.toLowerCase() : '';
        const et = typeof e.entityType === 'string' ? e.entityType.toLowerCase() : '';
        const eid = typeof e.entityId === 'string' ? e.entityId.toLowerCase() : '';
        if (!a.includes(searchFilter) && !et.includes(searchFilter) && !eid.includes(searchFilter)) {
          return false;
        }
      }
      return true;
    });

    const caseAccessCache: Record<string, boolean> = {};
    const accessible: any[] = [];
    for (const e of filtered) {
      const eCaseId = getEventCaseId(e);
      if (!eCaseId) {
        accessible.push(e);
        continue;
      }
      if (caseAccessCache[eCaseId] === undefined) {
        const access = await canUserAccessCase(orgId.trim(), eCaseId, uid);
        caseAccessCache[eCaseId] = access.allowed;
      }
      if (caseAccessCache[eCaseId]) accessible.push(e);
    }

    const toExport = accessible.slice(0, parsedLimit);

    const escapeCsv = (v: unknown): string => {
      if (v == null) return '';
      const s = String(v);
      if (s.includes('"') || s.includes(',') || s.includes('\n') || s.includes('\r')) {
        return `"${s.replace(/"/g, '""')}"`;
      }
      return s;
    };

    const header = 'Timestamp,Action,Entity Type,Entity ID,Case ID,Actor UID,Actor Email,Actor Display Name';
    const rows = toExport.map((e) => {
      const ts = (e.timestamp as FirestoreTimestamp).toDate?.() ?? new Date(0);
      const eCaseId = getEventCaseId(e);
      return [
        ts.toISOString(),
        e.action ?? '',
        e.entityType ?? '',
        e.entityId ?? '',
        eCaseId ?? '',
        e.actorUid ?? '',
        e.actorEmail ?? '',
        e.actorDisplayName ?? '',
      ].map(escapeCsv).join(',');
    });

    const csv = [header, ...rows].join('\r\n');

    return successResponse({ csv });
  } catch (error) {
    functions.logger.error('auditExport failed', { orgId, error });
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to export audit events');
  }
});

