# LEGAL AI APP - MASTER SPECIFICATION (SOURCE OF TRUTH)
Version: 1.3.1
Owner: Taimur (Product Owner)
Last Updated: 2026-01-16
Status: Active Master Spec (All builds must follow this document)

---

## 0) Purpose of this Document
This is the single, comprehensive Master Specification Document for the Legal AI Application.

It exists to:
- Prevent context loss across chats, tools, and team members
- Keep Cursor outputs consistent across time
- Align work across flowcharts, backend, frontend, security, and release planning
- Define the full roadmap as vertical slices from MVP-0 to production launch

This document is the top-level "constitution".
Slice Build Cards can be created later for execution detail, but this file is the authoritative reference.

---

## 1) Product Summary

### 1.1 What the app is
A world-class Legal AI Application for lawyers and legal teams to:
- Manage cases, clients, and documents
- Extract text from documents (OCR/parse)
- Run AI legal research and drafting with citations
- Store AI outputs back into the case record
- Collaborate, assign tasks, and track activity
- Upgrade plans to unlock features and capacity

### 1.2 Core design philosophy
Backend-first, legally safe, audit-friendly, scalable.

### 1.3 Target users
- Solo lawyers (Free, paid tiers)
- Small law firms (team roles and tasks)
- Larger firms (audit trail, admin controls, billing tiers)

---

## 2) Non-Negotiable Principles (World-Class Rules)

### 2.1 Development approach
- Build one vertical slice at a time
- Each slice must deliver an end-to-end working outcome: UI -> backend -> DB -> output -> saved result
- Avoid module-by-module development that causes integration chaos

### 2.2 UI rules
- UI stays thin
- No business logic in Flutter
- UI is a view layer only
- All permissions and feature gating must be enforced in backend, not only hidden in UI

### 2.3 Backend rules
- Backend is the single source of truth
- Every object is owned by an Organization
- All reads and writes must be scoped to orgId
- Auditability and traceability are first-class concerns

### 2.4 Consistency rules (Cursor must follow)
- One design system (theme, spacing, typography) for all screens
- Reusable widgets only
- Consistent folder structure
- Consistent naming conventions
- Shared data models across app

### 2.5 Security rules
- Never trust the client (Flutter)
- Firestore rules must enforce access boundaries
- Cloud Functions must enforce role permissions and plan entitlements
- Storage access must be scoped to org membership and permissions

### 2.6 Legal & Compliance Requirements
Legal applications handle sensitive data. These requirements are non-negotiable.

**Data Protection:**
- All data encrypted at rest (Firestore, Storage)
- All data encrypted in transit (TLS 1.2+)
- No sensitive data in logs (sanitize PII, case numbers, client names)
- Secure key management (use Firebase/Cloud KMS, never hardcode)

**Data Retention:**
- Cases and documents: Retain per org policy (default: 7 years, configurable)
- Audit logs: Retain minimum 7 years (legal requirement)
- Soft delete: All deletions are soft (deletedAt timestamp) for recovery
- Soft-deleted data is retained for 30 days. After 30 days, admin can trigger hard delete. Data is not permanently removed until hard delete.
- Hard delete: Only after retention period + explicit admin action

**Data Deletion (Right to be Forgotten):**
- Users can request data deletion
- Admin can delete org data (requires confirmation)
- Deletion must cascade: org → cases → documents → related data
- Audit log must record who deleted what and when
- Legal hold: Cases under legal hold cannot be deleted (future feature)

**Data Export:**
- Users can export their case data (JSON/PDF)
- Export includes: cases, documents metadata, AI outputs, audit trail
- Export must be available within 30 days of request

**Jurisdiction & Data Residency:**
- Document where data is stored (region/country)
- Consider GDPR if EU users
- Consider jurisdiction-specific requirements per org location

**Legal Disclaimers:**
- AI outputs must include disclaimer: "AI-generated content. Review before use."
- Citations must be verifiable
- No legal advice claims in UI or marketing

**Compliance Notes:**
- MVP: Basic encryption and retention
- Post-MVP: GDPR compliance, legal hold, advanced export

---

## 3) System Architecture (High Level)

### 3.1 Frontend
- Flutter application
- Uses standard navigation and a consistent AppShell layout
- Calls backend via Cloud Functions endpoints (REST or callable)

### 3.2 Backend
- Firebase Authentication
- Firestore (primary data store)
- Cloud Storage (documents)
- Cloud Functions (API + processing + AI requests)
- Optional: Pub/Sub / task queue for heavy jobs (OCR, chunking)

### 3.3 AI Layer
- LLM provider (OpenAI recommended for initial build)
- Embeddings for retrieval
- Retrieval returns chunks with citations
- Outputs are stored into Firestore as structured drafts/notes/messages

### 3.4 Eventing
- Background processing is job-based
- Job records stored in Firestore
- UI subscribes to job status updates (loading -> completed -> failed)

---

## 4) Identity, Organization, Plans, Roles (Entitlements Engine)
This is the foundation that controls what users can see and do.

### 4.1 Two separate control systems
1) Subscription Plan Tier (Free + paid tiers)
- Controls what the organization is allowed to use

2) Role-Based Permissions
- Controls what a user can do inside the organization

Key rule:
- Plan decides what features exist
- Role decides who can use them

### 4.2 Organization model
Each user belongs to an organization (orgId).
All cases, clients, docs, tasks, outputs, usage counts belong to orgId.

### 4.3 Plan tiers (initial)
Plan tiers can be adjusted later, but must exist from Slice-0.

Example plan names:
- FREE
- BASIC
- PRO
- ENTERPRISE

Plan entitlements examples:
- maxCases
- maxDocuments
- storageLimitMB
- maxTeamMembers
- AIRequestsPerMonth
- enableOCR
- enableDrafting
- enableAuditTrail
- enableExports
- enableAdvancedSearch
- enableBilling

### 4.4 Roles (initial)
Roles can be expanded but must start simple.

Minimum roles:
- ADMIN
- LAWYER
- PARALEGAL
- VIEWER

Role permission examples:
- case.create
- case.read
- case.update
- case.close
- doc.upload
- doc.delete
- ai.ask
- ai.draft
- task.create
- task.assign
- billing.manage
- admin.manage_users
- admin.manage_plan

### 4.5 Entitlements evaluation rules
The backend must enforce:

User is allowed if:
- org membership is valid AND
- plan allows the feature AND
- role allows the action AND
- object belongs to orgId AND
- object-level access rules pass (if applicable)

Example: User tries to "Ask AI Question" inside a case.

