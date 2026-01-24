# SLICE 4: Document Hub (Document Management) - Build Card

**⚠️ Important Notes:**
- **Function Names:** Flutter MUST use export names (`documentCreate`, `documentGet`, etc.), NOT callable names (`document.create`, etc.)
- **Cloud Storage:** Documents stored in `organizations/{orgId}/documents/{documentId}/file.ext`
- **File Upload:** Use Firebase Storage SDK in Flutter, then call Cloud Function to create metadata
- **File Size Limits:** MVP: 10MB per file (configurable per plan)
- **Supported Formats:** PDF, DOC, DOCX, TXT, RTF (MVP)

## 1) Purpose

Build the Document Hub feature that allows users to upload, view, list, and manage documents within their organization. Documents can be associated with cases and are stored in Cloud Storage with metadata in Firestore. This slice establishes document management as a core feature that supports case work and future AI processing.

## 2) Scope In ✅

### Backend (Cloud Functions):
- `document.create` - Create document metadata (after file upload)
- `document.get` - Get document details and download URL
- `document.list` - List documents for an organization/case (with filtering, search, pagination)
- `document.update` - Update document metadata (name, description, tags)
- `document.delete` - Soft delete documents (sets deletedAt, marks Storage file for deletion)
- Document-org relationship enforcement
- Document-case relationship management
- Entitlement checks (plan + role permissions)
- Storage quota enforcement (per plan)
- Audit logging for document operations
- Firestore security rules for document collection
- Cloud Storage security rules

### Frontend (Flutter):
- Document list screen (with search and filtering)
- Document upload screen (file picker + metadata form)
- Document details view (metadata + download)
- Document edit form (metadata only)
- Integration with existing navigation (AppShell)
- Document selection in case forms (attach documents to cases)
- Loading states and error handling
- Empty states for no documents
- File upload progress indicator

### Data Model:
- Documents belong to organizations (orgId required)
- Documents can be associated with cases (caseId optional)
- Documents have: name, description, fileType, fileSize, storagePath, downloadUrl
- Soft delete support (deletedAt timestamp)
- Timestamps (createdAt, updatedAt)
- Creator tracking (createdBy, updatedBy)

## 3) Scope Out ❌

- Document OCR/text extraction - Slice 6+ (AI features)
- Document versioning - Future slice
- Document collaboration (comments, annotations) - Future slice
- Document templates - Future slice
- Document sharing outside organization - Future slice
- Document preview/rendering in browser - Future enhancement
- Document bulk upload - Future enhancement
- Document folders/categories - Future enhancement
- Document tags (beyond basic metadata) - Future enhancement
- Document encryption at rest (beyond Firebase default) - Future enhancement

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0
- **Cloud Storage (required)** - NEW for Slice 4

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, membership, entitlements engine)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme system, reusable widgets)
- ✅ **Slice 2**: Required (documents can be associated with cases)

**No Dependencies on:**
- Slice 3 (Clients) - Documents can exist without clients
- Slice 5+ (Tasks, AI, etc.)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `document.create` (Callable Function)

**Function Name (Export):** `documentCreate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `document.create` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.create` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `DOCUMENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional, null if not associated with case)",
  "name": "string (required, 1-200 chars)",
  "description": "string (optional, max 1000 chars)",
  "storagePath": "string (required, path in Cloud Storage)",
  "fileType": "string (required, e.g., 'pdf', 'docx', 'txt')",
  "fileSize": "number (required, bytes)"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "documentId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "name": "string",
    "description": "string | null",
    "fileType": "string",
    "fileSize": "number",
    "storagePath": "string",
    "downloadUrl": "string (signed URL, expires in 1 hour)",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing or invalid name, invalid fileType, invalid fileSize
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `document.create` permission
- `PLAN_LIMIT` (403): DOCUMENTS feature not available in plan, or storage quota exceeded
- `NOT_FOUND` (404): Case not found (if caseId provided)
- `INTERNAL_ERROR` (500): Database write failure, Storage access failure

**Implementation Details:**

**DocumentId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc(orgId).collection('documents').doc()`
- Example: "doc_abc123def456"

