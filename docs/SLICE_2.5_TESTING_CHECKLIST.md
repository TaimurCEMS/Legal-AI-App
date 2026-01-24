# Slice 2.5: Member Management - Testing Checklist

## Pre-Deployment Checks ✅

### Code Review
- [x] Function signatures correct (`functions.https.onCall`)
- [x] All imports present
- [x] Error codes defined (`SAFETY_ERROR` added)
- [x] Functions exported in `index.ts`
- [x] Firestore rules updated
- [x] Frontend models, services, providers created
- [x] Navigation routes added
- [x] Provider registered in `app.dart`
- [x] **CRITICAL FIX**: Transaction bug fixed (cannot use `transaction.get()` on collection)

## Backend Function Testing

### 1. `memberListMembers` Function

#### Test Case 1.1: Success - ADMIN lists members
**Setup:**
- User with ADMIN role in organization
- Organization has 2+ members

**Steps:**
1. Call `memberListMembers` with valid `orgId`
2. Authenticate as ADMIN user

**Expected:**
- Returns `success: true`
- `data.members` array contains all members
- Each member has: `uid`, `email`, `displayName`, `role`, `joinedAt`, `isCurrentUser`
- Members sorted by role (ADMIN first), then by `joinedAt` (oldest first)
- Current user marked with `isCurrentUser: true`

#### Test Case 1.2: Permission Denied - Non-ADMIN
**Setup:**
- User with LAWYER/PARALEGAL/VIEWER role

**Steps:**
1. Call `memberListMembers` with valid `orgId`

**Expected:**
- Returns `success: false`
- Error code: `NOT_AUTHORIZED`
- Message: "You don't have permission to manage team members"

#### Test Case 1.3: Not a Member
**Setup:**
- User not a member of the organization

**Steps:**
1. Call `memberListMembers` with valid `orgId` for different org

**Expected:**
- Returns `success: false`
- Error code: `NOT_AUTHORIZED`
- Message: "You are not a member of this organization"

#### Test Case 1.4: Missing orgId
**Steps:**
1. Call `memberListMembers` without `orgId` or with empty string

**Expected:**
- Returns `success: false`
- Error code: `ORG_REQUIRED`
- Message: "Organization ID is required"

#### Test Case 1.5: Organization Not Found
**Steps:**
1. Call `memberListMembers` with non-existent `orgId`

**Expected:**
- Returns `success: false`
- Error code: `NOT_FOUND`
- Message: "Organization does not exist"

