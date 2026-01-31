# Slice 16: Comments + Activity Feed - Completion Report

**Date Completed:** 2026-01-31  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 5.5 ✅, P1 ✅  
**Build Card:** `docs/SLICE_16_BUILD_CARD.md`

---

## Summary

Slice 16 adds **Comments** on entities (matters, tasks, documents) and an **Activity Feed** showing "who did what, when" for auditable collaboration. All comment operations emit domain events (via P1) for full audit trails and notification routing (via P2).

---

## What Was Delivered

### Backend (Cloud Functions)

**New Functions (6):**
1. ✅ `commentCreate` – Create comment with domain event emission
2. ✅ `commentGet` – Get single comment with case access check
3. ✅ `commentList` – List comments by matterId/taskId/documentId (paginated)
4. ✅ `commentUpdate` – Update comment body + emit `comment.updated` event
5. ✅ `commentDelete` – Soft delete + emit `comment.deleted` event
6. ✅ `activityFeedList` – List activity feed from domain_events collection

**Security & Access:**
- All comment operations enforce case access via `canUserAccessCase` helper
- Comments inherit matter visibility (ORG_WIDE/PRIVATE with participants)
- Activity feed filtered by user's matter permissions (no private matter leakage)
- Unauthorized access returns "not found" (no existence leakage)

**Domain Events:**
- `comment.added` – Emitted on comment creation
- `comment.updated` – Emitted on comment body update
- `comment.deleted` – Emitted on soft delete
- All events routed through P2 notification system for future email/push notifications

**Infrastructure:**
- Firestore collection: `organizations/{orgId}/comments/{commentId}`
- Composite indexes:
  - `matterId` + `createdAt` (desc)
  - `taskId` + `createdAt` (desc)
  - `documentId` + `createdAt` (desc)
- Security rules: case access enforcement, writes via Admin SDK only

### Frontend (Flutter)

**New Files:**
- `CommentModel` – Data model for comments
- `CommentService` – Service for comment CRUD operations
- `CommentProvider` – State management (backend-loaded architecture)
- `CommentListSection` – Reusable comment UI widget
- `ActivityFeedModel` – Data model for activity feed items
- `ActivityFeedService` – Service for activity feed operations
- `ActivityFeedProvider` – State management for activity feed
- `ActivityFeedScreen` – Dedicated activity feed view

**Modified Screens:**
- `CaseDetailsScreen` – Added comments section (visible)
- `TaskDetailsScreen` – Added comments section (when linked to case)
- `DocumentDetailsScreen` – Added comments section
- `HomeScreen` – Added "Activity" card entry point

**Features:**
- Comment list with author name resolution (via MemberProvider)
- Add/edit/delete with SnackBar feedback
- "Post" button for new comments
- Edit/delete actions for owned comments
- Empty state handling ("No comments yet")
- Activity feed showing org-wide activity (filtered by permissions)

---

## Testing Results

### Backend
✅ Comment CRUD operations working  
✅ Domain events emitted correctly for all operations  
✅ Case access enforcement validated  
✅ Activity feed filtering by permissions  
✅ Idempotent comment delete

### Frontend
✅ Comments display with actual author names  
✅ Add/edit/delete working with user feedback  
✅ Activity feed integrated in Home dashboard  
✅ Cross-entity commenting (matter/task/document)  
✅ Empty states and error handling

---

## Key Decisions

### 1. Backend-Loaded Architecture (Not Real-Time)

**What was tried:**
- Implemented Firestore real-time listeners (`snapshots()`) for comments, cases, and tasks
- Added automatic fallback to Cloud Functions on permission errors
- Updated models to handle both Firestore `Timestamp` objects and ISO strings

**Why reverted:**
- Firestore security rules with complex access checks (`canAccessCase`) don't work with list queries
- Real-time creates architecture inconsistency (mix of direct Firestore and Cloud Functions)
- Legal app requirements favor controlled, audited access through backend

**Final approach:**
- All data fetched via Cloud Functions (backend-loaded)
- Optimistic UI updates for instant feedback where appropriate
- Clear user feedback via SnackBars
- Models retain `Timestamp` parsing for future flexibility

**Trade-offs:**
- ❌ No instant live updates across users
- ✅ Better security (complex rules work properly)
- ✅ Consistent architecture (all audited)
- ✅ Lower Firebase costs (no active listeners)
- ✅ Complete audit trail

### 2. Full Audit Trail for Comments

**Decision:** Emit domain events for create, update, AND delete (not just create)

**Benefits:**
- Complete history of all comment changes
- Activity feed shows edits and deletes
- Supports future compliance requirements
- Enables notifications for comment changes

### 3. Author Name Resolution

