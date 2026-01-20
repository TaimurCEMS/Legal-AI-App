# SLICE 2: Case Hub (Case Management) - Build Card

## 1) Purpose

Build the Case Hub feature that allows users to create, view, list, and manage legal cases within their organization. This slice establishes case management as the core entity that ties together clients, documents, and AI outputs. Cases are organization-scoped and support both ORG_WIDE and PRIVATE visibility.

## 2) Scope In ✅

### Backend (Cloud Functions):
- `case.create` - Create new cases
- `case.get` - Get case details by ID
- `case.list` - List cases for an organization (with filtering, search, pagination)
- `case.update` - Update case information
- `case.delete` - Soft delete cases (sets deletedAt timestamp)
- Case-client relationship management
- Case visibility enforcement (ORG_WIDE, PRIVATE)
- Entitlement checks (plan + role permissions)
- Audit logging for case operations
- Firestore security rules for case collection

### Frontend (Flutter):
- Case list screen (with search and filtering)
- Case creation form
- Case details view
- Case-client relationship UI
- Integration with existing navigation (AppShell)
- Loading states and error handling
- Empty states for no cases

### Data Model:
- Cases belong to organizations (orgId required)
- Cases can have associated clients (clientId optional)
- Case visibility (ORG_WIDE, PRIVATE)
- Case status tracking (OPEN, CLOSED, ARCHIVED)
- Soft delete support (deletedAt timestamp)

## 3) Scope Out ❌

- Client management UI (Slice 3)
- Document management UI (Slice 4)
- AI features (Slice 6+)
- Task management (Slice 5)
- Case access list management for PRIVATE cases (Slice 2.1)
- Case search across organizations
- Case templates
- Case duplication/cloning
- Case export functionality
- Advanced case filtering (by date range, status, etc.) - basic filtering only
- Case assignment to team members
- Case notes/comments (Slice 7)

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, membership, entitlements engine)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme system, reusable widgets)

**No Dependencies on:**
- Slice 3 (Client Hub) - Cases can exist without clients initially
- Slice 4+ (Documents, Tasks, AI, etc.)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `case.create` (Callable Function)

**Function Name:** `caseCreate`  
**Type:** Firebase Callable Function  
**Callable Name:** `case.create`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `case.create` (from ROLE_PERMISSIONS)

**Plan Gating:** `CASES` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "title": "string (required, 1-200 chars)",
  "description": "string (optional, max 2000 chars)",
  "clientId": "string (optional, must exist if provided)",
  "visibility": "ORG_WIDE | PRIVATE (optional, default: ORG_WIDE)",
  "status": "OPEN | CLOSED | ARCHIVED (optional, default: OPEN)"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "caseId": "string",
    "orgId": "string",
    "title": "string",
    "description": "string | null",
    "clientId": "string | null",
    "visibility": "ORG_WIDE | PRIVATE",
    "status": "OPEN | CLOSED | ARCHIVED",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing or invalid title, invalid description length, invalid visibility/status values
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `case.create` permission
- `NOT_FOUND` (404): ClientId provided but client doesn't exist
- `PLAN_LIMIT` (403): CASES feature not available in plan (shouldn't happen as all plans have it)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**CaseId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc(orgId).collection('cases').doc()`
- Example: "case_abc123def456"

**Title Validation:**
- Required: 1-200 characters
- Trim whitespace: `title.trim()`
- Sanitize: Remove leading/trailing special characters
- Pattern: Allow alphanumeric, spaces, hyphens, underscores, ampersands, commas, periods, parentheses, colons, semicolons
- Reject: Empty strings, only whitespace

**Description Validation (Optional):**
- Maximum: 2000 characters
- Trim whitespace
- Allow basic punctuation and line breaks

**Visibility Validation:**
- Must be one of: `ORG_WIDE`, `PRIVATE`
- Default: `ORG_WIDE` if not provided
- ORG_WIDE: All org members can see (subject to role permissions)
- PRIVATE: Only creator and explicitly granted users can see (access list management is Slice 2.1)

**Status Validation:**
- Must be one of: `OPEN`, `CLOSED`, `ARCHIVED`
- Default: `OPEN` if not provided

**ClientId Validation (Optional):**
- If provided, must exist in `organizations/{orgId}/clients/{clientId}`
- If client doesn't exist → return `NOT_FOUND`
- If client exists but belongs to different org → return `NOT_AUTHORIZED`

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.create' })`
4. Validate title (trim, sanitize, length check)
5. Validate description (optional, length check)
6. Validate visibility (default to ORG_WIDE)
7. Validate status (default to OPEN)
8. If clientId provided, validate client exists and belongs to org
9. Generate caseId using Firestore auto-ID
10. Create case document in `organizations/{orgId}/cases/{caseId}`
11. Create audit event (case.created)
12. Return case details

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'case.created',
    entityType: 'case',
    entityId: caseId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      title: sanitizedTitle,
      visibility: visibility,
      clientId: clientId || null,
    },
  });
```

---

### 5.2 `case.get` (Callable Function)

**Function Name:** `caseGet`  
**Type:** Firebase Callable Function  
**Callable Name:** `case.get`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `case.read` (from ROLE_PERMISSIONS)

**Plan Gating:** `CASES` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "caseId": "string",
    "orgId": "string",
    "title": "string",
    "description": "string | null",
    "clientId": "string | null",
    "clientName": "string | null (if clientId exists)",
    "visibility": "ORG_WIDE | PRIVATE",
    "status": "OPEN | CLOSED | ARCHIVED",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)",
    "deletedAt": "ISO 8601 timestamp | null"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing caseId
- `NOT_AUTHORIZED` (403): User not a member of org, role doesn't have `case.read`, or case is PRIVATE and user not in access list
- `NOT_FOUND` (404): Case doesn't exist or is soft-deleted
- `INTERNAL_ERROR` (500): Database read failure

**Implementation Details:**

**Visibility Check:**
- If case.visibility === "ORG_WIDE": Check org membership and role permission
- If case.visibility === "PRIVATE": Check org membership, role permission, AND access list (Slice 2.1 - for now, only creator can access)
- For Slice 2: PRIVATE cases are only accessible by creator (access list management is Slice 2.1)

**Soft Delete Check:**
- If case.deletedAt exists and is not null → return `NOT_FOUND`
- Soft-deleted cases should not be returned

**Client Name Lookup:**
- If clientId exists, lookup client name from `organizations/{orgId}/clients/{clientId}`
- Include clientName in response for convenience

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and caseId (both required)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.read' })`
4. Fetch case document
5. Check if case exists and is not soft-deleted
6. Check visibility:
   - If ORG_WIDE: Verify org membership (already checked in entitlement)
   - If PRIVATE: Verify user is creator (for Slice 2, access list is Slice 2.1)
