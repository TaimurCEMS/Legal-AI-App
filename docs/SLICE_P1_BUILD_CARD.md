# SLICE_P1_BUILD_CARD.md
## Slice: P1 Domain Events + Outbox (Thin Backbone)

### Objective
Introduce a minimal, durable, observable event and outbox foundation that enables:
- Notification dispatch (P2)
- Activity feed and audit patterns (later)
- Reliable retries without duplication

### In Scope
1) Domain Event creation for key actions
2) Outbox record creation with idempotency keys
3) Processor to drain outbox jobs (notification_dispatch only in v1)
4) Status visibility fields and basic dead-letter handling
5) Minimal admin visibility (logs + firestore status) to debug failures

### Out of Scope
- Deliverability hardening (P3)
- Full activity feed UI (Slice 16)
- External event bus (Pub/Sub/EventBridge)

---

## Data Model Changes
### New Collections
1) `domain_events`
2) `outbox`

### domain_events schema
Required fields:
- eventId, orgId, eventType, entityType, entityId, actor, timestamp, payload, visibility

### outbox schema
- id (idempotency key)
- orgId, eventId
- jobType: notification_dispatch
- status: pending | processing | sent | failed | dead
- attempts, maxAttempts (default 5)
- nextAttemptAt
- lockedAt, lockOwner
- lastError
- createdAt, updatedAt

---

## Event Emission Rules
### When to emit events
Emit for these existing actions (minimum set):
- matter.created, matter.updated
- task.created, task.assigned, task.completed
- document.uploaded
- invoice.created, invoice.sent
- payment.received, payment.failed (even if later)
- user.invited, user.joined

### Who emits
- Backend service layer after transaction success
- Actor captured from auth context or system

---

## Outbox Creation Rules
### Idempotency Key Format
`<jobType>:<orgId>:<eventType>:<entityType>:<entityId>:<recipientId>:<channel>:<templateId>`

### Durable intent
- Create outbox doc in same logical flow as creating the domain event.
- If domain events and outbox cannot be in a single transaction due to constraints, use a best-effort transactional batch. If batch fails, do not emit event.

---

## Processing Strategy
### Processor function
- Cloud Function scheduled every 1 minute OR Firestore trigger on outbox pending
- Preferred: scheduled processor for controlled concurrency.

### Locking
- Query pending where nextAttemptAt <= now
- For each doc, attempt lock:
  - update status=processing, lockedAt=now, lockOwner=functionInstanceId
  - only if current status is pending
- If lock fails, skip

### Attempt handling
- On success: set status=sent, sentAt, updatedAt
- On failure: attempts += 1
  - if attempts < maxAttempts: status=pending, nextAttemptAt = now + backoff(attempts)
  - else: status=dead, lastError

### Backoff
- attempts 1: 1 min
- attempts 2: 5 min
- attempts 3: 15 min
- attempts 4: 60 min
- attempts 5: dead

---

## Observability and Ops
- Log eventId, outbox id, status transitions
- Add a simple admin screen later or provide a Firestore query recipe:
  - outbox where status in (failed, dead)
  - group by jobType

---

## Security and Permissions
- domain_events and outbox are internal
- Only service account can write
- Admin role can read (optional), others no direct access

---

## Acceptance Criteria
- Creating a matter emits a domain_event
- Creating an outbox record is idempotent
- Processor sends each outbox record at most once (no duplicates on retries)
- Failures move to pending with backoff; repeated failures go to dead
- Status visibility shows pending/processing/sent/failed/dead

---

## Test Plan
- Unit: idempotency key generation
- Unit: backoff schedule
- Integration: simulate function retry, confirm no duplicate outbox records
- Integration: force send failure, confirm attempts increments and dead-letter triggers
