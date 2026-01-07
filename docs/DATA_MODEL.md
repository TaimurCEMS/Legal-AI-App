# DATA_MODEL.md

Contract Version: v1.0.0
Last Updated: 2026-01-07
Status: Frozen for implementation (Phase-1+)

## Firestore Data Model (V1)

All collections are tenant scoped by orgId. Every document that represents business data must include orgId.

## 1. Collections Overview

### 1.1 orgs/{orgId}
Represents a firm/organization.
Fields:
- name: string
- createdAt: timestamp
- createdBy: userId
- plan: string (free, trial, paid)
- limits: map (aiRequestsPerDay, maxDocs, maxStorageMb, etc.)
- deletedAt: timestamp|null

Indexes:
- none required beyond defaults

### 1.2 org_members/{orgId}_{userId}
Membership + role. Single doc per org-user pair.
Fields:
- orgId: string
- userId: string
- role: string (owner, admin, member)
- status: string (active, invited, suspended)
- joinedAt: timestamp
- invitedBy: userId|null
- deletedAt: timestamp|null

Indexes:
- orgId + role
- orgId + status

### 1.3 cases/{caseId}
Case container.
Fields:
- orgId: string
- title: string
- description: string|null
- createdAt: timestamp
- createdBy: userId
- updatedAt: timestamp
- deletedAt: timestamp|null
- deletedBy: userId|null

Indexes:
- orgId + deletedAt + updatedAt
- orgId + createdAt

### 1.4 documents/{docId}
Uploaded file metadata and ingestion status.
Fields:
- orgId: string
- caseId: string
- fileName: string
- fileType: string (pdf, docx)
- storagePath: string
- sizeBytes: number
- status: string (UPLOADED, INGESTING, READY, FAILED)
- progress: number (0..100)
- pageCount: number|null
- errorMessage: string|null
- createdAt: timestamp
- createdBy: userId
- updatedAt: timestamp
- deletedAt: timestamp|null
- deletedBy: userId|null
- retention: map|null
  - deletedAt: timestamp|null
  - purgeAfter: timestamp|null     # deletedAt + retentionDays


Indexes:
- orgId + caseId + deletedAt + updatedAt
- orgId + status + updatedAt

### 1.5 doc_chunks/{chunkId}
Access:
- Server-only collection. Client applications must not read or query `doc_chunks`.
- Firestore Security Rules should deny client reads/writes; backend uses Admin SDK for ingestion and retrieval.
Chunked text units for retrieval and citations.
Fields:
- orgId: string
- caseId: string
- docId: string
- chunkIndex: number

Source location:
- pageStart: number|null
- pageEnd: number|null
- charStart: number|null          # start offset within extracted page text (if available)
- charEnd: number|null            # end offset within extracted page text (if available)

Content:
- text: string                    # bounded, keep small and consistent

Citation metadata (recommended V1):
- metadata: map
  - sectionHeader: string|null    # e.g., "Termination", "Confidentiality"
  - headingPath: array<string>|null # e.g., ["Agreement", "Section 5", "Termination"]
  - paragraphNumber: string|null  # e.g., "2.1" (string because formats vary)
  - clauseId: string|null         # optional: stable internal locator if you generate one
  - sourceLabel: string|null      # optional: human label like "Page 44, Para 3"

Embeddings:
- embedding: array<number>|null   # optional V1, recommended for retrieval quality
  Notes:
  - If embeddings become too large or costly in Firestore at scale, migrate to a vector service (V1.1/V2).

Lifecycle:
- createdAt: timestamp
- deletedAt: timestamp|null
- deletedBy: userId|null

Indexes:
- orgId + docId + chunkIndex
- orgId + caseId + docId
- orgId + docId + deletedAt


### 1.6 ai_requests/{reqId}
AI request record for audit and reproducibility.
Fields:
- orgId: string
- userId: string
- caseId: string|null
- docId: string|null
- question: string
- retrieval: map
  - topK: number
  - filterCaseId: string|null
  - filterDocId: string|null
- model: map
  - provider: string (openai)
  - modelName: string
  - temperature: number
- status: string (PENDING, RUNNING, DONE, FAILED)
- createdAt: timestamp
- updatedAt: timestamp
- deletedAt: timestamp|null

Indexes:
- orgId + userId + createdAt
- orgId + status + updatedAt

### 1.7 ai_outputs/{outId}
AI output, linked to ai_requests.
Fields:
- orgId: string
- reqId: string
- answerText: string
- citations: array<map>
  - docId: string
  - chunkId: string
  - pageStart: number|null
  - pageEnd: number|null
  - sectionHeader: string|null
  - paragraphNumber: string|null
  - headingPath: array<string>|null
- safety: map
  - flagged: boolean
  - reason: string|null
- createdAt: timestamp
- deletedAt: timestamp|null
- deletedBy: userId|null

Indexes:
- orgId + reqId

Optional streaming support (V1.1):
- tokenStream: array<string> OR
- incrementalParts: subcollection ai_outputs/{outId}/parts/{partId}

### 1.8 audit_logs/{logId}
Immutable audit trail.
Fields:
- orgId: string
- userId: string
- actionType: string
- target: map (caseId, docId, reqId, outId)
- metadata: map (small, no secrets)
- createdAt: timestamp

Indexes:
- orgId + createdAt
- orgId + userId + createdAt

## 2. Soft Delete Policy (V1)
Soft delete uses deletedAt and deletedBy where applicable.
- Queries in app must default to deletedAt == null.
- Owner/Admin can restore by clearing deletedAt/deletedBy.
- Physical file deletion from Storage can be delayed (V2 retention policy).

## 3. Naming and IDs
- Use Firestore auto IDs for simplicity.
- Enforce orgId presence in every business document.
- Maintain referential integrity in application logic (Firestore is not relational).

## 4. Minimal Constraints
- Prevent cross-org reads via security rules.
- Prevent writes where orgId does not match membership orgId.
- Prefer server-side creation of sensitive records (ai_requests, ai_outputs, audit_logs).