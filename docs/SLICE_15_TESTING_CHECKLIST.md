# Slice 15 Testing Checklist

**Date:** 2026-01-29  
**Scope:** Advanced Admin Features (Backend + Frontend)

---

## Backend Tests

### Prerequisites
- Firebase project: `legal-ai-app-1203e`
- Environment: **`FIREBASE_API_KEY`** must be set (from Firebase Console → Project settings → Web API Key).  
  Example (PowerShell): `$env:FIREBASE_API_KEY = "your-web-api-key"`
- Test account: Valid Firebase Auth user with ADMIN role in at least one org (update `TEST_EMAIL` / `TEST_PASSWORD` in `slice15-terminal-test.ts` if needed)

### Run Backend Tests
```bash
cd functions
npm run test:slice15
```

### Backend Test Cases (slice15-terminal-test.ts)
| # | Test | Expected |
|---|------|----------|
| 1 | orgGetSettings | Returns org name, timezone, businessHours |
| 2 | orgUpdate | Updates description, timezone, businessHours, website |
| 3 | memberUpdateProfile (self) | Updates bio, title, specialties, barAdmissions |
| 4 | memberGetProfile | Returns profile with role, bio, title |
| 5 | invitationCreate | Returns invitationId, inviteCode, email, role |
| 6 | invitationList | Returns invitations list, totalCount |
| 7 | invitationRevoke | Returns status: revoked |
| 8 | orgGetStats | Returns counts, recentActivity, storage |
| 9 | orgExport (optional) | Returns downloadUrl, fileName, counts |

### Firestore Indexes
- **invitations:** Composite index `status` (ASC) + `invitedAt` (DESC) required for filtered list.
- Deploy indexes: `firebase deploy --only firestore:indexes`
- Wait a few minutes for indexes to build after first filtered invitation list call.

---

## Frontend Unit Tests (Slice 15 models & screens)

### Run
```bash
cd legal_ai_app
flutter test test/invitation_model_test.dart test/org_settings_model_test.dart test/member_profile_model_test.dart test/org_stats_model_test.dart
```

### Tests
| File | Scope |
|------|--------|
| `invitation_model_test.dart` | InvitationModel fromJson, isPending, isExpired |
| `org_settings_model_test.dart` | OrgSettingsModel, BusinessHours, Address fromJson/toJson |
| `member_profile_model_test.dart` | MemberProfileModel, BarAdmission, Education, displayLabel |
| `org_stats_model_test.dart` | OrgStatsModel, OrgStatsCounts, StorageInfo, RecentActivity |
| `admin_settings_screen_test.dart` | Widget tests skipped (require Firebase); use manual or integration tests |

---

## Frontend Manual Testing

### Prerequisites
- Flutter app running: `cd legal_ai_app && flutter run -d chrome`
- Log in as a user with **ADMIN** role in an organization

### 1. Admin Settings Hub
- [ ] Settings → **Admin Settings** visible (ADMIN only)
- [ ] Tap Admin Settings → Hub with 5 cards: Invitations, Org Settings, Team Members, Export, Dashboard
- [ ] Back button returns to Settings

### 2. Member Invitations
- [ ] Admin Settings → **Member Invitations**
- [ ] Enter email and select role (Lawyer/Paralegal/Viewer) → Send invitation
- [ ] Snackbar shows invite code
- [ ] Filter: Pending / Accepted / Revoked
- [ ] Pending invitation shows Revoke button; revoke works
- [ ] Empty state when no invitations

### 3. Organization Settings
- [ ] Admin Settings → **Organization Settings**
- [ ] Form shows current name, description, timezone, business hours, defaults, website
- [ ] Edit and Save → success snackbar; org name updates in app bar/context if applicable
- [ ] Default case visibility (Org-wide / Private) and default task visibility toggle

### 4. Team Members → Member Profile
- [ ] Admin Settings → **Team Members** (or Settings → Team Members)
- [ ] Tap a member row → **Member Profile** screen opens with memberUid
- [ ] View: bio, title, specialties, bar admissions, phone (if set)
- [ ] Edit (pencil): change bio, title, add/remove specialties, phone → Save
- [ ] "My Profile": open profile with no memberUid (current user) → same view/edit

### 5. Organization Export
- [ ] Admin Settings → **Export Data**
- [ ] Tap "Export data" → loading → snackbar and download URL opens in new tab (or copy link)
- [ ] Last export card shows fileName and counts

### 6. Organization Dashboard
- [ ] Admin Settings → **Organization Dashboard**
- [ ] Stats load: org name, plan, counts (members, cases, clients, documents, tasks, events, notes, time entries, invoices)
- [ ] Recent activity (last 30 days): cases created, documents uploaded, tasks created, events created
- [ ] Storage: total MB
- [ ] Refresh (pull or app bar) reloads stats

### 7. Non-Admin User
- [ ] Log in as LAWYER or VIEWER
- [ ] Settings → **Admin Settings** should **not** be visible (or show "Only administrators" if route opened directly)

### 8. Navigation & State
- [ ] Back from each admin screen returns to previous screen (Admin Hub or Settings)
- [ ] After org settings update, org name refreshes where displayed
- [ ] After revoking invitation, list refreshes
- [ ] Sign out clears admin state; no stale data on next login

---

## Frontend Unit/Widget Tests (Optional)

- **Models:** `InvitationModel`, `OrgSettingsModel`, `MemberProfileModel`, `OrgStatsModel` fromJson
- **AdminService:** Mock CloudFunctionsService and assert correct function names and payloads
- **AdminProvider:** Test loadInvitations, loadOrgSettings, createInvitation, revokeInvitation, etc. with mocked service

Example location: `legal_ai_app/test/features/admin/`

---

## Integration (E2E) Notes

- **Invitation flow:** Admin sends invite → copy code → second user (with same email in Firebase Auth) signs in → call `invitationAccept` with code (e.g. from a simple "Join with code" screen or API test) → user appears in Team Members
- **Export:** Trigger export → open download URL in browser → verify JSON structure (organization, members, cases, …)

---

## Known Limitations

- Invitation **email** is not sent automatically (no SendGrid/Postmark); invite code must be shared manually.
- **invitationList** with status filter requires Firestore composite index (status + invitedAt); deploy indexes if you see a missing-index error.
- **url_launcher** may not open signed URLs in all environments; user can copy link from snackbar if needed.

---

## Sign-Off

| Area | Status | Notes |
|------|--------|-------|
| Backend tests (test:slice15) | ☐ | Run with FIREBASE_API_KEY |
| Admin Hub + navigation | ☐ | |
| Invitations (send, list, revoke) | ☐ | |
| Organization Settings | ☐ | |
| Member Profile (view/edit) | ☐ | |
| Export Data | ☐ | |
| Organization Dashboard | ☐ | |
| Non-ADMIN access | ☐ | |
| Firestore indexes | ☐ | Deploy if using invitation status filter |