Checks:
1) Is user a member of the org? ✅
2) Does the plan include "AI Research"?
   - If NO -> return PLAN_LIMIT (UI shows upgrade prompt)
   - If YES -> continue
3) Does the user's role have permission "ai.ask"?
   - If NO -> return NOT_AUTHORIZED (UI hides/disabled or shows not authorized)
   - If YES -> continue
4) Does the case belong to this org?
  - If NO -> return NOT_AUTHORIZED
  - If YES -> continue
5) Is the user authorized to access this specific case? (See subsection 4.9 for case visibility rules)
  - If NO -> return NOT_AUTHORIZED
  - If YES -> allow request

### 4.6 Feature gating behavior
Two types of denial:
1) Plan blocks feature:
- UI shows locked feature with upgrade prompt
- Backend returns: "PLAN_LIMIT" or "UPGRADE_REQUIRED"

2) Role blocks feature:
- UI hides or disables feature OR shows "Not authorized"
- Backend returns: "NOT_AUTHORIZED"

### 4.7 Entitlements Matrix (Plan vs Features)
This matrix defines which capabilities are enabled by plan.
These values are enforced in backend, and reflected in UI via FeatureGateOverlay.

Legend:
- ✅ = enabled
- ❌ = disabled/locked

| Feature Key | FREE | BASIC | PRO | ENTERPRISE | Notes |
|------------|------|-------|-----|------------|------|
| CASES | ✅ | ✅ | ✅ | ✅ | Hard limits differ by plan (maxCases) |
| CLIENTS | ✅ | ✅ | ✅ | ✅ | Usually unlimited, can cap if needed |
| TEAM_MEMBERS | ❌ | ✅ | ✅ | ✅ | Free typically solo only |
| TASKS | ❌ | ✅ | ✅ | ✅ | Tasks are a paid productivity feature |
| DOCUMENT_UPLOAD | ✅ | ✅ | ✅ | ✅ | Limits differ by storage quota |
| OCR_EXTRACTION | ❌ | ✅ | ✅ | ✅ | OCR can be expensive |
| AI_RESEARCH | ❌ | ✅ | ✅ | ✅ | AI Q/A with citations |
| AI_DRAFTING | ❌ | ❌ | ✅ | ✅ | Drafting reserved for higher tiers |
| EXPORTS | ❌ | ✅ | ✅ | ✅ | PDF/DOC export gating |
| AUDIT_TRAIL | ❌ | ❌ | ✅ | ✅ | Compliance feature |
| NOTIFICATIONS | ❌ | ✅ | ✅ | ✅ | In-app notifications |
| ADVANCED_SEARCH | ❌ | ❌ | ✅ | ✅ | Full-text / filters / saved views |
| BILLING_SUBSCRIPTION | ✅ | ✅ | ✅ | ✅ | Always present for upgrades |
| ADMIN_PANEL | ❌ | ✅ | ✅ | ✅ | Org controls and usage |

### 4.8 Permissions Matrix (Role vs Actions)
This matrix defines what each role can do inside an organization.
All permissions are enforced in backend. UI only reflects them.

Legend:
- ✅ allowed
- ❌ not allowed

| Permission | ADMIN | LAWYER | PARALEGAL | VIEWER | Notes |
|-----------|:-----:|:------:|:---------:|:------:|------|
| case.create | ✅ | ✅ | ❌ | ❌ | Lawyers create cases, paralegals typically cannot |
| case.read | ✅ | ✅ | ✅ | ✅ | Everyone can read org content (scoped to their org) |
| case.update | ✅ | ✅ | ✅ | ❌ | Viewer is read-only |
| case.close | ✅ | ✅ | ❌ | ❌ | Closing is privileged |
| client.create | ✅ | ✅ | ✅ | ❌ | Viewer cannot create |
| client.update | ✅ | ✅ | ✅ | ❌ | Viewer cannot edit |
| doc.metadata.view | ✅ | ✅ | ✅ | ✅ | Can see document list + basic details |
| doc.content.view | ✅ | ✅ | ✅ | ✅ | Can open/read/download document content |
| doc.upload | ✅ | ✅ | ✅ | ❌ | Viewer cannot upload |
| doc.delete | ✅ | ✅ | ❌ | ❌ | Deletion is dangerous |
| ai.metadata.view | ✅ | ✅ | ✅ | ✅ | Can see AI threads exist |
| ai.results.view | ✅ | ✅ | ✅ | ✅ | Can read AI answers + citations |
| ai.ask | ✅ | ✅ | ✅ | ❌ | Generates cost + needs control |
| ai.draft | ✅ | ✅ | ✅ | ❌ | Plan gating also applies |
| task.create | ✅ | ✅ | ✅ | ❌ | Viewer cannot create tasks |
| task.assign | ✅ | ✅ | ✅ | ❌ | Assignments allowed to non-viewers |
| task.complete | ✅ | ✅ | ✅ | ❌ | Viewer cannot mark complete |
| audit.view | ✅ | ✅ | ✅ | ✅ | Viewing audit trail is typically safe |
| admin.manage_users | ✅ | ❌ | ❌ | ❌ | Only Admin |
| admin.manage_plan | ✅ | ❌ | ❌ | ❌ | Only Admin |
| billing.manage | ✅ | ❌ | ❌ | ❌ | Only Admin |

Notes:
- Keep roles as presets only (Admin/Lawyer/Paralegal/Viewer).
- Do NOT add per-user micro overrides UI.
- Permissions are enforced in backend, UI only reflects.

### 4.9 Case Visibility + Access Control (ClickUp-style)
A simple, world-class case privacy system that controls who can access each case.

### 4.9.1 Visibility Modes
Each case has a visibility mode:
- **ORG_WIDE** (default): Any org member with `case.read` permission can view the case.
- **PRIVATE**: Only the case owner (`ownerUid`) + explicitly granted users + Admin can view.

This is NOT micro-permissions. This is object-level visibility control.

### 4.9.2 Required Case Fields
- `visibility`: `"ORG_WIDE" | "PRIVATE"` (required, defaults to `ORG_WIDE`)
- `ownerUid`: `string` (required, must be set at creation)

CRITICAL: `ownerUid` must always be set at creation. `visibility` defaults to `ORG_WIDE`.

### 4.9.3 Firestore Structure
Private case access is managed via:
```
organizations/{orgId}/cases/{caseId}/access/{uid}
```

This access document means: `uid` can access this private case.

Suggested access document fields:
- `addedAt`: timestamp
- `addedBy`: uid of the user who granted access

### 4.9.4 Backend Enforcement Rule (MANDATORY)
All endpoints that use `caseId` must enforce case visibility:

