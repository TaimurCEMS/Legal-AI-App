# Slice 10: Time Tracking - Build Card

**Status:** ✅ COMPLETE  
**Priority:** 🟡 HIGH  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 5 ✅

---

## 1) Overview

### 1.1 Purpose
Enable lawyers and staff to record billable and non-billable time against cases/clients via **manual entries** and a **timer**, producing reporting-ready data that later powers Slice 11 (Billing & Invoicing).

### 1.2 User Stories
- As a lawyer, I want to start/stop a timer for a case so I don’t forget billable time.
- As a lawyer, I want to enter time manually (past work) with a description and billable flag.
- As a firm, I want to view time entries by date range, case, and user.
- As an admin, I want to ensure only one timer runs per user at a time.

### 1.3 Success Criteria (Definition of Done)
- [x] Create/edit/delete time entries (soft delete)
- [x] Timer start/stop supported and resilient (server is source of truth)
- [x] Only one running timer per user is allowed (backend enforced)
- [x] Entries support: case link, optional client link, description, billable flag, duration
- [x] Listing supports filters: caseId, clientId, userId, date range, billable
- [x] All operations org-scoped and enforce case access server-side
- [x] Docs updated (`SLICE_STATUS.md`, `SESSION_NOTES.md`)

---

## 2) Scope In ✅

### Backend (Cloud Functions)
- `timeEntryCreate` – Manual time entry (stopped; startAt, endAt, description, billable, caseId, clientId)
- `timeEntryStartTimer` – Start timer (creates running entry; one running timer per user enforced via lock doc)
- `timeEntryStopTimer` – Stop timer (sets endAt, durationSeconds; releases lock)
- `timeEntryList` – List/filter (caseId, clientId, userId, billable, from, to, status); pagination (limit, offset)
- `timeEntryUpdate` – Edit description, billable, caseId, clientId, startAt/endAt (when stopped)
- `timeEntryDelete` – Soft delete (idempotent); releases running timer lock if applicable
- Entitlement: TIME_TRACKING; permissions: time.create, time.read, time.update, time.delete
- Case/client access enforced; VIEWER restricted to own entries; only ADMIN can filter by userId

### Frontend (Flutter)
- Time tab: timer widget, manual entry form, entries list with filters (range, case, billable, “Mine” default)

### Data Model
- `organizations/{orgId}/timeEntries/{timeEntryId}`; `organizations/{orgId}/runningTimers/{uid}` (lock)

---

## 3) Scope Out ❌

- Trust/IOLTA, advanced rate rules, taxes, LEDES (Slice 11); email reminders; team availability view

---

## 4) Dependencies

**External Services:** Firebase Auth, Firestore, Cloud Functions (Slice 0).

**Dependencies on Other Slices:** Slice 0 (org, membership, entitlements), Slice 1 (Flutter UI), Slice 2 (cases), Slice 3 (clients – optional clientId).

**No Dependencies on:** Slice 4 (Documents), Slice 5 (Tasks), Slice 7+ (Calendar, Notes, Billing).

---

## 5) Backend Endpoints (Slice 4 style)

### 5.1 `timeEntryCreate` (Callable Function)

**Function Name (Export):** `timeEntryCreate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `TIME_TRACKING`  
**Required Permission:** `time.create`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional)",
  "clientId": "string (optional)",
  "description": "string (required, max 2000)",
  "billable": "boolean (optional, default true)",
  "startAt": "string (required, ISO 8601)",
  "endAt": "string (required, ISO 8601)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "timeEntry": { "timeEntryId", "orgId", "caseId", "clientId", "description", "billable", "status": "stopped", "startAt", "endAt", "durationSeconds", "createdAt", "updatedAt", "createdBy", "updatedBy" }
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (description, startAt/endAt, endAt < startAt, duration > 7 days, invalid caseId/clientId), `NOT_AUTHORIZED`, `PLAN_LIMIT`, `NOT_FOUND` (case/client).

**Implementation Flow:** Validate auth, orgId, description, startAt, endAt → entitlement → optional case/client access → create stopped entry → audit time.created → return timeEntry.

---

### 5.2 `timeEntryStartTimer` (Callable Function)

**Function Name (Export):** `timeEntryStartTimer`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `TIME_TRACKING`  
**Required Permission:** `time.create`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional)",
  "clientId": "string (optional)",
  "description": "string (optional)",
  "billable": "boolean (optional, default true)"
}
```

