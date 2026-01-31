# Slice P1 Build Card: Domain Events + Outbox (Thin Backbone)

**Status:** 🟢 IMPLEMENTED  
**Priority:** P1 (foundation for P2, Slice 16)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 5.5 ✅ (backend + Firestore)  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §2 (Domain Events), §4 (Notifications)

---

## 📋 Overview

P1 introduces a **minimal, durable, observable** event and outbox foundation that enables:
- **Notification dispatch** (P2) – events drive routing and outbox jobs for email/in-app.
- **Activity feed and audit patterns** (Slice 16 and later) – domain_events as source of truth.
- **Reliable retries without duplication** – idempotency keys and at-most-once processing.

**Key Features:**
1. **Domain events** – Emit for key actions (matter, task, document, invoice, payment, user).
2. **Outbox** – Durable job records with idempotency; status lifecycle (pending → processing → sent | failed | dead).
3. **Processor** – Scheduled job to drain outbox (v1: `notification_dispatch` only); locking, backoff, dead-letter.
4. **Observability** – Logs + Firestore status fields for debugging failures.

**Deferred (Out of Scope):**
- Deliverability hardening (bounce/complaint, P3).
- Full activity feed UI (Slice 16).
- External event bus (Pub/Sub/EventBridge).

---

## 🎯 Success Criteria

### Backend
- Creating a matter (and other in-scope actions) emits a `domain_event` with required fields.
- Creating an outbox record is **idempotent** (same key → no duplicate job).
- Processor sends each outbox record **at most once** (no duplicates on retries).
- Failures move to `pending` with backoff; repeated failures move to `dead`.
- Status visibility: `pending` | `processing` | `sent` | `failed` | `dead`.

### Frontend
- N/A for P1 (backend/infra only). Optional: simple admin query recipe or Firestore console usage for failed/dead jobs.

### Testing
- Unit: idempotency key generation, backoff schedule.
- Integration: simulate processor retry → no duplicate outbox records; force send failure → attempts increment and dead-letter.

---

## 🏗️ Technical Architecture

### Data Model

#### New Collections
1. **`domain_events`** – Immutable event log.
2. **`outbox`** – Durable job queue for dispatch (e.g. notification_dispatch).

#### domain_events schema
```typescript
// Required fields
{
  eventId: string;
  orgId: string;
  eventType: string;   // e.g. matter.created, task.assigned
  entityType: string;  // matter | task | document | invoice | payment | user
  entityId: string;
  actor: string;       // uid or "system"
  timestamp: Timestamp;
  payload: object;    // event-specific payload
  visibility?: string; // optional, e.g. org | matter
}
```

#### outbox schema
```typescript
{
  id: string;              // idempotency key (doc id)
  orgId: string;
  eventId: string;
  jobType: "notification_dispatch";  // v1 only
  status: "pending" | "processing" | "sent" | "failed" | "dead";
  attempts: number;
  maxAttempts: number;     // default 5
  nextAttemptAt: Timestamp;
  lockedAt?: Timestamp;
  lockOwner?: string;      // function instance id
  lastError?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  sentAt?: Timestamp;      // when status = sent
}
```

---

### Event Emission Rules

**When to emit:** After transaction success in backend service layer. Actor from auth context or `"system"`.

**Minimum event set (emit for these existing actions):**
| Event Type           | Entity   | When Emitted              |
|----------------------|----------|---------------------------|
| matter.created       | matter   | Matter created            |
| matter.updated       | matter   | Matter updated            |
| task.created         | task     | Task created              |
| task.assigned        | task     | Task assigned             |
| task.completed       | task     | Task completed            |
| document.uploaded    | document | Document uploaded         |
| invoice.created      | invoice  | Invoice created           |
| invoice.sent         | invoice  | Invoice sent              |
| payment.received     | payment  | Payment received          |
| payment.failed       | payment  | Payment failed            |
| user.invited         | user     | User invited              |
| user.joined          | user     | User joined org           |

**Who emits:** Backend service layer after transaction success; actor = auth uid or `"system"`.

---

### Outbox Creation Rules

**Idempotency key format:**  
`<jobType>:<orgId>:<eventType>:<entityType>:<entityId>:<recipientId>:<channel>:<templateId>`  
(Recipient/channel/template may be empty or placeholder for v1 notification_dispatch.)

