# TECH_SPEC.md

Contract Version: v1.0.0
Last Updated: 2026-01-07
Status: Frozen for implementation (Phase-1+)

## Legal AI Application (V1) Technical Specification

## 1. Purpose
Legal AI is a cross-platform application (Web, iOS, Android) that helps legal teams store case documents and extract reliable, cited answers using AI. The system uses Retrieval-Augmented Generation (RAG) to keep responses grounded in uploaded documents and produces citations (page ranges and chunk references) so lawyers can verify outputs.

## 2. Primary Goals (V1)
1) Cross-platform client: Web, iOS, Android via Flutter
2) Firm multitenancy: strict org-scoped access (orgId everywhere)
3) Document storage: large PDFs/DOCX stored in Firebase Storage
4) Ingestion pipeline: extract text, chunk, optionally embed, store in Firestore
5) AI Q&A with citations: retrieve relevant chunks, answer, cite sources
6) Near-real-time answer UX: incremental output via Firestore parts
7) Auditability: log key actions and AI usage
8) Cost controls: rate limits, quotas, and retrieval caps

## 3. Non-Goals (Not V1)
- Full practice management, time tracking, invoicing
- Advanced legal research across external law databases
- Complex collaboration tooling (annotations, highlights, real-time co-editing)
- Enterprise compliance claims (SOC2, ISO, “bank-grade” marketing language)

## 4. Top-Level Tools
- Cursor: primary IDE (Flutter + Functions + docs)
- ChatGPT: architecture, debugging, prompt templates, documentation
- Firebase: Auth, Firestore, Storage, Cloud Functions, Hosting, App Check
- Eraser: architecture maps, flows, schema visuals
- Figma (recommended): wireframes and UI system

## 5. Tech Stack
### 5.1 Frontend
- Flutter (Dart)
- State: Riverpod
- Routing: go_router
- Models: freezed + json_serializable
- Realtime data: Firestore listeners

### 5.2 Backend Platform
- Firebase Auth: Email, Google, Apple
- Firestore: structured data, chunks, outputs, logs
- Firebase Storage: document files
- Cloud Functions: Node.js + TypeScript (all server logic)
- Firebase App Check: required for production clients (web and mobile)

### 5.3 AI Provider
- OpenAI (via server calls only)
- Embeddings used for retrieval (recommended for V1 quality)

## 6. High-Level Architecture
### 6.1 Core Principle
- Files live in Storage
- Text and metadata live in Firestore
- AI keys live only on server (Functions)
- Client never calls OpenAI directly

### 6.2 Document Lifecycle
1) Upload file to Storage
2) Create `documents/{docId}` metadata in Firestore
3) Start ingestion job (Functions)
4) Extract text, chunk, store `doc_chunks`
5) Optional embeddings computed and stored per chunk
6) Mark document READY

### 6.3 Q&A Lifecycle (RAG)
1) User asks question scoped to org, optionally case/document
2) Function creates `ai_requests/{reqId}` with status RUNNING
3) Function retrieves relevant chunks (embedding similarity or fallback search)
4) Function calls OpenAI using only retrieved chunks as context
5) Function writes incremental output parts for streaming-like UX
6) Function writes final `ai_outputs/{outId}` with citations and status DONE
7) Client subscribes to output updates and renders as they arrive

## 7. Firestore Data Model
See docs/DATA_MODEL.md (source of truth). Summary:
- orgs, org_members, cases, documents
- doc_chunks (bounded chunk text, optional embeddings; **server-only access**)
- ai_requests, ai_outputs (+ optional ai_outputs/{outId}/parts)
- audit_logs
Soft delete fields: deletedAt, deletedBy (where applicable)

## 8. Security Model
See docs/SECURITY.md (source of truth). Key points:
- org-scoped multitenancy
- Firestore rules enforce membership and scope checks
- privileged operations only in Functions
- OpenAI keys only in server secrets
- audit logs for sensitive actions
- App Check to reduce abuse