7. If clientId exists, lookup client name
8. Return case details with client name

---

### 5.3 `case.list` (Callable Function)

**Function Name:** `caseList`  
**Type:** Firebase Callable Function  
**Callable Name:** `case.list`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `case.read` (from ROLE_PERMISSIONS)

**Plan Gating:** `CASES` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "limit": "number (optional, default: 50, max: 100)",
  "offset": "number (optional, default: 0)",
  "status": "OPEN | CLOSED | ARCHIVED (optional, filter by status)",
  "clientId": "string (optional, filter by client)",
  "search": "string (optional, search in title/description)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "cases": [
      {
        "caseId": "string",
        "orgId": "string",
        "title": "string",
        "description": "string | null",
        "clientId": "string | null",
        "clientName": "string | null",
        "visibility": "ORG_WIDE | PRIVATE",
        "status": "OPEN | CLOSED | ARCHIVED",
        "createdAt": "ISO 8601 timestamp",
        "updatedAt": "ISO 8601 timestamp",
        "createdBy": "string (uid)"
      }
    ],
    "total": "number (total count matching filters, before limit/offset)",
    "hasMore": "boolean (true if more cases available)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid limit (must be 1-100), invalid offset (must be >= 0), invalid status value
- `NOT_AUTHORIZED` (403): User not a member of org or role doesn't have `case.read` permission
- `INTERNAL_ERROR` (500): Database query failure

**Implementation Details:**

**Filtering Logic:**
- Filter by status: `where('status', '==', status)`
- Filter by clientId: `where('clientId', '==', clientId)`
- **Search (Slice 2 Scope - Title Prefix Only):**
  - Firestore prefix search on `title` field only
  - Query: `where('title', '>=', searchTerm)` AND `where('title', '<=', searchTerm + '\uf8ff')`
  - **Limitations:**
    - Case-sensitive (searches for exact case match)
    - Does NOT search `description` field
    - Does NOT support full-text search
    - Does NOT support fuzzy matching
  - **Future Enhancement (Slice 2.2+):**
    - Add `searchTokens` field (generated on write, lowercase, tokenized)
    - Implement full-text search service (Algolia, Elasticsearch, or Firestore full-text search when available)
    - Support case-insensitive search
    - Support description search
- Exclude soft-deleted: `where('deletedAt', '==', null)`
- Order by: `orderBy('updatedAt', 'desc')` (most recently updated first)

**Visibility Filtering (LOCKED APPROACH - Two-Query Merge):**

Firestore does not support native OR queries. To include both ORG_WIDE and PRIVATE (creator only) cases, use two-query merge:

1. **Query 1: ORG_WIDE Cases**
   ```typescript
   const orgWideQuery = db
     .collection('organizations').doc(orgId)
     .collection('cases')
     .where('visibility', '==', 'ORG_WIDE')
     .where('deletedAt', '==', null);
   
   // Apply additional filters if provided
   if (status) orgWideQuery = orgWideQuery.where('status', '==', status);
   if (clientId) orgWideQuery = orgWideQuery.where('clientId', '==', clientId);
   if (search) {
     orgWideQuery = orgWideQuery
       .where('title', '>=', search)
       .where('title', '<=', search + '\uf8ff');
   }
   
   orgWideQuery = orgWideQuery.orderBy('updatedAt', 'desc');
   const orgWideResults = await orgWideQuery.get();
   ```

2. **Query 2: PRIVATE Cases (Creator Only)**
   ```typescript
   const privateQuery = db
     .collection('organizations').doc(orgId)
     .collection('cases')
     .where('visibility', '==', 'PRIVATE')
     .where('createdBy', '==', uid)
     .where('deletedAt', '==', null);
   
   // Apply same additional filters
   if (status) privateQuery = privateQuery.where('status', '==', status);
   if (clientId) privateQuery = privateQuery.where('clientId', '==', clientId);
   if (search) {
     privateQuery = privateQuery
       .where('title', '>=', search)
       .where('title', '<=', search + '\uf8ff');
   }
   
   privateQuery = privateQuery.orderBy('updatedAt', 'desc');
   const privateResults = await privateQuery.get();
   ```

3. **Merge Results:**
   - Combine both result sets into single array
   - Remove duplicates (shouldn't occur, but safety check)
   - Sort merged array by `updatedAt` descending
   - Apply pagination (limit/offset) to merged results
   - Calculate `hasMore`: `mergedResults.length === limit + offset` indicates more available

**Pagination (Cursor-Based Recommended, Offset Acceptable for MVP):**

**Recommended Approach: Cursor-Based Pagination**
- Use `startAfter()` with last document snapshot
- More efficient for large datasets
- Scales better as collection grows
- Request payload: `{ orgId, limit, lastCaseId?, lastUpdatedAt? }`
- Response includes: `{ cases, hasMore, lastCaseId, lastUpdatedAt }`

**MVP Fallback: Offset-Based Pagination**
- Use `limit()` and `offset()` for simplicity
- Works fine for small datasets (< 10,000 cases)
- **Tech Debt Note:** Replace with cursor-based when collection exceeds 10,000 cases
- Calculate `hasMore`: `cases.length === limit` (if full limit returned, more may exist)
- Total count: Not provided (would require separate count query, expensive)

**Implementation Decision:** Use cursor-based pagination for world-class scalability. If time-constrained, offset is acceptable for MVP but must be documented as tech debt.

**Client Name Lookup:**
- Batch lookup client names for all cases with clientId
- Include clientName in each case object

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required)
3. Validate limit (1-100, default 50) and offset (>= 0, default 0)
4. Validate status filter (if provided)
5. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.read' })`
6. Execute two-query merge:
   - Query 1: ORG_WIDE cases with filters
   - Query 2: PRIVATE cases (creator only) with filters
   - Merge results and sort by updatedAt desc
   - Apply pagination (cursor-based or offset)