**Name Validation:**
- Required: 1-200 characters
- Trim whitespace: `name.trim()`
- Sanitize: Remove leading/trailing special characters
- Pattern: Allow alphanumeric, spaces, hyphens, underscores, ampersands, commas, periods, parentheses
- Reject: Empty strings, only whitespace

**File Type Validation:**
- Required: Must be one of: `pdf`, `doc`, `docx`, `txt`, `rtf`
- Case-insensitive
- Extract from file extension or MIME type

**File Size Validation:**
- Required: Must be > 0 and <= 10MB (10,485,760 bytes) for MVP
- Check against plan limits (future: per-plan quotas)
- Reject: 0 bytes, negative, or exceeds limit

**Storage Path Validation:**
- Required: Must match pattern: `organizations/{orgId}/documents/{documentId}/{filename}`
- Verify file exists in Storage at this path
- Verify user has permission to access this path

**Case Association (Optional):**
- If `caseId` provided, verify case exists and belongs to org
- Verify user has permission to view case
- If case is soft-deleted, reject association

**Storage Quota Check:**
- Calculate total storage used by org (sum of all non-deleted documents)
- Check against plan limit (MVP: 1GB for all plans)
- Reject if quota exceeded

**Download URL Generation:**
- Generate signed URL for Storage file
- Expiration: 1 hour (configurable)
- Use `getSignedUrl` from Storage Admin SDK

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'document.create' })`
4. Validate name (trim, sanitize, length check)
5. Validate description (optional, length check if provided)
6. Validate fileType (required, must be in allowed list)
7. Validate fileSize (required, must be > 0 and <= limit)
8. Validate storagePath (required, must match pattern, file must exist)
9. Verify file exists in Storage
10. Check storage quota (sum existing documents, add new size, check limit)
11. If caseId provided: verify case exists and belongs to org
12. Generate documentId using Firestore auto-ID
13. Create document metadata in `organizations/{orgId}/documents/{documentId}`
14. Generate signed download URL
15. Create audit event (document.created)
16. Return document details with download URL

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'document.created',
    entityType: 'document',
    entityId: documentId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      name: sanitizedName,
      fileType: fileType,
      fileSize: fileSize,
      caseId: caseId || null,
    },
  });
```

---

### 5.2 `document.get` (Callable Function)

**Function Name (Export):** `documentGet` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `document.get` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.read` (implicit - all org members can read documents)
- All roles can read documents (org-scoped access)

**Plan Gating:** `DOCUMENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "documentId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "name": "string",
    "description": "string | null",
    "fileType": "string",
    "fileSize": "number",
    "storagePath": "string",
    "downloadUrl": "string (signed URL, expires in 1 hour)",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing documentId
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Document not found or soft-deleted
- `INTERNAL_ERROR` (500): Database read failure, Storage access failure

**Implementation Details:**

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Validate documentId (required, non-empty)
4. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'DOCUMENTS' })`
5. Fetch document from `organizations/{orgId}/documents/{documentId}`
6. Verify document exists and is not soft-deleted (`deletedAt == null`)
7. Verify document belongs to org (`document.orgId == orgId`)
8. Generate fresh signed download URL (expires in 1 hour)
9. Return document details with download URL

---

### 5.3 `document.list` (Callable Function)

**Function Name (Export):** `documentList` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `document.list` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.read` (implicit - all org members can read documents)