## Chunk Access Boundary (V1)
- The Flutter client must **not** read `doc_chunks`.
- Retrieval and LLM context assembly happen only on the backend.
- The UI displays citations from `ai_outputs.citations` (docId, pageStart/pageEnd, sectionHeader, paragraphNumber, headingPath).

## 9. Cloud Functions API Contract (V1)
All endpoints require Firebase Auth token and enforce org membership.
Prefer HTTPS endpoints (not callable) for flexibility.

### 9.1 Core Endpoints
1) POST /cases.create
Input: { orgId, title, description? }
Output: { caseId }

2) POST /documents.initUpload
Creates document record and returns upload metadata.
Input: { orgId, caseId, fileName, fileType, sizeBytes }
Output: { docId, storagePath, uploadMethod }

3) POST /documents.startIngestion
Starts ingestion pipeline asynchronously.
Input: { orgId, docId }
Output: { accepted: true }

4) POST /ai.ask
Creates request, runs retrieval, writes output parts and final output.
Input: {
  orgId,
  question,
  scope: { caseId?, docId? },
  retrieval: { topK, strategy: "embeddings" | "keyword" }
}
Output: { reqId, outId } (outId may be returned immediately or after creation)

5) POST /draft.generate
Template-based generation with optional retrieval context.
Input: { orgId, templateKey, scope?, userInputs }
Output: { draftId, outId }

### 9.2 Membership Admin (V1 minimal)
- POST /org.inviteMember (Owner/Admin)
- POST /org.setMemberRole (Owner)
- POST /org.removeMember (Owner/Admin)

### 9.3 Usage and Limits
- GET /usage.summary (Owner/Admin)
Returns usage counts, quota remaining

## 10. Ingestion Pipeline Details
### 10.1 Inputs
- PDF (text-based) and DOCX in V1
- Scanned PDFs requiring OCR are V1.1 or V2 unless you explicitly include OCR in V1

### 10.2 Steps
1) Read file from Storage using secure server credentials
2) Extract text (page-by-page when possible)
3) Normalize text (remove weird whitespace, fix broken lines minimally)
4) Chunking:
   - target chunk size: 800 to 1500 tokens equivalent
   - store chunkIndex, pageStart/pageEnd if available
5) Store chunks in Firestore doc_chunks
6) Embeddings (recommended):
   - compute embedding per chunk
   - store embedding array or a reference
7) Update `documents.progress` and `documents.status`

### 10.3 Large Documents
- Never store full text in a single Firestore document
- Chunk documents into many chunk docs
- Use progress updates so UI can show ingestion state

### 10.4 Retries and Idempotency
- Ingestion must be idempotent:
  - if chunks exist for docId and status indicates partial ingest, continue safely
  - avoid duplicating chunks by chunkIndex uniqueness checks
- Use job locking:
  - set documents.ingestionLock with timestamp and workerId

## Ingestion Compute Strategy (V1)
### Default (V1)
- Ingestion is asynchronous and job-based.
- Client uploads file to Storage and creates the documents/{docId} record.
- Client calls start ingestion.
- Backend enqueues an ingestion task and returns immediately.
- Worker processes the file in stages and updates:
  - documents.status
  - documents.progress
  - documents.stage

### Large Documents
- Documents can be thousands of pages.
- The system must:
  - extract incrementally (page-by-page where possible)
  - chunk consistently
  - write chunks in batches
  - be retry-safe (idempotent chunk creation by chunkIndex)

### Upgrade Path (V1.1)
- If ingestion workloads become heavy or long-running, move the ingestion worker to a Cloud Run Job.
- The client and API contract remain unchanged.


## 11. Retrieval Strategy (RAG)
### 11.1 Default Strategy (V1 recommended)
Embeddings-based retrieval:
- Embed the user question
- Retrieve topK chunks within org scope and optionally case/doc scope
- Use chunk metadata to build citations