**If `visibility == ORG_WIDE`:**
- Allow based on org membership + role permission (`case.read`)

**If `visibility == PRIVATE`:**
- Allow only if:
  - `uid == ownerUid` OR
  - `access/{uid}` exists OR
  - `role == ADMIN`
- If denied: return `NOT_AUTHORIZED`

**Important:** Having `case.read` permission is necessary but not sufficient for PRIVATE cases. Users must also be owner, access-granted, or ADMIN.

**Cascade Rule:** Any entity linked to `caseId` inherits case visibility (documents, tasks, AI threads/messages, drafts, audit events). This prevents "doc can be accessed even when case is private" mistakes.

**MVP rule:** `ownerUid` is immutable after creation.

**Future:** If ownership transfer is introduced, access rules must be re-evaluated.

### 4.9.5 Access Management
Only **ADMIN** or case `ownerUid` can add/remove access members.

**Edge case:** If `ownerUid` leaves the org, they lose access immediately. Admin can still access/manage the case. Future: allow reassignment of ownership.

### 4.9.6 UI Requirements
- **Case Create screen**: Has a toggle "Private Case"
  - Default is OFF (`ORG_WIDE`)
  - If ON → create `PRIVATE` case and `ownerUid = creator`
- **Case Details screen**: Shows "Manage Access" button only for owner/admin
- **Case List**: Must only show cases user can access (backend filters)

---

## 5) Data Model (Core Entities)
This model must be consistent and stable early.

### 5.1 Core entities list
- Organization
- User (membership within org)
- Case
- Client
- Document
- DocumentVersion (optional later)
- DocumentChunk
- Task
- AIThread (or AIConversation)
- AIMessage
- AIDraft
- AuditEvent
- Notification
- Subscription
- UsageCounter
- Job (processing tasks like OCR, chunking)

### 5.2 Key fields required in all major entities
Common fields:
- id
- orgId
- createdAt
- updatedAt
- createdBy (uid)
- updatedBy (uid)
- deletedAt (optional soft delete)
- status (where relevant)

CRITICAL: Every document must have orgId.
This is not optional. Firestore queries and security rules depend on it.
If a document has no orgId, it is a data integrity bug.

### 5.2.1 Case Entity Fields
Case entity must include:
- `ownerUid`: string (required, must be set at creation)
- `visibility`: "ORG_WIDE" | "PRIVATE" (required, defaults to "ORG_WIDE")

CRITICAL: `ownerUid` must always be set at creation.

**Backend enforcement:** The `cases.create` endpoint must enforce the visibility default. If `visibility` is not provided, the backend must set it to `ORG_WIDE`. This prevents data integrity issues and ensures consistent behavior.

### 5.3 Ownership rules
- Everything is scoped to orgId
- A case is the container hub for most work
- Documents attach to cases (and optionally clients)
- Tasks attach to cases (and optionally documents)
- AI outputs attach to cases (and optionally documents)

---

## 6) Firestore Collections (Recommended)
This structure supports scaling and access control.

- organizations/{orgId}
- organizations/{orgId}/members/{uid}
- organizations/{orgId}/cases/{caseId}
- organizations/{orgId}/cases/{caseId}/access/{uid}
- organizations/{orgId}/clients/{clientId}
- organizations/{orgId}/documents/{docId}
- organizations/{orgId}/documents/{docId}/chunks/{chunkId}
- organizations/{orgId}/tasks/{taskId}
- organizations/{orgId}/ai_threads/{threadId}
- organizations/{orgId}/ai_threads/{threadId}/messages/{messageId}
- organizations/{orgId}/drafts/{draftId}
- organizations/{orgId}/audit_events/{eventId}
- organizations/{orgId}/notifications/{notificationId}
- organizations/{orgId}/subscriptions/{subscriptionId}
- organizations/{orgId}/usage/{usageDocId}
- organizations/{orgId}/jobs/{jobId}

MVP approach:
- Chunks are stored as sub-collections of documents:
  organizations/{orgId}/documents/{docId}/chunks/{chunkId}
- This keeps ownership clear and is simplest for permissions and maintenance.

Alternative optimization (later, only if required):
- Keep chunks in a separate top-level collection for indexing/query performance
- Store chunk pointers (docId, caseId, orgId) in each chunk document

---

## 7) Storage Structure (Cloud Storage)
Documents must not be stored in Firestore.

Bucket structure:
- orgs/{orgId}/cases/{caseId}/docs/{docId}/original/{filename}
- orgs/{orgId}/cases/{caseId}/docs/{docId}/derived/{variant}

Examples:
- extracted_text.json
- thumbnails/
- page_images/

Access:
- Storage must be secured by Firebase security rules
- Prefer backend-signed download URLs where needed

---

## 8) API Layer (Cloud Functions)
All sensitive operations must go through Cloud Functions for control and auditability.

### 8.1 API style
Either:
- Callable functions (Firebase callable)
OR
- REST endpoints using Express

Preferred for structure:
- REST-style endpoints for clarity

### 8.2 Core endpoint categories
Auth / Org:
- org.create
- org.join
- org.invite
- member.setRole

Cases:
- cases.create
- cases.list
- cases.get
- cases.update
- cases.close

Clients:
- clients.create
- clients.list
- clients.get
- clients.update
- clients.linkToCase

Documents:
- documents.createUploadSession (returns signed upload info)
- documents.finalizeUpload
- documents.listByCase
- documents.get
- documents.delete

Processing:
- jobs.startExtraction
- jobs.getStatus

AI:
- ai.ask (research Q/A with citations)
- ai.draft (drafting templates)
- ai.thread.list
- ai.thread.get

Tasks:
- tasks.create
- tasks.list
- tasks.assign
- tasks.update
- tasks.complete

Audit:
- audit.listByCase

Billing:
- billing.getPlan
- billing.upgrade
- billing.usageSummary

Notifications:
- notifications.list
- notifications.markRead

### 8.3 Error Response Format (Mandatory)
All endpoints must return responses in a consistent wrapper.

**Success responses:**
```json
{
  "success": true,
  "data": { }
}
```

**Error responses:**
```json
{
  "success": false,
  "error": {
    "code": "NOT_AUTHORIZED | PLAN_LIMIT | VALIDATION_ERROR | NOT_FOUND | INTERNAL_ERROR | RATE_LIMITED",
    "message": "User-friendly message",
    "details": { }
  }
}
```

## 9) Audit Trail (Legal Grade)
Every critical action must create an audit event:

case created/updated/closed

document uploaded/extracted/deleted

AI answer generated

draft saved/exported

role changed

team invited

subscription changed

Audit event fields:

orgId

actorUid

actionType

objectType

objectId

