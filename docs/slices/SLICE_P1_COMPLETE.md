# Slice P1: Domain Events + Outbox - Completion Report

**Date Completed:** 2026-01-31  
**Dependencies:** Slice 0 ✅ (Firestore, audit logging)  
**Type:** Platform infrastructure  
**Build Card:** `docs/SLICE_P1_BUILD_CARD.md`

---

## Summary

Slice P1 implements the **Domain Events + Outbox Pattern** for event-driven architecture. This provides the foundation for:
- Reliable asynchronous job processing
- Notification system (P2)
- Activity feeds
- Audit trails
- Inter-service communication

---

## What Was Delivered

### Backend (Cloud Functions)

**New Functions (1):**
1. ✅ `outboxProcessor` – Scheduled function (runs every 2 minutes) that processes pending outbox jobs

**New Utilities (`functions/src/utils/domain-events.ts`):**
- ✅ `emitDomainEventWithOutbox()` – Core event emission function
  - Atomic batch write (domain_event + outbox record)
  - Idempotency key generation
  - Event validation
- ✅ `getBackoffMs()` – Exponential backoff calculator
  - Attempt 1: 60 seconds
  - Attempt 2: 2 minutes
  - Attempt 3: 4 minutes
  - Attempt 4: 8 minutes
  - Attempt 5: 16 minutes
- ✅ `outboxIdempotencyKeyForEvent()` – Generate unique keys per event
  - Format: `notif:<orgId>:<eventId>`
  - Prevents duplicate processing

**Firestore Collections:**
- `domain_events` – Immutable event log
  - Fields: eventId, orgId, eventType, entityType, entityId, actor, payload, matterId, timestamp
- `outbox` – Async job queue
  - Fields: id, orgId, eventId, jobType, status, attempts, maxAttempts, nextAttemptAt, lastError, sentAt, createdAt, updatedAt

**Infrastructure:**
- Composite indexes:
  - `domain_events`: `orgId` + `timestamp` (desc)
  - `domain_events`: `orgId` + `matterId` + `timestamp` (desc)
- Security rules: server-only access (no direct client reads/writes)

### Event Types

**Implemented Events:**
- `invoice.sent` (Slice 11)
- `invoice.created` (Slice 11)
- `payment.received` (Slice 11)
- `comment.added` (Slice 16)
- `comment.updated` (Slice 16)
- `comment.deleted` (Slice 16)

**Future Events (ready to add):**
- `matter.created`, `matter.updated`
- `task.created`, `task.updated`, `task.assigned`, `task.completed`
- `document.uploaded`
- `user.joined`
- `client.created`

---

## Key Features

### 1. Atomic Event Emission

**Pattern:**
```typescript
await emitDomainEventWithOutbox({
  orgId: 'org123',
  eventType: 'comment.added',
  entityType: 'comment',
  entityId: 'comment456',
  actor: { actorType: 'user', actorId: 'user789' },
  payload: { body: 'Hello', matterId: 'matter123' },
  matterId: 'matter123'
});
```

**What happens:**
1. Domain event written to `domain_events` collection (immutable record)
2. Outbox job created with status `pending` and `nextAttemptAt = now`
3. Both writes in single Firestore batch (atomic)
4. `outboxProcessor` picks up job within 2 minutes

### 2. Reliable Job Processing

**Features:**
- ✅ Idempotency (duplicate prevention via unique keys)
- ✅ Exponential backoff (progressively longer delays on retry)
- ✅ Max attempts limit (5 attempts, then marked `failed`)
- ✅ Status tracking (`pending` → `processing` → `sent`/`failed`)
- ✅ Error logging (last error message stored)
- ✅ `sentAt` timestamp when job completes

**Flow:**
1. Job created with `status: pending`, `nextAttemptAt: now`
2. `outboxProcessor` runs every 2 minutes, queries jobs where `nextAttemptAt <= now` and `status in [pending, processing]`
3. Updates `status: processing`, increments `attempts`
4. Processes job (e.g., send notification via P2)
5. On success: `status: sent`, `sentAt: now`
6. On failure: `status: pending`, `nextAttemptAt: now + backoff`, stores `lastError`

### 3. Integration with P2 Notifications

**Ready for P2:**
- P2 notification routing reads from `domain_events` collection
- Outbox jobs trigger notification dispatch
- Idempotency keys prevent duplicate notifications
- Event payload includes all context needed for notification (matterId, body preview, etc.)

---

## Testing Results