### 11.2 Fallback Strategy
Keyword retrieval when embeddings not available:
- basic text match on chunk text (limited)
- or integrate a search index later (V2)

### 11.3 Context Window Management
- Only include the top relevant chunks
- Hard caps:
  - maxChunksSent: 20 (configurable)
  - maxTotalContextTokens: configurable
- Always include chunk IDs and page ranges in the context so citations can be produced

## Citation Quality (V1)
- Citations must include:
  - docId
  - chunkId
  - pageStart/pageEnd (when available)
- Improve citations by storing doc_chunks.metadata:
  - sectionHeader, paragraphNumber, headingPath
- The AI output formatter should prefer:
  - "Page X, Section Y, Para Z" when metadata exists
  - otherwise "Page X–Y" with chunk references


## 12. Prompt System (Prompt Library)
### 12.1 Storage
- Prompts stored in Firestore as editable templates:
  - promptKey
  - systemInstruction
  - userTemplate
  - citationFormatRules
  - jurisdictionSettings (optional)
  - version number
  - updatedAt

### 12.2 Usage
- Server fetches prompt by key
- Server assembles final prompt with:
  - policy guardrails
  - question
  - retrieved chunks
  - required citation output format

### 12.3 Versioning
- Each AI request stores prompt version and model params for reproducibility

## 13. Streaming-Like UX (V1.1 recommended, optional in V1)
True HTTP streaming is not required for V1.
Instead implement incremental output via Firestore:

Option A (recommended):
- Create ai_outputs/{outId}
- Write parts to ai_outputs/{outId}/parts/{partId}:
  - index, text, createdAt
- Client subscribes and renders parts in order

Option B:
- Store a growing string field outputSoFar (risk of doc growth)
Avoid this for long answers.

### Stream Toggle (API)
- `/ai/ask` accepts `response.stream` (boolean).
- If `stream=true`, the backend writes incremental output to `ai_outputs/{outId}/parts/*` and the UI renders parts in real time.
- If `stream=false`, the backend writes only the final `ai_outputs/{outId}.answerText` (no parts).

## 14. Soft Deletes (V1 required)
- Use deletedAt and deletedBy on cases/documents/chunks/outputs
- Default queries filter out deletedAt != null
- Owner/Admin can restore by clearing deleted fields
- Storage deletion is delayed by retention policy (V1): the file is retained until `purgeAfter`, then removed by the daily purge job.

## Deletion and Retention (V1)
- Soft delete for cases/documents/chunks/outputs using deletedAt/deletedBy.
- On soft delete, set `purgeAfter` (default: deletedAt + 30 days).
- Daily purge job permanently removes Storage objects where `purgeAfter <= now` and marks records purged.
- Restore is allowed until purgeAfter.


## 15. Storage Layout and Rules
### 15.1 Storage Paths
- orgId/caseId/documents/docId/original.ext
- orgId/caseId/exports/exportId.ext (generated drafts)

### 15.2 Security
- Storage rules restrict access to authenticated org members only
- No public buckets
- Do not embed signed URLs permanently in Firestore; generate short-lived URLs when needed

## 16. Performance and Cost Controls
### 16.1 Controls
- Per-user and per-org rate limiting on ai.ask
- Quotas per org (requests per day, ingestion per day)
- Caps: topK, maxChunksSent, maxOutputTokens
- Store token usage and estimated cost per request in ai_requests metadata

### 16.2 Monitoring
- Log function execution times and failures
- Track ingestion throughput and average time per page

## 17. Testing Strategy
### 17.1 Unit Tests
- role checks and membership logic
- retrieval selection logic
- prompt assembly correctness
- citation formatting output parser

### 17.2 Integration Tests
- Firebase Emulator tests:
  - Firestore rules enforcement
  - Functions endpoints auth enforcement
  - ingestion job behavior on sample files

