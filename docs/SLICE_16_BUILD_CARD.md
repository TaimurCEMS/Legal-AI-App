# Slice 16 Build Card: Comments + Activity Feed

**Status:** 🟢 IMPLEMENTED & DEPLOYED  
**Priority:** High (depends on P1 + P2)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 5.5 ✅, **P1 Domain Events + Outbox ✅**, **P2 Notification Engine** (routed)  
**Date Created:** 2026-01-30  
**Date Completed:** 2026-01-31  
**Spec Reference:** MASTER_SPEC_V2.0.md §5, §7

---

## 📋 Overview

Slice 16 adds **Comments** on entities (matters, tasks, documents) and a user-facing **Activity Feed** derived from domain events. Comments trigger notifications via P2; activity feed shows "who did what, when" for matters the user can access.

**Key Features:**
1. **Comments** – Add, edit, delete comments on matters, tasks, and documents; permission-aware; optional @mentions (future).
2. **Activity Feed** – Timeline of recent actions (matter created, task assigned, document uploaded, comment added, etc.) scoped by matter and permissions.

**Deferred:**
- @mentions and mention notifications (can be added in a follow-up).
- Rich text / markdown in comments (plain text MVP).
- Real-time updates for comments (tried but reverted to backend-loaded approach for security and architecture consistency).

---

## 🎯 Success Criteria

### Backend
- ✅ Comment CRUD (create, get, list, update, delete) with entity linkage (matterId, taskId, documentId).
- ✅ All comment operations enforce case/matter access via `canUserAccessCase`.
- ✅ Emit domain events: `comment.added`, `comment.updated`, `comment.deleted` for P2 notification routing and audit trail.
- ✅ Activity feed API: list recent activity for a matter or org-wide, filtered by permissions; derived from domain_events.

### Frontend
- ✅ Comment UI on Matter details, Task details, and Document details (thread or list).
- ✅ Activity Feed screen entry point on Home dashboard (showing timeline with deep links).
- ✅ Author display names resolved from MemberProvider (shows actual user names).

### Testing
- ✅ Backend: permission checks, case access, domain event emission for all comment operations.
- ✅ Frontend: add/edit/delete comment, activity feed integration, author name display.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. Comments
- **`commentCreate`** – Create comment on a matter, task, or document (exactly one of matterId, taskId, documentId).
- **`commentGet`** – Get single comment (with case access check).
- **`commentList`** – List comments by matterId, or by taskId, or by documentId (paginated).
- **`commentUpdate`** – Update own comment (body only).
- **`commentDelete`** – Soft delete own comment (or ADMIN).

**Data Model (Comments):**
```typescript
// Collection: organizations/{orgId}/comments/{commentId}
interface CommentDocument {
  commentId: string;
  orgId: string;
  matterId: string;       // required for all (task/document belong to matter)
  taskId?: string;        // optional, if comment is on task
  documentId?: string;    // optional, if comment is on document
  authorUid: string;
  body: string;           // plain text MVP
  createdAt: Timestamp;
  updatedAt: Timestamp;
  deletedAt?: Timestamp;
}
```

**Event emission:** On create (and optionally update/delete), write to `domain_events` with `eventType: comment.added` (or `comment.updated`, `comment.deleted`), so P2 can route in-app/email notifications.

#### 2. Activity Feed
- **`activityFeedList`** – List recent activity for org or for a single matter; filters by `canUserAccessCase` for matter-scoped events; returns list of activity items (eventType, entityType, entityId, matterId, actor, timestamp, human-readable summary, deepLink).

**Source of data:** Query `domain_events` (or materialized `activity_feed` if we add one) with ordering by timestamp desc, limit/offset. Map eventType to display label and deepLink (e.g. matter.created → "Matter created", link to matter details).

### Frontend (Flutter)

#### 1. Comment Widget / Section
- Reusable widget: `CommentListSection(entityType: matter|task|document, entityId, matterId)`.
- Shows list of comments, "Add comment" field, edit/delete for own comments.
- Used in: Matter details, Task details, Document details.

#### 2. Activity Feed Screen
- **ActivityFeedScreen** – List/grid of activity items; filters: All / This matter; date range optional; "Load more".
- Each item: icon, summary text, timestamp, link to matter/task/document.

#### 3. Models / Services / Providers
- **CommentModel**, **CommentService**, **CommentProvider**.
- **ActivityFeedModel** (item with eventType, entityType, entityId, matterId, actorDisplayName, timestamp, summary, deepLink).
- **ActivityFeedService**, **ActivityFeedProvider**.

---

## 🔐 Security & Permissions

- **Comments:** Create/list/get/update/delete require org membership and `canUserAccessCase(matterId)`. Update/delete: author or ADMIN.
- **Activity feed:** Requires org membership; matter-scoped events only included if `canUserAccessCase(matterId)`.
- Firestore rules: `organizations/{orgId}/comments/{commentId}` – read/write only if org member and case access; same for any `activity_feed` collection if used.

---

## 📊 Data Flow

1. **User adds comment:** Flutter → `commentCreate` → validate matter/task/document access → write comment doc → emit `comment.added` domain event → P2 creates in-app (and email) notifications for relevant recipients.
2. **User opens Activity:** Flutter → `activityFeedList` → backend queries events, filters by case access → returns list → UI renders with links.

---

## 📝 Backend Endpoints (Slice 4 style)