7. Batch lookup client names for all cases with clientId
8. Return cases with client names, pagination info (hasMore, lastCaseId if cursor-based)

---

### 5.4 `case.update` (Callable Function)

**Function Name:** `caseUpdate`  
**Type:** Firebase Callable Function  
**Callable Name:** `case.update`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `case.update` (from ROLE_PERMISSIONS)

**Plan Gating:** `CASES` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "title": "string (optional, 1-200 chars)",
  "description": "string (optional, max 2000 chars)",
  "clientId": "string (optional, null to remove client)",
  "visibility": "ORG_WIDE | PRIVATE (optional)",
  "status": "OPEN | CLOSED | ARCHIVED (optional)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "caseId": "string",
    "orgId": "string",
    "title": "string",
    "description": "string | null",
    "clientId": "string | null",
    "clientName": "string | null",
    "visibility": "ORG_WIDE | PRIVATE",
    "status": "OPEN | CLOSED | ARCHIVED",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing caseId, invalid field values
- `NOT_AUTHORIZED` (403): User not a member of org, role doesn't have `case.update`, or case is PRIVATE and user not creator
- `NOT_FOUND` (404): Case doesn't exist or is soft-deleted
- `NOT_FOUND` (404): ClientId provided but client doesn't exist
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Update Logic:**
- Only update fields that are provided in request
- Validate each field if provided (same validation as create)
- Update `updatedAt` timestamp
- Update `updatedBy` with current uid
- If clientId is explicitly set to null, remove client relationship

**Visibility Change:**
- If changing from ORG_WIDE to PRIVATE: No special handling (access list management is Slice 2.1)
- If changing from PRIVATE to ORG_WIDE: No special handling

**Status Change:**
- Allow status changes: OPEN → CLOSED, OPEN → ARCHIVED, CLOSED → ARCHIVED, etc.
- No restrictions on status transitions for Slice 2

**Access Control:**
- Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.update' })`
- For PRIVATE cases: Only creator can update (for Slice 2, access list is Slice 2.1)

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and caseId (both required)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.update' })`
4. Fetch case document
5. Check if case exists and is not soft-deleted
6. Check visibility: If PRIVATE, verify user is creator
7. Validate and apply updates (only provided fields)
8. If clientId provided, validate client exists and belongs to org
9. Update case document with new values
10. Update `updatedAt` and `updatedBy`
11. Create audit event (case.updated)
12. Lookup client name if clientId exists
13. Return updated case details

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'case.updated',
    entityType: 'case',
    entityId: caseId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      updatedFields: Object.keys(updates),
      // Don't log sensitive data, just field names
    },
  });
```

---

### 5.5 `case.delete` (Callable Function)

**Function Name:** `caseDelete`  
**Type:** Firebase Callable Function  
**Callable Name:** `case.delete`

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `case.delete` (from ROLE_PERMISSIONS - must be added to permissions.ts)

**Plan Gating:** `CASES` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "caseId": "string",
    "deletedAt": "ISO 8601 timestamp"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing caseId
- `NOT_AUTHORIZED` (403): User not a member of org, role doesn't have `case.delete` permission, or case is PRIVATE and user not creator
- `NOT_FOUND` (404): Case doesn't exist or already deleted
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Soft Delete Logic:**
- Sets `deletedAt` to current timestamp
- Does NOT permanently delete the document
- Soft-deleted cases are excluded from list/get queries
- Can be restored in future (restore functionality is Slice 2.1+)

**Access Control:**
- Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.delete' })`
- For PRIVATE cases: Only creator can delete (for Slice 2, access list is Slice 2.1)
- Verify case exists and is not already deleted

**Cascade Considerations:**
- Case deletion does NOT delete related documents (Slice 4)
- Case deletion does NOT delete related tasks (Slice 5)
- Related entities should handle orphaned case references gracefully
- Future: Hard delete will cascade (Slice 2.1+)

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and caseId (both required)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'case.delete' })`
4. Fetch case document
5. Check if case exists and is not already deleted
6. Check visibility: If PRIVATE, verify user is creator
7. Update case: Set `deletedAt` to current timestamp
8. Update `updatedAt` and `updatedBy` (for audit trail)
9. Create audit event (case.deleted)
10. Return success with deletedAt timestamp

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'case.deleted',
    entityType: 'case',
    entityId: caseId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      softDelete: true,
      deletedAt: admin.firestore.Timestamp.now().toMillis(),
    },
  });
```

**Note:** `case.delete` permission must be added to `ROLE_PERMISSIONS` in `functions/src/constants/permissions.ts`. Recommended permissions:
- ADMIN: `case.delete: true`
- LAWYER: `case.delete: true` (can delete their own cases)
- PARALEGAL: `case.delete: false`
- VIEWER: `case.delete: false`

---

## 6) Firestore Collections

### 6.1 `organizations/{orgId}/cases/{caseId}`

**Document Path:** `organizations/{orgId}/cases/{caseId}`

**Required Fields:**
```json
{
  "id": "string (same as caseId)",
  "orgId": "string (required)",
  "title": "string (required, 1-200 chars)",
  "description": "string (optional, max 2000 chars)",
  "clientId": "string (optional, null if no client)",
  "visibility": "ORG_WIDE | PRIVATE (required, default: ORG_WIDE)",
  "status": "OPEN | CLOSED | ARCHIVED (required, default: OPEN)",
  "createdAt": "Firestore Timestamp (required)",
  "updatedAt": "Firestore Timestamp (required)",
  "createdBy": "string (uid, required)",
  "updatedBy": "string (uid, required)",
  "deletedAt": "Firestore Timestamp | null (optional, null if not deleted)"
}
```