**Plan Gating:** `DOCUMENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional, filter by case)",
  "limit": "number (optional, default: 50, max: 100)",
  "offset": "number (optional, default: 0)",
  "search": "string (optional, search by name)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "documents": [
      {
        "documentId": "string",
        "orgId": "string",
        "caseId": "string | null",
        "name": "string",
        "description": "string | null",
        "fileType": "string",
        "fileSize": "number",
        "storagePath": "string",
        "downloadUrl": "string (signed URL, expires in 1 hour)",
        "createdAt": "ISO 8601 timestamp",
        "updatedAt": "ISO 8601 timestamp",
        "createdBy": "string (uid)",
        "updatedBy": "string (uid)"
      }
    ],
    "total": "number (total count, may be approximate)",
    "hasMore": "boolean (true if more documents available)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid limit or offset
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Case not found (if caseId provided)
- `INTERNAL_ERROR` (500): Database query failure

**Implementation Details:**

**Query Building:**
- Base query: `organizations/{orgId}/documents` where `deletedAt == null`
- If `caseId` provided: add filter `caseId == caseId`
- Order by: `updatedAt DESC`
- Apply limit and offset

**Search Implementation (MVP):**
- For MVP: Fetch all documents (up to 1000), filter in-memory by name (case-insensitive contains)
- Future: Use Firestore range queries with index when needed

**Download URLs:**
- Generate signed URL for each document (expires in 1 hour)
- Batch generation for efficiency

**Pagination:**
- Use limit/offset for MVP
- Future: Cursor-based pagination

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Validate limit (1-100, default 50)
4. Validate offset (>= 0, default 0)
5. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'DOCUMENTS' })`
6. If caseId provided: verify case exists and belongs to org
7. Build query: `organizations/{orgId}/documents` where `deletedAt == null`
8. If caseId provided: add filter `caseId == caseId`
9. Order by `updatedAt DESC`
10. Fetch documents (limit + 1 to check hasMore)
11. If search provided: filter in-memory by name (case-insensitive contains)
12. Apply pagination (slice results)
13. Generate signed download URLs for each document
14. Return documents with download URLs, total count, hasMore

---

### 5.4 `document.update` (Callable Function)

**Function Name (Export):** `documentUpdate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `document.update` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.update` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `DOCUMENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (required)",
  "name": "string (optional, 1-200 chars)",
  "description": "string (optional, max 1000 chars)",
  "caseId": "string (optional, null to remove association)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "documentId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "name": "string",
    "description": "string | null",
    "fileType": "string",
    "fileSize": "number",
    "storagePath": "string",
    "downloadUrl": "string (signed URL, expires in 1 hour)",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing documentId, invalid name, invalid description
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `document.update` permission
- `NOT_FOUND` (404): Document not found or soft-deleted, or case not found (if caseId provided)
- `INTERNAL_ERROR` (500): Database update failure

**Implementation Details:**

**Updateable Fields:**
- `name` (optional, 1-200 chars)
- `description` (optional, max 1000 chars)
- `caseId` (optional, can set to null to remove association)

**Non-Updateable Fields:**
- `fileType` (immutable - file cannot be changed)
- `fileSize` (immutable - file cannot be changed)
- `storagePath` (immutable - file cannot be changed)
- `orgId` (immutable)
- `createdAt` (immutable)
- `createdBy` (immutable)

**Case Association Update:**
- If `caseId` provided: verify case exists and belongs to org
- If `caseId` is `null`: remove case association
- Verify user has permission to view case (if associating)

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Validate documentId (required, non-empty)
4. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'document.update' })`
5. Fetch document from `organizations/{orgId}/documents/{documentId}`
6. Verify document exists and is not soft-deleted
7. Verify document belongs to org
8. If name provided: validate (trim, sanitize, length check)
9. If description provided: validate (length check)
10. If caseId provided: verify case exists and belongs to org
11. Update document fields (only provided fields)
12. Update `updatedAt` timestamp
13. Update `updatedBy` to current user uid
14. Generate fresh signed download URL
15. Create audit event (document.updated)
16. Return updated document details

---

### 5.5 `document.delete` (Callable Function)

**Function Name (Export):** `documentDelete` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `document.delete` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.delete` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅ (can delete their own documents)
- PARALEGAL: ❌
- VIEWER: ❌

**Plan Gating:** `DOCUMENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "documentId": "string",
    "deletedAt": "ISO 8601 timestamp"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing documentId
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `document.delete` permission
- `NOT_FOUND` (404): Document not found or already deleted
- `INTERNAL_ERROR` (500): Database update failure, Storage deletion failure

**Implementation Details:**

**Soft Delete:**
- Set `deletedAt` timestamp (do not delete from Firestore)
- Mark Storage file for deletion (schedule deletion after 30 days)
- Do not immediately delete Storage file (retention policy)

