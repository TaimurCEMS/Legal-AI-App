# Slice 12: Audit Trail UI - Build Card

**Status:** ✅ COMPLETE  
**Priority:** 🟡 MEDIUM  
**Completed:** 2026-01-29  
**Dependencies:** Slice 0 ✅ (audit logging), Slice 2 ✅ (case access), existing slices emitting audit events

---

## 1) Overview

### 1.1 Purpose
Provide a secure, usable UI for viewing and filtering audit events for compliance visibility (who did what, when), without leaking private-case activity.

### 1.2 MVP Scope (this slice)
- Backend callable function to list audit events with filters/search (MVP).
- Flutter UI (Settings → Audit Trail) to view audit events, filter, paginate, and inspect event metadata.
- Defense-in-depth filtering so **PRIVATE case** events are only visible to users with case access.

### 1.3 User Stories
- As an admin, I want to view a list of audit events (who did what, when) so I can support compliance and troubleshooting.
- As an admin, I want to filter events by date range, entity type, and actor so I can narrow down to relevant activity.
- As an admin, I want to export filtered events to CSV so I can share or archive audit data.
- As an admin, I want to be sure I never see audit events for PRIVATE cases I don’t have access to.

### 1.4 Success Criteria (Definition of Done)
- [x] Backend `auditList` and `auditExport` with auth, org, and `audit.view` permission
- [x] Case access filtering so PRIVATE case events are hidden from users without case access
- [x] Frontend: Settings → Audit Trail (ADMIN-only), filters (search, entity type, user, date range), export CSV, pagination
- [x] Human-readable labels and collapsible metadata for event details

### 1.5 Security Notes (Important)
- `audit.view` is **ADMIN-only** (to avoid privacy leaks via audit metadata).
- Audit listing filters by `canUserAccessCase(orgId, caseId, uid)` for any event tied to a case.

---

## 2) Data Model

### 2.1 Storage Location
Audit events are stored under:
```
organizations/{orgId}/audit_events/{auditEventId}
```

### 2.2 Audit Event Document Shape (MVP)
```typescript
interface AuditEventDocument {
  id: string;
  orgId: string;
  actorUid: string;
  action: string;      // e.g. "task.created", "invoice.exported"
  entityType: string;  // e.g. "task", "invoice", "document", "case"
  entityId: string;    // entity identifier
  caseId?: string;     // optional case scoping (when applicable)
  timestamp: Timestamp;
  metadata?: Record<string, any>;
}
```

**Note:** `caseId` is optional and is inferred from `metadata.caseId` where possible. For case entity events, the case id is derived from `entityId`.

---

## 2.5 Dependencies

**External Services:** Firebase Auth, Firestore, Cloud Functions (from Slice 0).

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Auth, org, entitlements; audit event emission from existing slices
- ✅ **Slice 2**: Case access (`canUserAccessCase`) for filtering PRIVATE case events

**No Dependencies on:** Slice 3+ for audit data (audit events are emitted by many slices; this slice only reads them).

---

## 3) Backend (Cloud Functions)

### 3.1 Functions Deployed
- `auditList` (exported in `functions/src/index.ts`)
  - Validates auth + org membership
  - Requires `audit.view`
  - Reads recent audit events (MVP cap), filters in-memory (search + filters + fromAt/toAt + actorUid)
  - Filters out case-linked events if `canUserAccessCase` denies access (PRIVATE case protection)
  - Returns pagination info (`limit`, `offset`, `hasMore`)
- `auditExport` (exported in `functions/src/index.ts`)
  - Same auth, permission, and filters as `auditList`
  - Returns CSV string (`{ csv: string }`) for clipboard/download

### 3.2 Key Files
- `functions/src/functions/audit.ts`
- `functions/src/utils/audit.ts` (enhanced to persist optional `caseId`)
- `functions/src/constants/permissions.ts` (`audit.view` admin-only)
- `functions/src/__tests__/slice12-terminal-test.ts`
- `functions/package.json` adds `test:slice12`

### 3.3 Backend Endpoints (Slice 4 style)

#### 3.3.1 `auditList` (Callable Function)

**Function Name (Export):** `auditList`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `audit.view` (ADMIN-only)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "limit": "number (optional, default 50, max 100)",
  "offset": "number (optional, default 0)",
  "search": "string (optional, free-text filter)",
  "entityType": "string (optional, filter by entity type)",
  "actorUid": "string (optional, filter by actor)",
  "fromAt": "string (optional, ISO 8601 start date)",
  "toAt": "string (optional, ISO 8601 end date)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "id": "string",
        "orgId": "string",
        "actorUid": "string",
        "action": "string",
        "entityType": "string",
        "entityId": "string",
        "caseId": "string | null",
        "timestamp": "ISO 8601",
        "metadata": "object",
        "actionDisplayLabel": "string",
        "entityTypeDisplayLabel": "string"
      }
    ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId
- `NOT_AUTHORIZED` (403): User not org member or role does not have `audit.view`
- `INTERNAL_ERROR` (500): Firestore read failure

