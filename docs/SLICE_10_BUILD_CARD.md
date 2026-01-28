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

## 2) Data Model

### 2.1 Firestore Collections
```
organizations/{orgId}/timeEntries/{timeEntryId}
```

### 2.2 TimeEntry (MVP)
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

## 3) Backend (Cloud Functions)

### 3.1 Functions (MVP)
- `timeEntryCreate` – manual time entry creation
- `timeEntryStartTimer` – start timer (creates running entry; blocks if already running for user)
- `timeEntryStopTimer` – stop timer (computes durationSeconds)
- `timeEntryUpdate` – edit description/billable/caseId/startAt/endAt/duration
- `timeEntryDelete` – soft delete (idempotent)
- `timeEntryList` – list/filter time entries (date range, caseId, userId, billable)

### 3.2 Security & Access Control
- All calls require `orgId`
- Case-linked entries require `canUserAccessCase(orgId, caseId, uid)`
- Existence-hiding semantics: unauthorized reads return NOT_FOUND where appropriate

---

## 4) Entitlements & Permissions

### 4.1 Plan Features
- `TIME_TRACKING` (initially plan-gated; development may allow ADMIN bypass while billing is unfinished)

### 4.2 Role Permissions
- `time.create`, `time.read`, `time.update`, `time.delete`

---

## 5) Frontend (Flutter)

### 5.1 Models
- `TimeEntryModel`

### 5.2 Service
- `TimeEntryService` (Cloud Functions wrapper)

### 5.3 Provider
- `TimeEntryProvider`

### 5.4 UI
- AppShell: new **Time** tab
- Timer widget (start/stop, shows active timer)
- Manual entry form
- Time entries list with filters (range, case, billable) and clear indicator of active range
- “Mine” filter (default ON) for personal time; team view available for non-VIEWER roles
- Billable defaults to ON and persists as a user preference (can be turned off)

---

## 6) Testing Checklist (Manual)

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

