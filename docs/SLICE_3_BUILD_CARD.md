# SLICE 3: Client Hub (Client Management) - Build Card

**⚠️ Important Notes:**
- **Function Names:** Flutter MUST use export names (`clientCreate`, `clientGet`, etc.), NOT callable names (`client.create`, etc.)
- **Firestore Indexes:** Create ALL indexes BEFORE deployment (Section 10)
- **Search Limitations:** Name-only prefix search (email search not supported in MVP)
- **Conflict Check:** Verify case index exists for delete conflict check (Section 10.2)

## 1) Purpose

Build the Client Hub feature that allows users to create, view, list, and manage clients within their organization. This slice establishes client management as a core entity that cases can be associated with. Clients are organization-scoped and support basic CRUD operations with search and filtering capabilities.

## 2) Scope In ✅

### Backend (Cloud Functions):
- `client.create` - Create new clients
- `client.get` - Get client details by ID
- `client.list` - List clients for an organization (with filtering, search, pagination)
- `client.update` - Update client information
- `client.delete` - Soft delete clients (sets deletedAt timestamp)
- Client-org relationship enforcement
- Entitlement checks (plan + role permissions)
- Audit logging for client operations
- Firestore security rules for client collection

### Frontend (Flutter):
- Client list screen (with search and filtering)
- Client creation form
- Client details view
- Client edit form
- Integration with existing navigation (AppShell)
- Loading states and error handling
- Empty states for no clients
- Client selection in case creation/edit (dropdown/picker)

### Data Model:
- Clients belong to organizations (orgId required)
- Clients have name, email, phone, notes fields
- Soft delete support (deletedAt timestamp)
- Timestamps (createdAt, updatedAt)
- Creator tracking (createdBy, updatedBy)

## 3) Scope Out ❌

- Client contact management (multiple contacts per client) - Future slice
- Client billing/invoicing features - Future slice
- Client document management - Slice 4
- Client case history aggregation - Future enhancement
- Client import/export - Future enhancement
- Client tags/categories - Future enhancement
- Client custom fields - Future enhancement
- Advanced client analytics - Future enhancement

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, membership, entitlements engine)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme system, reusable widgets)
- ✅ **Slice 2**: Required (cases reference clients via clientId)

**No Dependencies on:**
- Slice 4+ (Documents, Tasks, AI, etc.)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `client.create` (Callable Function)

**Function Name (Export):** `clientCreate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `client.create` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `client.create` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `CLIENTS` feature must be enabled (all plans have this)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "name": "string (required, 1-200 chars)",
  "email": "string (optional, valid email format)",
  "phone": "string (optional, max 50 chars)",
  "notes": "string (optional, max 1000 chars)"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "clientId": "string",
    "orgId": "string",
    "name": "string",
    "email": "string | null",
    "phone": "string | null",
    "notes": "string | null",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing or invalid name, invalid email format, invalid field lengths
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `client.create` permission
- `PLAN_LIMIT` (403): CLIENTS feature not available in plan (shouldn't happen as all plans have it)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**ClientId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc(orgId).collection('clients').doc()`
- Example: "client_abc123def456"

**Name Validation:**
- Required: 1-200 characters
- Trim whitespace: `name.trim()`
- Sanitize: Remove leading/trailing special characters
- Pattern: Allow alphanumeric, spaces, hyphens, underscores, ampersands, commas, periods, parentheses
- Reject: Empty strings, only whitespace

**Email Validation (Optional):**
- If provided, must be valid email format
- Case-insensitive
- Maximum 255 characters
- Basic regex validation: `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`

**Phone Validation (Optional):**
- Maximum 50 characters
- Allow digits, spaces, hyphens, parentheses, plus sign
- No strict format requirement (international formats vary)

**Notes Validation (Optional):**
- Maximum 1000 characters
- Trim whitespace
- Allow basic punctuation and line breaks

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'client.create' })`
4. Validate name (trim, sanitize, length check)
5. Validate email (optional, format check if provided)
6. Validate phone (optional, length check if provided)
7. Validate notes (optional, length check if provided)
8. Generate clientId using Firestore auto-ID
9. Create client document in `organizations/{orgId}/clients/{clientId}`
10. Create audit event (client.created)
11. Return client details

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'client.created',
    entityType: 'client',
    entityId: clientId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      name: sanitizedName,
      email: email || null,
    },
  });
```

---

### 5.2 `client.get` (Callable Function)

