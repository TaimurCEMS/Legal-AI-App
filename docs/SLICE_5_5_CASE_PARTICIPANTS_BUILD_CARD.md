# Slice 5.5 – Case Participants & Private Case Sharing (Build Card)

**Last Updated:** January 24, 2026  
**Status:** ✅ COMPLETE – DEPLOYED  
**Owner:** Taimur (CEMS)  

---

## 1) Purpose

Introduce **per-case sharing ("Case Participants")** so the creator of a PRIVATE case can invite specific org members, control who can see the case and its linked tasks/documents, and assign tasks only to participants. Also add a **task-level visibility flag** (`restrictedToAssignee`) for fine-grained task visibility. This slice builds on Slice 2 (Case Hub), Slice 4 (Document Hub), and Slice 5 (Task Hub).

---

## 2) Scope In ✅

### Backend (Cloud Functions):
- `caseListParticipants` – List participants for a case (creator + participants for PRIVATE)
- `caseAddParticipant` – Add org member as participant (creator or ADMIN only for PRIVATE case)
- `caseRemoveParticipant` – Remove participant (creator only; cannot remove self)
- Case access helper `canUserAccessCase(orgId, caseId, uid)` – used by case/task/document functions
- Task visibility: `restrictedToAssignee` on tasks (taskCreate/Get/List/Update enforce)
- Firestore rules for `organizations/{orgId}/cases/{caseId}/participants/{uid}`
- Audit events: `case.participant_added`, `case.participant_removed`

### Frontend (Flutter):
- Case Details – "People / Access" section: show participants, add/remove org members (creator only)
- Non-creators see who has access but cannot change it
- Task create/edit: support `restrictedToAssignee` toggle

### Data Model:
- `organizations/{orgId}/cases/{caseId}/participants/{uid}` – uid, role (PARTICIPANT), addedAt, addedBy
- Task document: new field `restrictedToAssignee: boolean` (default false)

---

## 3) Scope Out ❌

- Per-case roles (e.g. "Case Editor" vs "Viewer") – all participants share the same access level.
- Cross-org sharing / external guests.
- Email invitations or notifications.
- AI-specific behavior changes.
- Realtime "live updates" – MVP stays request-driven (screen entry, refresh, explicit actions).

---

## 4) Dependencies

**External Services:** Firebase Auth, Firestore, Cloud Functions (from Slice 0).

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Auth, org, entitlements
- ✅ **Slice 1**: Flutter shell, navigation, widgets
- ✅ **Slice 2**: Case Hub (cases, visibility PRIVATE/ORG_WIDE)
- ✅ **Slice 4**: Document Hub (case-linked documents)
- ✅ **Slice 5**: Task Hub (case-linked tasks, assignee)

**No Dependencies on:** Slice 6+ (AI, etc.)

---

## 5) Data Model

### 5.1 New Collection: Case Participants

Path (per org and case):

- `organizations/{orgId}/cases/{caseId}/participants/{uid}`

Document shape (MVP):

```json
{
  "uid": "string",          // user id (same as member.uid)
  "role": "PARTICIPANT",    // reserved for future; for now always "PARTICIPANT"
  "addedAt": "Timestamp",
  "addedBy": "string"       // uid of the user who added this participant
}
```

Notes:

- We **only create `participants` docs for PRIVATE cases** in MVP.
- For ORG_WIDE cases, org membership alone controls access; no need for per-case participants.

### 5.2 Task-Level Visibility Field

New field on `TaskDocument`:

- `restrictedToAssignee: boolean` (default `false`)

When `true`, the task is only visible to:
- Org-level ADMINs
- The task's assignee
- The case creator (if the task is unassigned)

### 5.3 Case Visibility Recap

Existing field in `CaseDocument`:

- `visibility: 'ORG_WIDE' | 'PRIVATE'`

Interpretation after this slice:

- `ORG_WIDE`  
  - Access: any org member (consistent with Slice 2).
  - Participants subcollection is **ignored** (may be empty / unused).

- `PRIVATE`  
  - Access: `createdBy` + any document in `cases/{caseId}/participants`.

---

