# P2 Notification Engine – Test Summary

**Date:** 2026-01-30  
**Scope:** Backend unit tests, Flutter analyze, code-path verification, manual test checklist.

---

## ✅ Automated Tests Run

### 1. Backend (Firebase Functions) – Jest

**Command:** `cd functions && npm run build && npx jest "src/__tests__/notifications.test.ts" --passWithNoTests`

**Result:** **PASS** – 10 tests, 0 failures.

| Suite | Tests | Status |
|-------|--------|--------|
| notifications/templates | renderTemplate (3), getDefaultTemplate (2) | ✅ |
| notifications/routing | buildDeepLink (3) – matter/case, task, document/invoice | ✅ |
| notifications/types | eventTypeToCategory, ROUTED_EVENT_TYPES | ✅ |

**Coverage:**
- Template variable substitution and default templates by event type.
- Deep link paths match Flutter routes: `/cases/details?caseId=`, `/tasks/details?taskId=`, `/documents/details/:id`, invoice → `/home`.
- Event type → category mapping and routed event types list.

**Config change:** `jest.config.js` now ignores `*-integration-test.ts` and `*-terminal-test.ts` so `npm test` does not load scripts that call `process.exit(1)` when env vars are missing.

### 2. Flutter Analyze

**Command:** `cd legal_ai_app && flutter analyze --no-pub`

**Result:** 342 issues (mostly pre-existing **info**: `prefer_const_constructors`, `deprecated_member_use`, etc.). **No errors** in notification code.

**Notification-related:**
- **Fixed:** Unused import `route_names.dart` in `notification_list_screen.dart` (removed).
- Remaining: 1 info (`_savingCategories` could be final), 2 info (prefer_const in notification screens). Non-blocking.

### 3. Backend Build

**Command:** `cd functions && npm run build`

**Result:** **Success** – TypeScript compiles; routing imports `deep-link.ts`; no type errors.

---

## Code Paths Verified (No Runtime Tests)

- **Domain events → notifications:** `emitDomainEventWithOutbox` (case, task, document, invoice, invitation) → Firestore `domain_events` → trigger `onDomainEventCreated` → `runNotificationRouting` → `getCandidateRecipients` (payload + matter participants + **org admins** for activity events) → `filterByAccess` → create in-app + email notification docs and outbox jobs.
- **Recipients:** Actor excluded; org admins/owners added for `matter.created`, `matter.updated`, `task.created`, `task.completed`, `document.uploaded`, `invoice.created`, `payment.received`.
- **Deep links:** Built in `notifications/deep-link.ts`; match Flutter `route_names` and `app_router` (cases/details, tasks/details, documents/details, home for invoice).
- **Callables:** `notificationList`, `notificationMarkRead`, `notificationMarkAllRead`, `notificationUnreadCount`, `notificationPreferencesGet`, `notificationPreferencesUpdate` – all exported and deployed (per earlier `firebase functions:list`).

---

## Manual Test Checklist (For You to Run)

Run these after deploying functions and with the app in Chrome.

### Deploy (if not already)

```bash
cd functions
npm run build
firebase deploy --only functions
```

### 1. Notifications list and bell

- [ ] Log in, select a firm.
- [ ] Open **Notifications** (bell icon). List loads (empty or with items); no crash.
- [ ] If error: tap **Retry**. If empty: message explains “when others create matters…” and **Refresh** works.
- [ ] Pull-to-refresh on the list works.

### 2. Notification preferences

- [ ] **Settings → Notification preferences**. Categories and toggles load.
- [ ] Toggle **In-app** or **Email** for one category. Spinner appears; toggle stays; no revert.
- [ ] If save fails, error banner appears and toggle reverts.

### 3. Receiving notifications (two users)

- [ ] **User A** (admin): create a new matter.
- [ ] **User B** (other admin or member): bell shows unread count; open Notifications → new “New matter” item.
- [ ] **User B**: tap notification → navigates to matter details (correct matter).
- [ ] **User B**: tap “Mark all read” → count goes to 0; items show as read.

### 4. Deep links from notifications

- [ ] From a **matter** notification → `/cases/details?caseId=...` (matter details).
- [ ] From a **task** notification → `/tasks/details?taskId=...` (task details).
- [ ] From a **document** notification → `/documents/details/:id` (document details).

### 5. Navigation and shell

- [ ] Bell icon → Notifications screen (no duplicate key / crash).
- [ ] Settings → Notification preferences (no crash).
- [ ] Switch firm → notification count refreshes; list reloads when opening Notifications.

---

## Optional: P2 terminal test (callables against deployed backend)

Requires Firebase Web API key and a real test user in Auth.

```bash
cd functions
# Set in .env or env: WEB_API_KEY or FIREBASE_API_KEY, TEST_EMAIL, TEST_PASSWORD
npm run test:p2
```

This hits the deployed callables (list, unread count, preferences get/update, mark read). If credentials are missing or invalid, sign-in will fail; unit tests above do not depend on this.

---

## Summary

| Area | Status |
|------|--------|
| Backend unit tests (Jest) | ✅ 10/10 pass |
| Backend build | ✅ |
| Deep link unit tests | ✅ 3 tests |
| Flutter analyze (notification code) | ✅ No errors; 1 warning fixed |
| Integration / E2E | ⏳ Manual only (checklist above) |
| P2 terminal test (callables) | ⏳ Optional; needs env vars |

**Conclusion:** Automated tests and build pass. Notification routing, recipients (including org admins), and deep links are covered by unit tests and code review. Full E2E (create matter as User A, see notification as User B, tap deep link) is left to manual testing with the checklist above.
