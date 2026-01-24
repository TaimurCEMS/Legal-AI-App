# SLICE 0: Foundation (Auth + Org + Entitlements Engine) - Build Card

## 1) Purpose

Establish the authentication, organization membership, and entitlements engine that controls user identity, org scoping, plan-based feature gating, and role-based permissions for all future slices.

## 2) Scope In ✅

- Firebase Authentication usage (handled in Flutter via Firebase Auth SDK). Slice 0 assumes auth exists and Cloud Functions rely on context.auth.uid.
- Organization creation and joining
- Membership record creation and management
- Plan tier assignment (FREE by default)
- Role assignment (ADMIN for org creator)
- Entitlements evaluation engine (plan + role checks)
- Basic Firestore security rules for org/member collections
- Internal entitlement helper function for reusable permission checks
- Structured error response format implementation

## 3) Scope Out ❌

- Team invites UI (Slice 4)
- Billing upgrade UI (Slice 13)
- Advanced granular permission management UI
- Cases, clients, documents, tasks, AI features
- Audit trail UI (Slice 12)
- Advanced admin features: member invitations, bulk operations, org settings (Slice 15)
- Any feature beyond auth, org, and entitlements foundation

## 4) Backend Endpoints

### 4.1 `org.create` (Callable Function)

**Function Name:** `orgCreate`  
**Type:** Firebase Callable Function  
**Callable Name:** `org.create`

**Auth Requirement:** Valid Firebase Auth token (authenticated user)

**Required Role/Permission:** None (any authenticated user can create an org)

**Plan Gating:** None (org creation is always allowed)

**Request Payload:**
```json
{
  "name": "string (required, 1-100 chars)",
  "description": "string (optional, max 500 chars)"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "orgId": "string",
    "name": "string",
    "plan": "FREE",
    "createdAt": "ISO 8601 timestamp",
    "createdBy": "uid"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing or invalid name
- `INTERNAL_ERROR` (500): Database write failure
- `RATE_LIMITED` (429): Too many org creations (if rate limiting implemented)

**Implementation Details:**

**OrgId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc()`
- This generates a unique, collision-free ID automatically
- Example: "abc123def456"

**Org Name Validation:**
- Required: 1-100 characters
- Trim whitespace: `orgName.trim()`
- Sanitize: Remove leading/trailing special characters
- Pattern: Allow alphanumeric, spaces, hyphens, underscores, ampersands, commas, periods, parentheses
- Reject: Empty strings, only whitespace
- Example validation:
  ```typescript
  const sanitizedName = orgName.trim();
  if (!sanitizedName || sanitizedName.length < 1 || sanitizedName.length > 100) {
    throw new Error("Organization name must be 1-100 characters");
  }
  if (!/^[a-zA-Z0-9\s\-_&.,()]+$/.test(sanitizedName)) {
    throw new Error("Organization name contains invalid characters");
  }
  ```

**Org Description Validation (Optional):**
- Maximum: 500 characters
- Trim whitespace
- Allow basic punctuation
- Example validation:
  ```typescript
  if (description && description.length > 500) {
    throw new Error("Organization description must be 500 characters or less");
  }
  ```

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgName (trim, sanitize, length check)
3. Validate orgDescription (optional, length check)
4. Generate orgId using Firestore auto-ID
5. Create organization document
6. Create membership document (user as ADMIN)
7. Create audit event (org.created) - see Section 5.3
8. Return orgId and org details

**Audit Logging:**
```typescript
// Log org creation
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'org.created',
    entityType: 'organization',
    entityId: orgId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      orgName: sanitizedName,
    },
  });
```

---

### 4.2 `org.join` (Callable Function)

**Function Name:** `orgJoin`  
**Type:** Firebase Callable Function  
**Callable Name:** `org.join`

**Auth Requirement:** Valid Firebase Auth token

**Required Role/Permission:** None (any authenticated user can join an org if they have the orgId)

**Plan Gating:** None

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
    "orgId": "string",
    "role": "VIEWER",
    "joinedAt": "ISO 8601 timestamp"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing or invalid orgId
- `NOT_FOUND` (404): Organization does not exist
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Notes:**

