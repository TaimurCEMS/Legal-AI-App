# SLICE 2.5: Member Management & Role Assignment - Build Card

**⚠️ Important Notes:**
- **This is a Mini-Slice** - Focused implementation of member management to unblock multi-user testing
- **Non-Breaking:** All changes are additive and isolated. Existing functionality remains unchanged.
- **Flexible Design:** Architecture supports future enhancements (invites, bulk operations, custom roles) without breaking changes.
- **Security First:** All operations require ADMIN role, with comprehensive validation and audit logging.

## 1) Purpose

Build a comprehensive member management system that allows organization administrators to view all organization members, see their current roles, and assign/update roles. This mini-slice unblocks multi-user testing by enabling role assignment, while maintaining a flexible architecture that can be extended in future slices (Slice 15: Admin Panel) without breaking changes.

## 2) Scope In ✅

### Backend (Cloud Functions):
- `member.list` - List all members of an organization (with role, joined date, user info)
- `member.update` - Update a member's role (ADMIN only, with safety checks)
- Member role validation (ADMIN, LAWYER, PARALEGAL, VIEWER)
- Admin-only access enforcement
- Safety checks (prevent lockout, prevent removing last ADMIN)
- User information lookup (email, display name from Firebase Auth)
- Audit logging for role changes
- Entitlement checks (plan + role permissions)
- Firestore security rules (read-only for members, write via Cloud Functions only)

### Frontend (Flutter):
- Member list screen (shows all org members with roles)
- Role assignment UI (dropdown for ADMIN users)
- Role permissions matrix display (informational)
- User information display (email, joined date)
- Loading states and error handling
- Success/error messages for role updates
- Integration with Settings screen (navigation)
- Empty states for edge cases

### Data Model:
- Members belong to organizations (orgId required)
- Member roles (ADMIN, LAWYER, PARALEGAL, VIEWER)
- Member metadata (joinedAt, role, uid)
- User information (fetched from Firebase Auth, not stored in Firestore)

## 3) Scope Out ❌

- Team invites/invitations (Slice 4 or future)
- Member removal/kick functionality (future)
- Bulk role assignment (future)
- Custom roles (future)
- Role templates (future)
- Member activity tracking (Slice 12: Audit Trail UI)
- Member profile editing (future)
- Member search/filtering (basic list only for MVP)
- Member pagination (assumes small teams for MVP)
- Email notifications for role changes (future)
- Member export functionality (future)
- Advanced permission customization (Slice 15: Admin Panel)
- Plan management (Slice 13: Billing)
- Organization settings (Slice 15: Admin Panel)

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0
- Firebase Admin SDK (for user lookup) - already available

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, membership, entitlements engine, permissions matrix)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme system, reusable widgets)
- ✅ **Slice 2**: Optional (for context, but not required)

**No Dependencies on:**
- Slice 3 (Client Hub)
- Slice 4 (Document Hub)
- Slice 5+ (Tasks, AI, etc.)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `member.list` (Callable Function)

**Function Name (Export):** `memberListMembers` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `member.list` (for reference only, Flutter uses export name)

**Note:** Naming follows existing pattern: `memberGetMyMembership`, `memberListMyOrgs` → `memberListMembers`, `memberUpdateRole`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `admin.manage_users` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ❌
- PARALEGAL: ❌
- VIEWER: ❌

**Plan Gating:** `TEAM_MEMBERS` feature must be enabled
- ✅ FREE: Enabled (for multi-user testing in Slice 2.5)
- ✅ BASIC: Enabled
- ✅ PRO: Enabled
- ✅ ENTERPRISE: Enabled

