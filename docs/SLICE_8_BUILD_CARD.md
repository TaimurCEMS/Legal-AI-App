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

## 2. Data Model

### 2.1 Firestore Collection
```
organizations/{orgId}/notes/{noteId}
```

### 2.2 NoteDocument Schema
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

## 3. Backend Functions

### 3.1 noteCreate
**Callable Name:** `noteCreate`

**Input:**
```typescript
{
  orgId: string;            // Required
  caseId: string;           // Required
  title: string;            // Required, 1-200 chars
  content: string;          // Required, 1-10000 chars
  category?: NoteCategory;  // Default: OTHER
  isPinned?: boolean;       // Default: false
  isPrivate?: boolean;      // Default: false
}
```

**Output:**
```typescript
{
  success: true;
  data: {
    noteId: string;
    caseId: string;
    title: string;
    content: string;
    category: NoteCategory;
    isPinned: boolean;
    createdAt: string;      // ISO string
    updatedAt: string;
    createdBy: string;
  }
}
```

**Validation:**
- User must have org membership
- User must have case access (ORG_WIDE or participant for PRIVATE)
- Title: 1-200 characters
- Content: 1-10000 characters
- Category: valid enum value

**Entitlements:**
- Feature: `NOTES`
- Permission: `note.create`

---

### 3.2 noteGet
**Callable Name:** `noteGet`

**Input:**
```typescript
{
  orgId: string;            // Required
  noteId: string;
}
```

**Output:**
```typescript
{
  success: true;
  data: NoteDocument;  // Full note with all fields
}
```

**Access Control:**
- Note visibility follows case visibility
- If case is PRIVATE, user must be creator or participant

---

### 3.3 noteList
**Callable Name:** `noteList`

**Input:**
```typescript
{
  orgId: string;            // Required
  caseId?: string;          // Filter by case (optional)
  category?: NoteCategory;  // Filter by category (optional)
  pinnedOnly?: boolean;     // Only pinned notes (optional)
  search?: string;          // Search in title/content (optional)
  limit?: number;           // Default: 50, max: 100
  offset?: number;          // Pagination offset
}
```

**Output:**
```typescript
{
  success: true;
  data: {
    notes: NoteDocument[];
    total: number;
    hasMore: boolean;
  }
}
```

**Behavior:**
- Returns notes user has access to (based on case visibility)
- Sorted by: pinned first, then updatedAt desc
- Search: in-memory contains on title and content

---

### 3.4 noteUpdate
**Callable Name:** `noteUpdate`

**Input:**
```typescript
{
  orgId: string;            // Required
  noteId: string;
  caseId?: string;          // Optional: move note to another case (requires access)
  title?: string;
  content?: string;
  category?: NoteCategory;
  isPinned?: boolean;
  isPrivate?: boolean;
}
```

**Output:**
```typescript
{
  success: true;
  data: NoteDocument;  // Updated note
}
```

**Validation:**
- User must have case access
- At least one field must be provided
- Same validation rules as create

---

### 3.5 noteDelete
**Callable Name:** `noteDelete`

**Input:**
```typescript
{
  orgId: string;            // Required
  noteId: string;
}
```

**Output:**
```typescript
{
  success: true;
  data: { deleted: true }
}
```

**Behavior:**
- Soft delete (sets deletedAt)
- Idempotent (returns success if already deleted)

---

## 4. Frontend Components

### 4.1 Models
- `NoteModel` - Data class with fromJson/toJson
- `NoteCategory` enum with display labels

### 4.2 Services
- `NoteService` - CRUD operations via Cloud Functions

### 4.3 Providers
- `NoteProvider` - State management with ChangeNotifier

### 4.4 Screens
- `NoteListScreen` - List notes (can filter by case, category, pinned)
- `NoteCreateScreen` - Create new note with case pre-selected
- `NoteDetailsScreen` - View/edit note

### 4.5 Integration Points
- `CaseDetailsScreen` - Add "Notes" section with recent notes + "Add Note" button
- `AppShell` - Optional: Notes tab in bottom navigation (or access via Cases only)

---

## 5. UI Design

### 5.1 Note List Screen
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

### 5.2 Note Create/Edit Screen
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

### 5.3 Note in Case Details
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

## 6. Implementation Plan

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

## 7. Security Considerations

### 7.1 Access Control
- Notes inherit visibility from their case
- PRIVATE case notes only visible to creator + participants
- ORG_WIDE case notes visible to all org members

### 7.2 Firestore Rules
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

## 8. Future Enhancements (Not in MVP)

- Rich text editor (markdown or WYSIWYG)
- Note templates
- Note sharing with specific users
- Note attachments
- Note history/versions
- Note tagging
- Export notes to PDF

---

## 9. Testing Checklist

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