#### Test Case 1.6: Empty Members List
**Setup:**
- Organization with no members (shouldn't happen, but test edge case)

**Expected:**
- Returns `success: true`
- `data.members` is empty array `[]`
- `data.totalCount` is `0`

#### Test Case 1.7: Batch User Lookup
**Setup:**
- Organization with 5+ members

**Steps:**
1. Call `memberListMembers`

**Expected:**
- All members have email/displayName populated (or null if user deleted)
- Function completes in reasonable time (< 3 seconds)

### 2. `memberUpdateRole` Function

#### Test Case 2.1: Success - ADMIN updates role
**Setup:**
- ADMIN user
- Target member with VIEWER role
- Organization has 2+ ADMINs (if changing from ADMIN)

**Steps:**
1. Call `memberUpdateRole` with:
   - `orgId`: valid org
   - `memberUid`: valid member UID
   - `role`: "LAWYER"

**Expected:**
- Returns `success: true`
- `data.role` is "LAWYER"
- `data.previousRole` is "VIEWER"
- `data.updatedAt` is ISO timestamp
- `data.updatedBy` is requester's UID
- Audit event created with action `member.role.updated`
- Member document in Firestore updated

#### Test Case 2.2: Permission Denied - Non-ADMIN
**Setup:**
- User with LAWYER role

**Steps:**
1. Call `memberUpdateRole` to change another member's role

**Expected:**
- Returns `success: false`
- Error code: `NOT_AUTHORIZED`
- Message: "You don't have permission to manage team members"

#### Test Case 2.3: Self-Role-Change Prevention
**Setup:**
- ADMIN user

**Steps:**
1. Call `memberUpdateRole` with `memberUid` = own UID

**Expected:**
- Returns `success: false`
- Error code: `SAFETY_ERROR`
- Message: "You cannot change your own role"

#### Test Case 2.4: Last ADMIN Prevention
**Setup:**
- Organization with only 1 ADMIN
- ADMIN user tries to change own role (via another admin) or demote the only ADMIN

**Steps:**
1. Call `memberUpdateRole` to change the only ADMIN to another role

**Expected:**
- Returns `success: false`
- Error code: `SAFETY_ERROR`
- Message: "Cannot remove the last administrator. Please assign another member as administrator first."

#### Test Case 2.5: Invalid Role Value
**Steps:**
1. Call `memberUpdateRole` with `role: "INVALID_ROLE"`

**Expected:**
- Returns `success: false`
- Error code: `VALIDATION_ERROR`
- Message: "Invalid role value. Must be one of: ADMIN, LAWYER, PARALEGAL, VIEWER"

#### Test Case 2.6: Role Unchanged
**Steps:**
1. Call `memberUpdateRole` to set role to same current role

**Expected:**
- Returns `success: false`
- Error code: `VALIDATION_ERROR`
- Message: "Role cannot be changed to the same value"

#### Test Case 2.7: Member Not Found
**Steps:**
1. Call `memberUpdateRole` with non-existent `memberUid`

**Expected:**
- Returns `success: false`
- Error code: `NOT_FOUND`
- Message: "Member not found in this organization"

#### Test Case 2.8: Only ADMIN Can Assign ADMIN
**Setup:**
- User with LAWYER role (somehow bypassed permission check - edge case)

**Steps:**
1. Try to assign ADMIN role to another member

**Expected:**
- Returns `success: false`
- Error code: `NOT_AUTHORIZED`
- Message: "Only administrators can assign the administrator role"

#### Test Case 2.9: Concurrent Updates
**Setup:**
- Two ADMIN users
- Same target member

**Steps:**
1. Both admins simultaneously call `memberUpdateRole` for same member with different roles

**Expected:**
- One succeeds
- One fails with transaction conflict or validation error
- Final role is one of the two requested roles (not corrupted)

#### Test Case 2.10: Audit Logging
**Steps:**
1. Successfully update a member's role

**Expected:**
- Audit event created in `organizations/{orgId}/audit_events/{eventId}`
- Event has:
  - `action`: "member.role.updated"
  - `entityType`: "membership"
  - `entityId`: member UID
  - `metadata.previousRole`: old role
  - `metadata.newRole`: new role
  - `metadata.memberEmail`: member's email (or null)

## Frontend Testing

### 3. Member Management Screen

#### Test Case 3.1: Access Control - ADMIN
**Setup:**
- User logged in as ADMIN

**Steps:**
1. Navigate to Settings
2. Click "Team Members"

**Expected:**
- Screen loads successfully
- Member list displays
- Role dropdowns visible for all members (except current user)

#### Test Case 3.2: Access Control - Non-ADMIN
**Setup:**
- User logged in as LAWYER/VIEWER

**Steps:**
1. Navigate to Settings

**Expected:**
- "Team Members" option NOT visible in Settings

#### Test Case 3.3: Member List Display
**Steps:**
1. Open Team Members screen

**Expected:**
- All members displayed
- Each member shows:
  - Avatar with initial
  - Display name (or email if no display name)
  - Email (if different from display name)
  - Role badge (color-coded)
  - Joined date (formatted)
  - "You" badge for current user
- Members sorted correctly (ADMIN first, then by joined date)

#### Test Case 3.4: Role Update - Success
**Steps:**
1. Select different role from dropdown
2. Wait for update

**Expected:**
- Optimistic UI: Role changes immediately
- Loading indicator shows during update
- Success snackbar: "Role updated successfully"
- Member list refreshes with new role
- Role badge updates

#### Test Case 3.5: Role Update - Error Handling
**Setup:**
- Try to change own role (should be blocked by backend)

**Steps:**
1. Attempt to change role (if UI allows)

**Expected:**
- Error snackbar with backend error message
- Role reverts to previous value (optimistic rollback)
- Error message matches backend exactly

#### Test Case 3.6: Loading States
**Steps:**
1. Open Team Members screen
2. Pull to refresh

**Expected:**
- Loading spinner during initial load
- Refresh indicator during pull-to-refresh
- Empty state if no members
- Error message if load fails (with retry button)

#### Test Case 3.7: Empty State
**Setup:**
- Organization with no members (edge case)

**Expected:**
- Empty state widget displayed
- Message: "No members found in this organization."

#### Test Case 3.8: Current User Highlighting
**Steps:**
1. View member list

**Expected:**
- Current user has "You" badge
- Current user's row does NOT have role dropdown (cannot change own role)

#### Test Case 3.9: Navigation
**Steps:**
1. Navigate: Settings → Team Members
2. Press back button

**Expected:**
- Returns to Settings screen
- State preserved

#### Test Case 3.10: State Clearing
**Steps:**
1. View member list
2. Switch organizations
3. Return to Team Members

**Expected:**
- Member list cleared on org switch
- New org's members loaded

## Integration Testing

### 4. End-to-End Flow

#### Test Case 4.1: Complete Role Update Flow
**Setup:**
- ADMIN user
- Organization with 2+ members

**Steps:**
1. Login as ADMIN
2. Navigate to Settings → Team Members
3. View member list
4. Change a member's role from VIEWER to LAWYER
5. Verify member list updates
6. Logout and login as the updated member
7. Verify new permissions (can create cases/documents)

**Expected:**
- All steps complete successfully
- Role change persists
- Permissions update immediately

#### Test Case 4.2: Multi-User Scenario
**Setup:**
- 3 users: 1 ADMIN, 2 VIEWERs
- All in same organization

**Steps:**
1. ADMIN changes VIEWER1 to LAWYER
2. VIEWER1 (now LAWYER) creates a case
3. ADMIN changes LAWYER back to VIEWER
4. VIEWER1 (now VIEWER) tries to create case

**Expected:**
- Step 2: Success (LAWYER can create)
- Step 4: Permission denied (VIEWER cannot create)

## Performance Testing

### 5. Performance Checks

#### Test Case 5.1: Large Team
**Setup:**
- Organization with 20+ members

**Steps:**
1. Load member list

**Expected:**
- Loads in < 3 seconds
- All members displayed
- Batch user lookup works efficiently

#### Test Case 5.2: Rapid Updates
**Steps:**
1. Quickly change multiple members' roles in succession

**Expected:**
- Each update completes successfully
- No race conditions
- UI remains responsive

## Security Testing

### 6. Security Checks

#### Test Case 6.1: Unauthenticated Access
**Steps:**
1. Call functions without authentication

**Expected:**
- Functions throw `unauthenticated` error
- No data returned

#### Test Case 6.2: Cross-Organization Access
**Setup:**
- User is ADMIN in Org A, not member of Org B

**Steps:**
1. Try to list/update members in Org B

**Expected:**
- Returns `NOT_AUTHORIZED`
- No data leaked

#### Test Case 6.3: Firestore Rules
**Steps:**
1. Try to directly read/write members collection from client

**Expected:**
- Reads allowed (all org members can read)
- Writes denied (only via Cloud Functions)

## Deployment Checklist

### Before Deployment
- [ ] All backend functions compile without errors
- [ ] All frontend code compiles without errors
- [ ] Firestore rules syntax valid
- [ ] `FREE.TEAM_MEMBERS` is `true` in `entitlements.ts`
- [ ] Functions exported in `index.ts`

### Deployment Steps
1. [ ] Deploy functions: `firebase deploy --only functions:memberListMembers,functions:memberUpdateRole`
2. [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
3. [ ] Verify functions appear in Firebase Console
4. [ ] Verify rules deployed successfully

### Post-Deployment Verification
1. [ ] Test `memberListMembers` via Firebase Console
2. [ ] Test `memberUpdateRole` via Firebase Console
3. [ ] Test via Flutter app (Settings → Team Members)
4. [ ] Check Firebase Functions logs for errors
5. [ ] Verify audit events are created

## Known Issues / Notes

- **Transaction Limitation**: Admin count check is done outside transaction to avoid collection reference issue. Small race condition window exists but is acceptable for MVP.
- **Batch User Lookup**: Uses `admin.auth().getUsers()` for efficiency. Handles deleted users gracefully.
- **Optimistic UI**: Frontend updates immediately, rolls back on error. Provides better UX.

## Success Criteria

✅ All test cases pass
✅ No security vulnerabilities
✅ Performance acceptable (< 3s for member list)
✅ Error messages clear and user-friendly
✅ Audit logging works correctly
✅ UI responsive and intuitive