## 6) Permissions & Entitlements

We **do not** add a new plan entitlement – case participants are part of the existing **CASES** feature for now.

### 6.1 New / Clarified Permissions

We reuse and slightly extend case permissions:

- `case.read` – unchanged:
  - ORG_WIDE: any org member with `case.read`.
  - PRIVATE: only creator + participants (this slice).

- `case.update` – unchanged base rule; **special handling for participants:**
  - Creator:
    - Can edit case metadata (title, description, status, client) as per Slice 2.
    - Can manage participants (add/remove).
  - Participant:
    - Can view case + linked tasks/docs.
    - **Cannot** manage participants (MVP).
    - Can still perform operations allowed by their role on tasks/documents (see below).

### 6.2 Tasks & Documents Permissions Interaction

For items linked to PRIVATE cases:

- **Tasks:**
  - `task.read`: allowed only if:
    - User is org member **and**  
    - User is the case creator or a participant of that case **and**  
    - Task-level visibility does not further restrict access (see `restrictedToAssignee` below).
  - `task.assign`:
    - For PRIVATE cases, `assigneeId` must be either:
      - Case creator, or
      - Any case participant.
    - Backend enforces: `assigneeId ∈ {createdBy} ∪ participants`.
  - **Task-level visibility flag (Slice 5.5 extension):**
    - New field on tasks: `restrictedToAssignee: boolean` (default `false`).
    - Semantics (applies to **both** PRIVATE and ORG_WIDE cases):
      - `false` (default) → task is visible to **all users who can see the case** (for ORG_WIDE: all org members; for PRIVATE: creator + participants) plus admins.
      - `true` → task is visible only to:
        - Admins (org-level role `ADMIN`), and
        - The assignee (`assigneeId`), and
        - The case creator while the task is unassigned.
    - This gives admins greater control over task privacy across all case types.

- **Documents:**
  - `document.read`:
    - For PRIVATE cases, only case creator + participants can read linked documents.
  - `documentUpdate` for case linking:
    - When linking to a PRIVATE case, ensure caller has access (creator/participant) before allowing link.

---

## 7) Backend Endpoints (Cloud Functions) — Slice 4 style

Case participant functions live in `functions/src/functions/case-participants.ts` and are exported in `functions/src/index.ts`.

### 7.1 `caseAddParticipant` (Callable Function)

**Function Name (Export):** `caseAddParticipant`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.update` (creator of PRIVATE case or ADMIN)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "participantUid": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "participants": [
      {
        "uid": "string",
        "role": "PARTICIPANT",
        "addedAt": "ISO 8601 timestamp",
        "addedBy": "string",
        "displayName": "string | null",
        "email": "string | null"
      }
    ]
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId, caseId, or participantUid
- `NOT_AUTHORIZED` (403): User not org member, or not case creator/ADMIN for PRIVATE case
- `NOT_FOUND` (404): Case not found or soft-deleted, or not PRIVATE
- `NOT_FOUND` (404): participantUid is not an org member
- `INTERNAL_ERROR` (500): Firestore write failure

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId, caseId, participantUid (required, non-empty)
3. Check entitlement: CASES feature + `case.update` permission
4. Load case: must exist, not soft-deleted, visibility === 'PRIVATE'
5. Verify caller is case creator or org ADMIN; otherwise NOT_AUTHORIZED
6. Verify participantUid is org member (`organizations/{orgId}/members/{participantUid}`)
7. Idempotently set `organizations/{orgId}/cases/{caseId}/participants/{participantUid}` (uid, role PARTICIPANT, addedAt, addedBy)
8. Create audit event: `case.participant_added`, metadata { caseId, participantUid }
9. Return success (e.g. updated participant list)

---

### 7.2 `caseRemoveParticipant` (Callable Function)

**Function Name (Export):** `caseRemoveParticipant`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.update` (creator of PRIVATE case only; cannot remove self)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "participantUid": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": { "removed": true }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId, caseId, or participantUid
- `VALIDATION_ERROR` (400): participantUid === createdBy (creator cannot remove self)
- `NOT_AUTHORIZED` (403): User not case creator for this PRIVATE case
- `NOT_FOUND` (404): Case not found or not PRIVATE
- `INTERNAL_ERROR` (500): Firestore delete failure