timestamp

metadata (minimal, safe)

10) Search, Sorting, Filtering (MVP vs Later)
10.1 MVP-level list controls
Must exist in MVP:

Cases: search by title, sort by newest, filter by status

Documents: search by name, sort by newest

Tasks: filter by assignee, due date sorting, status filter

10.2 Phase-2 advanced
Later features:

grouping by client or case type

saved filters

full-text search across chunk content

multi-condition query builder

11) UI System (Flutter Design Standard)
This standard prevents UI inconsistency as the app grows.

11.1 Folder structure (minimum)
lib/
main.dart
app_shell.dart (main navigation container)
theme/
app_theme.dart
spacing.dart
radius.dart
typography.dart
widgets/
app_button.dart
app_text_field.dart
app_card.dart
status_badge.dart
feature_gate_overlay.dart
empty_state.dart
loading_state.dart
error_state.dart
screens/
auth/
login_screen.dart
signup_screen.dart
dashboard/
dashboard_screen.dart
cases/
case_list_screen.dart
case_details_screen.dart
case_create_screen.dart
clients/
client_list_screen.dart
client_details_screen.dart
documents/
document_list_screen.dart
document_view_screen.dart
document_upload_screen.dart
tasks/
task_list_screen.dart
task_create_screen.dart
ai/
ai_chat_screen.dart
ai_sources_screen.dart
ai_draft_screen.dart
admin/
team_screen.dart
role_management_screen.dart
plan_screen.dart
settings/
settings_screen.dart
services/
api_service.dart
auth_service.dart
entitlement_service.dart
case_service.dart
client_service.dart
document_service.dart
task_service.dart
ai_service.dart
models/
org_model.dart
member_model.dart
case_model.dart
client_model.dart
document_model.dart
task_model.dart
ai_models.dart

11.2 Core reusable components required
Minimum components:

AppButton

AppTextField

AppCard

StatusBadge

FeatureGateOverlay (FeatureLockedWidget)
Purpose: Shows feature locked by plan or role
Behavior:

If plan blocks: shows upgrade CTA

If role blocks: shows not authorized message or disables action

AppScaffold (optional wrapper for consistent padding/top bar)

LoadingState, EmptyState, ErrorState

11.3 UI gating component
Create a widget or helper:

FeatureGate(featureKey)
Behavior:

if plan blocks: show FeatureGateOverlay with upgrade CTA

if role blocks: hide/disable OR show FeatureGateOverlay (not authorized)
Note: Backend is still the final enforcer.

### 11.4 Onboarding & User Experience
**First-Time User Onboarding:**
- Welcome screen after signup
- Quick tour of key features (optional, dismissible)
- Create first case prompt
- Link to help/documentation

**Empty States:**
- Case list empty: "Create your first case to get started"
- Document list empty: "Upload documents to analyze with AI"
- Task list empty: "No tasks yet. Create one to stay organized."

**Help & Documentation:**
- Help button in app (links to docs)
- Tooltips for key features (optional)
- FAQ section (future)
- Support contact: support@yourapp.com

**Accessibility:**
- Support screen readers (Flutter accessibility)
- Keyboard navigation (web)
- High contrast mode (future)
- Font size scaling

---

## 12) Error Handling Standard

### 12.1 Error Codes (Complete List)
All APIs must return structured errors with codes:

- `NOT_AUTHORIZED` - User lacks permission
- `ORG_REQUIRED` - User must belong to an org
- `PLAN_LIMIT` - Plan doesn't allow this feature
- `VALIDATION_ERROR` - Input validation failed
- `NOT_FOUND` - Resource doesn't exist
- `INTERNAL_ERROR` - Server error (don't expose details)
- `RATE_LIMITED` - Too many requests
- `SERVICE_UNAVAILABLE` - External service (AI, OCR) is down
- `QUOTA_EXCEEDED` - Storage or usage quota exceeded
- `CONFLICT` - Resource conflict (e.g., concurrent edit)

### 12.2 Edge Cases & Error Scenarios

**AI Service Down:**
- If AI provider is unavailable: Return `SERVICE_UNAVAILABLE`
- Show user-friendly message: "AI service is temporarily unavailable. Please try again later."
- Log error for monitoring
- Don't retry automatically (user can retry)

**OCR Failure:**
- If OCR fails: Mark document with `extractionStatus: "failed"`
- Show error in UI: "Text extraction failed. You can still upload the document."
- Allow manual text entry (future)
- Log failure for admin review

**Storage Quota Exceeded:**
- If org exceeds storage quota: Return `QUOTA_EXCEEDED` on upload
- Show upgrade prompt in UI
- Prevent new uploads until quota increased
- Allow deletion to free up space

**Org Deletion:**
- If org is deleted: All members lose access immediately
- All cases become inaccessible
- Admin can restore org within 30 days (soft delete)
- After 30 days: Hard delete (irreversible)

**Concurrent Edits:**
- If two users edit same case simultaneously: Last write wins (MVP)
- Future: Conflict detection and merge resolution
- Log concurrent edit attempts in audit trail

**Case Access Revoked:**
- If user's access to private case is revoked: Return `NOT_AUTHORIZED` on next request
- Remove case from user's case list immediately
- Show generic error (don't reveal case exists)

**Invalid File Type:**
- If unsupported file type uploaded: Return `VALIDATION_ERROR`
- Show clear message: "File type not supported. Supported types: PDF, DOC, DOCX, TXT, PNG, JPG."
- Reject before upload starts (client-side validation)

**Network Timeout:**
- If request times out: Show retry option
- Don't show technical error details
- Log timeout for monitoring

### 12.3 UI Error Display
UI must display:
- Friendly, user-friendly message (never technical stack traces)
- Retry option when applicable (network errors, timeouts)
- Upgrade prompt for PLAN_LIMIT errors
- Clear action items (what user should do next)
- Never reveal internal error details or stack traces

13) Observability and Monitoring
Must exist before production:

structured logs per request

job status tracking

failure alerts (minimal)

admin usage visibility

14) Testing Strategy (World-Class Minimal)
14.1 Must-have tests
Auth + membership checks

Entitlements checks (plan + role)

Case create/list/get

Document upload finalize

AI ask endpoint returns citations format

Firestore rules tests (basic)

14.2 Release checklist
staging deployment

smoke test core flows

permissions test matrix validation

billing plan gating verified

logging verified

14.3 Critical path tests (must pass before any slice ships)
For every slice, test:

Happy path (feature works as intended)

Entitlements path (plan blocks, role blocks, both allow)

Error path (network error, validation error, server error)

Audit path (critical action creates audit log)

Example for "Create Case":

