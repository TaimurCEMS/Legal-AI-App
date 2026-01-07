# CONTRACT_CHECKLIST.md

Contract Version: v1.0.1
Last Updated: 2026-01-07
Status: Implementation Gate (must pass before deploy)

Owner: Taimur
Scope: Legal AI Assistant V1 (Docs: TECH_SPEC, DATA_MODEL, SECURITY, API_CONTRACT)

---

## A) Contract Integrity

- [ ] All 4 canonical docs exist in `/docs/`:
  - [ ] `/docs/TECH_SPEC.md`
  - [ ] `/docs/DATA_MODEL.md`
  - [ ] `/docs/SECURITY.md`
  - [ ] `/docs/API_CONTRACT.md`
- [ ] All 4 docs show the same `Contract Version: v1.0.1`
- [ ] No duplicate “revised/final/v2” docs are being referenced in prompts or code
- [ ] Git tag exists for this contract version (example: `v1.0.1`)

---

## B) Hard Security Boundaries (Non-Negotiable)

### Tenant isolation
- [ ] Every API request validates Firebase ID token (reject if missing/invalid)
- [ ] Every API request enforces org membership (active membership required)
- [ ] Every document access enforces `orgId` match (no cross-org reads/writes)

### Server-only collections
- [ ] Firestore rules deny all client read/write to `doc_chunks`
- [ ] Client cannot write to any server-only collections (requests/outputs/audit/etc.)

---

## C) Streaming Output Behavior

- [ ] `response.stream=true` path:
  - [ ] Backend writes to `ai_outputs/{id}/parts/*` sequentially
  - [ ] Each part includes deterministic ordering field (example: `seq`)
  - [ ] Final output doc is marked complete when streaming ends
- [ ] `response.stream=false` path:
  - [ ] Backend does NOT write to `parts` subcollection
  - [ ] Backend writes only the final output document (single write path)

---

## D) Retention and Purge (Deterministic)

- [ ] Retention fields exist on records that must be purged (per DATA_MODEL)
- [ ] Purge job filters by: `retention.purgeAfter <= now`
- [ ] Purge job does NOT compute “30 days ago” dynamically as the source of truth
- [ ] Purge deletes in safe batches and logs results (audit trail)

---

## E) Firestore Vector Retrieval (Firestore-native KNN)

- [ ] Embeddings are stored in Firestore in the expected vector field(s)
- [ ] KNN index exists for the vector field(s) used in retrieval
- [ ] Retrieval always includes org scoping (and doc scoping where applicable)
- [ ] Returned citations include enough metadata to verify origin (docId, chunkId, offsets/pages)

---

## F) Operational Safety

- [ ] Structured logs include `orgId`, `docId`, `requestId` (where applicable)
- [ ] Rate limiting exists or is explicitly deferred with a tracked task
- [ ] Error responses never leak sensitive content (no raw chunk text, no secrets)

---

## G) Testing Gates (Minimum)

### Firestore rules tests (emulator)
- [ ] Same-org user can read allowed collections
- [ ] Cross-org user cannot read any protected data
- [ ] Any client read/write to `doc_chunks` is denied

### API integration checks
- [ ] Missing token -> 401
- [ ] Invalid token -> 401
- [ ] Valid token but no org membership -> 403
- [ ] Valid member, wrong doc org -> 403
- [ ] stream=true writes parts, stream=false does not

---

## H) Release Notes (Fill before deploy)

Release Tag:
- v1.0.1

What changed:
- -

Known limitations:
- -

Rollback plan:
- Re-deploy previous tag:
  - -

Sign-off:
- [ ] Contract gate passed
- [ ] Ready to deploy