**Concurrency Protection:**
- Use Firestore transaction to prevent race conditions when multiple users join simultaneously
- Wrap membership creation in a transaction
- Check `!exists(memberDoc)` inside transaction
- Atomically create membership if check passes

**Idempotent Join Behavior:**
- If membership already exists → return success with message "Already a member"
- This makes the endpoint idempotent and reduces client complexity
- No error is returned for duplicate join attempts

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check if org exists
4. Use Firestore transaction:
   - Check if membership already exists
   - If exists → return success with existing membership data
   - If not exists → create membership document with role: "VIEWER"
5. Create audit event (member.added) - see Section 5.3
6. Return membership info

**Transaction Example:**
```typescript
const memberRef = db
  .collection('organizations')
  .doc(orgId)
  .collection('members')
  .doc(uid);

await db.runTransaction(async (transaction) => {
  const memberDoc = await transaction.get(memberRef);
  
  if (memberDoc.exists) {
    // Already a member - return success (idempotent)
    return {
      success: true,
      data: {
        orgId,
        role: memberDoc.data()!.role,
        joinedAt: memberDoc.data()!.joinedAt,
        message: "Already a member"
      }
    };
  }
  
  // Create new membership
  transaction.set(memberRef, {
    uid,
    orgId,
    role: 'VIEWER',
    joinedAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  });
  
  return { success: true, data: { orgId, role: 'VIEWER', joinedAt: ... } };
});
```

---

### 4.3 `member.getMyMembership` (Callable Function)

**Function Name:** `memberGetMyMembership`  
**Type:** Firebase Callable Function  
**Callable Name:** `member.getMyMembership`

**Auth Requirement:** Valid Firebase Auth token

**Required Role/Permission:** None (user can always check their own membership)

**Plan Gating:** None

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
    "orgId": "string",
    "uid": "string",
    "role": "ADMIN | LAWYER | PARALEGAL | VIEWER",
    "plan": "FREE | BASIC | PRO | ENTERPRISE",
    "joinedAt": "ISO 8601 timestamp",
    "orgName": "string"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId
- `NOT_FOUND` (404): User is not a member of this org
- `NOT_FOUND` (404): Organization does not exist
- `INTERNAL_ERROR` (500): Database read failure

**Implementation Notes:**
- Lookup membership document
- Lookup org document to get plan and name
- Return combined membership + org info
- Used by client to determine current user's permissions

---

### 4.4 `entitlement.check` (Internal Helper Function)

**Function Name:** `checkEntitlement`  
**Type:** Internal helper (not exposed as endpoint)  
**Usage:** Called by other Cloud Functions to validate permissions

**Parameters:**
```typescript
{
  uid: string,
  orgId: string,
  requiredPermission?: string,  // e.g., "case.create", "ai.ask"
  requiredFeature?: string,      // e.g., "AI_RESEARCH", "TASKS"
  objectOrgId?: string          // For org scoping validation
}
```

**Returns:**
```typescript
{
  allowed: boolean,
  reason?: "ORG_MEMBER" | "PLAN_LIMIT" | "ROLE_BLOCKED" | "ORG_MISMATCH" | "ORG_REQUIRED",
  plan?: string,
  role?: string
}
```