### commentCreate
- **Auth:** Required. **Permission:** Org member; case access for matterId.
- **Request:** `{ orgId, matterId, taskId?, documentId?, body }` (exactly one of taskId or documentId optional; matterId always present).
- **Success:** `{ commentId, orgId, matterId, taskId?, documentId?, authorUid, body, createdAt, updatedAt }`.
- **Errors:** VALIDATION_ERROR, NOT_FOUND, FORBIDDEN.
- **Flow:** Validate auth → org membership → canUserAccessCase(matterId) → validate body length → create comment doc → emit domain_event comment.added → return.

### commentGet
- **Request:** `{ orgId, commentId }`.
- **Success:** Full comment document.
- **Flow:** Auth → org → load comment → resolve matterId → canUserAccessCase → return.

### commentList
- **Request:** `{ orgId, matterId?, taskId?, documentId?, limit?, offset? }` (one of matterId, taskId, documentId required).
- **Success:** `{ comments: [...], total, hasMore }`.
- **Flow:** Auth → org → canUserAccessCase(matterId) → query comments by matterId/taskId/documentId, exclude deleted → paginate → return.

### commentUpdate
- **Request:** `{ orgId, commentId, body }`.
- **Flow:** Auth → org → load comment → case access → author or ADMIN → update body, updatedAt → optionally emit comment.updated → return.

### commentDelete
- **Request:** `{ orgId, commentId }`.
- **Flow:** Auth → org → load comment → case access → author or ADMIN → soft delete (deletedAt) → return.

### activityFeedList
- **Request:** `{ orgId, matterId?, limit?, offset?, fromAt?, toAt? }`.
- **Success:** `{ items: [{ eventId, eventType, entityType, entityId, matterId, actorUid, actorDisplayName?, timestamp, summary, deepLink }], hasMore }`.
- **Flow:** Auth → org → query domain_events (orgId, optional matterId, date range) → for each event with matterId, filter by canUserAccessCase → map to summary + deepLink → return.

---

## 🧪 Testing Strategy

- **Backend:** Unit tests for comment CRUD and access control; activity feed filtering (private matter events hidden).
- **Frontend:** Manual: add comment on matter/task/document, edit, delete; open Activity feed, click links.
- **Integration:** Comment created → domain event present → (with P2) notification appears.

---

## ✅ Implementation Summary

### What Was Delivered

**Backend (Cloud Functions):**
- ✅ `commentCreate` – Create comments with domain event emission
- ✅ `commentGet` – Get single comment with access control
- ✅ `commentList` – List comments by matterId/taskId/documentId
- ✅ `commentUpdate` – Update comment body with `comment.updated` event
- ✅ `commentDelete` – Soft delete with `comment.deleted` event
- ✅ `activityFeedList` – List activity feed from domain_events
- ✅ Domain events: `comment.added`, `comment.updated`, `comment.deleted`
- ✅ P2 notification routing configured for all comment events

**Frontend (Flutter):**
- ✅ CommentProvider – Backend-loaded state management (no real-time due to architecture)
- ✅ CommentListSection widget – Reusable comment UI for matter/task/document
- ✅ ActivityFeedScreen – Dedicated activity feed view
- ✅ ActivityFeedProvider – State management for activity feed
- ✅ Author name resolution via MemberProvider
- ✅ SnackBar feedback for comment post success/failure
- ✅ Integration in CaseDetailsScreen, TaskDetailsScreen, DocumentDetailsScreen
- ✅ Home dashboard "Activity" card entry point

**Infrastructure:**
- ✅ Firestore indexes for comments (matterId, taskId, documentId with createdAt)
- ✅ Firestore indexes for domain_events (orgId+timestamp, orgId+matterId+timestamp)
- ✅ Firestore security rules for comments (case access enforcement)
- ✅ Updated models to support Firestore Timestamp (for potential future real-time)

### Key Decisions

1. **Backend-Loaded Architecture:** After attempting real-time Firestore listeners, reverted to Cloud Functions approach for:
   - Better security (complex case access rules work properly)
   - Consistent architecture (all data flows through backend)
   - Audit trail through functions
   - Lower Firebase costs (no active listeners)

2. **Full Audit Trail:** All comment operations (create/update/delete) emit domain events for complete history tracking

3. **Notification Routing:** All comment events routed through P2 notification system for future email/push notifications

### Real-Time Attempt (Deferred)

**What was tried:**
- Implemented Firestore real-time listeners (`snapshots()`) for comments, tasks, and cases
- Updated models to handle both Firestore `Timestamp` objects and ISO strings
- Added automatic fallback to Cloud Functions on permission errors

**Why reverted:**
- Firestore security rules for complex case access checks (`canAccessCase`) don't work with list queries
- Real-time creates architecture inconsistency (some data direct, some via functions)
- Backend-loaded approach preferred for legal app (controlled, audited, secure)

**Future consideration:**
- Could simplify rules for org-member-only access to enable real-time
- Trade-off: real-time updates vs. granular case-level security enforcement at Firestore level

### Testing Results

✅ **Backend:**
- Comment CRUD operations working
- Domain events emitted correctly
- Case access enforcement validated
- Activity feed filtering by permissions

✅ **Frontend:**
- Comments display with actual author names
- Add/edit/delete working with feedback
- Activity feed integrated in Home dashboard
- Cross-entity commenting (matter/task/document)

---

## 📚 References

- MASTER_SPEC_V2.0.md §2 (Domain Events), §4 (Notifications), §5 (Activity)
- SLICE_P1_BUILD_CARD.md, SLICE_P2_BUILD_CARD.md

---

**Last Updated:** 2026-01-31