**Function Name (Export):** `clientGet` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `client.get` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `client.read` (implicit - all org members can read clients)
- All roles can read clients (org-scoped access)

**Plan Gating:** `CLIENTS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "clientId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "clientId": "string",
    "orgId": "string",
    "name": "string",
    "email": "string | null",
    "phone": "string | null",
    "notes": "string | null",
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
- `VALIDATION_ERROR` (400): Missing clientId
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Client doesn't exist or is soft-deleted
- `INTERNAL_ERROR` (500): Database read failure

**Implementation Details:**

**Soft Delete Check:**
- If client.deletedAt exists and is not null → return `NOT_FOUND`
- Soft-deleted clients should not be returned

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and clientId (both required)
3. Check org membership: `checkEntitlement({ uid, orgId, requiredPermission: 'client.read' })` or verify membership
4. Fetch client document
5. Check if client exists and is not soft-deleted
6. Verify client belongs to org (orgId match)
7. Return client details

---

### 5.3 `client.list` (Callable Function)

**Function Name (Export):** `clientList` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `client.list` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `client.read` (implicit - all org members can read clients)

**Plan Gating:** `CLIENTS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "limit": "number (optional, default: 50, max: 100)",
  "offset": "number (optional, default: 0)",
  "search": "string (optional, search in name only - see limitations below)"
}
```

**⚠️ Search Limitations:**
- **Current Implementation:** Name-only prefix search (Firestore limitation)
- **Email Search:** NOT supported in Firestore query (would require in-memory filtering or future enhancement)
- **Future Enhancement:** Full-text search with `searchTokens` field or Algolia integration

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "clients": [
      {
        "clientId": "string",
        "orgId": "string",
        "name": "string",
        "email": "string | null",
        "phone": "string | null",
        "notes": "string | null",
        "createdAt": "ISO 8601 timestamp",
        "updatedAt": "ISO 8601 timestamp",
        "createdBy": "string (uid)",
        "updatedBy": "string (uid)"
      }
    ],
    "total": "number (total count matching filters, before limit/offset)",
    "hasMore": "boolean (true if more clients available)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid limit (must be 1-100), invalid offset (must be >= 0)
- `NOT_AUTHORIZED` (403): User not a member of org
- `INTERNAL_ERROR` (500): Database query failure

**Implementation Details:**

**Filtering Logic:**
- **Search (Slice 3 Scope - Name Prefix Only):**
  - Firestore prefix search on `name` field: `where('name', '>=', searchTerm)` AND `where('name', '<=', searchTerm + '\uf8ff')`
  - **⚠️ Current Limitations:**
    - **Name-only:** Does NOT search `email` field (Firestore query limitation)
    - Case-sensitive (searches for exact case match)
    - Does NOT support full-text search
    - Does NOT support fuzzy matching
    - **Email filtering:** Would require in-memory filtering (not implemented in MVP)
  - **Future Enhancement (Slice 3.1+):**
    - Add `searchTokens` field (generated on write, lowercase, tokenized)
    - Implement full-text search service (Algolia/Elasticsearch)
    - Support case-insensitive search
    - Support email search
- Exclude soft-deleted: `where('deletedAt', '==', null)`
- Order by: `orderBy('updatedAt', 'desc')` (most recently updated first)

**Pagination (Offset Acceptable for MVP):**
- Use `limit` and `offset` for pagination
- Calculate `hasMore`: `clients.length === limit` indicates more available
- **Future Enhancement:** Cursor-based pagination

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check org membership
4. Validate limit (1-100, default 50)
5. Validate offset (>= 0, default 0)
6. Build Firestore query:
   - Base: `organizations/{orgId}/clients`
   - Filter: `where('deletedAt', '==', null)`
   - Search: If provided, add name prefix search
   - Order: `orderBy('updatedAt', 'desc')`
   - Limit: Apply limit
   - Offset: Apply offset
7. Execute query
8. Calculate total (if needed for hasMore)
9. Return clients list with pagination info

---

### 5.4 `client.update` (Callable Function)

**Function Name (Export):** `clientUpdate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `client.update` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `client.update` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `CLIENTS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "clientId": "string (required)",
  "name": "string (optional, 1-200 chars)",
  "email": "string (optional, valid email format)",
  "phone": "string (optional, max 50 chars)",
  "notes": "string (optional, max 1000 chars)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "clientId": "string",
    "orgId": "string",
    "name": "string",
    "email": "string | null",
    "phone": "string | null",
    "notes": "string | null",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing clientId, invalid field values or lengths
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `client.update` permission
- `NOT_FOUND` (404): Client doesn't exist or is soft-deleted
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Update Logic:**
- Only update fields that are provided (partial updates allowed)
- Validate each provided field (same rules as create)
- Update `updatedAt` timestamp
- Update `updatedBy` to current user uid
- Do not modify `createdAt` or `createdBy`

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and clientId (both required)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'client.update' })`
4. Fetch existing client document
5. Check if client exists and is not soft-deleted
6. Verify client belongs to org
7. Validate provided fields (name, email, phone, notes)
8. Update client document (only provided fields)
9. Update `updatedAt` and `updatedBy`
10. Create audit event (client.updated)
11. Return updated client details

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'client.updated',
    entityType: 'client',
    entityId: clientId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      updatedFields: Object.keys(updateData),
    },
  });
