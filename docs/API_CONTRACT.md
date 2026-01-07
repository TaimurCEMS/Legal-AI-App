# API_CONTRACT.md

Contract Version: v1.0.0
Last Updated: 2026-01-07
Status: Frozen for implementation (Phase-1+)

## Legal AI Application Backend Contract (V1)

**Backend compute:** Firebase Cloud Functions (Node.js + TypeScript)  
**Auth:** Firebase Auth (ID token required)  
**Storage:** Firebase Storage (documents and exports)  
**Database:** Firestore (metadata, chunks, AI requests/outputs, audit logs)

This document defines:
- HTTPS endpoints exposed by Cloud Functions
- Request/response schemas
- Auth rules and error codes
- Idempotency and async job behavior
- How the client consumes streaming-like responses via Firestore

---

## 1) Conventions

### 1.1 Base URL
All endpoints are hosted under a single HTTPS Cloud Function (recommended):

- `https://<region>-<project>.cloudfunctions.net/api/v1/...`

### 1.2 Required headers
- `Authorization: Bearer <FIREBASE_ID_TOKEN>`
- `X-App-Check: <FIREBASE_APP_CHECK_TOKEN>` (required in prod, optional in dev)

### 1.3 Response envelope
Success:

```json
{
  "ok": true,
  "data": {}
}
```

Error:

```json
{
  "ok": false,
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "User is not a member of orgId",
    "details": {}
  }
}
```

### 1.4 Standard error codes
- `UNAUTHENTICATED` (missing/invalid token)
- `PERMISSION_DENIED` (not member, wrong role, cross-org access)
- `NOT_FOUND`
- `INVALID_ARGUMENT`
- `FAILED_PRECONDITION` (resource not READY, ingestion locked, etc.)
- `RESOURCE_EXHAUSTED` (rate limit, quota exceeded)
- `INTERNAL`

### 1.5 Soft delete (V1)
Resources are not hard deleted. Instead use:
- `deletedAt: timestamp`
- `deletedBy: userId`

Default queries and UI must exclude `deletedAt != null` unless explicitly requested by Admin/Owner.

### 1.6 Idempotency (recommended)
For endpoints that can be retried safely, the client may send:

- `Idempotency-Key: <uuid>`

Server stores and returns the first successful response for the same key (scoped to userId + orgId + endpoint).

---

## 2) Authorization rules (high level)

Every endpoint enforces:
1) Firebase token verification
2) org membership check (orgId must be present and user must be active member)
3) role enforcement for admin endpoints

Role gates (V1):
- **Owner:** everything including limits and member management
- **Admin:** case/document management, member management (optional)
- **Member:** create cases, upload docs, ask AI, generate drafts

Note: Firestore Security Rules must also enforce org scoping for direct client reads/writes.

---

**Security boundary:** `doc_chunks` is **server-only**. The API does not expose raw chunk text. The client consumes answers and citations via `ai_outputs`.

## 3) Core entities (reference)

IDs (strings): `orgId`, `caseId`, `docId`, `chunkId`, `reqId`, `outId`, `draftId`, `exportId`

Document status: `UPLOADED`, `INGESTING`, `READY`, `FAILED`  
AI request status: `PENDING`, `RUNNING`, `DONE`, `FAILED`

---

## 4) Endpoints

### 4.1 Health

#### GET /health
Purpose: basic service check

Response:

```json
{ "ok": true, "data": { "status": "healthy" } }
```

---

### 4.2 Orgs and members

#### GET /orgs/:orgId/members
Role: Admin/Owner

Response:

```json
{
  "ok": true,
  "data": {
    "members": [
      { "userId": "u1", "role": "admin", "status": "active", "joinedAt": "..." }
    ]
  }
}
```

#### POST /orgs/:orgId/invite
Role: Admin/Owner

Request:

```json
{
  "email": "member@example.com",
  "role": "member"
}
```

Response:

```json
{ "ok": true, "data": { "invitationId": "inv_123" } }
```

#### POST /orgs/:orgId/members/:userId/role
Role: Owner

Request:

```json
{ "role": "admin" }
```

Response:

```json
{ "ok": true, "data": { "updated": true } }
```

#### POST /orgs/:orgId/members/:userId/remove
Role: Admin/Owner

Request:

```json
{ "reason": "optional" }
```

Response:

```json
{ "ok": true, "data": { "removed": true } }
```

---

### 4.3 Cases

#### POST /cases
Role: Member+

Request:

```json
{
  "orgId": "org_123",
  "title": "Client v. Vendor",
  "description": "optional"
}
```

Response:

```json
{ "ok": true, "data": { "caseId": "case_abc" } }
```

#### GET /cases?orgId=...&limit=...&cursor=...
Role: Member+

Response:

```json
{
  "ok": true,
  "data": {
    "cases": [
      { "caseId": "case_abc", "title": "Client v. Vendor", "updatedAt": "..." }
    ],
    "nextCursor": "optional"
  }
}
```

#### PATCH /cases/:caseId
Role: Member+ (must be org member; optionally restrict edits to creator/Admin)

Request:

```json
{
  "orgId": "org_123",
  "title": "updated title",
  "description": "updated description"
}
```

Response:

```json
{ "ok": true, "data": { "updated": true } }
```

#### POST /cases/:caseId/delete
Role: Admin/Owner (or creator if allowed)

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{ "ok": true, "data": { "deleted": true } }
```

#### POST /cases/:caseId/restore
Role: Admin/Owner

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{ "ok": true, "data": { "restored": true } }
```

---

### 4.4 Documents (Storage + Firestore metadata)

#### POST /documents/init-upload
Role: Member+

Purpose: create a Firestore `documents/{docId}` record and provide a Storage path.

Notes:
- Upload itself is done from Flutter using Firebase Storage SDK to the returned `storagePath`.

Request:

```json
{
  "orgId": "org_123",
  "caseId": "case_abc",
  "fileName": "Contract.pdf",
  "fileType": "pdf",
  "sizeBytes": 1234567
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "docId": "doc_xyz",
    "storagePath": "org_123/case_abc/documents/doc_xyz/original.pdf",
    "status": "UPLOADED"
  }
}
```

#### POST /documents/:docId/start-ingestion
Role: Member+

Purpose: start async ingestion job. Updates `documents.status`, `documents.progress`, and `documents.stage`.

Request:

```json
{
  "orgId": "org_123",
  "options": {
    "chunking": { "maxChars": 6000, "overlapChars": 500 },
    "embeddings": { "enabled": true, "model": "text-embedding-3-large" }
  }
}
```

Response:

```json
{ "ok": true, "data": { "accepted": true } }
```

#### GET /documents/:docId?orgId=...
Role: Member+

Response:

```json
{
  "ok": true,
  "data": {
    "docId": "doc_xyz",
    "orgId": "org_123",
    "caseId": "case_abc",
    "fileName": "Contract.pdf",
    "fileType": "pdf",
    "storagePath": "org_123/case_abc/documents/doc_xyz/original.pdf",
    "status": "READY",
    "progress": 100,
    "pageCount": 200,
    "updatedAt": "..."
  }
}
```

#### POST /documents/:docId/get-download-url
Role: Member+

Purpose: Return a short-lived URL for downloading the original file from Storage.

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{
  "ok": true,
  "data": {
    "docId": "doc_xyz",
    "downloadUrl": "https://...short-lived..."
  }
}
```

#### POST /documents/:docId/delete
Role: Admin/Owner (or creator if allowed)

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{ "ok": true, "data": { "deleted": true } }
```