**Success Response (200):** `data.timeEntry` with status `running`, startAt=now, endAt=null, durationSeconds=0.

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR`, `NOT_AUTHORIZED`, `PLAN_LIMIT`, `NOT_FOUND` (case/client), `VALIDATION_ERROR` (TIMER_ALREADY_RUNNING – second start blocked).

**Implementation Flow:** Validate → entitlement → optional case/client → transaction: check runningTimers/{uid} lock; if exists throw TIMER_ALREADY_RUNNING; create time entry (status running), set lock doc → audit → return timeEntry.

---

### 5.3 `timeEntryStopTimer` (Callable Function)

**Function Name (Export):** `timeEntryStopTimer`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `time.update`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "timeEntryId": "string (optional – if omitted, uses current running timer for user)"
}
```

**Success Response (200):** `data.timeEntry` with status `stopped`, endAt, durationSeconds computed.

**Error Responses:** `ORG_REQUIRED`, `NOT_AUTHORIZED`, `VALIDATION_ERROR` (no running timer), `NOT_FOUND`, `NOT_AUTHORIZED` (not owner and not ADMIN), `VALIDATION_ERROR` (NOT_RUNNING – entry already stopped).

**Implementation Flow:** Validate → resolve timeEntryId (explicit or from lock or running query) → transaction: get entry, verify running, compute duration, update entry (stopped, endAt, durationSeconds), delete lock if same entry → audit → return timeEntry.

---

### 5.4 `timeEntryList` (Callable Function)

**Function Name (Export):** `timeEntryList`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `time.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "limit": "number (optional, default 50, max 100)",
  "offset": "number (optional, default 0)",
  "caseId": "string (optional)",
  "clientId": "string (optional)",
  "userId": "string (optional – ADMIN only)",
  "billable": "boolean (optional)",
  "from": "string (optional, ISO date/time)",
  "to": "string (optional, ISO date/time)",
  "status": "string (optional, running | stopped)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "timeEntries": [ { "timeEntryId", "orgId", "caseId", "clientId", "description", "billable", "status", "startAt", "endAt", "durationSeconds", "createdAt", "updatedAt", "createdBy", "updatedBy" } ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invalid params), `NOT_AUTHORIZED` (VIEWER must pass userId=self; non-ADMIN cannot pass userId≠self), `NOT_FOUND` (case).

**Implementation Flow:** Validate → entitlement → if userId and not ADMIN return NOT_AUTHORIZED; if VIEWER and !userId return NOT_AUTHORIZED (mine-only) → query timeEntries deletedAt==null, apply filters → filter by case access for case-linked entries → paginate → return.

---

### 5.5 `timeEntryUpdate` (Callable Function)

**Function Name (Export):** `timeEntryUpdate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `time.update`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "timeEntryId": "string (required)",
  "description": "string (optional; may be empty)",
  "billable": "boolean (optional)",
  "caseId": "string | null (optional)",
  "clientId": "string | null (optional)",
  "startAt": "string (optional, only when stopped)",
  "endAt": "string (optional, only when stopped)"
}
```

**Success Response (200):** `data.timeEntry` (full updated entry).

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (timeEntryId, description length, start/end while running, endAt < startAt), `NOT_FOUND` (entry or case/client), `NOT_AUTHORIZED` (not owner and not ADMIN).

**Implementation Flow:** Validate → load entry → entitlement → owner or ADMIN → apply updates (description may be cleared; startAt/endAt only if status stopped) → audit → return updated timeEntry.

---

### 5.6 `timeEntryDelete` (Callable Function)

**Function Name (Export):** `timeEntryDelete`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `time.delete`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "timeEntryId": "string (required)"
}
```