**Permission Check:**
- ADMIN: Can delete any document
- LAWYER: Can delete documents they created (`createdBy == uid`)
- PARALEGAL: Cannot delete documents
- VIEWER: Cannot delete documents

**Storage File Handling:**
- Do not immediately delete Storage file
- Mark for deletion (add to deletion queue or set metadata)
- Future: Background job will delete after 30 days
- For MVP: Just mark in Firestore, Storage cleanup can be manual or future job

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Validate documentId (required, non-empty)
4. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'document.delete' })`
5. Fetch document from `organizations/{orgId}/documents/{documentId}`
6. Verify document exists and is not already soft-deleted
7. Verify document belongs to org
8. Check role permissions:
   - If ADMIN: allow
   - If LAWYER: verify `document.createdBy == uid`
   - Otherwise: reject
9. Set `deletedAt` timestamp
10. Update `updatedAt` timestamp
11. Update `updatedBy` to current user uid
12. Mark Storage file for deletion (set metadata or add to queue)
13. Create audit event (document.deleted)
14. Return documentId and deletedAt

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'document.deleted',
    entityType: 'document',
    entityId: documentId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      name: document.name,
      fileType: document.fileType,
      fileSize: document.fileSize,
    },
  });
```

---

## 6) Firestore Collections

### 6.1 `organizations/{orgId}/documents/{documentId}`

**Document Path:** `organizations/{orgId}/documents/{documentId}`

**Required Fields:**
```json
{
  "id": "string (same as documentId)",
  "orgId": "string (required)",
  "caseId": "string (optional, null if not associated with case)",
  "name": "string (required, 1-200 chars)",
  "description": "string (optional, max 1000 chars)",
  "fileType": "string (required, e.g., 'pdf', 'docx', 'txt')",
  "fileSize": "number (required, bytes)",
  "storagePath": "string (required, path in Cloud Storage)",
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
  "id": "doc_abc123",
  "orgId": "org_xyz789",
  "caseId": "case_def456",
  "name": "Contract Agreement - Smith v. Jones.pdf",
  "description": "Original signed contract agreement",
  "fileType": "pdf",
  "fileSize": 2456789,
  "storagePath": "organizations/org_xyz789/documents/doc_abc123/contract.pdf",
  "createdAt": "2026-01-20T10:00:00Z",
  "updatedAt": "2026-01-20T10:00:00Z",
  "createdBy": "user_xyz789",
  "updatedBy": "user_xyz789",
  "deletedAt": null
}
```

**Indexing Notes:**
- Composite index on: `orgId`, `deletedAt`, `updatedAt` (for list queries)
- Composite index on: `orgId`, `caseId`, `deletedAt`, `updatedAt` (for case-filtered queries)
- Index on `deletedAt` for soft delete filtering

---

## 7) Cloud Storage Structure

### 7.1 Storage Bucket

**Bucket Name:** `legal-ai-app-1203e.appspot.com` (default Firebase Storage bucket)

**Path Structure:**
```
organizations/
  {orgId}/
    documents/
      {documentId}/
        {filename}
```

**Example Path:**
```
organizations/org_xyz789/documents/doc_abc123/contract-agreement.pdf
```

### 7.2 File Naming

**Rules:**
- Use original filename from upload
- Sanitize filename: remove special characters, replace spaces with hyphens
- Preserve file extension
- Maximum filename length: 255 characters

**Example:**
- Original: `Contract Agreement - Smith v. Jones (Final).pdf`
- Sanitized: `contract-agreement-smith-v-jones-final.pdf`

### 7.3 Storage Security Rules

**File:** `storage.rules` (root level)

**Storage Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Organization-scoped documents
    match /organizations/{orgId}/documents/{documentId}/{fileName} {
      // Allow read if user is org member
      allow read: if request.auth != null 
        && exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
      
      // Allow write only via Cloud Functions (signed URLs)
      allow write: if false; // All writes go through Cloud Functions
    }
  }
}
```

**Note:** For MVP, Cloud Functions will handle all file operations. Storage rules are primarily for read access control.

---

## 8) Frontend Implementation

### 8.1 DocumentModel

**File:** `legal_ai_app/lib/core/models/document_model.dart`

**Fields:**
```dart
class DocumentModel {
  final String documentId;
  final String orgId;
  final String? caseId;
  final String name;
  final String? description;
  final String fileType;
  final int fileSize;
  final String storagePath;
  final String? downloadUrl; // Signed URL, may expire
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;
  