Happy: User creates case, sees it in list

Plan blocks: Free plan user tries to create 11th case, gets PLAN_LIMIT

Role blocks: Viewer role tries to create case, gets NOT_AUTHORIZED

Error: Network fails, user sees retry option

Audit: Case creation creates audit event with correct metadata

15) Vertical Slice Roadmap (MVP-0 to Production Launch)
Each slice is a self-contained deliverable with dependencies and expected effort.

Legend:

Complexity: Low, Medium, High

Est. Days: Cursor-driven dev days including basic polish and tests

#	Slice	Complexity	Depends On	Est. Days
0	Foundation: Auth + Org + Entitlements Engine	High	-	10-15
1	Navigation Shell + UI System	Medium	0	5-8
2	Case Hub (Core Container)	Medium	0-1	5-8
2.1	Case Privacy + Access List	Medium	2	4-6
3	Client Hub + Case Linking	Medium	2	4-7
4	Team Members + Role Assignment UI	Medium	0-2	5-8
5	Tasks: Assignment + Case Linking	Medium	2,4	6-10
6	Document Intake (Upload + Attach)	Medium	2,3	6-10
7	Text Extraction + Chunk Storage	High	6	8-12
8	AI Research: Answer + Citations	High	7	10-15
9	AI Drafting + Save Outputs	High	8	8-12
10	Search + Filters + Sorting (MVP-grade)	Medium	2,5,6	5-8
11	Notifications (In-App)	Low	5	3-5
12	Audit Trail + Activity Feed	Medium	2,4,6,8	5-8
13	Billing + Subscription Upgrade	High	0	8-12
14	Security Hardening + Retention	High	0-12	8-12
15	Admin Panel (Org Controls)	Medium	4,13	5-8
16	Reliability + Background Jobs	High	6-9	8-12
17	Observability (Monitoring)	Medium	0-16	4-7
18	QA + Staging + Release Checklist	Medium	0-17	5-10
19	Production Launch	Medium	18	5-8

16) Slice Specifications (Detailed)
Each slice below includes:

Goal

Scope In

Scope Out

Screens

Backend endpoints

Firestore collections involved

Definition of Done

SLICE 0: Foundation (Auth + Org + Entitlements Engine)
Goal
Ensure the app can identify who the user is, which org they belong to, and what they are allowed to do.

Scope In
Firebase Auth login/signup

Organization create/join

Membership record creation

Plan tier initial assignment (FREE)

Role assignment (ADMIN for org creator)

Entitlements checks in backend for all protected endpoints

Basic Firestore security rules

Scope Out
Team invites UI (Slice 4)

Billing upgrade UI (Slice 13)

Advanced granular permission management (later)

Screens
Login

Signup

Org create/join flow

Backend endpoints
org.create

org.join

member.getMyMembership

entitlement.check (internal helper)

Firestore collections
organizations

organizations/{orgId}/members

Definition of Done
User can signup and create org

User gets role ADMIN

User has plan FREE

Backend denies actions when orgId missing

Backend denies actions when plan blocks feature

Backend denies actions when role blocks action

Structured error responses used everywhere

SLICE 1: Navigation Shell + UI System
Goal
Create a stable Flutter UI foundation that prevents design inconsistency.

Scope In
App routes and navigation layout

AppTheme, spacing, radius, typography

Reusable widgets: button, field, card, status badge

FeatureGateOverlay

Loading/empty/error components

FeatureGate helper behavior

Scope Out
Complex animations

Full component library

Screens
AppShell scaffold

Placeholder Dashboard screen

Definition of Done
New screen can be added in <10 minutes

All screens use theme and widgets

FeatureGate works in UI for locked features

SLICE 2: Case Hub (Core Container)
Goal
Make cases the core container of the product.

Scope In
Create case

Case list

Case details

Basic status: Open/Closed

Ownership and org scoping

Scope Out
Advanced filters (Slice 10)

Collaboration comments (later)

Screens
Case list

Case detail

Create case

Backend endpoints
cases.create

cases.list

cases.get

cases.update

cases.close

Firestore collections
organizations/{orgId}/cases

Definition of Done
Case created and visible in list

Case details show correct data

Closed cases show read-only behavior for restricted actions

SLICE 2.1: Case Privacy + Access List
Goal
Implement ClickUp-style case visibility and access control.

Scope In
Case visibility toggle + ownerUid

access subcollection

Backend enforcement for case access

Manage Access UI

Scope Out
Advanced permission inheritance (later)

Screens
Case Create screen (add "Private Case" toggle)

Case Details screen (add "Manage Access" button)

Manage Access screen (list/add/remove access members)

Backend endpoints
cases.create (update to set ownerUid and visibility)

cases.list (update to filter by access)

cases.get (update to enforce visibility)

cases.updateAccess (add/remove access members)

cases.listAccess (get list of users with access)

**Planned endpoint (Post-MVP):** cases.transferOwnership (transfer case ownership to another user). Not in Slice 2.1 scope.

Firestore collections
organizations/{orgId}/cases/{caseId} (add ownerUid, visibility)

organizations/{orgId}/cases/{caseId}/access/{uid}

Definition of Done
Private case toggle works in create flow

ownerUid is set correctly at creation

Backend enforces case visibility on all endpoints

Manage Access UI allows owner/admin to grant/revoke access

Case list only shows cases user can access

SLICE 3: Client Hub + Case Linking
Goal
Add client as a first-class entity and link to cases.

Scope In
Create client

Client list

Client details

Link client to case

Show client summary in case

Scope Out
Complex CRM features (later)

Screens
Client list

Client detail

Case link selector

Firestore collections
organizations/{orgId}/clients

organizations/{orgId}/cases (client pointers)

Definition of Done
Client created and visible in list

Case can attach client

Client summary appears inside case detail

SLICE 4: Team Members + Role Assignment UI
Goal
Allow org admin to invite and manage team roles using the existing engine from Slice 0.

Scope In
Invite member

Accept invite

Assign role

Change role

Remove member (optional)

Scope Out
Advanced granular permissions UI (later)

Screens
Team management

Role assignment UI

Firestore collections
organizations/{orgId}/members

Definition of Done
Admin can add member

Role changes apply instantly

Member sees different access based on role

SLICE 5: Tasks (Assignment + Case Linking)
Goal
Tasks drive daily legal work. Link tasks to case and assign to team members.

Scope In
Create task

Assign to member

Due date, priority, status

Link task to case

My Tasks view

Scope Out
Calendar sync (later)

Gantt views (later)

Screens
Task list

Task create

Tasks inside case detail

Firestore collections
organizations/{orgId}/tasks