**Complete Implementation:**
```typescript
/**
 * Check if user is entitled to perform an action
 * @param uid - User ID
 * @param orgId - Organization ID
 * @param requiredFeature - Feature key (e.g., "AI_RESEARCH", "TASKS")
 * @param requiredPermission - Permission key (e.g., "case.create", "ai.ask")
 * @param objectOrgId - For org scoping validation
 * @returns Entitlement check result
 */
export async function checkEntitlement(params: {
  uid: string;
  orgId: string;
  requiredFeature?: string;
  requiredPermission?: string;
  objectOrgId?: string;
}): Promise<{
  allowed: boolean;
  reason?: "ORG_MEMBER" | "PLAN_LIMIT" | "ROLE_BLOCKED" | "ORG_MISMATCH" | "ORG_REQUIRED";
  plan?: string;
  role?: string;
}> {
  const { uid, orgId, requiredFeature, requiredPermission, objectOrgId } = params;

  // 1. Org membership check
  if (!orgId) {
    return { allowed: false, reason: "ORG_REQUIRED" };
  }

  const memberDoc = await db
    .collection('organizations')
    .doc(orgId)
    .collection('members')
    .doc(uid)
    .get();

  if (!memberDoc.exists) {
    return { allowed: false, reason: "ORG_MEMBER" };
  }

  const memberData = memberDoc.data()!;
  const role = memberData.role;

  // 2. Get org plan
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  if (!orgDoc.exists) {
    return { allowed: false, reason: "ORG_MEMBER" };
  }

  const plan = orgDoc.data()!.plan;

  // 3. Plan feature check
  if (requiredFeature && !PLAN_FEATURES[plan][requiredFeature]) {
    return { allowed: false, reason: "PLAN_LIMIT", plan, role };
  }

  // 4. Role permission check
  if (requiredPermission && !ROLE_PERMISSIONS[role][requiredPermission]) {
    return { allowed: false, reason: "ROLE_BLOCKED", plan, role };
  }

  // 5. Org scoping check
  if (objectOrgId && objectOrgId !== orgId) {
    return { allowed: false, reason: "ORG_MISMATCH" };
  }

  return { allowed: true, plan, role };
}
```

**Error Handling:**
- Returns `ORG_REQUIRED` if orgId is missing
- Returns `ORG_MEMBER` if user is not a member
- Log entitlement check failures for monitoring

---

## 5) Firestore Collections

### 5.1 `organizations/{orgId}`

**Document Path:** `organizations/{orgId}`

**Required Fields:**
```json
{
  "id": "string (same as orgId)",
  "name": "string (required, 1-100 chars)",
  "description": "string (optional, max 500 chars)",
  "plan": "FREE | BASIC | PRO | ENTERPRISE (required, default: FREE)",
  "createdAt": "Firestore Timestamp (required)",
  "updatedAt": "Firestore Timestamp (required)",
  "createdBy": "string (uid, required)",
  "updatedBy": "string (uid, optional)"
}
```

**Example Document:**
```json
{
  "id": "org_abc123",
  "name": "Smith & Associates Law Firm",
  "description": "Corporate law practice",
  "plan": "FREE",
  "createdAt": "2026-01-16T10:00:00Z",
  "updatedAt": "2026-01-16T10:00:00Z",
  "createdBy": "user_xyz789"
}
```

**Indexing Notes:**
- Index on `createdAt` for sorting orgs by creation date (optional, for admin queries)

**Security Rules:**
- Read: User must be member of org (`exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid))`)
- Write: Only via Cloud Functions (no direct client writes)

---

### 5.2 `organizations/{orgId}/members/{uid}`

**Document Path:** `organizations/{orgId}/members/{uid}`

**Required Fields:**
```json
{
  "uid": "string (same as document ID, required)",
  "orgId": "string (required)",
  "role": "ADMIN | LAWYER | PARALEGAL | VIEWER (required, default: VIEWER)",
  "joinedAt": "Firestore Timestamp (required)",
  "updatedAt": "Firestore Timestamp (required)",
  "createdBy": "string (uid, optional, for audit)"
}
```

**Example Document:**
```json
{
  "uid": "user_xyz789",
  "orgId": "org_abc123",
  "role": "ADMIN",
  "joinedAt": "2026-01-16T10:00:00Z",
  "updatedAt": "2026-01-16T10:00:00Z",
  "createdBy": "user_xyz789"
}
```

**Indexing Notes:**
- Index on `role` for role-based queries (optional)
- Index on `joinedAt` for sorting members (optional)

**Security Rules:**
- Read: User must be member of same org
- Write: Only via Cloud Functions (no direct client writes)

**CRITICAL:** Every membership document MUST have `orgId` field. This is not optional.

---

### 5.3 `organizations/{orgId}/audit_events/{eventId}`

**Document Path:** `organizations/{orgId}/audit_events/{eventId}`

**Purpose:** Minimal audit logging for critical actions. Full audit trail is Slice 12.

