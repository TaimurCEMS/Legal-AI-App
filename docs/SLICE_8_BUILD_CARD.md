# Slice 8: Notes/Memos on Cases - Build Card

**Status:** ✅ COMPLETE  
**Priority:** 🔴 HIGH  
**Estimated Effort:** Low (follows established patterns)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅

---

## 1. Overview

### 1.1 Purpose
Enable lawyers to capture and organize notes for every case - meeting notes, research findings, strategy discussions, client conversations, and more.

### 1.2 User Stories
- As a lawyer, I want to quickly jot down notes during/after client meetings
- As a lawyer, I want to categorize notes (meeting, research, strategy, etc.)
- As a lawyer, I want to pin important notes for quick access
- As a lawyer, I want to search notes across my cases
- As a lawyer, I want to share notes with team members on the case

### 1.3 Success Criteria
- [x] Notes can be created, read, updated, deleted
- [x] Notes are linked to cases
- [x] Notes can be categorized
- [x] Important notes can be pinned
- [x] Notes follow case visibility rules (inherit case access)
- [x] Optional `isPrivate` toggle hides note from other users
- [x] Notes appear in case details view

---

## 2) Scope In ✅

### Backend (Cloud Functions)
- `noteCreate` – Create new note linked to a case
- `noteGet` – Get note by ID (with case/private visibility checks)
- `noteList` – List notes with filters (caseId, category, pinnedOnly, search) and pagination
- `noteUpdate` – Update note (title, content, category, isPinned, isPrivate, caseId)
- `noteDelete` – Soft delete note (idempotent)
- Entitlement checks (`NOTES` feature, `note.create` / `note.read` / `note.update` / `note.delete`)
- Case access enforcement (notes inherit case visibility; private notes creator-only)
- Audit logging (`note.created`, `note.updated`, `note.deleted`)

### Frontend (Flutter)
- Note list screen with search, category filter, pinned filter
- Note create screen (case, title, content, category, pin, private)
- Note details screen (view/edit, delete)
- Case details integration: Notes section with recent notes + "Add Note"

### Data Model
- Collection: `organizations/{orgId}/notes/{noteId}`
- Fields: noteId, orgId, caseId, title, content, category, isPinned, isPrivate, timestamps, createdBy, updatedBy, deletedAt

---

## 3) Scope Out ❌

- Rich text editor (markdown/WYSIWYG) – future
- Note templates, note sharing with specific users, note attachments
- Note history/versions, note tagging, export notes to PDF

---

## 4) Dependencies

**External Services:** Firebase Auth, Firestore, Cloud Functions (from Slice 0).

**Dependencies on Other Slices:** Slice 0 (org, membership, entitlements), Slice 1 (Flutter UI shell), Slice 2 (cases – notes are case-linked).

**No Dependencies on:** Slice 3 (Clients), Slice 4 (Documents), Slice 5+ (Tasks, Calendar, etc.)

---

## 5) Backend Endpoints (Slice 4 style)

### 5.1 `noteCreate` (Callable Function)

**Function Name (Export):** `noteCreate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `NOTES`  
**Required Permission:** `note.create`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "title": "string (required, 1-200 chars)",
  "content": "string (required, 1-10000 chars)",
  "category": "string (optional, CLIENT_MEETING | RESEARCH | STRATEGY | INTERNAL | OTHER, default OTHER)",
  "isPinned": "boolean (optional, default false)",
  "isPrivate": "boolean (optional, default false)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "noteId": "string",
    "orgId": "string",
    "caseId": "string",
    "title": "string",
    "content": "string",
    "category": "string",
    "isPinned": "boolean",
    "isPrivate": "boolean",
    "createdAt": "ISO 8601",
    "updatedAt": "ISO 8601",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId/caseId, invalid title (1-200), invalid content (1-10000), invalid category
- `NOT_AUTHORIZED` (403): Not org member or lacks NOTES/note.create
- `PLAN_LIMIT` (403): Notes feature not available on plan
- `NOT_FOUND` (404): Case not found or no case access

**Implementation Flow:**
1. Validate auth; validate orgId, caseId, title, content (required); parse category, isPinned, isPrivate
2. Check case access: canUserAccessCase(orgId, caseId, uid)
3. Check entitlement: NOTES + note.create
4. Create note document at organizations/{orgId}/notes/{noteId}; set deletedAt: null
5. Create audit event note.created
6. Return successResponse with note fields (timestamps as ISO)

---

### 5.2 `noteGet` (Callable Function)

**Function Name (Export):** `noteGet`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `NOTES`  
**Required Permission:** `note.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "noteId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "noteId": "string",
    "orgId": "string",
    "caseId": "string",
    "title": "string",
    "content": "string",
    "category": "string",
    "isPinned": "boolean",
    "isPrivate": "boolean",
    "createdAt": "ISO 8601",
    "updatedAt": "ISO 8601",
    "createdBy": "string",
    "updatedBy": "string"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or noteId