  // Helper methods
  String get fileSizeFormatted; // "2.3 MB"
  String get fileTypeIcon; // Icon name based on fileType
  bool get isDeleted;
}
```

### 8.2 DocumentService

**File:** `legal_ai_app/lib/core/services/document_service.dart`

**Methods:**
- `uploadDocument()` - Upload file to Storage, then create metadata
- `getDocument()` - Get document details with fresh download URL
- `listDocuments()` - List documents with filters
- `updateDocument()` - Update document metadata
- `deleteDocument()` - Soft delete document

### 8.3 DocumentProvider

**File:** `legal_ai_app/lib/features/documents/providers/document_provider.dart`

**State Management:**
- Documents list
- Selected document
- Loading states
- Error states
- Upload progress

### 8.4 DocumentListScreen

**File:** `legal_ai_app/lib/features/documents/screens/document_list_screen.dart`

**Features:**
- List all documents (or filtered by case)
- Search by name (debounced)
- Filter by case (if viewing case documents)
- Pull-to-refresh
- Empty states
- Error states with retry
- Upload button (FAB)

### 8.5 DocumentUploadScreen

**File:** `legal_ai_app/lib/features/documents/screens/document_upload_screen.dart`

**Features:**
- File picker (PDF, DOC, DOCX, TXT, RTT)
- File size validation (max 10MB)
- Name input (pre-filled from filename, editable)
- Description input (optional)
- Case selection (optional dropdown)
- Upload progress indicator
- Error handling
- Success navigation

### 8.6 DocumentDetailsScreen

**File:** `legal_ai_app/lib/features/documents/screens/document_details_screen.dart`

**Features:**
- View document metadata
- Download button (opens download URL)
- Edit metadata (name, description, case association)
- Delete button (with confirmation)
- Loading states
- Error handling

### 8.7 Document Selection in Case Forms

**Integration:**
- Add document picker to `CaseCreateScreen` and `CaseDetailsScreen`
- Allow attaching multiple documents to a case
- Show attached documents list
- Allow removing document associations

---

## 9) Security Rules

### 9.1 Firestore Rules

**File:** `firestore.rules`

**Document Collection Rules:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function: Check if user is org member
    function isOrgMember(orgId) {
      return exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
    }
    
    // Document collection
    match /organizations/{orgId}/documents/{documentId} {
      // Read: Org members can read non-deleted documents
      allow read: if isOrgMember(orgId) 
        && (!resource.data.keys().hasAny(['deletedAt']) || resource.data.deletedAt == null);
      
      // Write: All writes go through Cloud Functions
      allow write: if false; // Cloud Functions own all writes
    }
  }
}
```

### 9.2 Storage Rules

**File:** `storage.rules`

