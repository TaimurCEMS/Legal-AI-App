# Slice 22 Build Card: Matter Intake Workflow

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (after launch criteria or in parallel as capacity allows)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 2.5 ✅, Slice 5 ✅, **P1 Domain Events** (optional for notifications), **P2** (optional)  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §7

---

## 📋 Overview

Slice 22 adds a **Matter Intake Workflow**: a structured process for new matters from initial request through conflict check (optional), approval, and creation. It gives firms a repeatable pipeline and audit trail for "how matters get opened."

**Key Features:**
1. **Intake request** – Form or portal submission to request a new matter (client/case type, description, requested by, attachments). Creates an intake request record (status: draft → submitted).
2. **Intake pipeline** – List of intake requests with status (submitted, under_review, approved, rejected, converted). Optional assignment to a reviewer (lawyer/admin).
3. **Approval / rejection** – Reviewer approves (optionally run conflict check first) and converts request into a real matter (Slice 2 case + client link) and optionally assigns; or rejects with reason.
4. **Conflict check (optional)** – Before approval, run a simple conflict check (e.g. client name match against existing clients/cases); flag for manual review. Full conflict-of-interest slice can be a separate slice.
5. **Notifications** – On submit, notify reviewers; on approval/rejection, notify requester (P2 if available).
6. **Audit** – All state changes and conversions logged in audit_events.

**Out of Scope (MVP):**
- Full conflict-of-interest engine (Slice 19 in v1 roadmap; can integrate later).
- Custom intake form builder (fixed form for MVP).
- Client self-service intake (Client Portal can link later).

---

## 🎯 Success Criteria

### Backend
- **Intake request CRUD:** `intakeRequestCreate`, `intakeRequestGet`, `intakeRequestList`, `intakeRequestUpdate`, `intakeRequestSubmit` – create and submit intake requests; list with filters (status, assignedTo, date range).
- **Workflow:** `intakeRequestApprove` – Converts request to matter (case + client if new); optionally assign matter to user; set intake status to converted; emit domain event; audit. `intakeRequestReject` – Set status rejected, reason, audit.
- **Optional:** `intakeConflictCheck` – Given intake request (client name, etc.), return potential conflicts (existing clients/cases with similar name); no auto-block, for reviewer info.
- **Permissions:** Create/submit: org members with matter create permission; approve/reject: admin or designated "intake reviewer" role.

### Frontend
- **Intake list screen** – Table or cards of intake requests; filters (status, assigned to me, date); columns: title, client name, status, requested by, date, actions (View, Approve, Reject).
- **Intake request form** – Create/edit draft: matter title, description, client (select or create new), case type, requested by (default current user), attachments (optional); Submit button.
- **Intake detail screen** – Full request; Approve / Reject buttons (with optional conflict check result); Approve opens dialog: "Create matter and assign to?" (optional assignee); on confirm, call approve and navigate to new matter.
- **Navigation** – Entry from Home or Matters: "New matter request" or "Intake" tab/section for users with permission.

### Testing
- Backend: Create request → submit → approve → verify case and client created; reject → verify status and audit.
- Frontend: Submit intake, approve as admin, see new matter in list.
- Optional: Conflict check returns matches when client name exists.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. Data Model
- **Collection:** `organizations/{orgId}/intake_requests/{requestId}`
```typescript
interface IntakeRequestDocument {
  requestId: string;
  orgId: string;
  title: string;
  description?: string;
  clientName: string;        // or clientId if existing client
  clientEmail?: string;
  clientPhone?: string;
  caseType?: string;        // e.g. "Litigation", "Corporate"
  requestedByUid: string;
  requestedAt: Timestamp;
  status: "draft" | "submitted" | "under_review" | "approved" | "rejected" | "converted";
  assignedToUid?: string;   // reviewer
  reviewedByUid?: string;
  reviewedAt?: Timestamp;
  rejectionReason?: string;
  convertedCaseId?: string; // set when approved → matter created
  convertedAt?: Timestamp;
  attachmentIds?: string[]; // references to Storage or document IDs
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### 2. Callables
- **`intakeRequestCreate`** – Create draft; auth, org, permission to create matters.
- **`intakeRequestGet`** – Get one request; org member.
- **`intakeRequestList`** – List with filters: status, assignedToUid, fromDate, toDate; pagination; org member.
- **`intakeRequestUpdate`** – Update draft only (status = draft); author or admin.
- **`intakeRequestSubmit`** – Set status = submitted; validate required fields; emit event for notifications (P2); org member.
- **`intakeRequestApprove`** – Require permission (admin or intake_reviewer); load request (status = submitted or under_review); optional conflict check; create case (Slice 2 caseCreate) and client if new (Slice 3 clientCreate); link case to client; optionally assign matter to user; set request status = converted, convertedCaseId, convertedAt; emit domain event matter.created (and intake.converted); audit.
- **`intakeRequestReject`** – Set status = rejected, rejectionReason, reviewedByUid, reviewedAt; audit; optional P2 notify requester.
- **`intakeConflictCheck`** – Request: orgId, requestId or clientName; return list of potential conflicts (client/case names containing similar string); no write.

#### 3. Permissions
- New permission or role: `intake.create`, `intake.review` (or reuse admin + matter.create).
- List: only show requests user can see (e.g. all for admin, or assigned to me + submitted for reviewer).

### Frontend (Flutter)

- **IntakeRequestModel** – Mirrors backend document.
- **IntakeRequestService** – CRUD + submit, approve, reject, conflictCheck.
- **IntakeRequestProvider** – State for list and current request.
- **IntakeListScreen** – List with filters; row actions View, Approve, Reject.
- **IntakeRequestFormScreen** – Create/edit draft; Submit.
- **IntakeRequestDetailScreen** – Read-only view + Approve (with optional conflict check result and assignee picker) / Reject (with reason dialog).
- **Routes:** e.g. `/intake`, `/intake/new`, `/intake/:id`.

### Security

- Only org members; approve/reject restricted to admin or intake reviewer.
- Audit every state change (submitted, approved, rejected, converted).
- When converting, use existing caseCreate/clientCreate with same entitlement checks.

---

## 📝 Backend Endpoints (Summary)

| Function | Request | Success |
|----------|---------|---------|
| intakeRequestCreate | orgId, title, description, clientName, ... | { requestId, ... } |
| intakeRequestGet | orgId, requestId | intake request |
| intakeRequestList | orgId, status?, assignedTo?, limit?, offset? | { requests, hasMore } |
| intakeRequestUpdate | orgId, requestId, ... | updated request |
| intakeRequestSubmit | orgId, requestId | { status: "submitted" } |
| intakeRequestApprove | orgId, requestId, assignToUid? | { caseId, ... } |
| intakeRequestReject | orgId, requestId, reason | { success } |
| intakeConflictCheck | orgId, requestId or clientName | { conflicts: [...] } |

---

## 🧪 Testing Strategy

- Unit: Approve flow creates case and client with correct fields.
- Integration: Submit → Approve → verify case in Firestore and in case list; Reject → verify status.
- Frontend: Full flow from create to approve and navigate to matter.

---

## 📚 References

- MASTER_SPEC_V2.0.md §7 (Slice 22)
- SLICE_2_BUILD_CARD.md (Case create)
- SLICE_3_BUILD_CARD.md (Client create)
- SLICE_P1_BUILD_CARD.md (matter.created event)

---

**Last Updated:** 2026-01-30