organizations/{orgId}/cases (task references)

Definition of Done
Task assignment works

Due tasks show correctly

Task list can filter by "My tasks"

SLICE 6: Document Intake (Upload + Attach)
Goal
Upload and attach documents to cases and clients.

Scope In
Upload file to Storage

Create document metadata record

Attach to case

Document list in case

Scope Out
Advanced viewer features

Full versioning system (later)

Screens
Document upload

Document list in case

Firestore collections
organizations/{orgId}/documents

Definition of Done
Upload works reliably

Document shows in case

Storage file access is secure

SLICE 7: Text Extraction + Chunk Storage
Goal
Extract clean text so AI can work legally and reliably.

Scope In
OCR/parse pipeline

Clean text stored

Chunking and metadata

Job status tracking

Scope Out
Advanced semantic labeling

Firestore collections
organizations/{orgId}/jobs

organizations/{orgId}/documents/{docId}/chunks/{chunkId}

Definition of Done
Extraction completes for common PDFs

Chunks created and queryable

Failure states handled gracefully

SLICE 8: AI Research (Answer + Citations)
Goal
Core AI feature: answer with citations from uploaded documents.

Scope In
Question input

Retrieval from chunks

LLM answer generation

Citation mapping

Save results in thread

Scope Out
Advanced multi-step reasoning UI (later)

Full semantic ranking engine (later)

Screens
AI Chat inside case

Sources view

Firestore collections
organizations/{orgId}/ai_threads/{threadId}/messages/{messageId}

Definition of Done
Answer produced

Citations shown and linkable

Output saved in Firestore

SLICE 9: AI Drafting + Save Outputs
Goal
Produce legal drafts and store them as structured case outputs.

Scope In
Draft templates

Generate draft

Save draft versions

Export basic

Scope Out
Collaborative editing suite (later)

Firestore collections
organizations/{orgId}/drafts

Definition of Done
Draft generated

Draft saved with version history

Export works (at least PDF or DOC)

SLICE 10: Search + Filters + Sorting (MVP-grade)
Goal
Make the system usable at scale.

Scope In
Case search + status filter

Doc search

Task filters: assignee, status, due date sort

Scope Out
Saved filters and advanced grouping

Definition of Done
Lists remain usable with 200+ records

Filters work fast and reliably

SLICE 11: Notifications (In-App)
Goal
Basic alerts for assignments and due dates.

Scope In
Notification records

In-app feed

Mark read

Scope Out
Push notifications (optional later)

Email notifications (optional later)

Definition of Done
Assignment triggers notification

Unread badge works

SLICE 12: Audit Trail + Activity Feed
Goal
Legal-grade accountability.

Scope In
Audit event creation

Activity feed per case

Role changes logged

AI generation logged

Definition of Done
Critical actions produce audit logs

Case shows activity timeline

SLICE 13: Billing + Subscription Upgrade
Goal
Plans must control limits and upgrades.

Scope In
Upgrade plan flow

Enforce AI usage limits

Enforce team limits

Enforce storage limits

Scope Out
Complex accounting and invoicing

Definition of Done
Free plan is constrained

Upgrade unlocks features immediately

Limits enforce correctly in backend

SLICE 14: Security Hardening + Retention
Goal
Production safety.

Scope In
Firestore rules tightened

Storage rules verified

Retention and archiving plan

Delete behavior defined

Definition of Done
No cross-org data leakage possible

Retention rules tested

---

## 14) Security Hardening + Retention (Detailed)

### 14.1 Firestore Security Rules (Patterns)
All Firestore rules must follow these patterns:

**Organization Scoping:**
```
// Example: Cases can only be read by org members
match /organizations/{orgId}/cases/{caseId} {
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
  allow write: if request.auth != null && 
    exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid)) &&
    // Additional role/permission checks via Cloud Functions
    false; // All sensitive writes (create, update, delete) must go through Cloud Functions for validation and audit logging. See Section 8 (API Layer) for Cloud Function patterns.
}
```

**Key Rules:**
- All writes must go through Cloud Functions (no direct client writes to sensitive collections)
- Reads can be direct but must check org membership
- Private case access must check access/{uid} subcollection
- Never allow cross-org data access

### 14.2 Storage Security Rules
Cloud Storage rules must enforce:

```
// Example: Documents only accessible by org members
match /orgs/{orgId}/{allPaths=**} {
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
  allow write: if false; // All uploads via signed URLs from Cloud Functions
}
```

**Key Rules:**
- All uploads use backend-signed URLs (time-limited)
- Downloads can be direct but require org membership check
- Never expose storage paths in client code

### 14.3 API Security
**Authentication:**
- All endpoints require valid Firebase Auth token
- Token validation in every Cloud Function
- Reject expired or invalid tokens

**Authorization:**
- Every endpoint checks: org membership + plan + role + object access
- Never trust client-provided role/plan data (lookup from database)
- Return generic errors (don't reveal existence of resources)

**Input Validation:**
- Validate all inputs (type, length, format)
- Sanitize user inputs (prevent injection attacks)
- Reject malformed requests immediately

**Rate Limiting:**
- Per-user rate limits (e.g., 100 requests/minute)
- Per-org rate limits (e.g., 1000 requests/minute)
- AI endpoints: stricter limits (e.g., 10 requests/minute per user)
- Return RATE_LIMITED error when exceeded

**CSRF Protection:**
- Use Firebase Auth tokens (built-in CSRF protection)
- Validate origin headers for web clients (if applicable)

### 14.4 Data Retention & Archival
**Retention Policy:**
- Default: Cases retained 7 years after case closure
- Configurable per org (admin setting)
- Audit logs: Always 7 years minimum

**Archival:**
- Closed cases older than 1 year: Move to cold storage (future)
- Archived cases: Read-only, cannot be modified
- Restore: Admin can restore archived cases (future)

**Deletion:**
- Soft delete: Set deletedAt timestamp, hide from UI
- Hard delete: Only after retention period + explicit action
- Legal hold: Prevent deletion if case is under legal hold (future)

### 14.5 Backup & Disaster Recovery
**Backups:**
- Firestore: Automatic daily backups (Firebase feature)
- Storage: Automatic versioning enabled
- Backup retention: 30 days minimum

**Disaster Recovery:**
- Recovery Point Objective (RPO): 24 hours
- Recovery Time Objective (RTO): 4 hours
- Document recovery procedures
- Test recovery annually

### 14.6 Security Monitoring
**Logging:**
- Log all authentication attempts (success and failure)
- Log all permission denials (NOT_AUTHORIZED)
- Log all admin actions
- Log all data deletions

**Alerts:**
- Alert on repeated authentication failures
- Alert on permission denial spikes
- Alert on unusual data access patterns
- Alert on storage quota approaching limits

**Audit:**
- All security events must be in audit trail
- Admin can view security audit log
- Export security audit for compliance

SLICE 15: Admin Panel (Org Controls)
Goal
Give admin control over settings and system health.

Scope In
Team overview

Plan overview

Usage overview

Basic system settings

Definition of Done
Admin can see usage and manage roles

Locked features show upgrade prompts

SLICE 16: Reliability + Background Jobs
Goal
Make long-running tasks stable.

Scope In
Job orchestration and retry logic

Large file handling

Timeouts, retries, fail-safe states

Definition of Done
Extraction and AI do not fail silently

Job status is always consistent

SLICE 17: Observability (Monitoring)
Goal
Diagnose issues quickly.

Scope In
structured logs

errors captured

basic metrics and dashboards

Definition of Done
admin can identify failures

logs contain traceId and orgId

SLICE 18: QA + Staging + Release Checklist
Goal
Launch with confidence.

Scope In
staging environment

regression checklist

permission matrix validation

deployment checklist

Definition of Done
staging matches production config

core flows tested end-to-end

SLICE 19: Production Launch
Goal
Ship.

Scope In
production deployment

onboarding polish

release notes

first patch plan

Definition of Done
app runs in production

upgrade flow works

AI core works reliably

security is verified

17) Final Rules of Execution (How we actually build)
Never start a slice until dependencies are stable