**Success Response (200):** `data: { deleted: true }`

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (timeEntryId), `NOT_AUTHORIZED` (not owner and not ADMIN).

**Implementation Flow:** Validate → load entry; if !exists or already deletedAt return success (idempotent) → entitlement → owner or ADMIN → transaction: set deletedAt, if entry was running delete lock → audit → return { deleted: true }.

---

## 6) Data Model

### 6.1 Firestore Collections
```
organizations/{orgId}/timeEntries/{timeEntryId}
```

### 6.2 TimeEntry (MVP)
```typescript
type TimeEntryStatus = 'running' | 'stopped';

interface TimeEntryDocument {
  timeEntryId: string;
  orgId: string;
  caseId?: string | null;
  clientId?: string | null;
  description: string;
  billable: boolean;

  // Timer + manual entry fields
  status: TimeEntryStatus;
  startAt: Timestamp;          // required (manual entry uses startAt/endAt)
  endAt?: Timestamp | null;    // null while running
  durationSeconds: number;     // derived when stopped; validated when manual

  // Future billing fields (Slice 11)
  rateCents?: number | null;
  currency?: string | null;

  createdAt: Timestamp;
  updatedAt: Timestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: Timestamp | null;
}
```

---

## 7) Backend Summary (see 5) for Slice 4 style)

### 7.1 Functions (MVP)
- `timeEntryCreate` – manual time entry creation
- `timeEntryStartTimer` – start timer (creates running entry; blocks if already running for user)
- `timeEntryStopTimer` – stop timer (computes durationSeconds)
- `timeEntryUpdate` – edit description/billable/caseId/startAt/endAt/duration
- `timeEntryDelete` – soft delete (idempotent)
- `timeEntryList` – list/filter time entries (date range, caseId, userId, billable)

### 7.2 Security & Access Control
- All calls require `orgId`
- Case-linked entries require `canUserAccessCase(orgId, caseId, uid)`
- Existence-hiding semantics: unauthorized reads return NOT_FOUND where appropriate

---

## 8) Entitlements & Permissions

### 8.1 Plan Features
- `TIME_TRACKING` (initially plan-gated; development may allow ADMIN bypass while billing is unfinished)

### 8.2 Role Permissions
- `time.create`, `time.read`, `time.update`, `time.delete`

---

## 9) Frontend (Flutter)

### 9.1 Models
- `TimeEntryModel`

### 9.2 Service
- `TimeEntryService` (Cloud Functions wrapper)

### 9.3 Provider
- `TimeEntryProvider`

### 9.4 UI
- AppShell: new **Time** tab
- Timer widget (start/stop, shows active timer)
- Manual entry form
- Time entries list with filters (range, case, billable) and clear indicator of active range
- “Mine” filter (default ON) for personal time; team view available for non-VIEWER roles
- Billable defaults to ON and persists as a user preference (can be turned off)

---

## 10) Testing Checklist (Manual)

### Backend
- [x] Start timer → creates running entry
- [x] Start timer again → blocked (only one running timer per user)
- [x] Stop timer → sets endAt and durationSeconds
- [x] Manual entry → validates endAt >= startAt and durationSeconds matches
- [x] List filters work (caseId, date range, billable)
- [x] Update allows clearing description (empty string) without validation error
- [x] Permissions: admin-only userId filtering; viewer restricted to mine-only

### Frontend
- [x] Time tab shows entries for selected range
- [x] Start/stop timer updates UI and persists after refresh
- [x] Manual add/edit/delete works
- [x] “All cases” filter works reliably (explicit sentinel value, not null)

---

**Created:** 2026-01-27  
**Last Updated:** 2026-01-28  