```

---

### 5.5 `client.delete` (Callable Function)

**Function Name (Export):** `clientDelete` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `client.delete` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `client.delete` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅ (can delete clients)
- PARALEGAL: ❌
- VIEWER: ❌

**Plan Gating:** `CLIENTS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "clientId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "clientId": "string",
    "message": "Client deleted successfully"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing clientId
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `client.delete` permission
- `NOT_FOUND` (404): Client doesn't exist or already soft-deleted
- `CONFLICT` (409): Client has associated cases (cannot delete)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Soft Delete:**
- Set `deletedAt` to current timestamp
- Update `updatedAt` and `updatedBy`
- Do not permanently delete the document
- Soft-deleted clients are excluded from list queries

**Conflict Check:**
- Before deleting, check if client has associated cases
- Query: `organizations/{orgId}/cases` where `clientId == clientId` and `deletedAt == null`
- ⚠️ **Index Requirement:** This query may require a Firestore composite index on `cases` collection:
  - Fields: `clientId` (ASCENDING), `deletedAt` (ASCENDING)
  - Check existing Slice 2 indexes - may already exist, but verify before deployment
- If cases exist → return `CONFLICT` error
- User must first remove client from all cases or delete cases

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId and clientId (both required)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'client.delete' })`
4. Fetch existing client document
5. Check if client exists and is not already soft-deleted
6. Verify client belongs to org
7. Check for associated cases (conflict check)
8. If cases exist → return CONFLICT error
9. Update client document: set `deletedAt`, `updatedAt`, `updatedBy`
10. Create audit event (client.deleted)
11. Return success response

**Audit Logging:**
```typescript
await db
  .collection('organizations')
  .doc(orgId)
  .collection('audit_events')
  .add({
    orgId: orgId,
    actorUid: uid,
    action: 'client.deleted',
    entityType: 'client',
    entityId: clientId,
    timestamp: admin.firestore.Timestamp.now(),
    metadata: {
      name: clientData.name,
    },
  });
```

---

## 6) Firestore Collections

### 6.1 `organizations/{orgId}/clients/{clientId}`

**Document Path:** `organizations/{orgId}/clients/{clientId}`

**Required Fields:**
```json
{
  "id": "string (same as clientId)",
  "orgId": "string (required)",
  "name": "string (required, 1-200 chars)",
  "email": "string (optional, valid email)",
  "phone": "string (optional, max 50 chars)",
  "notes": "string (optional, max 1000 chars)",
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
  "id": "client_abc123",
  "orgId": "org_xyz789",
  "name": "Smith & Associates",
  "email": "contact@smithassociates.com",
  "phone": "+1-555-123-4567",
  "notes": "Primary contact: John Smith",
  "createdAt": "2026-01-20T10:00:00Z",
  "updatedAt": "2026-01-20T10:00:00Z",
  "createdBy": "user_xyz789",
  "updatedBy": "user_xyz789",
  "deletedAt": null
}
```

**Indexing Notes:**
- Composite index on: `orgId`, `deletedAt`, `updatedAt` (for list queries)
- Composite index on: `orgId`, `deletedAt`, `name` (for search queries)
- Index on `deletedAt` for soft delete filtering

**Security Rules (Concrete Implementation):**

**File:** `firestore.rules` (root level)

**Client Collection Rules:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check org membership
    function isOrgMember(orgId) {
      return exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
    }

    // Client collection rules
    match /organizations/{orgId}/clients/{clientId} {
      // Read: User must be org member
      allow read: if isOrgMember(orgId);
      
      // Write: Deny all client writes (Cloud Functions only)
      allow write: if false;
    }
  }
}
```