**Required Fields:**
```json
{
  "id": "string (same as eventId)",
  "orgId": "string (required)",
  "actorUid": "string (uid of user who performed action)",
  "action": "string (e.g., 'org.created', 'member.added')",
  "entityType": "string (e.g., 'organization', 'membership')",
  "entityId": "string (id of affected entity)",
  "timestamp": "Firestore Timestamp (required)",
  "metadata": "object (optional, additional context)"
}
```

**Example Document:**
```json
{
  "id": "audit_xyz789",
  "orgId": "org_abc123",
  "actorUid": "user_xyz789",
  "action": "org.created",
  "entityType": "organization",
  "entityId": "org_abc123",
  "timestamp": "2026-01-16T10:00:00Z",
  "metadata": {
    "orgName": "Smith & Associates Law Firm"
  }
}
```

**Slice 0 Usage:**
- Log org creation in `org.create` endpoint
- Log membership creation in `org.join` endpoint
- Log membership changes (future, when role assignment is added)

**Security Rules:**
- Read: User must be member of org
- Write: Only via Cloud Functions (no direct client writes)

**Note:** Full audit trail UI and advanced querying is Slice 12. Slice 0 just creates the structure and logs critical actions.

---

## 6) Roles & Plan Gating

### 6.1 Roles

**Available Roles:**
- `ADMIN`: Full access, can manage users and plan
- `LAWYER`: Can create cases, use AI, manage most content
- `PARALEGAL`: Can update cases, use AI, but cannot create cases or close them
- `VIEWER`: Read-only access, cannot create or modify content

**Role Assignment Rules:**
- Org creator automatically gets `ADMIN` role
- New members joining org get `VIEWER` role by default
- Role changes must go through Cloud Functions (not in Slice 0 scope, but structure must support it)

### 6.2 Plan Tiers

**Available Plans:**
- `FREE`: Basic features, limited team members (solo typically)
- `BASIC`: More features, team collaboration
- `PRO`: Advanced features, AI drafting
- `ENTERPRISE`: All features, unlimited

**Plan Assignment Rules:**
- New orgs get `FREE` plan by default
- Plan changes must go through Cloud Functions (not in Slice 0 scope, but structure must support it)

### 6.3 Entitlement Evaluation Flow

**For any protected action, check in this order:**

1. **Org Membership Check:**
   - User must exist in `organizations/{orgId}/members/{uid}`
   - If NO → return `NOT_AUTHORIZED` with message "You are not a member of this organization"

2. **Plan Feature Check:**
   - Lookup org plan from `organizations/{orgId}.plan`
   - Check if plan allows the feature (see Section 4.7 Entitlements Matrix)
   - If NO → return `PLAN_LIMIT` with message "This feature requires [PLAN_NAME] plan. Upgrade to continue."

3. **Role Permission Check:**
   - Lookup user role from `organizations/{orgId}/members/{uid}.role`
   - Check if role has required permission (see Section 4.8 Permissions Matrix)
   - If NO → return `NOT_AUTHORIZED` with message "You do not have permission to perform this action"

4. **Org Scoping Check:**
   - If accessing an object (case, document, etc.), verify `object.orgId === user.orgId`
   - If NO → return `NOT_AUTHORIZED` with message "Resource does not belong to your organization"

5. **Object-Level Access Check:**
   - For cases with `visibility: "PRIVATE"`, check case access rules (not in Slice 0, but structure must support)