**Durable intent:**
- Create outbox doc in the **same logical flow** as creating the domain event.
- If domain_events and outbox cannot be in a single Firestore transaction (e.g. cross-collection), use a **best-effort transactional batch**. If the batch fails, do not commit the event (rollback or do not emit).

---

### Processing Strategy

**Processor:** Cloud Function **scheduled every 1 minute** (preferred for controlled concurrency), or Firestore trigger on `outbox` pending. Prefer scheduled to avoid thundering herd.

**Locking:**
1. Query `outbox` where `status == "pending"` and `nextAttemptAt <= now`.
2. For each doc, attempt lock: `update status = "processing", lockedAt = now, lockOwner = functionInstanceId` **only if** current `status == "pending"`.
3. If lock fails (e.g. another instance updated), skip and continue.

**Attempt handling:**
- **Success:** Set `status = "sent"`, `sentAt`, `updatedAt`.
- **Failure:** `attempts += 1`.
  - If `attempts < maxAttempts`: set `status = "pending"`, `nextAttemptAt = now + backoff(attempts)`, `lastError`.
  - Else: set `status = "dead"`, `lastError`, `updatedAt`.

**Backoff schedule:**
| Attempt | Delay before next try |
|---------|------------------------|
| 1       | 1 min                  |
| 2       | 5 min                  |
| 3       | 15 min                 |
| 4       | 60 min                 |
| 5       | dead                   |

---

## 🔐 Security & Permissions

- **domain_events** and **outbox** are **internal** – no client direct access.
- Only **service account** (Cloud Functions) can write.
- Optional: **admin** role can read for debugging; others have no direct access.
- Firestore rules: deny client read/write on these collections; allow only backend.

---

## 📊 Data Flow

1. **Action occurs (e.g. matter created):** Backend handler completes transaction → writes `domain_event` → creates one or more `outbox` docs (e.g. one per recipient/channel for P2) in same batch. If batch fails, event is not emitted.
2. **Processor runs (every 1 min):** Query pending outbox → lock doc → execute job (v1: notification_dispatch placeholder or P2 integration) → on success mark `sent`, on failure apply backoff or mark `dead`.
3. **Observability:** Log eventId, outbox id, status transitions; query Firestore for `status in (failed, dead)` for ops.

---

## 📝 Backend Contract (Event Emission + Processor)

### Event emission (call sites)
- **Matter:** On `caseCreate` / case update success → emit `matter.created` / `matter.updated` with entityId = caseId, payload with matter summary.
- **Task:** On task create / assign / complete → emit `task.created` / `task.assigned` / `task.completed`.
- **Document:** On document upload success → emit `document.uploaded`.
- **Invoice:** On invoice create / send → emit `invoice.created` / `invoice.sent`.
- **Payment:** On payment success / failure (e.g. webhook) → emit `payment.received` / `payment.failed`.
- **User:** On invite / join → emit `user.invited` / `user.joined`.

(Exact call sites depend on existing Cloud Functions; add emission after existing write operations.)

### Processor function
- **Name:** e.g. `outboxProcessor` or `processOutbox`.
- **Trigger:** Scheduled (every 1 min).
- **Logic:** Query → lock → process jobType `notification_dispatch` (v1: may no-op or call P2 routing) → update status.
- **Idempotency:** Lock ensures at-most-once; idempotency key on outbox doc prevents duplicate job creation.

---

## 🧪 Testing Strategy

- **Unit:** Idempotency key generation (same inputs → same key). Backoff schedule (attempts 1–5 → correct nextAttemptAt).
- **Integration:** Create domain_event + outbox in batch; run processor twice on same doc → only one successful send; status ends `sent`. Force send failure (e.g. mock failure) → attempts increment, nextAttemptAt set, after maxAttempts status = `dead`.
- **Regression:** Creating a matter results in one domain_event and expected outbox records (if P2 wired); no duplicate outbox docs for same idempotency key.

---

## 📚 References

- MASTER_SPEC_V2.0.md §2 (Domain Events), §4 (Notifications)
- SLICE_P2_BUILD_CARD.md (consumes events + outbox)
- SLICE_16_BUILD_CARD.md (activity feed reads domain_events)

---

**Last Updated:** 2026-01-30
