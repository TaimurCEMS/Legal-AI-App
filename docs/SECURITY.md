# SECURITY.md

Contract Version: v1.0.0
Last Updated: 2026-01-07
Status: Frozen for implementation (Phase-1+)

## Legal AI Application Security Model (V1)

## 1. Core Principles
- Tenant isolation is mandatory. Every read/write is scoped to an organization (orgId).
- Client apps never hold provider secrets (OpenAI keys, OCR keys).
- All AI actions are auditable: who requested, what inputs, what outputs, when, and against which case/document.

## 2. Identity and Authentication
- Auth Provider: Firebase Auth (Email/Password, Google, Apple).
- The client obtains a Firebase ID token and presents it to backend endpoints (Cloud Functions HTTPS).
- Backend verifies ID token on every request.

## 3. Authorization and Tenant Isolation
### 3.1 Tenant Scope
- Every document, case, chunk, AI request, and AI output includes orgId.
- org_membership is the source of truth for roles and access.

### 3.2 Roles (V1)
- Owner: billing, org settings, member management, full access.
- Admin: case/document management, member management (optional), full access except billing.
- Member: create/read/update allowed resources within org, no billing.

### 3.3 Firestore Security Rules (High-Level)
Rules must enforce:
- Any read/write requires:
  - user is authenticated
  - user is a member of orgId referenced by the document
- Role-gated actions:
  - member invites/role changes: Owner/Admin only
  - org settings and subscription: Owner only
- No cross-org queries without orgId constraints.

Important: Do not encode complex business logic into security rules.
Rules should check membership and org scope. Backend functions enforce deeper policy.

## 4. Backend Compute Security (Cloud Functions)
- All privileged operations occur in Cloud Functions:
  - OpenAI calls
  - ingestion orchestration
  - retrieval and citations assembly
  - usage tracking and rate limiting
- Store OpenAI API key in function environment secrets (never in repo, never in client).
- Verify Firebase token and org membership in each endpoint.
## App Check (HTTPS Endpoints)

Because the API uses HTTPS endpoints (not Callable functions), App Check must be enforced manually in backend middleware.

Requirement:
- Client must send App Check token in header: `X-Firebase-AppCheck`
- Backend must verify the token using Firebase Admin SDK and reject requests that fail verification (401).


## 5. Data Protection
- Files stored in Firebase Storage with path scoping:
  - orgId/caseId/docId/...
- Storage Security Rules:
  - Only org members can read files for their org
  - Only authorized roles can upload/delete (based on V1 policy)
## Chunk Access Boundary (V1)
- Client applications must **not** read or query `doc_chunks`.
- Firestore Security Rules should deny client reads/writes to `doc_chunks`.
- Only backend services (Cloud Functions using the Admin SDK) access `doc_chunks` for ingestion and retrieval.
- The client UI relies on `ai_outputs` and its `citations` to show users *where* an answer came from without exposing raw chunk text.

## Storage Lifecycle and Retention (V1)
### Soft Delete Policy
- Deleting a case or document is a soft delete:
  - Set deletedAt and deletedBy on Firestore records
  - Hide deleted content from default queries and UI

### Storage File Retention
- When a document is soft-deleted, the Storage file is not immediately removed.
- Retention window: 30 days by default.
- Source of truth: `purgeAfter` timestamp stored on the document metadata (set when soft-deleted).
- The document can be restored within the retention window by clearing deletedAt/deletedBy fields.

### Purge Policy
- A scheduled server job (Cloud Function scheduled trigger) runs daily:
  - Finds documents where deletedAt is set and purgeAfter <= now
  - Deletes the Storage object
  - Marks Firestore document as purged (e.g., purgedAt)
  - Optionally deletes doc_chunks (or soft-deletes them) to reduce storage usage

### Notes
- Avoid permanent signed URLs stored in Firestore.
- Generate short-lived download URLs on demand via a backend endpoint.

## Ingestion Compute Strategy (V1)
- Default ingestion runs in backend compute, not the client.
- Use queued/background processing for ingestion to avoid request timeouts:
  - Cloud Functions HTTP endpoint enqueues ingestion task
  - Task executes extraction, chunking, embeddings, and progress updates
- If ingestion grows beyond practical task limits, move the ingestion worker to Cloud Run Job (V1.1) while keeping the same API contract.

## App Check (Required for Production)
- Require Firebase App Check tokens for:
  - Functions endpoints
  - Firestore access (where applicable)
  - Storage access (where applicable)
- This reduces abuse, automated scraping, and quota theft.


## 6. Audit Logging (Required)
Create audit log records for:
- Document upload initiated/completed/failed
- Document ingestion started/completed/failed
- AI question asked and AI response generated
- Draft generated/exported
- Membership changes (invite, role change, removal)
Audit logs must include:
- orgId, userId, actionType, targetIds, timestamp, minimal metadata

## 7. Abuse Prevention and Cost Control
- Rate limit per user and per org for AI endpoints.
- Enforce max retrieval chunks and max tokens per response.
- Enforce ingestion quotas per org (plan-based).
- Require Firebase App Check for web and mobile builds (recommended for V1 hardening).

## 8. Handling PII and Sensitive Data
- Do not send entire documents to LLMs.
- Send only retrieved chunks required to answer.
- Store model inputs/outputs with access controls (org scoped).
- Allow a future "redaction policy" hook:
  - redact identifiers before LLM call when configured

## 9. Incident Safety (V1 Minimal)
- Logging: Cloud Logging for functions errors and job failures.
- Alerting: basic error alerting (Crashlytics/Sentry optional).
- Backups: plan for scheduled export/backup strategy (V2).