**Implementation Flow:**
1. Validate auth token
2. Validate orgId, caseId, participantUid (required)
3. Check entitlement: CASES + `case.update`
4. Load case: must exist, PRIVATE, caller must be createdBy (creator)
5. If participantUid === createdBy, return VALIDATION_ERROR (prevent self-lockout)
6. Delete `organizations/{orgId}/cases/{caseId}/participants/{participantUid}` if exists (idempotent)
7. Create audit event: `case.participant_removed`
8. Return success

---

### 7.3 `caseListParticipants` (Callable Function)

**Function Name (Export):** `caseListParticipants`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.read`; caller must be able to read the case (creator or participant for PRIVATE)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "participants": [
      {
        "uid": "string",
        "role": "PARTICIPANT",
        "addedAt": "ISO 8601 timestamp",
        "addedBy": "string",
        "displayName": "string | null",
        "email": "string | null"
      }
    ]
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or caseId
- `NOT_AUTHORIZED` (403): User cannot read this case (e.g. PRIVATE and not creator/participant)
- `NOT_FOUND` (404): Case not found or soft-deleted
- `INTERNAL_ERROR` (500): Firestore read failure

**Implementation Flow:**
1. Validate auth token
2. Validate orgId, caseId (required)
3. Check entitlement: CASES + `case.read`
4. Verify case access via `canUserAccessCase(orgId, caseId, uid)` (for PRIVATE: creator or participant)
5. Query `organizations/{orgId}/cases/{caseId}/participants`; resolve displayName/email from members or Auth
6. Return participants array

---

### 7.4 Case Access Helper

Created `functions/src/utils/case-access.ts` with `canUserAccessCase` helper:

- When evaluating access for PRIVATE cases:
  - Allow if `uid === createdBy`.
  - Otherwise, check if `participants/{uid}` exists.

This helper is used in:

- `caseGet`, `caseList` (when filtering PRIVATE cases),
- `documentGet` / `documentList` (for documents linked to PRIVATE cases),
- `taskList` / `taskGet` (for tasks linked to PRIVATE cases),
- Any new function that needs case access decisions.

### 7.5 Task-Level Visibility Implementation

In `functions/src/functions/task.ts`:

- `taskCreate`: Accepts `restrictedToAssignee` (defaults to `false`), stores it.
- `taskGet`: Enforces visibility based on `restrictedToAssignee`.
- `taskList`: Filters tasks based on `restrictedToAssignee` for non-admin users.
- `taskUpdate`: Accepts `restrictedToAssignee` for updates.
- `taskDelete`: Made idempotent (returns success even if task already deleted).

---

## 8) Firestore Rules & Indexes

### 8.1 Security Rules – Case Participants

Update `firestore.rules` under the `organizations/{orgId}` namespace:

```firestore
match /organizations/{orgId}/cases/{caseId}/participants/{uid} {
  // All writes go through callable functions (Admin SDK); deny direct client writes.
  allow create, update, delete: if false;

  // Reads: allowed to logged-in org members who can already read the case.
  allow read: if isOrgMember(orgId) && canReadCase(orgId, caseId);
}
```

### 8.2 Indexes

Added collection group index for `participants.uid` in `firestore.indexes.json`:

```json
{
  "collectionGroup": "participants",
  "fieldPath": "uid",
  "indexes": [
    {
      "order": "ASCENDING",
      "queryScope": "COLLECTION_GROUP"
    }
  ]
}
```

This enables the `caseList` function to query across all `participants` subcollections to find cases the user has been added to.

---

## 7) Frontend Changes

### 7.1 Case Model

No schema change required in `CaseModel` – participants live in a subcollection and are fetched separately.

### 7.2 New Frontend Service: CaseParticipantsService

Added `legal_ai_app/lib/core/services/case_participants_service.dart`:

```dart
Future<List<CaseParticipantModel>> listParticipants({
  required OrgModel org,
  required String caseId,
});