Never add "nice to have" features inside a slice

Every slice ends with a working demo

Every protected action checks Plan + Role in backend

Flowcharts remain the master blueprint

Slices are the execution plan

18) What Hafsa Produces (Standard Output Format)
For each slice, Hafsa creates:

A 1-page Eraser flow (user steps)

A 1-page UI instruction sheet:

screen purpose

UI elements list

actions and outcomes

empty/loading/error states

This gets pasted into Cursor prompts.

19) Cursor Prompt Standard (Mandatory Wrapper)
Use this wrapper for all UI screens:

You must follow our Master Spec and Design System strictly.
Rules:

Use AppTheme, spacing constants, and reusable widgets only

Keep widget trees shallow and readable

Do not hardcode colors

Add UI states: loading, empty, error

Do not implement business logic in UI

Validate all user input before sending to backend
Now generate/update this screen:
[PASTE SLICE SCREEN UI INSTRUCTIONS HERE]

Use this wrapper for all backend endpoints:

You must follow our Master Spec strictly.
Rules:

Enforce orgId scoping and membership checks

Enforce Plan entitlements and Role permissions

Return structured errors in the mandatory format

Log audit events for critical actions
Now implement endpoint:
[ENDPOINT NAME + INPUT/OUTPUT + VALIDATION]

20) Forbidden Patterns (Anti-Rules)
Never:

Store sensitive data in Flutter (keys, tokens, passwords)

Trust the client for permission checks

Hardcode colors, spacing, or typography in screens

Create documents without orgId

Allow cross-org data access

Hide errors from the user silently

Make backend decisions based on client-provided role/plan

Store large files in Firestore (use Cloud Storage)

Skip audit logging for critical actions

Deploy to production without staging validation

---

## 21) Data Lifecycle Management

### 21.1 Soft Delete vs Hard Delete
**Soft Delete (Default):**
- All deletions set `deletedAt` timestamp
- Data remains in database but hidden from UI
- Can be restored by admin
- Used for: cases, documents, clients, tasks

**Hard Delete:**
- Permanent removal from database
- Only allowed after retention period
- Requires explicit admin action + confirmation
- Audit log must record hard delete

### 21.2 Deletion Cascade Rules
When an org is deleted:
1. Mark org as deleted (soft delete)
2. Mark all cases as deleted
3. Mark all documents as deleted
4. Mark all clients as deleted
5. Retain audit logs (never delete)

When a case is deleted:
1. Mark case as deleted
2. Mark all documents in case as deleted
3. Mark all tasks in case as deleted
4. Retain AI outputs (for audit)

When a document is deleted:
1. Mark document as deleted
2. Mark all chunks as deleted
3. Delete file from Storage (after retention period)
4. Retain metadata (for audit)

### 21.3 Data Purging Schedule
**Automated Purging:**
- Run daily job to check retention periods
- Cases past retention: Mark for archival
- Documents past retention: Mark for deletion
- Audit logs: Never auto-purge (manual only)

**Manual Purging:**
- Admin can trigger purge for specific org
- Requires confirmation and audit log entry
- Cannot purge if legal hold is active

### 21.4 Legal Hold
**Future Feature:**
- Admin can place case under legal hold
- Legal hold prevents deletion (soft or hard)
- Legal hold prevents archival
- Legal hold must be logged in audit trail
- Only admin can release legal hold

---

## 22) AI-Specific Considerations

### 22.1 AI Model Versioning
**Requirement:**
- Every AI output must record:
  - Model name (e.g., "gpt-4", "gpt-3.5-turbo")
  - Model version/timestamp
  - Prompt template used
  - Temperature/settings used

**Storage:**
- Store in AIMessage or AIDraft document:
  - `modelName`: string
  - `modelVersion`: string
  - `promptTemplate`: string (or reference)
  - `settings`: object (temperature, maxTokens, etc.)

**Rationale:**
- Legal requirement: Know which AI generated what
- Reproducibility: Can regenerate with same settings
- Audit: Track model changes over time

### 22.2 AI Cost Tracking
**Per-Request Tracking:**
- Record cost per AI request (tokens used × cost per token)
- Store in UsageCounter: `aiCostUSD`, `aiTokensUsed`
- Aggregate per org, per month

**Limits:**
- Plan-based limits: `maxAIRequestsPerMonth`, `maxAICostPerMonth`
- Enforce in backend before AI request
- Return PLAN_LIMIT if exceeded

**Billing:**
- Include AI costs in usage summary
- Show cost breakdown per case (future)
- Alert when approaching limits

### 22.3 AI Output Disclaimers
**Required Disclaimers:**
- Every AI answer must include: "AI-generated content. Review before use."
- Every AI draft must include: "AI-generated draft. Review and edit before use."
- Citations must be verifiable (link to source document)

**UI Display:**
- Disclaimers must appear in: (1) AI chat screen (top of response), (2) Draft editor (before content), (3) Export (in footer)
- Cannot be dismissed or hidden

### 22.4 AI Prompt Injection Prevention
**Validation:**
- Sanitize user inputs before sending to AI
- Remove or escape special characters that could inject prompts
- Limit input length (prevent prompt injection via long inputs)