**Decision:** Resolve author UIDs to display names via `MemberProvider`

**Implementation:**
- `_getAuthorDisplayName()` helper function
- Fallbacks: displayName → email → truncated UID
- Cached member data prevents repeated lookups

---

## Files Changed

### New Files
```
functions/src/functions/comment.ts
functions/src/functions/activity-feed.ts
legal_ai_app/lib/core/models/comment_model.dart
legal_ai_app/lib/core/models/activity_feed_model.dart
legal_ai_app/lib/core/services/comment_service.dart
legal_ai_app/lib/core/services/activity_feed_service.dart
legal_ai_app/lib/features/comments/providers/comment_provider.dart
legal_ai_app/lib/features/comments/widgets/comment_list_section.dart
legal_ai_app/lib/features/activity_feed/providers/activity_feed_provider.dart
legal_ai_app/lib/features/activity_feed/screens/activity_feed_screen.dart
docs/slices/SLICE_16_COMPLETE.md
```

### Modified Files
```
functions/src/index.ts (exports)
functions/src/notifications/types.ts (ROUTED_EVENT_TYPES)
functions/src/notifications/routing.ts (buildTitleAndBody cases)
functions/src/notifications/deep-link.ts (comment link handling)
firestore.rules (comments access rules)
firestore.indexes.json (comment composite indexes)
legal_ai_app/lib/app.dart (provider imports)
legal_ai_app/lib/core/routing/route_names.dart (activityFeed route)
legal_ai_app/lib/core/routing/app_router.dart (ActivityFeedScreen route)
legal_ai_app/lib/features/cases/screens/case_details_screen.dart (_buildCommentsSection)
legal_ai_app/lib/features/tasks/screens/task_details_screen.dart (comments integration)
legal_ai_app/lib/features/documents/screens/document_details_screen.dart (comments integration)
legal_ai_app/lib/features/home/screens/home_screen.dart (Activity card + scroll fix)
legal_ai_app/pubspec.yaml (cloud_firestore dependency)
docs/SLICE_16_BUILD_CARD.md (implementation details)
docs/SESSION_NOTES.md (session updates)
docs/status/SLICE_STATUS.md (Slice 16 status)
docs/DEVELOPMENT_LEARNINGS.md (Learning 67)
```

---

## Deployment

**Functions Deployed:**
- `commentCreate`
- `commentGet`
- `commentList`
- `commentUpdate` (**new** - with domain event)
- `commentDelete` (**new** - with domain event)
- `activityFeedList`

**Firestore Indexes Deployed:**
- `organizations/{orgId}/comments`: `matterId` + `createdAt` (desc)
- `organizations/{orgId}/comments`: `taskId` + `createdAt` (desc)
- `organizations/{orgId}/comments`: `documentId` + `createdAt` (desc)
- `domain_events`: `orgId` + `timestamp` (desc)
- `domain_events`: `orgId` + `matterId` + `timestamp` (desc)

**Firestore Rules Updated:**
- Comments collection (case access enforcement)
- Domain events collection (server-only)

---

## Bug Fixes

1. ✅ **commentCreate 500 error** – Sanitized event payload to remove `undefined` values, wrapped event emission in try-catch
2. ✅ **Client dropdown assertion error** – Deduplicated items, handle null value properly
3. ✅ **Home screen overflow** – Wrapped Column in SingleChildScrollView
4. ✅ **Comment author showing "User"** – Resolved actual names via MemberProvider

---

## Performance

- Comments loaded via Cloud Functions (no real-time overhead)
- Pagination support (limit/offset) for large comment threads
- Activity feed paginated (limit/offset)
- Author name lookups cached in MemberProvider

---

## Next Steps

### Immediate
- ✅ All TODOs completed
- ✅ Documentation updated
- Ready for GitHub sync

### Future Enhancements (Deferred)
- @mentions in comments (with notification routing)
- Rich text/markdown support in comment body
- Real-time updates (if/when rules simplified or architecture changes)
- Comment reactions/likes
- Comment threading/replies
- Attachment support

---

## Lessons Learned

1. **Real-time isn't always better** – Backend-loaded can be more secure and consistent
2. **Complex Firestore rules** – Don't work well with real-time list queries
3. **Full audit trail** – Emit events for all operations (create/update/delete), not just creates
4. **Architecture consistency** – All data through one path (backend) is simpler and more maintainable
5. **User feedback matters** – SnackBars for success/failure improve UX significantly

---

**Overall Status:** ✅ **COMPLETE & DEPLOYED**
**Build Quality:** Excellent
**Test Coverage:** Manual testing complete
**Documentation:** Complete

---

*Last Updated: 2026-01-31*