Future<void> addParticipant({
  required OrgModel org,
  required String caseId,
  required String participantUid,
});

Future<void> removeParticipant({
  required OrgModel org,
  required String caseId,
  required String participantUid,
});
```

### 7.3 Participant Model

`legal_ai_app/lib/core/models/case_participant_model.dart`:

```dart
class CaseParticipantModel {
  final String uid;
  final String? displayName;
  final String? email;
  final String role; // "PARTICIPANT" for now
  final DateTime addedAt;
  final String addedBy;

  // fromJson / toJson helpers
}
```

### 7.4 Task Model Updates

`legal_ai_app/lib/core/models/task_model.dart`:

- Added `final bool restrictedToAssignee;` field (default `false`).
- Updated `fromJson` and `toJson` methods.

### 7.5 CaseDetailsScreen – People / Access Section

Added a **"People with access"** section:

- **ORG_WIDE Cases:** Shows "All members of this organization can see this case."
- **PRIVATE Cases (Creator/Admin View):**
  - Shows creator as "You (Owner)"
  - Lists current participants with remove buttons
  - "Add person" control with member dropdown
- **PRIVATE Cases (Participant View):**
  - Read-only list of creator + participants
  - No add/remove controls

### 7.6 Task Screens – Visibility Toggle

Both `TaskCreateScreen` and `TaskDetailsScreen` now include:

- A `SwitchListTile` for "Visible only to assignee and admins"
- Toggle state is passed to backend on create/update
- Proper initialization and reset on edit cancel

### 7.7 Task Assignee Dropdown Behavior

When a PRIVATE case is linked:
- Assignee list is filtered to only show case creator + participants
- Backend enforces this rule as well

---

## 8) Error Handling

### 8.1 Error Codes (Backend)

In `functions/src/constants/errors.ts`:

- `CASE_PARTICIPANT_NOT_ALLOWED` – caller not allowed to manage participants.
- `CASE_PARTICIPANT_INVALID` – participantUid is not an org member.
- `CASE_VISIBILITY_REQUIRED` – attempt to add participants to a non-PRIVATE case.
- `CASE_PARTICIPANT_SELF_REMOVE_FORBIDDEN` – creator trying to remove themselves.

---

## 9) Implementation Order

1. ✅ **Backend – Core Access Helper**
   - Created `functions/src/utils/case-access.ts` with `canUserAccessCase` helper.
   - Extended case/document/task functions to use the shared helper.

2. ✅ **Backend – Participants Functions**
   - Implemented `caseAddParticipant`, `caseRemoveParticipant`, `caseListParticipants` in `functions/src/functions/case-participants.ts`.
   - Added new error codes and audit events.
   - Updated `index.ts` exports.
   - Added Firestore index for `participants` collection group queries.

3. ✅ **Frontend – Models & Service**
   - Added `CaseParticipantModel` in `legal_ai_app/lib/core/models/case_participant_model.dart`.
   - Added `CaseParticipantsService` in `legal_ai_app/lib/core/services/case_participants_service.dart`.

4. ✅ **Frontend – CaseDetails People Section**
   - Added participants section to `CaseDetailsScreen`.
   - Wired up list, add, remove flows with proper permission controls.

5. ✅ **Frontend – Task Assignee Filtering for PRIVATE Cases**
   - Updated task create/details screens to restrict assignee options when a PRIVATE case is linked.

6. ✅ **Frontend/Backend – Task-Level Visibility Flag**
   - Added `restrictedToAssignee` field to `TaskModel` and backend.
   - Added toggle switch in task create and edit screens.
   - Backend enforces visibility rules for both PRIVATE and ORG_WIDE cases.

7. ✅ **Testing & Polish**
   - Tested PRIVATE case flows end-to-end.
   - Verified task visibility controls work for both case types.
   - Fixed idempotent task deletion and layout issues.

---

## 10) Testing Checklist (MVP)

### 10.1 Backend

- [x] `caseAddParticipant` fails if:
  - [x] Case not found / deleted.
  - [x] Case not PRIVATE.
  - [x] Caller is not creator (or ADMIN).
  - [x] `participantUid` not an org member.
- [x] `caseRemoveParticipant`:
  - [x] Caller not creator → NOT_AUTHORIZED.
  - [x] Creator cannot remove themselves.
  - [x] Removing non-existing participant is idempotent (no error).
- [x] `caseListParticipants`:
  - [x] Creator can list.
  - [x] Participant can list.
  - [x] Non-participant cannot list (NOT_AUTHORIZED).
- [x] Case access:
  - [x] PRIVATE case visible to creator + participants only.
  - [x] Tasks/documents for PRIVATE case only visible to creator + participants.
- [x] Task-level visibility (`restrictedToAssignee`):
  - [x] When `true`, task only visible to admin, assignee, or case creator (if unassigned).
  - [x] Works for both PRIVATE and ORG_WIDE cases.

### 10.2 Frontend

- [x] CaseDetails:
  - [x] ORG_WIDE case shows "All org members have access" message, no participant controls.
  - [x] PRIVATE case creator sees participants list + add/remove controls.
  - [x] PRIVATE case participant sees read-only list, no controls.
  - [x] ADMINs can also manage participants for PRIVATE cases.
- [x] Adding participant:
  - [x] New user appears in list.
  - [x] That user can now see the PRIVATE case.
  - [x] That user can now see linked tasks/documents.
- [x] Removing participant:
  - [x] Removed user can no longer see the PRIVATE case or its tasks/documents.
- [x] Task assignee dropdown:
  - [x] For PRIVATE case, shows only creator + participants.
  - [x] For ORG_WIDE case / no case, shows all org members as before.
- [x] Task visibility toggle:
  - [x] Toggle present in task create screen.
  - [x] Toggle present in task edit/details screen.
  - [x] Toggle state persists correctly.

---

## 11) Files Created / Modified

### Backend

- `functions/src/utils/case-access.ts` ✅ (new)
  - Created `canUserAccessCase` helper for centralized case access logic.
- `functions/src/functions/case-participants.ts` ✅ (new)
  - Implemented `caseAddParticipant`, `caseRemoveParticipant`, `caseListParticipants`.
- `functions/src/functions/case.ts` ✅
  - Extended `caseGet` and `caseList` to use case access helper.
- `functions/src/functions/task.ts` ✅
  - Added `restrictedToAssignee` field and visibility filtering.
  - Made `taskDelete` idempotent.
- `functions/src/index.ts` ✅
  - Exported new case participant functions.
- `functions/src/constants/errors.ts` ✅
  - Added case participant-related error codes.
- `firestore.indexes.json` ✅
  - Added collection group index for `participants.uid`.

### Frontend

- `legal_ai_app/lib/core/models/case_participant_model.dart` ✅ (new)
- `legal_ai_app/lib/core/services/case_participants_service.dart` ✅ (new)
- `legal_ai_app/lib/core/models/task_model.dart` ✅
  - Added `restrictedToAssignee` field.
- `legal_ai_app/lib/core/services/task_service.dart` ✅
  - Updated to pass `restrictedToAssignee` flag.
- `legal_ai_app/lib/features/cases/screens/case_details_screen.dart` ✅
  - Added participants section with add/remove controls.
- `legal_ai_app/lib/features/tasks/screens/task_create_screen.dart` ✅
  - Added assignee filtering for PRIVATE cases.
  - Added task visibility toggle.
- `legal_ai_app/lib/features/tasks/screens/task_details_screen.dart` ✅
  - Added assignee filtering for PRIVATE cases.
  - Added task visibility toggle.
- `legal_ai_app/lib/features/tasks/providers/task_provider.dart` ✅
  - Updated to handle `restrictedToAssignee` flag.
- `legal_ai_app/lib/features/common/widgets/buttons/primary_button.dart` ✅
  - Fixed layout constraint issues.

---

## 12) Deployment Notes

- **Backend deployed:** January 24, 2026
- **Firestore index deployed:** Collection group index on `participants.uid`
- **No migration required:** New fields (`restrictedToAssignee`) default to `false`

---

**End of Slice 5.5 Build Card – Case Participants & Private Case Sharing**