**Implementation Flow:**
1. Validate auth token
2. Validate orgId (required)
3. Check entitlement: `audit.view` (ADMIN-only)
4. Parse limit (1–100, default 50), offset (≥ 0)
5. Query audit events for org (e.g. `organizations/{orgId}/audit_events` or audit_logs); order by timestamp desc; apply limit/offset
6. For each event with caseId: filter out if `canUserAccessCase(orgId, caseId, uid)` denies
7. Apply in-memory filters: search (action/entityType/entityId), entityType, actorUid, fromAt, toAt
8. Resolve actionDisplayLabel, entityTypeDisplayLabel
9. Return events array, total, hasMore

---

#### 3.3.2 `auditExport` (Callable Function)

**Function Name (Export):** `auditExport`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `audit.view` (ADMIN-only)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "search": "string (optional)",
  "entityType": "string (optional)",
  "actorUid": "string (optional)",
  "fromAt": "string (optional, ISO 8601)",
  "toAt": "string (optional, ISO 8601)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "csv": "string (CSV content, same filters as auditList)"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId
- `NOT_AUTHORIZED` (403): User not org member or role does not have `audit.view`
- `INTERNAL_ERROR` (500): Firestore read or export failure

**Implementation Flow:**
1. Validate auth token
2. Validate orgId (required)
3. Check entitlement: `audit.view`
4. Apply same filters as auditList (search, entityType, actorUid, fromAt, toAt) and case access filtering
5. Fetch matching events (cap limit for export, e.g. 1000)
6. Build CSV string (headers + rows)
7. Return { csv }

---

## 4) Frontend (Flutter)

### 4.1 UI Entry Point
- Settings → **Audit Trail** (ADMIN-only UI)

### 4.2 Features Implemented
- **Search:** Free-text search across action, entity type, entity ID
- **Entity type filter:** Dropdown to filter by case, document, task, etc.
- **User filter:** Dropdown populated from org members to filter by actor
- **Date range filter:** From/To date pickers; passed to backend as `fromAt`/`toAt`
- **Export CSV:** Export button calls `auditExport`; CSV copied to clipboard
- **Human-readable labels:** `actionDisplayLabel` and `entityTypeDisplayLabel` for better UX
- **Collapsible metadata:** Technical details hidden by default, expandable on demand
- **Pagination:** "Load more" button for large result sets

### 4.3 Key Files
- `legal_ai_app/lib/core/models/audit_event_model.dart` (includes `actionDisplayLabel`, `entityTypeDisplayLabel`)
- `legal_ai_app/lib/core/services/audit_service.dart` (`listAuditEvents`, `exportAuditEvents`)
- `legal_ai_app/lib/features/audit/providers/audit_provider.dart` (`refresh` with filters, `export`)
- `legal_ai_app/lib/features/audit/screens/audit_trail_screen.dart` (all filters, export, collapsible detail dialog)
- `legal_ai_app/lib/core/routing/route_names.dart` + `app_router.dart` (route wiring)
- `legal_ai_app/lib/app.dart` (provider registration)

---

## 5) Entitlements & Permissions

### 5.1 Role Permissions
- **`audit.view`** – Required to list and export audit events
  - ADMIN: ✅
  - LAWYER: ❌
  - PARALEGAL: ❌
  - VIEWER: ❌

### 5.2 Plan Features
- **`AUDIT_TRAIL`** – Feature availability by plan (FREE: false, BASIC: false, PRO: true, ENTERPRISE: true; ADMIN bypass per `checkEntitlement`)

### 5.3 Case Access
- Events tied to a case are filtered by `canUserAccessCase(orgId, caseId, uid)`; PRIVATE case events are hidden from users without access.

---

## 6) Testing

### 6.1 Backend Terminal Test (requires deployed functions)
```powershell
cd functions
$env:FIREBASE_API_KEY="AIza...."
npm run test:slice12
```

### 6.2 Manual Testing Checklist

**Backend**
- [x] `auditList` returns events for org with valid auth and `audit.view`
- [x] Non-admin cannot list audit events (permission denied)
- [x] Case-linked events for PRIVATE cases are excluded when user lacks case access
- [x] `auditExport` returns CSV with same filters as list

**Frontend**
- [x] Audit Trail entry visible in Settings for ADMIN only
- [x] Filters (search, entity type, user, date range) apply and refresh list
- [x] Export CSV copies filtered events to clipboard
- [x] Event detail expandable (technical details)

---

## 7) Deployment Notes

- Cloud Functions deployed: 2026-01-29
- `firebase deploy --only functions`

---

## 8) Deferred / Future Improvements
- Cursor-based pagination for audit events (avoid offset cost at scale).
- Action filter dropdown (e.g., show only "created" or "deleted" actions).
- Export to file (save CSV directly to device) or PDF format.
- "Entity detail" deep-links (tap to navigate to the referenced case/task/document).
- Real-time audit feed (live updates via Firestore listeners).

---

**Created:** 2026-01-29  
**Last Updated:** 2026-01-29
