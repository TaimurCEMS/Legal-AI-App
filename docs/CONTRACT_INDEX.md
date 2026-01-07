# CONTRACT_INDEX.md

Contract Version: v1.0.0
Last Updated: 2026-01-07
Status: Frozen for implementation (Phase-1+)

---

## Purpose

This folder contains the **canonical contract** for Legal AI Assistant V1.
If implementation differs from these documents, **implementation is wrong** (or the contract must be version-bumped).

---

## Canonical Documents

1) `TECH_SPEC.md`
- System architecture, components, responsibilities, and execution flow.
- Defines what runs where (client vs API vs worker), and the non-functional expectations.

2) `DATA_MODEL.md`
- Firestore collections, document schemas, and scoping rules.
- Defines the **server-only boundary** for `doc_chunks`.
- Defines retention fields (including `retention.purgeAfter`) as the purge truth.

3) `SECURITY.md`
- Authentication/authorization model and tenant isolation.
- Defines membership checks, org scoping, and enforcement expectations in both rules and backend.

4) `API_CONTRACT.md`
- HTTP endpoints, request/response payloads, error codes.
- Defines the `response.stream` flag behavior for streaming vs non-stream output paths.

---

## Non-Negotiables (Must Not Drift)

### Tenant isolation
- Every request must be authorized via Firebase ID token.
- Every access must be scoped to `orgId` with active membership verification.
- No cross-org reads/writes, ever.

### Secure chunk boundary (server-only)
- `doc_chunks` is **server-only**.
- Client must never read or write `doc_chunks`.
- Retrieval happens via server-side KNN and returns only citations/snippets allowed by the contract.

### Streaming contract
- `stream=true`: write sequential parts to `ai_outputs/{id}/parts/*`.
- `stream=false`: bypass parts entirely and write only the final output doc.

### Deterministic purge
- Purge job uses `retention.purgeAfter <= now` as the deletion filter.
- No dynamic “30 days ago” logic as the purge source of truth.

### Firestore-native vector strategy
- Retrieval uses Firestore KNN/vector indexes as defined.
- All KNN queries must be org-scoped (and doc-scoped where required).

---

## Change Control

Contract changes require:
- Updating the contract version in all docs
- A new git tag (example: v1.1.0)
- A brief entry in release notes describing why the contract changed

No contract changes are allowed “silently” inside code-only commits.

---

## Implementation Phases (High-Level)

- Phase-0: Freeze contract + repo structure + drift blockers
- Phase-1: Enforce tenancy + security boundaries (rules + backend guards)
- Phase-2: Ingestion pipeline (upload → extract → chunk → embed → index)
- Phase-3: Retrieval via Firestore KNN + citations
- Phase-4: `/ai/ask` with stream toggle (parts vs single write)
- Phase-5: Purge job using `purgeAfter`
- Phase-6: Observability + cost controls
- Phase-7: Tests that prove tenant isolation + correctness

---

## Quick Start (Implementation Rule)

Do not implement “extra features” until this vertical slice works end-to-end:

Upload 1 doc → ingest → ask 1 question → citations return → stream toggle works.