- `NOT_FOUND` (404): Note not found, deleted, or no case access; or private note and not creator
- `NOT_AUTHORIZED` (403): Lacks note.read

**Implementation Flow:**
1. Validate auth, orgId, noteId
2. Load note; if !exists or deletedAt → NOT_FOUND
3. Check case access for note.caseId; if !allowed → NOT_FOUND
4. If note.isPrivate && note.createdBy !== uid → NOT_FOUND
5. Check entitlement: NOTES + note.read
6. Return successResponse with full note (timestamps as ISO)

---

### 5.3 `noteList` (Callable Function)

**Function Name (Export):** `noteList`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `note.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional)",
  "category": "string (optional)",
  "pinnedOnly": "boolean (optional)",
  "search": "string (optional, in-memory on title+content)",
  "limit": "number (optional, default 50, max 100)",
  "offset": "number (optional, default 0)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "notes": [ { "noteId", "orgId", "caseId", "title", "content": "first 200 chars...", "category", "isPinned", "isPrivate", "createdAt", "updatedAt", "createdBy" } ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId
- `NOT_AUTHORIZED` (403): Not allowed to read notes
- `NOT_FOUND` (404): caseId provided but case not found / no access

**Implementation Flow:**
1. Validate auth, orgId; parse limit (1-100), offset
2. Check entitlement: NOTES + note.read
3. If caseId: verify case access; query notes where caseId, deletedAt==null; optional category/pinnedOnly; orderBy updatedAt desc; filter private (creator-only); in-memory search; sort pinned first then updatedAt; slice(offset, offset+limit)
4. If !caseId: query all org notes deletedAt==null; filter by case access per note; filter private; search; sort; paginate
5. Return notes (content truncated to 200 chars in list), total, hasMore

---

### 5.4 `noteUpdate` (Callable Function)

**Function Name (Export):** `noteUpdate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `note.update`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "noteId": "string (required)",
  "caseId": "string (optional, move to another case; requires access to target)",
  "title": "string (optional)",
  "content": "string (optional)",
  "category": "string (optional)",
  "isPinned": "boolean (optional)",
  "isPrivate": "boolean (optional)"
}
```

**Success Response (200):** Full note object (same shape as noteGet).

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId/noteId, or no fields to update; invalid title/content/category
- `NOT_FOUND` (404): Note not found or no case access; or private note and not creator; or target case not found when moving
- `NOT_AUTHORIZED` (403): Lacks note.update

**Implementation Flow:**
1. Validate auth, orgId, noteId; at least one update field required
2. Load note; if !exists or deletedAt → NOT_FOUND
3. Check case access for note.caseId; if private and createdBy !== uid → NOT_FOUND
4. Check entitlement: note.update
5. Apply updates (if caseId changed, verify target case access)
6. Update document; audit note.updated; return updated note

---

### 5.5 `noteDelete` (Callable Function)

**Function Name (Export):** `noteDelete`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `note.delete` (or note.update per implementation)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "noteId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": { "deleted": true }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or noteId
- `NOT_FOUND` (404): Note not found / no access (existence-hiding)
- `NOT_AUTHORIZED` (403): Not allowed to delete

**Implementation Flow:**
1. Validate auth, orgId, noteId
2. If note !exists → return successResponse({ deleted: true }) (idempotent)
3. Load note; if deletedAt already set → return successResponse({ deleted: true })
4. Check case access and private (creator); if !allowed → NOT_FOUND
5. Check entitlement; set deletedAt = now; audit note.deleted
6. Return successResponse({ deleted: true })

---

## 6. Data Model

### 6.1 Firestore Collection
```
organizations/{orgId}/notes/{noteId}
```

### 6.2 NoteDocument Schema
```typescript
interface NoteDocument {
  noteId: string;           // Auto-generated ID
  orgId: string;            // Organization ID
  caseId: string;           // Required - notes must be linked to a case
  
  // Content
  title: string;            // Required, 1-200 chars
  content: string;          // Required, 1-10000 chars (plain text for MVP)
  
  // Organization
  category: NoteCategory;   // CLIENT_MEETING, RESEARCH, STRATEGY, INTERNAL, OTHER
  isPinned: boolean;        // Default: false
  isPrivate: boolean;       // Default: false (if true, creator-only)
  
  // Metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
  createdBy: string;        // User ID
  updatedBy: string;        // User ID
  deletedAt?: Timestamp;    // Soft delete
}

type NoteCategory = 'CLIENT_MEETING' | 'RESEARCH' | 'STRATEGY' | 'INTERNAL' | 'OTHER';
```

---

## 7. Frontend Components

### 7.1 Models
- `NoteModel` - Data class with fromJson/toJson
- `NoteCategory` enum with display labels

### 7.2 Services
- `NoteService` - CRUD operations via Cloud Functions

### 7.3 Providers
- `NoteProvider` - State management with ChangeNotifier

### 7.4 Screens
- `NoteListScreen` - List notes (can filter by case, category, pinned)
- `NoteCreateScreen` - Create new note with case pre-selected
- `NoteDetailsScreen` - View/edit note

### 7.5 Integration Points
- `CaseDetailsScreen` - Add "Notes" section with recent notes + "Add Note" button
- `AppShell` - Optional: Notes tab in bottom navigation (or access via Cases only)

---

## 8. UI Design

### 8.1 Note List Screen
```
┌─────────────────────────────────────┐
│ Notes                    [+ New]    │
├─────────────────────────────────────┤
│ [Search...]                         │
│ [Category ▼] [Pinned Only ☐]       │
├─────────────────────────────────────┤
│ 📌 Strategy Meeting Notes           │
│    Case: Smith v. Jones             │
│    Updated 2 hours ago              │
├─────────────────────────────────────┤
│    Client Call - Jan 25             │
│    Case: Johnson Estate             │
│    Updated yesterday                │
├─────────────────────────────────────┤
│    Research: Statute of Limits      │
│    Case: Smith v. Jones             │
│    Updated 3 days ago               │
└─────────────────────────────────────┘
```

### 8.2 Note Create/Edit Screen
```
┌─────────────────────────────────────┐
│ ← New Note              [Save]      │
├─────────────────────────────────────┤
│ Case: [Select Case ▼]               │
│                                     │
│ Title: [________________________]   │
│                                     │
│ Category: [CLIENT_MEETING ▼]        │
│                                     │
│ Content:                            │
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │ (Multi-line text area)          │ │
│ │                                 │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ☐ Pin this note                     │
└─────────────────────────────────────┘
```

### 8.3 Note in Case Details
```
┌─────────────────────────────────────┐
│ Notes (3)              [+ Add Note] │
├─────────────────────────────────────┤
│ 📌 Strategy Discussion              │
│    STRATEGY · Updated 2h ago        │
├─────────────────────────────────────┤
│    Client Meeting Jan 25            │
│    CLIENT_MEETING · Updated 1d ago  │
├─────────────────────────────────────┤
│ [View All Notes →]                  │
└─────────────────────────────────────┘
```

---

## 9. Implementation Plan

### Phase 1: Backend (30 min)
1. Create `functions/src/functions/note.ts`
2. Implement 5 CRUD functions
3. Add entitlements for NOTES feature
4. Export functions in `index.ts`
5. Deploy functions

### Phase 2: Frontend Models & Services (20 min)
1. Create `NoteModel` and `NoteCategory` enum
2. Create `NoteService` with CRUD methods
3. Create `NoteProvider` for state management

### Phase 3: Frontend Screens (40 min)
1. Create `NoteListScreen` with filtering
2. Create `NoteCreateScreen` with form
3. Create `NoteDetailsScreen` with edit/delete
4. Add routes in `app_router.dart`

### Phase 4: Integration (20 min)
1. Add Notes section to `CaseDetailsScreen`
2. Add navigation from case to notes
3. Test end-to-end flow

### Phase 5: Testing & Polish (20 min)
1. Test all CRUD operations
2. Test case visibility rules
3. Test pinned notes sorting
4. Fix any issues

---

## 10. Security Considerations

### 10.1 Access Control
- Notes inherit visibility from their case
- PRIVATE case notes only visible to creator + participants
- ORG_WIDE case notes visible to all org members

### 10.2 Firestore Rules
```javascript
match /organizations/{orgId}/notes/{noteId} {
  // Read: org member can read non-deleted notes (case/private enforcement is in Cloud Functions)
  allow read: if isOrgMember(orgId) 
              && resource.data.deletedAt == null;
  
  // Write: only via Cloud Functions
  allow write: if false;
}
```

---

## 11. Future Enhancements (Not in MVP)

- Rich text editor (markdown or WYSIWYG)
- Note templates
- Note sharing with specific users
- Note attachments
- Note history/versions
- Note tagging
- Export notes to PDF

---

## 12. Testing Checklist

### Backend
- [ ] noteCreate with valid data
- [ ] noteCreate with invalid case access
- [ ] noteGet existing note
- [ ] noteGet with no access
- [ ] noteList with filters
- [ ] noteList respects case visibility
- [ ] noteUpdate all fields
- [ ] noteUpdate pin/unpin
- [ ] noteDelete and idempotency

### Frontend
- [ ] Create note from case details
- [ ] Create note from notes list
- [ ] View note details
- [ ] Edit note
- [ ] Delete note
- [ ] Pin/unpin note
- [ ] Filter by category
- [ ] Search notes
- [ ] Empty state handling

---

**Created:** 2026-01-26  
**Last Updated:** 2026-01-27  
**Completion Report:** `docs/slices/SLICE_8_COMPLETE.md`