#### POST /documents/:docId/restore
Role: Admin/Owner

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{ "ok": true, "data": { "restored": true } }
```

#### POST /documents/:docId/purge
Role: Owner/Admin

Purpose: Immediately and permanently remove Storage object and mark Firestore record as purged.

Request:

```json
{ "orgId": "org_123" }
```

Response:

```json
{ "ok": true, "data": { "purged": true } }
```

---

### 4.5 AI Q&A (RAG with citations)

#### POST /ai/ask
Role: Member+

Purpose:
- Creates `ai_requests/{reqId}`
- Retrieves relevant chunks
- Calls OpenAI
- Creates `ai_outputs/{outId}`
- Writes incremental parts to `ai_outputs/{outId}/parts/*` (streaming-like UX)
- Writes final answer and citations to `ai_outputs/{outId}`

Request:

```json
{
  "orgId": "org_123",
  "question": "What are the termination clauses and notice period?",
  "scope": { "caseId": "case_abc", "docId": "doc_xyz" },
  "retrieval": {
    "strategy": "embeddings",
    "topK": 12
  },
  "response": {
    "style": "concise",
    "includeCitations": true,
    "stream": true
  }
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "reqId": "req_111",
    "outId": "out_222"
  }
}
```

Client behavior:
- Immediately start listening to:
  - `ai_outputs/out_222`
  - `ai_outputs/out_222/parts` ordered by `index`
- Render parts as they arrive, then finalize when status becomes `DONE`.

Stream toggle:
- If `response.stream=true`, the backend writes `ai_outputs/{outId}/parts/*` incrementally.
- If `response.stream=false`, the backend writes only the final `ai_outputs/{outId}.answerText` (no parts).


#### GET /ai/requests/:reqId?orgId=...
Role: Member+

Response:

```json
{
  "ok": true,
  "data": {
    "reqId": "req_111",
    "status": "RUNNING",
    "createdAt": "...",
    "model": { "provider": "openai", "name": "gpt-4o-mini" },
    "usage": { "inputTokens": 0, "outputTokens": 0, "estimatedCostUsd": 0.0 }
  }
}
```

#### GET /ai/outputs/:outId?orgId=...
Role: Member+

Preferred citations format:

```json
{
  "ok": true,
  "data": {
    "outId": "out_222",
    "reqId": "req_111",
    "status": "DONE",
    "answerText": "Termination requires 30 days notice ...",
    "citations": [
      {
        "docId": "doc_xyz",
        "chunkId": "chunk_9",
        "pageStart": 44,
        "pageEnd": 46,
        "sectionHeader": "Termination",
        "paragraphNumber": "2.1",
        "headingPath": ["Agreement", "Section 2", "Termination"]
      }
    ],
    "createdAt": "..."
  }
}
```

---

### 4.6 Draft generation

#### POST /drafts/generate
Role: Member+

Purpose: generate a structured draft (NDA, notice, etc.) using a prompt template plus optional retrieval context.

Request:

```json
{
  "orgId": "org_123",
  "templateKey": "nda_basic_v1",
  "scope": { "caseId": "case_abc" },
  "inputs": {
    "partyA": "ABC Ltd",
    "partyB": "XYZ LLC",
    "effectiveDate": "2026-01-01",
    "jurisdiction": "Pakistan"
  },
  "retrieval": { "useCaseContext": true, "topK": 8 }
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "draftId": "draft_333",
    "outId": "out_444"
  }
}
```

#### POST /drafts/:draftId/export
Role: Member+

Purpose:
Export draft to Storage. V1 can export plain text first, then DOCX/PDF in V1.1.

Request:

```json
{
  "orgId": "org_123",
  "format": "docx"
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "exportId": "exp_555",
    "storagePath": "org_123/case_abc/exports/exp_555/draft.docx"
  }
}
```

---

### 4.7 Prompt library (optional in V1, recommended early)

#### GET /prompts?orgId=...&activeOnly=true
Role: Admin/Owner (or allow read-only to all members)

Response:

```json
{
  "ok": true,
  "data": {
    "prompts": [
      { "promptKey": "qa_default", "activeVersion": 3, "updatedAt": "..." }
    ]
  }
}
```

#### POST /prompts
Role: Admin/Owner

Request:

```json
{
  "orgId": "org_123",
  "promptKey": "qa_default",
  "version": 1,
  "systemInstruction": "You are a legal assistant...",
  "userTemplate": "Question: {{question}} ...",
  "citationRules": "Cite as (Doc, PageStart-PageEnd)."
}
```

Response:

```json
{ "ok": true, "data": { "created": true } }
```

#### POST /prompts/:promptKey/activate
Role: Admin/Owner

Request:

```json
{ "orgId": "org_123", "version": 3 }
```

Response:

```json
{ "ok": true, "data": { "activated": true } }
```

---

### 4.8 Usage (cost control)

#### GET /usage/summary?orgId=...&from=...&to=...
Role: Admin/Owner

Response:

```json
{
  "ok": true,
  "data": {
    "period": { "from": "2026-01-01", "to": "2026-01-07" },
    "aiRequests": 120,
    "ingestedDocs": 18,
    "estimatedCostUsd": 12.34,
    "quota": { "aiRequestsPerDay": 200, "remainingToday": 55 }
  }
}
```

---

## 5) Ingestion job guarantees

### 5.1 Progress updates
`documents/{docId}` fields updated during ingest:
- status: `INGESTING`
- progress: `0..100`
- stage: `"extracting"` | `"chunking"` | `"embedding"` | `"finalizing"`
- updatedAt

### 5.2 Locking
Server sets:

- `ingestionLock: { workerId, lockedAt }`

If lock is fresh, reject concurrent starts with `FAILED_PRECONDITION`.

### 5.3 Failure handling
On error:
- status: `FAILED`
- errorMessage: safe text (no secrets)
- audit log written

---

## 6) Streaming-like output contract

### 6.1 Parts subcollection
`ai_outputs/{outId}/parts/{partId}` documents:
- index: number (0..n)
- text: string
- createdAt: timestamp

Client must (when streaming is enabled):
- subscribe to parts ordered by index
- append text incrementally
- stop when `ai_outputs/{outId}.status` becomes `DONE` or `FAILED`

---

## 7) Minimum logging (audit)
Each endpoint must write audit logs for:
- case created/updated/deleted/restored
- document init upload, ingestion start, ingestion completed/failed, delete/restore/purge
- ai ask started/completed/failed
- draft generation/export
- member invite/role change/removal

---

## 8) Versioning
- All endpoints are under `/v1`
- Backward-incompatible changes require `/v2`

---

## 9) Legal and safety note (product behavior)
AI outputs are assistance, not legal advice. The system must:
- show citations when requested
- encourage verification of sources
- avoid fabricating citations (if unknown, say unknown)

End of API_CONTRACT.md