**Error Code Priority:**
- `ORG_REQUIRED` (if orgId is missing or invalid)
- `NOT_AUTHORIZED` (if not member or role blocks)
- `PLAN_LIMIT` (if plan blocks feature)
- `NOT_FOUND` (if resource doesn't exist)
- `VALIDATION_ERROR` (if input invalid)
- `INTERNAL_ERROR` (if server error)
- `RATE_LIMITED` (if rate limit exceeded)

---

## 7) Edge Cases & Failure States

### 7.1 Missing Org Membership

**Scenario:** User tries to access org resource but is not a member

**Handling:**
- Check `organizations/{orgId}/members/{uid}` exists
- If not found → return `NOT_AUTHORIZED`
- Error message: "You are not a member of this organization"

**Test Cases:**
- User not in members collection
- User in different org trying to access another org's resource

---

### 7.2 Invalid Role

**Scenario:** Membership document has invalid role value

**Handling:**
- Validate role is one of: ADMIN, LAWYER, PARALEGAL, VIEWER
- If invalid → default to VIEWER (safe fallback) OR return `INTERNAL_ERROR`
- Log error for admin review

**Test Cases:**
- Role field missing → default to VIEWER
- Role = "INVALID_ROLE" → default to VIEWER
- Role = null → default to VIEWER

---

### 7.3 Plan Limits

**Scenario:** User tries to use feature not available in their plan

**Handling:**
- Check org plan from `organizations/{orgId}.plan`
- Check feature availability in plan (see Entitlements Matrix)
- If blocked → return `PLAN_LIMIT`
- Error message: "This feature requires [PLAN_NAME] plan. Upgrade to continue."

**Test Cases:**
- FREE plan user tries to use AI_RESEARCH → `PLAN_LIMIT`
- FREE plan user tries to use TASKS → `PLAN_LIMIT`
- BASIC plan user tries to use AI_DRAFTING → `PLAN_LIMIT`

---

### 7.4 Token/Auth Issues

**Scenario:** Invalid, expired, or missing Firebase Auth token

**Handling:**
- Firebase Callable Functions automatically validate tokens
- If invalid/expired → Firebase returns auth error before function executes
- If missing → Firebase returns auth error

**Test Cases:**
- No token provided → Firebase auth error
- Expired token → Firebase auth error
- Invalid token format → Firebase auth error

---

### 7.5 Cross-Org Access Attempt

**Scenario:** User tries to access resource from different org

**Handling:**
- Verify `object.orgId === user.orgId`
- If mismatch → return `NOT_AUTHORIZED`
- Error message: "Resource does not belong to your organization"

**Test Cases:**
- User from org_123 tries to access case from org_456 → `NOT_AUTHORIZED`
- User provides wrong orgId in request → `NOT_AUTHORIZED`

---

### 7.6 Duplicate Org Creation

**Scenario:** User tries to create multiple orgs (if rate limited)

**Handling:**
- Check rate limit (if implemented)
- If exceeded → return `RATE_LIMITED`
- Error message: "Too many organization creations. Please try again later."

**Test Cases:**
- User creates 5 orgs in 1 minute → `RATE_LIMITED` (if limit is 3)

---

### 7.7 Duplicate Membership

**Scenario:** User tries to join org they're already a member of

**Handling:**
- Use Firestore transaction to check membership atomically
- If membership already exists → return success with message "Already a member" (idempotent behavior)
- This prevents race conditions when multiple users join simultaneously
- Transaction ensures atomic check-and-create operation

**Concurrency Protection:**
- Wrap membership creation in Firestore transaction
- Check `!exists(memberDoc)` inside transaction
- Atomically create membership if check passes
- If membership exists, return existing membership data (idempotent)

**Test Cases:**
- User calls `org.join` twice with same orgId → Success on both calls (idempotent)
- Two users join same org simultaneously → Both succeed without race condition
- Transaction retries on conflict → Handled automatically by Firestore

---

### 7.8 Missing Required Fields

**Scenario:** Request missing required fields (name, orgId, etc.)

**Handling:**
- Validate all required fields present and non-empty
- If missing → return `VALIDATION_ERROR`
- Error message: "Missing required field: [fieldName]"

**Test Cases:**
- `org.create` without name → `VALIDATION_ERROR`
- `org.join` without orgId → `VALIDATION_ERROR`
- `member.getMyMembership` without orgId → `VALIDATION_ERROR`

---

## 8) Definition of Done

### 8.1 Core Functionality ✅

- [ ] User can sign up with Firebase Auth
- [ ] User can log in with Firebase Auth
- [ ] User can create an organization via `org.create`
- [ ] User automatically gets ADMIN role when creating org
- [ ] Org is created with FREE plan by default
- [ ] User can join an existing organization via `org.join`
- [ ] User gets VIEWER role when joining org
- [ ] User can retrieve their membership info via `member.getMyMembership`
- [ ] All endpoints return structured JSON responses (success/error format)

### 8.2 Entitlements Engine ✅

- [ ] `entitlement.check` helper function implemented
- [ ] Org membership validation works
- [ ] Plan feature gating works (returns PLAN_LIMIT when blocked)
- [ ] Role permission checking works (returns NOT_AUTHORIZED when blocked)
- [ ] Org scoping validation works (prevents cross-org access)
- [ ] Entitlement checks are reusable across all endpoints

### 8.3 Firestore Structure ✅

- [ ] `organizations/{orgId}` collection created with required fields
- [ ] `organizations/{orgId}/members/{uid}` subcollection created with required fields
- [ ] `organizations/{orgId}/audit_events/{eventId}` subcollection created with required fields
- [ ] All documents include `orgId` field (where applicable)
- [ ] All documents include `createdAt`, `updatedAt` timestamps
- [ ] All documents include `createdBy` field

### 8.4 Security Rules ✅

- [ ] Firestore security rules enforce org membership for reads
- [ ] Firestore security rules prevent direct client writes (all writes via Cloud Functions)
- [ ] Storage rules (if applicable) enforce org membership
- [ ] No sensitive data exposed in client-readable fields

### 8.5 Error Handling ✅

- [ ] All endpoints return consistent error format
- [ ] Error codes match master spec: ORG_REQUIRED, NOT_AUTHORIZED, PLAN_LIMIT, VALIDATION_ERROR, NOT_FOUND, INTERNAL_ERROR, RATE_LIMITED
- [ ] ORG_REQUIRED error code is returned when orgId is missing
- [ ] Error messages are user-friendly (no stack traces)
- [ ] Error responses include proper HTTP status codes

### 8.6 Testing ✅

**Happy Path Tests:**
- [ ] User creates org → org created, user is ADMIN, plan is FREE
- [ ] User joins org → membership created, user is VIEWER
- [ ] User gets membership → returns correct role and plan info

**Unauthorized Tests:**
- [ ] Non-member tries to access org resource → NOT_AUTHORIZED
- [ ] User with insufficient role tries protected action → NOT_AUTHORIZED
- [ ] User tries to access different org's resource → NOT_AUTHORIZED

**Plan Blocked Tests:**
- [ ] FREE plan user tries to use AI_RESEARCH → PLAN_LIMIT
- [ ] FREE plan user tries to use TASKS → PLAN_LIMIT
- [ ] BASIC plan user tries to use AI_DRAFTING → PLAN_LIMIT

**Validation Tests:**
- [ ] `org.create` without name → VALIDATION_ERROR
- [ ] `org.join` without orgId → VALIDATION_ERROR
- [ ] `org.join` with invalid orgId → NOT_FOUND

**Edge Case Tests:**
- [ ] User tries to join org twice → Success on both calls (idempotent behavior)
- [ ] Two users join same org simultaneously → Both succeed without race condition
- [ ] User tries to join non-existent org → NOT_FOUND
- [ ] Missing auth token → Firebase auth error (handled by Firebase)

**Firestore Rules Tests:**
- [ ] Non-member cannot read org document
- [ ] Non-member cannot read membership document
- [ ] Member can read org document
- [ ] Member can read their own membership document
- [ ] Direct client write to org document is rejected

**Audit Logging Tests:**
- [ ] Org creation creates audit event
- [ ] Audit event has all required fields (orgId, actorUid, action, timestamp)
- [ ] Membership creation creates audit event

**Entitlements Tests:**
- [ ] PLAN_FEATURES constant is used correctly
- [ ] ROLE_PERMISSIONS constant is used correctly
- [ ] entitlement.check returns correct reason codes
- [ ] ORG_REQUIRED is returned when orgId is missing

### 8.7 Documentation ✅

- [ ] All endpoint signatures documented
- [ ] Request/response examples provided
- [ ] Error codes and scenarios documented
- [ ] Firestore document structures documented
- [ ] Entitlement evaluation flow documented

### 8.8 Code Quality ✅

- [ ] All Cloud Functions follow consistent structure
- [ ] Error handling is consistent across all endpoints
- [ ] Entitlement checks use reusable helper function
- [ ] No hardcoded plan/role values (use constants)
- [ ] Logging added for critical actions (org creation, membership changes)

---

## 9) Implementation Notes

### 9.1 Firebase Auth Integration

- Use Firebase Auth SDK in Flutter for login/signup
- Cloud Functions receive `context.auth.uid` automatically
- No need to manually validate tokens (Firebase handles this)

**Flutter Implementation:** 
- Basic auth screens (login/signup/password reset) will be built in Slice 1 (UI System)
- Slice 0 ensures backend Cloud Functions and Firebase Auth integration are ready
- Auth UI screens (Login/Signup/Forgot Password) are implemented in Slice 1 (UI System)
- Slice 0 does not include UI screens

### 9.2 Plan Entitlements Lookup

**Required Constant:**
```typescript
// constants/entitlements.ts
// Must match Master Spec Section 4.7 (Entitlements Matrix)

export const PLAN_FEATURES = {
  FREE: {
    CASES: true,
    CLIENTS: true,
    TEAM_MEMBERS: false,
    TASKS: false,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: false,
    AI_RESEARCH: false,
    AI_DRAFTING: false,
    EXPORTS: false,
    AUDIT_TRAIL: false,
    NOTIFICATIONS: false,
    ADVANCED_SEARCH: false,
    BILLING_SUBSCRIPTION: true,
    ADMIN_PANEL: false,
  },
  BASIC: {
    CASES: true,
    CLIENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: false,
    EXPORTS: true,
    AUDIT_TRAIL: false,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: false,
    BILLING_SUBSCRIPTION: true,
    ADMIN_PANEL: true,
  },
  PRO: {
    CASES: true,
    CLIENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: true,
    EXPORTS: true,
    AUDIT_TRAIL: true,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: true,
    BILLING_SUBSCRIPTION: true,
    ADMIN_PANEL: true,
  },
  ENTERPRISE: {
    CASES: true,
    CLIENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: true,
    EXPORTS: true,
    AUDIT_TRAIL: true,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: true,
    BILLING_SUBSCRIPTION: true,
    ADMIN_PANEL: true,
  },
};
```

**Usage in entitlement.check:**
```typescript
if (requiredFeature && !PLAN_FEATURES[plan][requiredFeature]) {
  return { allowed: false, reason: "PLAN_LIMIT" };
}
```

**Constants Module Structure:**
- `/constants/entitlements.ts` - PLAN_FEATURES constant
- `/constants/permissions.ts` - ROLE_PERMISSIONS constant
- `/constants/errors.ts` - Error codes and messages
- `/constants/index.ts` - Unified exports

**Example:**
```typescript
// constants/index.ts
export * from './entitlements';
export * from './permissions';
export * from './errors';
```

### 9.3 Role Permissions Lookup

**Required Constant:**
```typescript
// constants/permissions.ts
// Must match Master Spec Section 4.8 (Permissions Matrix)

export const ROLE_PERMISSIONS = {
  ADMIN: {
    'case.create': true,
    'case.read': true,
    'case.update': true,
    'case.close': true,
    'client.create': true,
    'client.update': true,
    'doc.metadata.view': true,
    'doc.content.view': true,
    'doc.upload': true,
    'doc.delete': true,
    'ai.metadata.view': true,
    'ai.results.view': true,
    'ai.ask': true,
    'ai.draft': true,
    'task.create': true,
    'task.assign': true,
    'task.complete': true,
    'audit.view': true,
    'admin.manage_users': true,
    'admin.manage_plan': true,
    'billing.manage': true,
  },
  LAWYER: {
    'case.create': true,
    'case.read': true,
    'case.update': true,
    'case.close': true,
    'client.create': true,
    'client.update': true,
    'doc.metadata.view': true,
    'doc.content.view': true,
    'doc.upload': true,
    'doc.delete': false,
    'ai.metadata.view': true,
    'ai.results.view': true,
    'ai.ask': true,
    'ai.draft': true,
    'task.create': true,
    'task.assign': true,
    'task.complete': true,
    'audit.view': true,
    'admin.manage_users': false,
    'admin.manage_plan': false,
    'billing.manage': false,
  },
  PARALEGAL: {
    'case.create': false,
    'case.read': true,
    'case.update': true,
    'case.close': false,
    'client.create': true,
    'client.update': true,
    'doc.metadata.view': true,
    'doc.content.view': true,
    'doc.upload': true,
    'doc.delete': false,
    'ai.metadata.view': true,
    'ai.results.view': true,
    'ai.ask': true,
    'ai.draft': true,
    'task.create': true,
    'task.assign': true,
    'task.complete': true,
    'audit.view': true,
    'admin.manage_users': false,
    'admin.manage_plan': false,
    'billing.manage': false,
  },
  VIEWER: {
    'case.create': false,
    'case.read': true,
    'case.update': false,
    'case.close': false,
    'client.create': false,
    'client.update': false,
    'doc.metadata.view': true,
    'doc.content.view': true,
    'doc.upload': false,
    'doc.delete': false,
    'ai.metadata.view': true,
    'ai.results.view': true,
    'ai.ask': false,
    'ai.draft': false,
    'task.create': false,
    'task.assign': false,
    'task.complete': false,
    'audit.view': true,
    'admin.manage_users': false,
    'admin.manage_plan': false,
    'billing.manage': false,
  },
};
```

**Usage in entitlement.check:**
```typescript
if (requiredPermission && !ROLE_PERMISSIONS[role][requiredPermission]) {
  return { allowed: false, reason: "ROLE_BLOCKED" };
}
```

**Constants Module Structure:**
- `/constants/entitlements.ts` - PLAN_FEATURES constant
- `/constants/permissions.ts` - ROLE_PERMISSIONS constant
- `/constants/errors.ts` - Error codes and messages
- `/constants/index.ts` - Unified exports

**Example:**
```typescript
// constants/index.ts
export * from './entitlements';
export * from './permissions';
export * from './errors';
```

### 9.4 Firestore Security Rules

**Complete Rules for Slice 0:**

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function: Check if user is member of org
    function isMember(orgId) {
      return request.auth != null && 
        exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
    }

    // Organizations collection
    match /organizations/{orgId} {
      allow read: if isMember(orgId);
      allow create: if request.auth != null && 
        request.resource.data.createdBy == request.auth.uid;
      allow update, delete: if false; // Only via Cloud Functions
    }

    // Members subcollection
    match /organizations/{orgId}/members/{uid} {
      allow read: if isMember(orgId);
      allow write: if false; // Only via Cloud Functions
    }

    // Audit events subcollection
    match /organizations/{orgId}/audit_events/{eventId} {
      allow read: if isMember(orgId);
      allow write: if false; // Only via Cloud Functions
    }
  }
}
```

**Key Points:**
- All reads require org membership
- All writes go through Cloud Functions only
- Helper function `isMember()` is reusable
- No direct client writes to sensitive data

### 9.5 Audit Logging

- Slice 0 creates audit_events collection structure (see Section 5.3)
- Log org creation in `org.create` endpoint
- Log membership creation in `org.join` endpoint
- Full audit trail UI is Slice 12

### 9.6 Rate Limiting Status

**Implementation Status:**
- Rate limiting logic will be added in Slice 14 (Security Hardening)
- For Slice 0, the `RATE_LIMITED` error code is defined for future compatibility but not enforced
- Endpoints should be structured to handle this error code
- No rate limiting enforcement is implemented in Slice 0
- Actual rate limiting is implemented in Slice 14 (Security Hardening)

---

## 10) Dependencies

**External Services:**
- Firebase Authentication (required)
- Firestore Database (required)
- Cloud Functions (required)

**No Dependencies on Other Slices:**
- Slice 0 is the foundation
- All other slices depend on Slice 0

---

## 11) Estimated Effort

**Complexity:** High  
**Estimated Days:** 10-15 days  
**Dependencies:** None

**Breakdown:**
- Firebase Auth setup: 1-2 days
- Cloud Functions setup: 1-2 days
- Org/membership endpoints: 3-4 days
- Entitlements engine: 3-4 days
- Security rules: 1-2 days
- Testing: 2-3 days

---

END OF BUILD CARD