### 17.3 UAT
- Android/iOS real devices for upload and camera related features (if OCR later)
- Web performance tests for large file upload and realtime rendering

## 18. Deployment
### 18.1 Environments
- dev, staging, prod Firebase projects
- Separate keys and quotas per environment

### 18.2 Hosting
- Web: Firebase Hosting
- Functions: deployed via Firebase CLI

### 18.3 CI/CD
- GitHub Actions:
  - lint and tests
  - deploy rules, functions, hosting (staging on merge, prod on tag)

## 19. Repository Structure
Recommended:
- apps/client_flutter
- functions/backend_functions_ts
- docs/ (TECH_SPEC.md, SECURITY.md, DATA_MODEL.md, API_CONTRACT.md, PROMPTS.md)
- diagrams/ (Eraser exports)

## Vector Search Strategy (V1 vs V1.1)
### V1 (Firebase-native)
- Store embeddings on `doc_chunks.embedding`.
- Use Firestore KNN vector queries with vector indexes for similarity search.
- Optional automation: install the **Vector Search with Firestore** extension to automate embedding generation and provide a callable query function.

### V1.1
- If scale, cost, or query constraints require it, migrate embeddings to a dedicated vector service while keeping the same RAG flow and API contract.

## 20. V2 Roadmap (After V1 ships)
- OCR pipeline for scanned docs (Document AI or Textract)
- External vector DB or search service if Firestore retrieval hits scale limits
- Fine-grained permissions per case/document
- Collaboration features
- Advanced compliance and retention tooling

## Vertical Slice Verification (Implementation Gate)

The first implementation must complete this loop end-to-end:

### 1) Ingestion
File Upload → `documents/{docId}` created → backend worker extracts text → chunks/embeds → writes `doc_chunks` (server-only) → marks `documents.status=ready`.

PASS if:
- `doc_chunks` is written only by backend
- Client cannot read/write `doc_chunks`
- `documents/{docId}` reaches `ready` deterministically

### 2) Retrieval
User query → backend embeds query → Firestore vector KNN (`findNearest`) against `doc_chunks` (org-scoped, and doc-scoped where applicable) → returns topK citations.

PASS if:
- KNN query is always tenant-scoped
- Citations include docId + chunkId + location metadata
- Results are stable and relevant on a known test doc

### 3) Output
Backend generates answer → if `response.stream=true` writes sequential `ai_outputs/{id}/parts/*` + final `ai_outputs/{id}` with citations.  
If `response.stream=false`, writes only final `ai_outputs/{id}` (no parts).

PASS if:
- Stream path produces ordered parts and a final completed output
- Non-stream path bypasses parts entirely
- Both paths yield the same final answer semantics + citations

### 4) UI
Flutter listens to `ai_outputs/{id}` and (optionally) `ai_outputs/{id}/parts/*` for the typewriter UX and source-link metadata.

PASS if:
- Stream toggle changes UX (typewriter vs spinner) without changing correctness
- No direct client dependency on `doc_chunks`

## Platform Constraints (Verified as of 2026-01-07)

### Firestore Vector Search
- Max supported embedding dimension for Firestore vector fields/indexes: **2048**.
- Max results (`findNearest.limit`) per nearest-neighbor query: **1000**.
- Vector search does **not** support real-time snapshot listeners.
- Vector search support is available in backend/server client libraries (not intended for client-side Flutter usage).

### Cloud Functions Timeouts
- Cloud Functions / Cloud Run Functions: **HTTP-triggered functions can run up to 60 minutes**.
- Event-driven functions have shorter limits (commonly **up to 9 minutes**).

### OpenAI Embedding Model Dimension Compatibility
- `text-embedding-3-small` defaults to **1536 dims**.
- `text-embedding-3-large` defaults to **3072 dims** and therefore exceeds Firestore’s **2048** max unless reduced via the embeddings API `dimensions` parameter.