**Rationale:**
- All writes go through Cloud Functions (enforces permissions, validation, audit)
- Client reads allowed for all org members (org-scoped access)
- Soft-deleted clients filtered in queries (deletedAt == null)

---

## 7) Frontend Implementation

### 7.1 Data Models

**File:** `legal_ai_app/lib/core/models/client_model.dart`

```dart
class ClientModel {
  final String clientId;
  final String orgId;
  final String name;
  final String? email;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;

  const ClientModel({
    required this.clientId,
    required this.orgId,
    required this.name,
    this.email,
    this.phone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      clientId: json['clientId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      deletedAt: json['deletedAt'] != null 
        ? _parseTimestamp(json['deletedAt']) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'orgId': orgId,
      'name': name,
      'email': email,
      'phone': phone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for ClientModel');
}
```

### 7.2 Services

**File:** `legal_ai_app/lib/core/services/client_service.dart`

```dart
import 'package:legal_ai_app/core/services/cloud_functions_service.dart';
import 'package:legal_ai_app/core/models/client_model.dart';

class ClientService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<Map<String, dynamic>> createClient({
    required String orgId,
    required String name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final response = await _functionsService.callFunction(
      'clientCreate',
      {
        'orgId': orgId,
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return {'success': true, 'data': response['data']};
    } else {
      final error = response['error'] ?? {};
      throw Exception(error['message'] ?? 'Failed to create client');
    }
  }

  Future<Map<String, dynamic>> getClient({
    required String orgId,
    required String clientId,
  }) async {
    final response = await _functionsService.callFunction(
      'clientGet',
      {
        'orgId': orgId,
        'clientId': clientId,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return {'success': true, 'data': response['data']};
    } else {
      final error = response['error'] ?? {};
      throw Exception(error['message'] ?? 'Failed to get client');
    }
  }

  Future<Map<String, dynamic>> listClients({
    required String orgId,
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final response = await _functionsService.callFunction(
      'clientList',
      {
        'orgId': orgId,
        'limit': limit,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return {'success': true, 'data': response['data']};
    } else {
      final error = response['error'] ?? {};
      throw Exception(error['message'] ?? 'Failed to list clients');
    }
  }

  Future<Map<String, dynamic>> updateClient({
    required String orgId,
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final data = {
      'orgId': orgId,
      'clientId': clientId,
    };
    
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (notes != null) data['notes'] = notes;

    final response = await _functionsService.callFunction(
      'clientUpdate',
      data,
    );

    if (response['success'] == true && response['data'] != null) {
      return {'success': true, 'data': response['data']};
    } else {
      final error = response['error'] ?? {};
      throw Exception(error['message'] ?? 'Failed to update client');
    }
  }

  Future<Map<String, dynamic>> deleteClient({
    required String orgId,
    required String clientId,
  }) async {
    final response = await _functionsService.callFunction(
      'clientDelete',
      {
        'orgId': orgId,
        'clientId': clientId,
      },
    );

    if (response['success'] == true) {
      return {'success': true};
    } else {
      final error = response['error'] ?? {};
      throw Exception(error['message'] ?? 'Failed to delete client');
    }
  }
}
```

### 7.3 State Management

**File:** `legal_ai_app/lib/features/clients/providers/client_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:legal_ai_app/core/services/client_service.dart';
import 'package:legal_ai_app/core/models/client_model.dart';
import 'package:legal_ai_app/core/models/org_model.dart';

class ClientProvider with ChangeNotifier {
  final ClientService _clientService = ClientService();
  
  List<ClientModel> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ClientModel> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Future<void> loadClients({
    required OrgModel org,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _clientService.listClients(
        orgId: org.orgId,
        search: search,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final clientsList = data['clients'] as List<dynamic>? ?? [];
        
        _clients = clientsList
            .map((json) => ClientModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to load clients';
        _clients = [];
      }
    } catch (e) {
      _errorMessage = e.toString();
      _clients = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createClient({
    required OrgModel org,
    required String name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _clientService.createClient(
        orgId: org.orgId,
        name: name,
        email: email,
        phone: phone,
        notes: notes,
      );

      if (response['success'] == true) {
        // Reload clients list
        await loadClients(org: org);
        return true;
      } else {
        _errorMessage = 'Failed to create client';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateClient({
    required OrgModel org,
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _clientService.updateClient(
        orgId: org.orgId,
        clientId: clientId,
        name: name,
        email: email,
        phone: phone,
        notes: notes,
      );

      if (response['success'] == true) {
        // Reload clients list
        await loadClients(org: org);
        return true;
      } else {
        _errorMessage = 'Failed to update client';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteClient({
    required OrgModel org,
    required String clientId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _clientService.deleteClient(
        orgId: org.orgId,
        clientId: clientId,
      );

      if (response['success'] == true) {
        // Remove from local list
        _clients.removeWhere((c) => c.clientId == clientId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to delete client';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearClients() {
    _clients = [];
    notifyListeners();
  }
}
```