**Example Document:**
```json
{
  "id": "case_abc123",
  "orgId": "org_xyz789",
  "title": "Smith v. Jones Contract Dispute",
  "description": "Breach of contract case involving service agreement",
  "clientId": "client_def456",
  "visibility": "ORG_WIDE",
  "status": "OPEN",
  "createdAt": "2026-01-17T10:00:00Z",
  "updatedAt": "2026-01-17T10:00:00Z",
  "createdBy": "user_xyz789",
  "updatedBy": "user_xyz789",
  "deletedAt": null
}
```

**Indexing Notes:**
- Composite index on: `orgId`, `visibility`, `createdBy`, `updatedAt` (for list queries)
- Composite index on: `orgId`, `status`, `updatedAt` (for status filtering)
- Composite index on: `orgId`, `clientId`, `updatedAt` (for client filtering)
- Index on `deletedAt` for soft delete filtering

**Security Rules (Concrete Implementation):**

**File:** `firestore.rules` (root level)

**Case Collection Rules:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function: Check if user is member of org
    function isOrgMember(orgId) {
      return request.auth != null && 
        exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
    }

    // Cases collection
    match /organizations/{orgId}/cases/{caseId} {
      // Read rule: User must be org member AND
      //   (case is ORG_WIDE OR user is creator for PRIVATE cases) AND
      //   case is not soft-deleted
      allow read: if isOrgMember(orgId) && 
                     (resource.data.visibility == 'ORG_WIDE' || 
                      resource.data.createdBy == request.auth.uid) &&
                     resource.data.deletedAt == null;
      
      // Write rule: Only via Cloud Functions (no direct client writes)
      allow create, update, delete: if false;
    }
  }
}
```

**Security Rule Testing:**
- Test: Non-member cannot read cases → Denied
- Test: Member can read ORG_WIDE cases → Allowed
- Test: Member can read own PRIVATE cases → Allowed
- Test: Member cannot read others' PRIVATE cases → Denied
- Test: Member cannot read soft-deleted cases → Denied
- Test: Direct client write attempt → Denied
- Test: Cloud Function write (via admin SDK) → Allowed (bypasses rules)

**Deployment:**
```bash
firebase deploy --only firestore:rules
```

**Note:** Security rules are defense-in-depth. Cloud Functions must also enforce these rules. Rules prevent accidental client access, but Cloud Functions are the primary enforcement mechanism.

---

## 7) Frontend Implementation (Flutter)

### 7.1 Case Model

**File:** `legal_ai_app/lib/core/models/case_model.dart`

```dart
class CaseModel {
  final String caseId;
  final String orgId;
  final String title;
  final String? description;
  final String? clientId;
  final String? clientName;
  final CaseVisibility visibility;
  final CaseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;

  CaseModel({
    required this.caseId,
    required this.orgId,
    required this.title,
    this.description,
    this.clientId,
    this.clientName,
    required this.visibility,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.deletedAt,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      caseId: json['caseId'] as String,
      orgId: json['orgId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      clientId: json['clientId'] as String?,
      clientName: json['clientName'] as String?,
      visibility: CaseVisibility.fromString(json['visibility'] as String),
      status: CaseStatus.fromString(json['status'] as String),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String,
      updatedBy: json['updatedBy'] as String,
      deletedAt: json['deletedAt'] != null 
        ? _parseTimestamp(json['deletedAt']) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caseId': caseId,
      'orgId': orgId,
      'title': title,
      'description': description,
      'clientId': clientId,
      'clientName': clientName,
      'visibility': visibility.value,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is Map && timestamp['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (timestamp['_seconds'] as int) * 1000,
      );
    }
    throw FormatException('Invalid timestamp format');
  }
}

enum CaseVisibility {
  orgWide('ORG_WIDE'),
  private('PRIVATE');

  final String value;
  const CaseVisibility(this.value);

  static CaseVisibility fromString(String value) {
    return CaseVisibility.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CaseVisibility.orgWide,
    );
  }
}

enum CaseStatus {
  open('OPEN'),
  closed('CLOSED'),
  archived('ARCHIVED');

  final String value;
  const CaseStatus(this.value);

