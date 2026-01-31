# P2 Notification Engine – tests

## Unit tests (Jest)

Templates and types are covered by Jest:

```bash
cd functions
npx jest src/__tests__/notifications.test.ts
```

No credentials needed. Run `npm run test` to run all Jest tests (including P2).

---

## Terminal test (deployed callables)

The P2 terminal test calls your **deployed** notification functions (notificationList, notificationUnreadCount, notificationPreferencesGet/Update, notificationMarkAllRead).

**Prerequisites**

1. **Firebase Web API key** – Firebase Console → Project Settings → General → Web API Key.
2. **A real user** that can sign in and has (or can create) an org.

**Run**

1. In `functions/.env` (or env), set:
   - `WEB_API_KEY` or `FIREBASE_API_KEY` = your Web API key
   - `TEST_EMAIL` = email of a user that can sign in (e.g. the one you use in Chrome)
   - `TEST_PASSWORD` = that user’s password

2. From project root or `functions`:

   ```bash
   cd functions
   npm run test:p2
   ```

If you don’t set `TEST_EMAIL` / `TEST_PASSWORD`, the script uses `test@example.com` / `testpassword123`; that user must exist in Firebase Auth for the test to pass.