**Monitoring:**
- Log unusual AI responses (very long, suspicious patterns)
- Alert on potential injection attempts
- Review AI outputs for quality

### 22.5 AI Output Quality Checks
**Validation:**
- Check for empty responses
- Check for error responses
- Validate citation format
- Check response length (not too short, not suspiciously long)

**Fallback:**
- If AI fails: Return error, don't show broken output
- If citations missing: Log warning, show output with disclaimer
- If quality low: Consider retry with different prompt (future)

### 22.6 AI Usage Analytics
**Track:**
- Requests per user, per org
- Success rate (successful vs failed requests)
- Average response time
- Average cost per request
- Most common question types (future)

**Reporting:**
- Admin dashboard: AI usage summary
- Per-case: AI usage stats
- Monthly reports: AI costs and usage trends

---

## 23) Performance & Scalability Requirements

### 23.1 Response Time SLAs
**Target Response Times:**
- Case list: < 2 seconds (for 100 cases)
- Case details: < 1 second
- Document list: < 2 seconds (for 50 documents)
- AI answer: < 30 seconds (depends on AI provider)
- Document upload: < 5 seconds (for 10MB file)

**Measurement:**
- Measure using Firebase Performance Monitoring or custom logging
- Track p50, p95, p99 response times
- Alert if p95 exceeds target by >20%
- Log slow requests (> 5 seconds)

### 23.2 Concurrent User Limits
**Per Organization:**
- Support minimum 50 concurrent users per org
- Support minimum 500 concurrent users system-wide (MVP)
- Scale horizontally as needed

**Per User:**
- Support multiple tabs/sessions per user
- Handle concurrent edits gracefully (last-write-wins or conflict detection)

### 23.3 File Size Limits
**Document Upload:**
- Maximum file size: 100MB per document (MVP)
- Maximum total storage: Per plan (see plan entitlements)
- Reject files exceeding limits with clear error message

**File Types:**
- Supported: PDF, DOC, DOCX, TXT, images (PNG, JPG)
- Reject unsupported types with clear error

### 23.4 Pagination Standards
**List Endpoints:**
- All list endpoints must support pagination
- Default page size: 20 items
- Maximum page size: 100 items
- Return: `items[]`, `nextPageToken`, `totalCount` (optional)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "items": [...],
    "nextPageToken": "abc123",
    "hasMore": true
  }
}
```

### 23.5 Caching Strategy
**Client-Side Caching:**
- Cache case list for 5 minutes
- Cache case details for 2 minutes
- Invalidate cache on updates

**Backend Caching:**
- Cache org membership lookups (5 minutes)
- Cache plan entitlements (10 minutes)
- Cache AI responses (optional, for identical queries)

**Cache Invalidation:**
- Invalidate on role changes
- Invalidate on plan changes
- Invalidate on case updates

### 23.6 Database Indexing Requirements
**Required Indexes:**
- `organizations/{orgId}/cases`: Index on `status`, `createdAt`, `ownerUid`
- `organizations/{orgId}/cases/{caseId}/access`: Index on `uid`
- `organizations/{orgId}/documents`: Index on `caseId`, `createdAt`
- `organizations/{orgId}/tasks`: Index on `assigneeUid`, `status`, `dueDate`

**Query Optimization:**
- All queries must use indexes
- Avoid full collection scans
- Monitor slow queries and add indexes as needed

---

## 24) Integration Points

### 24.1 Payment Processor
**Provider:** TBD (Stripe recommended)
- Handle subscription upgrades
- Handle plan changes
- Webhook for payment events
- Store payment method (encrypted)

**Endpoints:**
- `billing.createSubscription` (creates Stripe subscription)
- `billing.updatePaymentMethod`
- `billing.cancelSubscription`
- Webhook: `billing.handleWebhook` (payment succeeded/failed)

**Security:**
- Never store full credit card numbers
- Use Stripe tokens for payment methods
- Validate webhook signatures

### 24.2 Email Service
**Provider:** TBD (SendGrid, AWS SES, or Firebase Extensions)
- Send invitation emails
- Send notification emails (future)
- Send password reset emails (if applicable)

**Templates:**
- Org invitation email
- Welcome email
- Password reset email (if applicable)

**Rate Limiting:**
- Max 100 emails per org per day (prevent abuse)
- Max 10 invitation emails per user per day

### 24.3 AI Provider (OpenAI)
**Configuration:**
- API key stored in Cloud Functions environment variables
- Never expose API key to client
- Support multiple API keys (for rate limit distribution)

**Fallback:**
- If OpenAI is down: Return error, don't retry indefinitely
- Consider fallback provider (future)
- Cache responses for identical queries (optional)

**Cost Management:**
- Track token usage per request
- Set org-level cost limits
- Alert when approaching limits

### 24.4 Future Integrations (Post-MVP)
**Calendar Integration:**
- Sync tasks to Google Calendar / Outlook
- Two-way sync (future)

**Email Integration:**
- Import emails as documents
- Link emails to cases

**Document Signing:**
- Integrate with DocuSign / HelloSign
- Send documents for signature
- Track signature status

---

## 25) Cost Management & Monitoring

### 25.1 Cost Tracking
**Per-Organization Costs:**
- AI usage costs (tokens × cost per token)
- Storage costs (GB stored × cost per GB)
- API request costs (if applicable)

**Storage:**
- Track storage per org: `totalStorageMB`
- Alert when approaching plan limit
- Show usage in admin dashboard

**AI Costs:**
- Track per request: `tokensUsed`, `costUSD`
- Aggregate per month: `monthlyAICost`
- Show cost per case (future)

### 25.2 Cost Limits & Alerts
**Plan-Based Limits:**
- FREE: $0 AI cost (or very limited)
- BASIC: $50/month AI budget
- PRO: $200/month AI budget
- ENTERPRISE: Unlimited (with monitoring)

**Alerts:**
- Alert at 80% of monthly budget
- Alert at 100% of monthly budget (block further AI requests)
- Alert on unusual cost spikes

**When 100% Budget is Reached:**
- Block new AI requests
- Return error: "Monthly AI budget exceeded. Upgrade plan or wait for next month."
- Admin can override (temporary increase or reset)

### 25.3 Usage-Based Billing (Future)
**Post-MVP:**
- Charge per AI request (pay-as-you-go)
- Charge per GB storage (beyond plan limit)
- Show cost breakdown per case
- Invoice generation

### 25.4 Cost Optimization
**Strategies:**
- Cache AI responses for identical queries
- Compress documents before storage
- Archive old cases to cold storage (future)
- Monitor and optimize expensive queries

---

END OF MASTER SPEC