**Request Payload:**
```json
{
  "orgId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "members": [
      {
        "uid": "string",
        "email": "string | null",
        "displayName": "string | null",
        "role": "ADMIN | LAWYER | PARALEGAL | VIEWER",
        "joinedAt": "ISO 8601 timestamp",
        "isCurrentUser": "boolean"
      }
    ],
    "totalCount": "number"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid orgId format
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `admin.manage_users` permission
- `NOT_FOUND` (404): Organization does not exist
- `PLAN_LIMIT` (403): TEAM_MEMBERS feature not available in plan (shouldn't happen as all plans have it)
- `INTERNAL_ERROR` (500): Database read failure or Firebase Auth lookup failure

**Implementation Details:**

**Security:**
- Verify user is authenticated
- Verify user is a member of the organization
- Verify user has `admin.manage_users` permission (only ADMIN)
- Verify organization exists and is not deleted

**User Information Lookup:**
- For each member, fetch user info from Firebase Auth Admin SDK
- Use `admin.auth().getUser(uid)` to get email and displayName
- **Performance Optimization:** Batch lookups using `admin.auth().getUsers(uids)` for better performance with multiple members
- Handle cases where user account may be deleted (return null for email/displayName)
- For MVP, assume small teams (< 50 members). For larger teams, consider caching user info in Firestore with TTL

**Sorting:**
- Sort by role priority (ADMIN first, then LAWYER, PARALEGAL, VIEWER)
- Within same role, sort by joinedAt (oldest first)
- Mark current user with `isCurrentUser: true` flag

**Performance:**
- For MVP, assume small teams (< 50 members)
- No pagination required (can be added in future if needed)
- Batch user lookups using `admin.auth().getUsers(uids)` for better performance

**Caching Strategy (Future Enhancement):**
- **Current (MVP):** Firebase Auth lookups each time (acceptable for < 50 members)
- **When to Implement Caching:** Teams > 50 members or performance issues observed
- **Option A (Recommended):** Cache in Firestore with TTL (7 days)
  - Store `email`, `displayName` in membership document
  - Update on role change or manual refresh
  - TTL ensures data freshness
- **Option B:** In-memory cache with invalidation on role change
  - Faster but lost on function restart
  - Good for high-traffic scenarios
- **Option C:** Real-time user info updates via Cloud Function trigger
  - Most accurate but more complex
  - Best for enterprise scenarios

---

### 5.2 `member.update` (Callable Function)

**Function Name (Export):** `memberUpdateRole` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `member.update` (for reference only, Flutter uses export name)

**Note:** Naming follows existing pattern: `memberGetMyMembership`, `memberListMyOrgs` → `memberListMembers`, `memberUpdateRole`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `admin.manage_users` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ❌
- PARALEGAL: ❌
- VIEWER: ❌

**Plan Gating:** `TEAM_MEMBERS` feature must be enabled
- ✅ FREE: Enabled (for multi-user testing in Slice 2.5)
- ✅ BASIC: Enabled
- ✅ PRO: Enabled
- ✅ ENTERPRISE: Enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "memberUid": "string (required)",
  "role": "ADMIN | LAWYER | PARALEGAL | VIEWER (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "uid": "string",
    "orgId": "string",
    "role": "ADMIN | LAWYER | PARALEGAL | VIEWER",
    "previousRole": "ADMIN | LAWYER | PARALEGAL | VIEWER",
    "updatedAt": "ISO 8601 timestamp",
    "updatedBy": "string (uid of requester)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing memberUid, missing role, invalid role value, role unchanged
- `NOT_AUTHORIZED` (403): Requester not a member of org, requester doesn't have `admin.manage_users` permission, attempting to change own role
- `NOT_FOUND` (404): Organization does not exist, member not found in org
- `SAFETY_ERROR` (403): Attempting to remove last ADMIN, attempting to demote self from ADMIN
- `PLAN_LIMIT` (403): TEAM_MEMBERS feature not available in plan
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Security Checks (in order):**
1. Verify user is authenticated
2. Verify user is a member of the organization
3. Verify user has `admin.manage_users` permission (only ADMIN)
4. Verify organization exists and is not deleted
5. Verify target member exists in organization
6. Verify new role is valid (one of: ADMIN, LAWYER, PARALEGAL, VIEWER)
7. Verify role is actually changing (not setting same role)
8. **Safety Check:** Prevent changing own role (to avoid lockout)
9. **Safety Check:** If changing from ADMIN, verify at least one other ADMIN exists
10. **Safety Check:** If changing to ADMIN, verify requester is currently ADMIN (only ADMIN can create other ADMINs)

**Role Validation:**
- Must be one of: `ADMIN`, `LAWYER`, `PARALEGAL`, `VIEWER`
- Case-sensitive (use exact match)
- Reject invalid values with clear error message

**Safety Rules:**
- **Rule 1:** Cannot change own role (prevents accidental lockout)
  - Error: `SAFETY_ERROR` - "You cannot change your own role"
- **Rule 2:** Cannot remove last ADMIN (must have at least one ADMIN)
  - Error: `SAFETY_ERROR` - "Cannot remove the last administrator. Please assign another member as administrator first."
- **Rule 3:** Only ADMIN can assign ADMIN role (prevents privilege escalation)
  - Error: `NOT_AUTHORIZED` - "Only administrators can assign the administrator role"

**Update Process:**
1. Fetch current membership document
2. Store previous role for audit log
3. Update membership document with new role
4. Set `updatedAt` timestamp
5. Set `updatedBy` to requester's UID
6. Create audit event (see Section 7)
7. Return success response with updated data

**Transaction Safety:**
- Use Firestore transaction for atomic update
- Verify member still exists and role hasn't changed during transaction
- Handle concurrent update conflicts gracefully
- **Concurrent Update Scenario:** If two admins update the same user simultaneously, Firestore transaction will ensure only one succeeds. The other will receive a conflict error and should retry.

**Role Change Impact:**
- **Permissions Change Immediately:** When a role is updated, the new permissions take effect immediately on the next API call
- **No Session Invalidation:** Existing user sessions are not invalidated. Users may need to refresh their app to see permission changes reflected in UI
- **Data Access Changes:**
  - **LAWYER → VIEWER:** User loses ability to create/update/delete cases, clients, documents. They can still read ORG_WIDE cases and their own PRIVATE cases (if they created them)
  - **VIEWER → LAWYER:** User gains ability to create/update/delete cases, clients, documents immediately
  - **Any → ADMIN:** User gains full access including member management
- **Recommendation:** Frontend should refresh user's membership info after role change to update UI permissions

---

## 6) Frontend Implementation (Flutter)

### 6.1 Member Management Screen

**Location:** `legal_ai_app/lib/features/home/screens/member_management_screen.dart`

**Features:**
- Display list of all organization members
- Show member email, display name, role, joined date
- Highlight current user in the list
- Role dropdown (only visible for ADMIN users)
- Role permissions matrix (informational, read-only)
- Loading states (initial load, role update)
- Error handling with user-friendly messages
- Success messages for role updates
- Pull-to-refresh to reload member list
- Empty state (shouldn't happen, but handle gracefully)

**UI Components:**
- AppBar with title "Team Members"
- Member list (ListView or similar)
- Member card widget (reusable)
- Role dropdown (DropdownButton or similar)
- Role badge/chip (color-coded by role)
- Loading spinner
- Error message widget
- Success snackbar

**State Management:**
- Use Provider pattern (MemberProvider)
- Load members on screen init
- Handle role update with optimistic UI update
- Refresh list after successful role update

**Navigation:**
- Accessible from Settings screen
- Only visible if user has ADMIN role
- Back button returns to Settings

### 6.2 Member Model

**Location:** `legal_ai_app/lib/core/models/member_model.dart`

**Fields:**
```dart
class MemberModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String role; // 'ADMIN', 'LAWYER', 'PARALEGAL', 'VIEWER'
  final DateTime joinedAt;
  final bool isCurrentUser;
  
  // Constructor, toJson, fromJson, etc.
}
```

### 6.3 Member Service

**Location:** `legal_ai_app/lib/core/services/member_service.dart`

**Methods:**
- `listMembers(OrgModel org)`: Calls `memberList` Cloud Function
- `updateMemberRole(OrgModel org, String memberUid, String role)`: Calls `memberUpdate` Cloud Function

**Error Handling:**
- Parse backend error codes
- Convert to user-friendly messages
- Handle network errors
- Handle permission errors

### 6.4 Member Provider

**Location:** `legal_ai_app/lib/features/home/providers/member_provider.dart`

**State:**
- `List<MemberModel> members`
- `bool isLoading`
- `String? errorMessage`
- `bool isUpdatingRole`
- `Map<String, String>? pendingRoleUpdates` (for optimistic updates)

**Methods:**
- `loadMembers(OrgModel org)`: Load member list
- `updateMemberRole(OrgModel org, String memberUid, String role)`: Update role with optimistic UI
- `clearMembers()`: Clear state on logout/org switch

**Optimistic UI Updates:**
- Immediately update UI when role change is initiated
- Store pending updates in `pendingRoleUpdates` map
- Rollback if backend update fails
- Show loading indicator during update

**Listeners:**
- Notify listeners on state changes
- Handle loading/error states

### 6.5 Navigation Integration

**Location:** `legal_ai_app/lib/features/home/screens/settings_screen.dart`

**Changes:**
- Add "Team Members" button/link (only visible for ADMIN)
- Navigate to `RouteNames.memberManagement` when clicked

**Location:** `legal_ai_app/lib/core/routing/app_router.dart`

**Changes:**
- Add route: `memberManagement` → `MemberManagementScreen`
- Add to `RouteNames` constants

---

## 7) Security & Validation

### 7.1 Backend Security

**Authentication:**
- All functions require valid Firebase Auth token
- Reject unauthenticated requests immediately

**Authorization:**
- Verify user is member of organization
- Verify user has `admin.manage_users` permission (only ADMIN)
- Use `checkEntitlement` helper from Slice 0

**Input Validation:**
- Validate all required fields present
- Validate orgId format (non-empty string)
- Validate memberUid format (non-empty string)
- Validate role value (enum check)
- Sanitize all string inputs (trim, validate length)

**Safety Checks:**
- Prevent self-role-change (lockout prevention)
- Prevent removing last ADMIN (org must have at least one ADMIN)
- Prevent privilege escalation (only ADMIN can assign ADMIN)

**Data Integrity:**
- Use Firestore transactions for atomic updates
- Verify member exists before update
- Verify organization exists and is not deleted
- Handle concurrent updates gracefully

### 7.2 Frontend Security

**UI Gating:**
- Only show "Team Members" link to ADMIN users
- Only show role dropdown to ADMIN users
- Hide member management entirely for non-ADMIN users

**Permission Checks:**
- Check user role before allowing navigation
- Check user role before showing role update UI
- Display clear message if user lacks permission

**Error Handling:**
- Display user-friendly error messages
- Handle permission errors gracefully
- Handle network errors with retry option

### 7.3 Firestore Security Rules

**Location:** `firestore.rules`

**Changes:**
- Add read rule for members collection (members can read their org's members)
- Deny direct writes (all writes via Cloud Functions)
- Scope reads to organization membership

**Example Rules:**
```javascript
// Members collection
match /organizations/{orgId}/members/{memberId} {
  // Allow read if user is member of org
  // Note: All org members can see other members (for team visibility)
  // If privacy is required, restrict to ADMIN-only in future
  allow read: if request.auth != null 
    && exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
  
  // Deny all writes (only via Cloud Functions)
  allow write: if false;
}
```

**Privacy Consideration:**
- Current design: All org members can see all other members (simpler, better for team collaboration)
- Future enhancement: Restrict to ADMIN-only if privacy is required
- This can be changed later without breaking existing functionality

---

## 8) Audit Logging

### 8.1 Audit Events

**Event Type:** `member.role.updated`

**Location:** `organizations/{orgId}/audit_events/{eventId}`

**Event Structure:**
```json
{
  "id": "audit_event_id",
  "orgId": "org_abc123",
  "actorUid": "requester_uid",
  "action": "member.role.updated",
  "entityType": "membership",
  "entityId": "member_uid",
  "timestamp": "Firestore Timestamp",
  "metadata": {
    "memberUid": "member_uid",
    "previousRole": "VIEWER",
    "newRole": "LAWYER",
    "memberEmail": "member@example.com"
  }
}
```

**Implementation:**
- Use `createAuditEvent` helper from Slice 0
- Log after successful role update
- Include previous and new role in metadata
- Include member email for traceability

---

## 9) Data Model

### 9.1 Membership Document

**Location:** `organizations/{orgId}/members/{uid}`

**Existing Structure (from Slice 0):**
```json
{
  "uid": "user_uid",
  "role": "ADMIN | LAWYER | PARALEGAL | VIEWER",
  "joinedAt": "Firestore Timestamp",
  "createdAt": "Firestore Timestamp",
  "updatedAt": "Firestore Timestamp",
  "createdBy": "uid",
  "updatedBy": "uid"
}
```

**Changes for Slice 2.5:**
- `updatedAt` and `updatedBy` will be set when role is updated
- No schema changes required (fields already exist)

### 9.2 User Information

**Source:** Firebase Authentication (not stored in Firestore)

**Lookup Method:**
- Use Firebase Admin SDK: `admin.auth().getUser(uid)`
- Returns: `email`, `displayName`, `photoURL` (optional)

**Caching:**
- Not required for MVP
- Can be added in future if performance is an issue

---

## 10) Error Handling

### 10.1 Backend Error Codes

**New Error Codes (if needed):**
- `SAFETY_ERROR` (403): Safety check failed (self-role-change, last ADMIN, etc.)

**Existing Error Codes (reuse):**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid input
- `NOT_AUTHORIZED` (403): Permission denied
- `NOT_FOUND` (404): Resource not found
- `PLAN_LIMIT` (403): Plan feature not available
- `INTERNAL_ERROR` (500): Server error

### 10.2 Frontend Error Messages

**User-Friendly Messages (Must Match Backend Exactly):**
- **NOT_AUTHORIZED:** "You don't have permission to manage team members"
- **SAFETY_ERROR (self-change):** "You cannot change your own role" (exact match)
- **SAFETY_ERROR (last ADMIN):** "Cannot remove the last administrator. Please assign another member as administrator first." (exact match)
- **SAFETY_ERROR (demote self):** "You cannot change your own role" (exact match)
- **NOT_AUTHORIZED (assign ADMIN):** "Only administrators can assign the administrator role" (exact match)
- **NOT_FOUND:** "Member not found"
- **VALIDATION_ERROR:** "Invalid role value" or "Role cannot be changed to the same value"
- **INTERNAL_ERROR:** "Failed to update role. Please try again."
- **Network Error:** "Network error. Please check your connection."

**Error Message Consistency:**
- Frontend error messages MUST match backend error messages exactly
- Use error code mapping to ensure consistency
- Test error messages match in both frontend and backend tests

---

## 11) Testing Requirements

### 11.1 Backend Tests

**Test Cases:**
1. ✅ `memberListMembers` - Successfully list members (ADMIN)
2. ✅ `memberListMembers` - Reject non-member
3. ✅ `memberListMembers` - Reject non-ADMIN member
4. ✅ `memberListMembers` - Handle deleted user accounts
5. ✅ `memberListMembers` - Batch user lookup performance (10, 25, 50 members)
6. ✅ `memberListMembers` - Verify FREE plan allows access
7. ✅ `memberUpdateRole` - Successfully update role (ADMIN)
8. ✅ `memberUpdateRole` - Reject non-member
9. ✅ `memberUpdateRole` - Reject non-ADMIN member
10. ✅ `memberUpdateRole` - Reject self-role-change
11. ✅ `memberUpdateRole` - Reject removing last ADMIN
12. ✅ `memberUpdateRole` - Reject invalid role value
13. ✅ `memberUpdateRole` - Reject setting same role
14. ✅ `memberUpdateRole` - Verify audit log created
15. ✅ `memberUpdateRole` - **Concurrent updates:** Two admins update same user simultaneously (one succeeds, one gets conflict)
16. ✅ `memberUpdateRole` - Verify FREE plan allows TEAM_MEMBERS
17. ✅ `memberUpdateRole` - Verify permissions change immediately after role update

**Test Location:** `functions/src/__tests__/member.test.ts` (create new file)

**Performance Testing:**
- Test with 10, 25, 50 members to verify batch lookup performance
- Measure response time for member list
- Verify no timeout issues with Firebase Auth batch lookups

### 11.2 Frontend Tests

**Test Cases:**
1. ✅ Member list loads correctly
2. ✅ Role dropdown only visible for ADMIN
3. ✅ Role update succeeds with optimistic UI
4. ✅ Optimistic update rollback on error
5. ✅ Error messages display correctly
6. ✅ Loading states work correctly
7. ✅ Navigation works correctly
8. ✅ Member list clears on org switch
9. ✅ Permission gating works (non-ADMIN can't access)

**Test Location:** `legal_ai_app/test/features/home/member_management_screen_test.dart` (create new file)

---

## 12) Deployment Checklist

### 12.1 Backend Deployment

- [ ] Implement `memberListMembers` function
- [ ] Implement `memberUpdateRole` function
- [ ] Use batch user lookup (`admin.auth().getUsers()`) for performance
- [ ] Add error codes if needed
- [ ] Write unit tests
- [ ] Run tests locally
- [ ] Deploy to Firebase: `firebase deploy --only functions:memberListMembers,functions:memberUpdateRole`
- [ ] Verify deployment in Firebase Console
- [ ] Test deployed functions manually

### 12.2 Frontend Implementation

- [ ] Create `MemberModel`
- [ ] Create `MemberService`
- [ ] Create `MemberProvider`
- [ ] Create `MemberManagementScreen`
- [ ] Add route to `AppRouter`
- [ ] Add navigation from Settings screen
- [ ] Test UI flows
- [ ] Test error handling
- [ ] Test permission gating

### 12.3 Security Rules

- [ ] Update `firestore.rules` for members collection
- [ ] Deploy rules: `firebase deploy --only firestore:rules`
- [ ] Test rules in Firebase Console

### 12.4 Integration Testing

- [ ] Test full flow: List → Update Role → Verify
- [ ] Test permission enforcement
- [ ] Test safety checks
- [ ] Test error scenarios
- [ ] Test with multiple users
- [ ] Test logout/login state clearing

---

## 13) Future Enhancements (Out of Scope)

These features are explicitly out of scope for this mini-slice but can be added in future slices without breaking changes:

1. **Member Invitations** (Slice 4 or future)
   - Invite users by email
   - Invitation tokens
   - Email notifications

2. **Member Removal** (Future)
   - Remove members from organization
   - Handle data ownership transfer

3. **Bulk Operations** (Future)
   - Bulk role assignment
   - Bulk member removal

4. **Advanced Filtering** (Future)
   - Filter by role
   - Search by name/email
   - Sort options

5. **Member Activity** (Slice 12: Audit Trail UI)
   - View member activity history
   - Last login tracking

6. **Custom Roles** (Future)
   - Create custom roles
   - Define custom permissions

7. **Role Templates** (Future)
   - Predefined role sets
   - Role inheritance

---

## 14) Architecture Flexibility

### 14.1 Design Principles

**Isolation:**
- Member management is isolated from other features
- Changes don't affect existing functionality
- Can be enhanced without breaking changes

**Extensibility:**
- Data model supports future fields
- Function signatures can be extended with optional parameters
- UI can be enhanced without breaking existing screens

**Backward Compatibility:**
- New functions don't break existing code
- Existing functions unchanged
- Frontend gracefully handles missing features

### 14.2 Future-Proof Design

**Data Model:**
- Membership document has `updatedAt` and `updatedBy` (already exists)
- Can add more fields in future without migration

**Function Design:**
- Functions accept optional parameters for future features
- Response format can be extended with additional fields
- Error codes are extensible

**UI Design:**
- Screen layout supports additional features
- Components are reusable
- Navigation can be extended

---

## 15) Success Criteria

### 15.1 Functional Requirements

- [ ] ADMIN can view all organization members
- [ ] ADMIN can see member roles, emails, joined dates
- [ ] ADMIN can update member roles
- [ ] Safety checks prevent lockout and last ADMIN removal
- [ ] Non-ADMIN users cannot access member management
- [ ] Role changes are logged in audit trail
- [ ] Error messages are clear and user-friendly

### 15.2 Non-Functional Requirements

- [ ] All security checks pass
- [ ] Performance is acceptable (< 2s for member list)
- [ ] UI is responsive and intuitive
- [ ] Error handling is comprehensive
- [ ] Code follows existing patterns
- [ ] Tests pass
- [ ] No breaking changes to existing functionality

---

## 16) Estimated Effort

- **Backend Functions:** 2-3 hours
  - `memberListMembers`: 1 hour (including batch user lookup)
  - `memberUpdateRole`: 1.5 hours
  - Tests: 0.5 hours

- **Frontend Implementation:** 3-4 hours
  - Models/Services: 0.5 hours
  - Provider: 0.5 hours
  - Screen: 2 hours
  - Navigation: 0.5 hours
  - Testing: 0.5 hours

- **Security Rules:** 0.5 hours

- **Integration Testing:** 1 hour

**Total:** 6-8 hours

---

## 17) Notes

### 17.1 Why Mini-Slice?

This is implemented as a mini-slice (Slice 2.5) rather than waiting for Slice 15 because:
1. **Blocking Issue:** Role assignment is required for multi-user testing
2. **Small Scope:** Focused feature set, manageable implementation
3. **Non-Breaking:** All changes are additive, existing code unaffected
4. **Foundation:** Sets up architecture for Slice 15 enhancements

### 17.2 Relationship to Slice 15

Slice 15 (Admin Panel) will build upon this foundation:
- This mini-slice provides core member management
- Slice 15 can add: invites, bulk operations, advanced filtering, member profiles, etc.
- No breaking changes required for Slice 15

### 17.3 Versioning

- **Version:** 1.0 (initial implementation)
- **Compatibility:** Backward compatible with all existing slices
- **Future Versions:** Can add features without breaking changes

---

**Last Updated:** January 21, 2026  
**Status:** Ready for Implementation  
**Priority:** High (blocks multi-user testing)

---

## 18) Review Feedback Implementation

### 18.1 Critical Fixes Applied ✅

1. **PLAN_FEATURES Alignment (ChatGPT)**
   - ✅ Fixed: `FREE.TEAM_MEMBERS` set to `true` in `entitlements.ts`
   - ✅ Updated build card to reflect actual plan features
   - **Impact:** Functions will now work for FREE plan users

2. **Function Naming Consistency (DeepSeek)**
   - ✅ Changed: `memberList` → `memberListMembers`
   - ✅ Changed: `memberUpdate` → `memberUpdateRole`
   - ✅ Follows existing pattern: `memberGetMyMembership`, `memberListMyOrgs`
   - **Impact:** Consistent naming across all member functions

3. **Performance Optimization (DeepSeek)**
   - ✅ Added: Batch user lookup using `admin.auth().getUsers(uids)`
   - ✅ Added: Performance testing requirements
   - ✅ Added: Note about caching for larger teams
   - **Impact:** Better performance for teams with multiple members

4. **Optimistic UI Updates (DeepSeek)**
   - ✅ Added: Optimistic update pattern to MemberProvider
   - ✅ Added: Rollback mechanism on error
   - ✅ Added: Pending updates tracking
   - **Impact:** Better user experience with immediate feedback

5. **Firestore Security Rules (DeepSeek)**
   - ✅ Added: Security rules for members collection
   - ✅ Added: Privacy consideration note
   - ✅ Added: Future enhancement path for ADMIN-only access
   - **Impact:** Proper security while maintaining flexibility

### 18.2 Additional Improvements

- ✅ Enhanced test coverage (15 backend tests, 9 frontend tests)
- ✅ Added performance testing requirements
- ✅ Clarified privacy considerations
- ✅ Added concurrent update handling notes
- ✅ Enhanced error handling documentation

### 18.3 Future Enhancements (Noted for Later)

- Member info caching in Firestore (for teams > 50)
- Pagination for member list (if needed)
- ADMIN-only member visibility option
- Custom permissions per user (additive fields)

### 18.4 Additional Considerations Addressed ✅

1. **Member Info Caching Strategy (DeepSeek)**
   - ✅ Documented caching strategy in Section 5.1
   - ✅ Three options provided (Firestore TTL, in-memory, real-time)
   - ✅ Clear threshold: Implement when teams > 50 members

2. **Concurrent Updates Edge Case (DeepSeek)**
   - ✅ Added specific test case (#15) for concurrent updates
   - ✅ Documented transaction behavior in Section 5.2
   - ✅ Explained conflict handling

3. **Role Change Impact Documentation (DeepSeek)**
   - ✅ Added "Role Change Impact" section in Section 5.2
   - ✅ Documented immediate permission changes
   - ✅ Explained data access changes for each role transition
   - ✅ Noted session invalidation behavior

4. **Error Message Consistency (DeepSeek)**
   - ✅ Added "Error Message Consistency" section in Section 10.2
   - ✅ Listed exact error messages that must match
   - ✅ Added requirement to test message matching

### 18.5 Verification Checklist

- [x] ✅ FREE.TEAM_MEMBERS set to `true` in `entitlements.ts` (VERIFIED - Line 11)
- [x] ✅ Function names follow existing pattern
- [x] ✅ Performance optimizations documented
- [x] ✅ Optimistic UI updates included
- [x] ✅ Security rules documented
- [x] ✅ Caching strategy documented
- [x] ✅ Concurrent updates test case added
- [x] ✅ Role change impact documented
- [x] ✅ Error message consistency requirements added