### 7.4 Screens

**File:** `legal_ai_app/lib/features/clients/screens/client_list_screen.dart`

**Features:**
- List all clients for current organization
- Search by name (debounced input)
- Pull-to-refresh
- Empty state when no clients
- Error state with retry
- Loading states
- Navigate to client details on tap
- Navigate to create client screen
- Organization change handling (reload clients)

**File:** `legal_ai_app/lib/features/clients/screens/client_create_screen.dart`

**Features:**
- Form with validation:
  - Name (required, 1-200 chars)
  - Email (optional, valid format)
  - Phone (optional, max 50 chars)
  - Notes (optional, max 1000 chars)
- Error handling
- Success navigation back to list
- Loading states

**File:** `legal_ai_app/lib/features/clients/screens/client_details_screen.dart`

**Features:**
- View mode (read-only display)
- Edit mode (form with same validation as create)
- Delete button (with confirmation)
- Navigation back to list after save/delete
- Loading states
- Error handling

### 7.5 Navigation Integration

**File:** `legal_ai_app/lib/core/routing/route_names.dart`

```dart
static const String clients = '/clients';
static const String clientsCreate = '/clients/create';
static const String clientDetails = '/clients/:clientId';
```

**File:** `legal_ai_app/lib/core/routing/app_router.dart`

Add routes:
- `/clients` → `ClientListScreen`
- `/clients/create` → `ClientCreateScreen`
- `/clients/:clientId` → `ClientDetailsScreen`

**File:** `legal_ai_app/lib/features/home/widgets/app_shell.dart`

Add "Clients" tab to bottom navigation (if not already present)

### 7.6 Client Selection in Case Forms

**Update:** `legal_ai_app/lib/features/cases/screens/case_create_screen.dart`
**Update:** `legal_ai_app/lib/features/cases/screens/case_details_screen.dart`

Add client selection dropdown/picker:
- Load clients list from `ClientProvider`
- Display client name
- Allow "No client" option (null)
- Show loading state while fetching clients
- Handle client not found scenarios

---

## 8) Permissions & Entitlements

### 8.1 Role Permissions

**File:** `functions/src/constants/permissions.ts`

Already defined:
- `client.create`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌
- `client.update`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌
- `client.delete`: ADMIN ✅, LAWYER ✅, PARALEGAL ❌, VIEWER ❌
- `client.read`: All roles (implicit - org membership grants read access)

### 8.2 Plan Features

**File:** `functions/src/constants/entitlements.ts`

Already defined:
- `CLIENTS`: All plans (FREE, BASIC, PRO, ENTERPRISE) have this enabled ✅

---

## 9) Testing & Acceptance Criteria

### 9.1 Pre-Deployment Verification

**⚠️ Critical Checks Before Deployment:**
- [ ] **Firestore Indexes:** All required indexes created and deployed (see Section 10)
- [ ] **Case Index for Conflict Check:** Verify index exists for `cases` collection query (`clientId`, `deletedAt`)
- [ ] **Function Export Names:** Verify all functions exported with correct names (`clientCreate`, `clientGet`, `clientList`, `clientUpdate`, `clientDelete`)
- [ ] **Flutter Service:** Verify Flutter calls use export names (NOT callable names)

### 9.2 Backend Testing