  static CaseStatus fromString(String value) {
    return CaseStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CaseStatus.open,
    );
  }
}
```

---

### 7.2 Case Service

**File:** `legal_ai_app/lib/core/services/case_service.dart`

**Methods:**
- `createCase({orgId, title, description, clientId, visibility, status})`
- `getCase({orgId, caseId})`
- `listCases({orgId, limit, offset, status, clientId, search})` - OR cursor-based: `listCases({orgId, limit, lastCaseId, lastUpdatedAt, status, clientId, search})`
- `updateCase({orgId, caseId, title, description, clientId, visibility, status})`
- `deleteCase({orgId, caseId})` - Soft delete case

**Implementation:**
- Use `CloudFunctionsService` to call backend functions
- Handle errors consistently
- Return standardized response format
- Parse timestamps correctly (handle both String and Timestamp formats)

---

### 7.3 Case Provider (State Management)

**File:** `legal_ai_app/lib/features/cases/providers/case_provider.dart`

**State:**
- `List<CaseModel> cases` - Current list of cases
- `CaseModel? selectedCase` - Currently selected case
- `bool isLoading` - Loading state
- `String? error` - Error message
- `bool hasMore` - Whether more cases available

**Methods:**
- `loadCases({status, clientId, search})` - Load cases list (first page)
- `loadMoreCases()` - Load next page (cursor-based or offset-based)
- `loadCaseDetails(caseId)` - Load single case
- `createCase({title, description, clientId, visibility, status})` - Create new case
- `updateCase(caseId, {title, description, clientId, visibility, status})` - Update case
- `deleteCase(caseId)` - Soft delete case
- `refreshCases()` - Refresh cases list

---

### 7.4 Case List Screen

**File:** `legal_ai_app/lib/features/cases/screens/case_list_screen.dart`

**Features:**
- Display list of cases in cards
- Search bar (search in title only - prefix search, case-sensitive)
- Filter by status (OPEN, CLOSED, ARCHIVED)
- Filter by client (if clients exist - Slice 3)
- Pull-to-refresh
- Infinite scroll (load more on scroll)
- Empty state when no cases
- Loading state
- Error state with retry
- "Create Case" button (if user has permission)

**Case Card Display:**
- Case title
- Case description (truncated)
- Client name (if exists)
- Status badge (OPEN/CLOSED/ARCHIVED)
- Visibility indicator (ORG_WIDE/PRIVATE)
- Last updated date
- Click to navigate to case details

---

### 7.5 Case Create Screen

**File:** `legal_ai_app/lib/features/cases/screens/case_create_screen.dart`

**Form Fields:**
- Title (required, text input)
- Description (optional, multiline text input)
- Client (optional, dropdown - placeholder for Slice 3)
- Visibility (ORG_WIDE/PRIVATE, radio buttons or dropdown)
- Status (default: OPEN, hidden or disabled)

**Validation:**
- Title: Required, 1-200 characters
- Description: Optional, max 2000 characters
- Show validation errors inline

**Actions:**
- "Create" button (disabled while loading)
- "Cancel" button (navigate back)
- Show loading state during creation
- Show success message and navigate to case details
- Show error message if creation fails

---

### 7.6 Case Details Screen

**File:** `legal_ai_app/lib/features/cases/screens/case_details_screen.dart`

**Display:**
- Case title (editable if user has permission)
- Case description (editable if user has permission)
- Client name (if exists, link to client - Slice 3)
- Status badge (editable if user has permission)
- Visibility indicator
- Created date and creator
- Updated date and updater
- "Edit" button (if user has permission)
- "Delete" button (if user has permission - soft delete, calls `case.delete` endpoint)

**Edit Mode:**
- Same form as create screen
- Pre-populate with current values
- "Save" and "Cancel" buttons
- Show loading state during update
- Show success/error messages

---

### 7.7 Navigation Integration

**Update:** `legal_ai_app/lib/core/routing/route_names.dart`

```dart
class RouteNames {
  // ... existing routes ...
  static const String caseList = '/cases';
  static const String caseCreate = '/cases/create';
  static const String caseDetails = '/cases/:caseId';
}
```

**Update:** `legal_ai_app/lib/core/routing/app_router.dart`
- Add routes for case list, create, and details
- Add route guards (auth required, org required)

**Update:** `legal_ai_app/lib/features/home/widgets/app_shell.dart`
- Add "Cases" tab to bottom navigation
- Navigate to case list on tab tap

---

## 8) Implementation Checklist

### 8.1 Backend (Cloud Functions)

#### Setup
- [ ] Create `functions/src/functions/case.ts` file
- [ ] Add `case.delete` permission to `ROLE_PERMISSIONS` in `functions/src/constants/permissions.ts`
  - ADMIN: `case.delete: true`
  - LAWYER: `case.delete: true`
  - PARALEGAL: `case.delete: false`
  - VIEWER: `case.delete: false`
- [ ] Export `caseCreate`, `caseGet`, `caseList`, `caseUpdate`, `caseDelete` functions
- [ ] Update `functions/src/index.ts` to export all case functions

#### Case Create
- [ ] Implement `caseCreate` function
- [ ] Add entitlement check (`case.create` permission)
- [ ] Add title validation (1-200 chars)
- [ ] Add description validation (max 2000 chars)
- [ ] Add visibility validation (default ORG_WIDE)
- [ ] Add status validation (default OPEN)
- [ ] Add clientId validation (if provided)
- [ ] Create case document in Firestore
- [ ] Create audit event
- [ ] Return case details

#### Case Get
- [ ] Implement `caseGet` function
- [ ] Add entitlement check (`case.read` permission)
- [ ] Add visibility check (ORG_WIDE or PRIVATE with creator check)
- [ ] Add soft delete check
- [ ] Lookup client name if clientId exists
- [ ] Return case details

#### Case List
- [ ] Implement `caseList` function
- [ ] Add entitlement check (`case.read` permission)
- [ ] Implement two-query merge for visibility:
  - [ ] Query 1: ORG_WIDE cases with filters
  - [ ] Query 2: PRIVATE cases (creator only) with filters
  - [ ] Merge results and sort by updatedAt desc
- [ ] Add pagination (cursor-based recommended OR offset for MVP)
- [ ] Add status filtering (apply to both queries)
- [ ] Add clientId filtering (apply to both queries)
- [ ] Add search (title prefix match only, apply to both queries)
- [ ] Exclude soft-deleted cases (apply to both queries)
- [ ] Batch lookup client names for all cases
- [ ] Return cases with pagination info (hasMore, lastCaseId if cursor-based)

#### Case Update
- [ ] Implement `caseUpdate` function
- [ ] Add entitlement check (`case.update` permission)
- [ ] Add visibility check for PRIVATE cases
- [ ] Add field validation (same as create)
- [ ] Update only provided fields
- [ ] Update `updatedAt` and `updatedBy`
- [ ] Create audit event
- [ ] Return updated case details

#### Case Delete
- [ ] Add `case.delete` permission to ROLE_PERMISSIONS constant
- [ ] Implement `caseDelete` function
- [ ] Add entitlement check (`case.delete` permission)
- [ ] Add visibility check for PRIVATE cases
- [ ] Set `deletedAt` timestamp (soft delete)
- [ ] Update `updatedAt` and `updatedBy`
- [ ] Create audit event (case.deleted)
- [ ] Return success with deletedAt timestamp

#### Testing
- [ ] Test case creation (happy path)
- [ ] Test case creation validation errors
- [ ] Test case creation permission errors
- [ ] Test case retrieval (happy path)
- [ ] Test case retrieval visibility checks
- [ ] Test case list (happy path)
- [ ] Test case list filtering
- [ ] Test case list pagination
- [ ] Test case update (happy path)
- [ ] Test case update validation errors
- [ ] Test case update permission errors

### 8.2 Frontend (Flutter)

#### Models
- [ ] Create `CaseModel` class
- [ ] Create `CaseVisibility` enum
- [ ] Create `CaseStatus` enum
- [ ] Add timestamp parsing (handle String and Timestamp formats)
- [ ] Add JSON serialization

#### Services
- [ ] Create `CaseService` class
- [ ] Implement `createCase` method
- [ ] Implement `getCase` method
- [ ] Implement `listCases` method (support both cursor-based and offset pagination)
- [ ] Implement `updateCase` method
- [ ] Implement `deleteCase` method
- [ ] Add error handling
- [ ] Add logging

#### Providers
- [ ] Create `CaseProvider` class
- [ ] Add state management (cases list, selected case, loading, error)
- [ ] Implement `loadCases` method
- [ ] Implement `loadMoreCases` method
- [ ] Implement `loadCaseDetails` method
- [ ] Implement `createCase` method
- [ ] Implement `updateCase` method
- [ ] Implement `deleteCase` method
- [ ] Implement `refreshCases` method

#### Screens
- [ ] Create `CaseListScreen`
- [ ] Add case cards display
- [ ] Add search bar
- [ ] Add status filter
- [ ] Add client filter (placeholder)
- [ ] Add pull-to-refresh
- [ ] Add infinite scroll
- [ ] Add empty state
- [ ] Add loading state
- [ ] Add error state
- [ ] Add "Create Case" button
- [ ] Create `CaseCreateScreen`
- [ ] Add form fields (title, description, client, visibility)
- [ ] Add validation
- [ ] Add create action
- [ ] Add loading/error states
- [ ] Create `CaseDetailsScreen`
- [ ] Add case details display
- [ ] Add edit mode
- [ ] Add update action
- [ ] Add delete action (soft delete)

#### Navigation
- [ ] Add case routes to `RouteNames`
- [ ] Add case routes to `AppRouter`
- [ ] Add "Cases" tab to `AppShell`
- [ ] Test navigation flow

#### Integration
- [ ] Test end-to-end case creation
- [ ] Test end-to-end case listing
- [ ] Test end-to-end case details
- [ ] Test end-to-end case update
- [ ] Test error handling
- [ ] Test loading states
- [ ] Test empty states

### 8.3 Firestore

#### Collections
- [ ] Create `organizations/{orgId}/cases/{caseId}` collection structure
- [ ] Add required fields to case documents
- [ ] Test document creation
- [ ] Test document retrieval
- [ ] Test document update

#### Indexes
- [ ] Create composite index for ORG_WIDE case list queries:
  - Collection: `organizations/{orgId}/cases`
  - Fields: `visibility` (ASC), `deletedAt` (ASC), `updatedAt` (DESC)
  - Query scope: Collection
- [ ] Create composite index for PRIVATE case list queries:
  - Collection: `organizations/{orgId}/cases`
  - Fields: `visibility` (ASC), `createdBy` (ASC), `deletedAt` (ASC), `updatedAt` (DESC)
  - Query scope: Collection
- [ ] Create composite index for status filtering:
  - Fields: `visibility` (ASC), `status` (ASC), `deletedAt` (ASC), `updatedAt` (DESC)
- [ ] Create composite index for client filtering:
  - Fields: `visibility` (ASC), `clientId` (ASC), `deletedAt` (ASC), `updatedAt` (DESC)
- [ ] Create composite index for title search:
  - Fields: `visibility` (ASC), `title` (ASC), `deletedAt` (ASC), `updatedAt` (DESC)
- [ ] Deploy indexes: `firebase deploy --only firestore:indexes`

#### Security Rules
- [ ] Write concrete Firestore rules for cases collection (see Section 6.2)
- [ ] Add read rule (org membership + visibility check + soft delete check)
- [ ] Add write rule (only via Cloud Functions - deny all client writes)
- [ ] Test security rules with test cases:
  - [ ] Non-member read attempt → Denied
  - [ ] Member read ORG_WIDE case → Allowed
  - [ ] Member read own PRIVATE case → Allowed
  - [ ] Member read others' PRIVATE case → Denied
  - [ ] Member read soft-deleted case → Denied
  - [ ] Direct client write attempt → Denied
- [ ] Deploy rules: `firebase deploy --only firestore:rules`

### 8.4 Documentation
- [ ] Document all endpoint signatures
- [ ] Document request/response examples
- [ ] Document error codes
- [ ] Document Firestore document structure
- [ ] Update README with Slice 2 status
- [ ] Update SLICE_STATUS.md

---

## 9) Learnings Applied

Based on `docs/DEVELOPMENT_LEARNINGS.md`:

### Learning 1: Function Name Consistency
- ✅ Use exact export names: `caseCreate`, `caseGet`, `caseList`, `caseUpdate`
- ✅ Document callable names in comments but use export names in code
- ✅ Verify function names match between backend and frontend

### Learning 2: Firebase Configuration
- ✅ Ensure `firebase_options.dart` has real values (no placeholders)
- ✅ Verify region configuration matches (`us-central1`)

### Learning 3: Error Handling
- ✅ Use structured error responses (success/error format)
- ✅ Show user-friendly error messages in UI
- ✅ Log detailed errors with `debugPrint()` for debugging
- ✅ Check browser console (F12) for full error details

### Learning 4: Timestamp Handling
- ✅ Handle both String and Timestamp formats in Flutter
- ✅ Use consistent timestamp parsing in models
- ✅ Test with actual Firestore Timestamp objects

### Learning 5: State Management
- ✅ Use Provider for state management (consistent with Slice 1)
- ✅ Separate concerns: Models, Services, Providers, Screens
- ✅ Handle loading and error states consistently

### Learning 6: UI Consistency
- ✅ Use existing theme system from Slice 1
- ✅ Use existing reusable widgets (AppButton, AppTextField, AppCard, etc.)
- ✅ Follow existing navigation patterns
- ✅ Maintain consistent spacing and typography

---

## 10) Estimated Effort

**Complexity:** High  
**Estimated Days:** 12-18 days  
**Dependencies:** Slice 0 ✅, Slice 1 ✅

**Breakdown:**
- Backend Cloud Functions: 5-7 days
  - Case create: 1 day
  - Case get: 1 day
  - Case list: 2 days (filtering, pagination, visibility)
  - Case update: 1 day
  - Testing: 1-2 days
- Frontend Flutter: 5-7 days
  - Models and services: 1 day
  - Providers: 1 day
  - Case list screen: 2 days
  - Case create screen: 1 day
  - Case details screen: 1 day
  - Integration: 1 day
- Firestore setup: 1-2 days
  - Collection structure: 0.5 day
  - Indexes: 0.5 day
  - Security rules: 0.5 day
  - Testing: 0.5 day
- Testing & polish: 1-2 days

---

## 11) Success Criteria

**Slice 2 is complete when:**
- ✅ All 5 Cloud Functions deployed and working (`case.create`, `case.get`, `case.list`, `case.update`, `case.delete`)
- ✅ Users can create cases via UI
- ✅ Users can view case list with filtering
- ✅ Users can view case details
- ✅ Users can update cases via UI
- ✅ Users can delete cases via UI (soft delete)
- ✅ Case-client relationships work (when clientId provided)
- ✅ Case visibility enforcement works (ORG_WIDE, PRIVATE)
- ✅ Entitlement checks work (plan + role permissions)
- ✅ Audit logging works for all case operations
- ✅ Firestore security rules enforce access
- ✅ Soft delete works (cases not shown when deletedAt set)
- ✅ Loading states and error handling work
- ✅ Empty states display correctly
- ✅ Navigation integrated with AppShell
- ✅ **State Persistence Requirements (CRITICAL):**
  - ✅ Organization persists across browser refresh (F5)
  - ✅ Organization persists across tab close/reopen
  - ✅ Cases list persists when switching tabs (Cases → Clients → Cases)
  - ✅ Cases list reloads from backend after browser refresh
  - ✅ Cases list reloads from backend after app restart
  - ✅ Created cases appear immediately in list (no refresh needed)
  - ✅ Updated cases reflect changes immediately
  - ✅ Deleted cases disappear immediately
- ✅ All tests passing
- ✅ Code follows Flutter/TypeScript best practices
- ✅ No business logic in UI (all in backend)

**See [Testing & Acceptance Criteria](../TESTING_ACCEPTANCE_CRITERIA.md) for detailed test cases.**

---

## 12) Edge Cases & Failure States

### 12.1 Missing OrgId
- **Scenario:** Request missing orgId
- **Handling:** Return `ORG_REQUIRED` error
- **Test:** Case create without orgId → `ORG_REQUIRED`

### 12.2 Invalid CaseId
- **Scenario:** CaseId doesn't exist
- **Handling:** Return `NOT_FOUND` error
- **Test:** Get case with invalid caseId → `NOT_FOUND`

### 12.3 Soft-Deleted Case
- **Scenario:** Case exists but deletedAt is set
- **Handling:** Return `NOT_FOUND` (don't show soft-deleted cases)
- **Test:** Get/list soft-deleted case → `NOT_FOUND` or excluded from list

### 12.4 PRIVATE Case Access
- **Scenario:** User tries to access PRIVATE case they didn't create
- **Handling:** Return `NOT_AUTHORIZED` error
- **Test:** Non-creator tries to access PRIVATE case → `NOT_AUTHORIZED`

### 12.5 Invalid ClientId
- **Scenario:** ClientId provided but client doesn't exist
- **Handling:** Return `NOT_FOUND` error
- **Test:** Create case with invalid clientId → `NOT_FOUND`

### 12.6 Cross-Org Client Access
- **Scenario:** ClientId belongs to different org
- **Handling:** Return `NOT_AUTHORIZED` error
- **Test:** Create case with clientId from different org → `NOT_AUTHORIZED`

### 12.7 Permission Denied
- **Scenario:** User doesn't have required permission
- **Handling:** Return `NOT_AUTHORIZED` with reason
- **Test:** VIEWER tries to create case → `NOT_AUTHORIZED`

### 12.8 Plan Limit
- **Scenario:** Plan doesn't have CASES feature (shouldn't happen, all plans have it)
- **Handling:** Return `PLAN_LIMIT` error
- **Test:** Edge case if plan configuration changes

---

## 13) Testing Strategy

### 13.1 Backend Tests
- Unit tests for each function
- Test entitlement checks
- Test validation
- Test error cases
- Test audit logging

### 13.2 Frontend Tests
- Widget tests for screens
- Provider tests for state management
- Integration tests for user flows

### 13.3 End-to-End Tests
- Create case → View in list → View details → Update → Verify
- Test filtering and search
- Test pagination
- Test error handling
- Test permission checks

### 13.4 State Persistence Tests (CRITICAL)
**These tests MUST pass for Slice 2 to be considered complete:**

1. **Organization Persistence:**
   - ✅ Create org → Refresh page (F5) → Org still selected
   - ✅ Create org → Close tab → Reopen app → Org still selected
   - ✅ Create org → Logout → Login → Org still selected (same user)

2. **Cases List Persistence:**
   - ✅ Load cases → Switch to Clients tab → Switch back → Cases still visible
   - ✅ Load cases → Click case details → Go back → Cases still visible
   - ✅ Load cases → Refresh page (F5) → Cases reload from backend
   - ✅ Create case → Case appears in list immediately (no refresh)
   - ✅ Create case → Switch tabs → Switch back → Case still in list

3. **Data Consistency:**
   - ✅ Create case → Appears immediately
   - ✅ Update case → Changes visible immediately
   - ✅ Delete case → Disappears immediately

**See [Testing & Acceptance Criteria](../TESTING_ACCEPTANCE_CRITERIA.md) for comprehensive test checklist.**

---

## 14) Critical Analysis & Additional Considerations

### 14.1 Review of Consolidated Feedback

**Status:** ✅ All 5 critical gaps have been addressed in this Build Card:

1. ✅ **Soft Delete Operation** - Added `case.delete` endpoint (Section 5.5)
2. ✅ **List Visibility Logic** - Locked two-query merge approach (Section 5.3)
3. ✅ **Pagination** - Documented cursor-based (recommended) and offset (MVP fallback) (Section 5.3)
4. ✅ **Search Scope** - Clarified as title-only prefix search (Section 5.3)
5. ✅ **Security Rules** - Defined concrete Firestore rules with tests (Section 6.2)

### 14.2 Additional Critical Considerations

#### Performance Optimization

**Two-Query Merge Performance:**
- **Concern:** Two queries + merge + sort in memory could be slow for large datasets
- **Mitigation:** 
  - Firestore queries are fast (indexed)
  - Merge is in-memory (fast for reasonable dataset sizes)
  - For MVP (< 10,000 cases per org), performance is acceptable
  - Future: Consider composite index with visibility + createdBy if performance degrades

**Client Name Batch Lookup:**
- **Concern:** N+1 query problem if done per case
- **Mitigation:** ✅ Already specified as batch lookup (collect all clientIds, fetch in one batch)
- **Implementation:** Use `Promise.all()` or Firestore batch get

#### Data Consistency

**Soft Delete Cascade:**
- **Current:** Soft delete only sets `deletedAt` on case
- **Concern:** Related documents/tasks may reference deleted case
- **Mitigation:** 
  - Related entities should check `deletedAt` before displaying
  - Future: Add cascade soft delete in Slice 2.1+
  - Hard delete will cascade (future feature)

**Concurrent Updates:**
- **Concern:** Two users updating same case simultaneously
- **Mitigation:** 
  - Firestore handles concurrent writes (last write wins)
  - `updatedAt` and `updatedBy` track who made last change
  - Future: Add optimistic locking with version field (Slice 2.1+)

#### Security Hardening

**Defense in Depth:**
- ✅ Cloud Functions enforce permissions (primary)
- ✅ Firestore rules enforce access (defense-in-depth)
- ✅ Client-side UI hides actions user can't perform (UX only, not security)

**Audit Trail Completeness:**
- ✅ All CRUD operations logged
- ✅ Metadata includes relevant context
- ✅ Timestamps are accurate (server-side)
- **Future:** Add audit trail UI (Slice 12)

#### UX Considerations

**Search Limitations:**
- **User Expectation:** Users may expect description search
- **Mitigation:** 
  - Clear UI indication: "Search case titles"
  - Tooltip explaining search scope
  - Future: Full-text search in Slice 2.2+

**Pagination UX:**
- **Cursor-Based:** Requires "Load More" button or infinite scroll
- **Offset-Based:** Can show page numbers (but less efficient)
- **Recommendation:** Use infinite scroll with cursor-based for best UX

**Empty States:**
- ✅ Specified in Build Card
- **Enhancement:** Consider helpful empty state messages:
  - "No cases yet. Create your first case to get started."
  - "No cases match your filters. Try adjusting your search."

#### Error Handling

**Error Message Clarity:**
- ✅ Structured error responses (success/error format)
- ✅ User-friendly error messages
- **Enhancement:** Consider specific error messages:
  - "You don't have permission to delete cases. Contact your administrator."
  - "This case is private and can only be accessed by its creator."

**Retry Logic:**
- **Current:** Not specified in Build Card
- **Recommendation:** Add retry logic for transient failures:
  - Network errors: Auto-retry with exponential backoff
  - Rate limiting: Show user-friendly message with retry button

#### Scalability Considerations

**Collection Growth:**
- **Current:** Cases stored in subcollection per org
- **Scaling:** Works well for most orgs (< 100,000 cases)
- **Future:** If org exceeds 100K cases, consider:
  - Sharding by date range
  - Archive old cases to separate collection
  - Implement case archival feature

**Index Management:**
- ✅ All required indexes specified
- **Concern:** Too many composite indexes can slow writes
- **Mitigation:** Only create indexes actually needed for queries
- **Monitoring:** Monitor index usage in Firebase Console

### 14.3 World-Class Application Standards

**Backend-First Architecture:** ✅
- All business logic in Cloud Functions
- UI is thin view layer
- Entitlement checks in backend
- Audit logging in backend

**Security:** ✅
- Defense-in-depth (Functions + Rules)
- Org-scoped access
- Role-based permissions
- Plan-based feature gating
- Soft delete for data retention

**Performance:** ✅
- Efficient queries (indexed)
- Batch operations where possible
- Cursor-based pagination (recommended)
- Client name batch lookup

**Maintainability:** ✅
- Clear separation of concerns
- Consistent error handling
- Comprehensive audit logging
- Well-documented endpoints

**User Experience:** ✅
- Loading states
- Error states with retry
- Empty states
- Clear validation feedback
- Responsive design (from Slice 1)

### 14.4 Implementation Priority

**Phase 1 (Critical Path):**
1. Add `case.delete` permission to ROLE_PERMISSIONS
2. Implement `caseCreate` (simplest, validates setup)
3. Implement `caseGet` (validates read path)
4. Implement `caseList` with two-query merge (most complex)
5. Implement `caseUpdate`
6. Implement `caseDelete`

**Phase 2 (Security & Infrastructure):**
1. Create Firestore indexes
2. Write and deploy security rules
3. Test security rules
4. Test entitlement checks

**Phase 3 (Frontend Foundation):**
1. Create CaseModel
2. Create CaseService
3. Create CaseProvider
4. Test service integration

**Phase 4 (UI Implementation):**
1. CaseListScreen (most important)
2. CaseCreateScreen
3. CaseDetailsScreen
4. Navigation integration

**Phase 5 (Polish & Testing):**
1. End-to-end testing
2. Error handling refinement
3. UX polish
4. Performance testing

### 14.5 Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Two-query merge performance | Low | Medium | Monitor performance, optimize if needed |
| Search limitations frustrate users | Medium | Low | Clear UI messaging, plan full-text search |
| Offset pagination doesn't scale | High | Medium | Use cursor-based, or document as tech debt |
| Security rules misconfigured | Low | High | Comprehensive testing, code review |
| Concurrent update conflicts | Low | Low | Acceptable for MVP, add locking later |

**Overall Risk Level:** ✅ **LOW** (after fixes applied)

---

## 15) Final Status

**Build Card Status:** ✅ **READY FOR IMPLEMENTATION**

**All Critical Gaps:** ✅ **RESOLVED**

**Documentation Completeness:** ✅ **100%**

**Implementation Readiness:** ✅ **READY**

**Recommendation:** ✅ **PROCEED WITH IMPLEMENTATION**

---

END OF BUILD CARD