**Storage Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /organizations/{orgId}/documents/{documentId}/{fileName} {
      // Read: Org members can read
      allow read: if request.auth != null 
        && exists(/databases/(default)/documents/organizations/$(orgId)/members/$(request.auth.uid));
      
      // Write: All writes go through Cloud Functions
      allow write: if false; // Cloud Functions own all writes
    }
  }
}
```

---

## 10) Firestore Indexes

### 10.1 Required Indexes

**File:** `firestore.indexes.json`

**Index 1: List documents (no case filter)**
```json
{
  "collectionGroup": "documents",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "deletedAt",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "updatedAt",
      "order": "DESCENDING"
    }
  ]
}
```

**Index 2: List documents (with case filter)**
```json
{
  "collectionGroup": "documents",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "deletedAt",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "caseId",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "updatedAt",
      "order": "DESCENDING"
    }
  ]
}
```

**Deployment:**
```bash
firebase deploy --only firestore:indexes
```

---

## 11) Permissions Matrix

### 11.1 Document Permissions

**File:** `functions/src/constants/permissions.ts`

**ROLE_PERMISSIONS:**
```typescript
{
  ADMIN: {
    document: {
      create: true,
      read: true,
      update: true,
      delete: true,
    },
  },
  LAWYER: {
    document: {
      create: true,
      read: true,
      update: true,
      delete: true, // Can delete own documents
    },
  },
  PARALEGAL: {
    document: {
      create: true,
      read: true,
      update: true,
      delete: false,
    },
  },
  VIEWER: {
    document: {
      create: false,
      read: true,
      update: false,
      delete: false,
    },
  },
}
```

---

## 12) Plan Features

### 12.1 DOCUMENTS Feature

**File:** `functions/src/constants/features.ts`

**PLAN_FEATURES:**
```typescript
{
  FREE: {
    DOCUMENTS: true,
    documentStorageQuota: 1 * 1024 * 1024 * 1024, // 1GB
    documentMaxFileSize: 10 * 1024 * 1024, // 10MB
  },
  BASIC: {
    DOCUMENTS: true,
    documentStorageQuota: 5 * 1024 * 1024 * 1024, // 5GB
    documentMaxFileSize: 25 * 1024 * 1024, // 25MB
  },
  PRO: {
    DOCUMENTS: true,
    documentStorageQuota: 50 * 1024 * 1024 * 1024, // 50GB
    documentMaxFileSize: 100 * 1024 * 1024, // 100MB
  },
  ENTERPRISE: {
    DOCUMENTS: true,
    documentStorageQuota: 500 * 1024 * 1024 * 1024, // 500GB
    documentMaxFileSize: 500 * 1024 * 1024, // 500MB
  },
}
```

**MVP:** All plans have DOCUMENTS enabled with 1GB quota and 10MB max file size.

---

## 13) Testing Requirements

### 13.1 Backend Testing

**Test Cases:**
- ✅ Create document (with/without case)
- ✅ Get document (existing, non-existent, soft-deleted)
- ✅ List documents (with/without case filter, pagination)
- ✅ Update document (all fields, partial updates)
- ✅ Delete document (success, permission check)
- ✅ Storage quota enforcement
- ✅ File size validation
- ✅ File type validation
- ✅ Case association validation

### 13.2 Frontend Testing

**Test Cases:**
- ✅ Document list loads correctly
- ✅ Upload document (file picker, validation, progress)
- ✅ View document details
- ✅ Edit document metadata
- ✅ Delete document (confirmation, success)
- ✅ Document selection in case forms
- ✅ Search works
- ✅ Filter by case works
- ✅ Organization switching (documents reload)
- ✅ Browser refresh (state persists)

### 13.3 Integration Testing

**Test Cases:**
- ✅ Upload document → appears in list
- ✅ Attach document to case → appears in case documents
- ✅ Remove document from case → association removed
- ✅ Delete document → removed from list, Storage file marked
- ✅ Switch org → documents reload for new org
- ✅ Network errors (retry works)

---

## 14) Success Criteria

**Slice 4 is complete when:**
- ✅ All 5 backend functions deployed and tested
- ✅ All Firestore indexes created and enabled
- ✅ Storage rules deployed
- ✅ All 3 frontend screens implemented and tested
- ✅ Document upload working (file picker → Storage → metadata)
- ✅ Document selection integrated into case forms
- ✅ State management working correctly (applying Slice 2 & 3 learnings)
- ✅ Organization switching working
- ✅ Browser refresh working
- ✅ Storage quota enforcement working
- ✅ File size/type validation working
- ✅ All edge cases tested
- ✅ Code cleanup completed
- ✅ Documentation updated

---

## 15) Next Steps After Slice 4

1. **Slice 5: Task Hub** (if planned)
   - Task management
   - Task-case relationships
   - Task assignment

2. **Slice 6+: AI Features**
   - Document OCR/text extraction
   - AI research and drafting
   - Document analysis

3. **Future Enhancements**
   - Document versioning
   - Document preview
   - Document collaboration
   - Document templates

---

**Build Card Created:** 2026-01-20  
**Status:** 🔄 **READY TO START**  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅
