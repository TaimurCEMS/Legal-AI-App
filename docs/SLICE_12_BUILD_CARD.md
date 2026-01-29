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

### 1.3 Security Notes (Important)
- `audit.view` is treated as **ADMIN-only** (to avoid privacy leaks via audit metadata).
- Audit listing additionally filters by `canUserAccessCase(orgId, caseId, uid)` for any event tied to a case.

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

## 5) Testing

### 5.1 Backend Terminal Test (requires deployed functions)
```bash
cd functions
$env:FIREBASE_API_KEY="AIza...."
npm run test:slice12
```

### 5.2 Flutter
- `flutter test` (unit/widget tests)

---

## 6) Deployment Notes

- Cloud Functions deployed: 2026-01-29
- `firebase deploy --only functions`

---

## 7) Deferred / Future Improvements
- Cursor-based pagination for audit events (avoid offset cost at scale).
- Action filter dropdown (e.g., show only "created" or "deleted" actions).
- Export to file (save CSV directly to device) or PDF format.
- "Entity detail" deep-links (tap to navigate to the referenced case/task/document).
- Real-time audit feed (live updates via Firestore listeners).