### Unit Tests
✅ `functions/src/__tests__/domain-events.test.ts`
- `getBackoffMs()` calculations correct
- `outboxIdempotencyKeyForEvent()` format correct

### Integration Tests
✅ Manual testing:
- Domain events emitted on comment create/update/delete
- Outbox jobs created atomically
- `outboxProcessor` picks up and processes jobs
- Idempotency prevents duplicates

---

## Files Changed

### New Files
```
functions/src/utils/domain-events.ts
functions/src/functions/outbox-processor.ts
functions/src/__tests__/domain-events.test.ts
docs/SLICE_P1_BUILD_CARD.md
docs/slices/SLICE_P1_COMPLETE.md
```

### Modified Files
```
functions/src/index.ts (export outboxProcessor)
functions/src/functions/invoice.ts (emit events)
functions/src/functions/comment.ts (emit events)
functions/src/notifications/types.ts (event types)
firestore.rules (domain_events, outbox)
firestore.indexes.json (composite indexes)
docs/SESSION_NOTES.md
docs/status/SLICE_STATUS.md
```

---

## Deployment

**Functions Deployed:**
- `outboxProcessor` (scheduled, every 2 minutes)

**Firestore Indexes Deployed:**
- `domain_events`: `orgId` + `timestamp` (desc)
- `domain_events`: `orgId` + `matterId` + `timestamp` (desc)

**Firestore Rules Updated:**
- `domain_events` collection (server-only)
- `outbox` collection (server-only)

---

## Performance Characteristics

**Event Emission:**
- ~2 Firestore writes per event (1 domain_event + 1 outbox)
- Batched for atomicity (single transaction cost)

**Outbox Processing:**
- Scheduled every 2 minutes (configurable)
- Processes up to 500 jobs per invocation (configurable)
- Exponential backoff reduces retry storm

**Scaling:**
- Domain events collection grows linearly with activity
- Outbox collection stable (jobs removed after processing or marked `sent`)
- Consider archiving old domain events (>90 days) for cost optimization

---

## Key Design Decisions

### 1. Event-Level Outbox Records

**Decision:** One outbox job per event (not per recipient)

**Rationale:**
- P2 routing determines recipients dynamically (case access, preferences)
- Simpler event emission (don't need recipient list upfront)
- More flexible (recipients can change between event and processing)

**Trade-off:**
- P2 must query for recipients at processing time
- Idempotency key includes recipient UID to prevent duplicates

### 2. Immutable Domain Events

**Decision:** Domain events are never updated or deleted

**Benefits:**
- Complete audit trail
- Can replay events for debugging
- Activity feed always accurate

### 3. Exponential Backoff

**Decision:** Retry with increasing delays (60s → 2m → 4m → 8m → 16m)

**Benefits:**
- Reduces retry storm on persistent failures
- Gives external services time to recover
- Balances speed (first retry quick) with stability

### 4. Idempotency Keys

**Decision:** Format: `<jobType>:<orgId>:<eventId>[:<recipientUid>]`

**Benefits:**
- Prevents duplicate processing if job accidentally re-queued
- Per-recipient idempotency for notification dispatch
- Org-scoped for better debugging

---

## Next Steps

### Immediate
- ✅ P1 infrastructure complete
- ✅ Ready for P2 notification engine integration
- ✅ Slice 16 using P1 for comment events

### P2 Integration (Next)
- P2 notification routing reads `domain_events` on onCreate trigger
- P2 creates `notifications` records
- P2 creates per-recipient outbox jobs for email dispatch
- Outbox processor dispatches emails via SendGrid

### Future Enhancements
- Archive old domain events (>90 days)
- Dashboard for outbox job monitoring
- Manual retry/cancel for failed jobs
- Event replay for debugging
- Custom event types per org

---

## Lessons Learned

1. **Atomic writes are critical** – Batch writes ensure domain_event and outbox are created together
2. **Idempotency prevents pain** – Duplicate event processing would cause serious issues (double notifications, etc.)
3. **Exponential backoff is smart** – Prevents retry storms, gives systems time to recover
4. **Server-only collections** – domain_events and outbox should never be directly accessed by clients
5. **Test early** – Unit tests for utility functions caught edge cases

---

**Overall Status:** ✅ **COMPLETE & DEPLOYED**
**Build Quality:** Excellent
**Test Coverage:** Unit tests + manual integration testing
**Documentation:** Complete

---

*Last Updated: 2026-01-31*