**Manual Testing Checklist:**
- [ ] Create client (all fields, minimal fields)
- [ ] Create client with invalid data (validation errors)
- [ ] Get client (existing, non-existent, soft-deleted)
- [ ] List clients (with/without search, pagination)
- [ ] Update client (all fields, partial update)
- [ ] Delete client (with/without associated cases) - **Verify conflict check works**
- [ ] Permission checks (different roles)
- [ ] Org-scoped access (cannot access other org's clients)
- [ ] Audit logging (all operations)

### 9.2 Frontend Testing

**Manual Testing Checklist:**
- [ ] Client list loads correctly
- [ ] Search by name works
- [ ] Create client form validation
- [ ] Create client success navigation
- [ ] View client details
- [ ] Edit client (save changes)
- [ ] Delete client (with confirmation)
- [ ] Delete client with cases (error handling)
- [ ] Organization switching (clients reload)
- [ ] Browser refresh (state persists)
- [ ] Empty states display
- [ ] Error states with retry
- [ ] Loading states
- [ ] Client selection in case forms

### 9.3 Integration Testing

**End-to-End Flows:**
- [ ] Create client → Use in case creation → Case shows client name
- [ ] Update client → Case list shows updated client name
- [ ] Delete client with cases → Error message shown (CONFLICT error)
- [ ] Remove client from all cases → Delete client succeeds
- [ ] Switch organizations → Clients list updates correctly
- [ ] **Client-Case Relationship:** Verify cases correctly reference clients
- [ ] **Performance:** Test client list with many clients (100+)

### 9.4 Performance Testing

**Scalability Checks:**
- [ ] Client list loads efficiently with 50+ clients
- [ ] Search performance acceptable with large client lists
- [ ] Organization switching doesn't cause performance issues
- [ ] Conflict check query performs well (verify index usage)

---

## 10) Firestore Indexes

### 10.1 Required Indexes

**⚠️ CRITICAL: Create indexes BEFORE deployment**

**File:** `firestore.indexes.json`

Add indexes for client collection:

```json
{
  "indexes": [
    {
      "collectionGroup": "clients",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "deletedAt", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "clients",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "deletedAt", "order": "ASCENDING" },
        { "fieldPath": "name", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### 10.2 Case Collection Index (for Conflict Check)

**⚠️ Verify this index exists (may already be created in Slice 2):**

The `clientDelete` function queries cases to check for conflicts:
- Query: `cases` where `clientId == X` AND `deletedAt == null`

**Check existing Slice 2 indexes:**
- If index exists: ✅ No action needed
- If index missing: Add to `firestore.indexes.json`:
```json
{
  "collectionGroup": "cases",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "clientId", "order": "ASCENDING" },
    { "fieldPath": "deletedAt", "order": "ASCENDING" }
  ]
}
```

**Deployment:**
```bash
firebase deploy --only firestore:indexes
```

**Verification:**
- Check Firebase Console → Firestore → Indexes
- Verify all indexes are "Enabled" (not "Building")
- Test conflict check query manually before deploying functions

---

## 11) Lessons from Slice 2 (Apply to Slice 3)

### 11.1 State Management
- ✅ Use listener pattern (not didChangeDependencies) for provider changes
- ✅ Reset tracking variables on user actions (filters, search)
- ✅ Keep state management simple - avoid over-engineering

### 11.2 Filtering & Search
- ✅ Add explicit `onTap` handlers for critical menu items (especially null values)
- ✅ Test edge cases immediately (filter transitions, search combinations)
- ✅ Debounce search input (500ms delay)

### 11.3 Error Handling
- ✅ Show user-friendly error messages
- ✅ Provide retry functionality
- ✅ Handle conflict errors (client with cases cannot be deleted)

### 11.4 Code Quality
- ✅ Keep debug logging minimal (only errors)
- ✅ Clean, maintainable code
- ✅ Follow existing patterns from Slice 1 & 2

---

## 12) Success Criteria

**Slice 3 is complete when:**
- ✅ All 5 backend functions deployed and tested
- ✅ **All Firestore indexes created and enabled** (Section 10)
- ✅ **Case index for conflict check verified** (Section 10.2)
- ✅ All 3 frontend screens implemented and tested
- ✅ Client selection integrated into case forms
- ✅ State management working correctly (applying Slice 2 learnings)
- ✅ Organization switching working
- ✅ Browser refresh working
- ✅ **Integration testing complete** (client-case relationships)
- ✅ **Performance testing complete** (large client lists)
- ✅ All edge cases tested
- ✅ Code cleanup completed
- ✅ Documentation updated

**⚠️ Pre-Deployment Checklist:**
- [ ] Firestore indexes deployed and enabled
- [ ] Function export names verified (`clientCreate`, not `client.create`)
- [ ] Flutter service uses correct function names
- [ ] Conflict check index verified
- [ ] Search limitations documented in UI (name-only)

---

## 13) Next Steps After Slice 3

1. **Slice 4: Document Hub**
   - Document upload and management
   - Document-case relationships
   - Document metadata

2. **Future Enhancements**
   - Client contact management (multiple contacts)
   - Client import/export
   - Client tags/categories
   - Client analytics

---

**Build Card Created:** 2026-01-20  
**Status:** 🔄 **READY TO START**  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅
