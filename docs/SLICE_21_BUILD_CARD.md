# Slice 21 Build Card: Global Search

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (after launch criteria or in parallel as capacity allows)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 4 ✅, Slice 5 ✅, Slice 7 ✅, Slice 8 ✅  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §7

---

## 📋 Overview

Slice 21 adds **Global Search** across the main entities (matters, clients, documents, tasks, events, notes) within the user's accessible scope. Results are permission-filtered (case access, role) and presented in a unified search UI with deep links.

**Key Features:**
1. **Unified search API** – Single callable that accepts a query string and returns grouped results (matters, clients, documents, tasks, events, notes) with highlights and deep links.
2. **Permission-aware** – Only matters (and their children) that the user can access via `canUserAccessCase` are included; org-wide entities (clients) filtered by org membership.
3. **Search UX** – App bar or dedicated search entry; type-ahead or "Search" button; results grouped by type with icons and links.
4. **Scope** – Search within current org only; optional filters (e.g. "Matters only", "Documents only") in UI.

**Out of Scope (MVP):**
- Full-text search inside document content (Slice 6a extracted text could be added later; requires indexing).
- Vector/semantic search (Slice 20 in v1 spec = Vector Search; separate slice).
- Search across multiple orgs (single org only).

---

## 🎯 Success Criteria

### Backend
- **`globalSearch`** – Request: `{ orgId, query, limitPerType?, types? }`. Query string applied to matters (title, description), clients (name, email), documents (name), tasks (title, description), events (title), notes (title, body). Each entity type queried with Firestore constraints (or in-memory filter after fetch); results truncated per type; each result includes id, type, title/summary, matterId if applicable, deepLink. Enforce case access for matter-scoped entities.
- **Performance:** Limit total results and per-type results (e.g. 5 per type, 25 total) to keep response fast; optional debounce on client.

### Frontend
- **Search bar** – In app bar or home; tap opens search screen or overlay.
- **Search screen** – Input field; on submit (or debounced), call `globalSearch`; display results in sections (Matters, Clients, Documents, Tasks, Events, Notes); tap row navigates to detail (deepLink).
- **Empty state** – "No results" when query returns nothing.

### Testing
- Backend: Query "Acme" returns matters/clients/documents containing "Acme"; private matter "Acme" not returned for user without access.
- Frontend: Type query, see grouped results, tap to navigate.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. Global Search Implementation
- **`globalSearch`**  
  - **Request:** `{ orgId: string, query: string, limitPerType?: number (default 5), types?: ("matter"|"client"|"document"|"task"|"event"|"note")[] }`.  
  - **Process:**  
    - Validate auth and org membership.  
    - Normalize query (trim, toLowerCase for comparisons).  
    - For each requested type (or all):  
      - **Matters:** Query cases where orgId match; filter by canUserAccessCase; in-memory filter title/description contains query.  
      - **Clients:** Query clients where orgId; in-memory filter name/email contains query.  
      - **Documents:** List documents (org-wide or by matter); filter by case access; in-memory filter name (and optionally extractedText if indexed later).  
      - **Tasks:** List tasks (org or by matter); filter by case access; in-memory filter title/description.  
      - **Events:** List events (org or by matter); filter by case access; in-memory filter title.  
      - **Notes:** List notes (org or by case); filter by case access; in-memory filter title/body.  
    - Build result items: `{ type, id, title, subtitle?, matterId?, deepLink }`.  
    - Return `{ results: { matter: [...], client: [...], ... } }` or flat list with type tag.  
  - **Success:** `{ results: { matter: [...], client: [...], document: [...], task: [...], event: [...], note: [...] } }`.  
  - **Errors:** VALIDATION_ERROR (query too short), FORBIDDEN.

**Implementation note:** Firestore does not support full-text search natively. Options: (1) In-memory filter after fetching recent/paginated items (simplest MVP); (2) Algolia/Elasticsearch (future); (3) Use existing list endpoints with client-side filter for very small datasets. For MVP, use list endpoints with reasonable limit (e.g. last 100 matters, 200 documents, etc.) and filter in-memory by query string (case-insensitive contains). This is acceptable for small/medium orgs; document later for scaling.

### Frontend (Flutter)

- **GlobalSearchScreen** or **SearchOverlay** – TextField; onChanged debounce 300–500 ms; call GlobalSearchService.globalSearch(orgId, query).
- **SearchResultsWidget** – Grouped list by type; each item: icon, title, subtitle (e.g. matter name for a task), onTap → GoRouter.push(deepLink).
- **Deep links:** Define route patterns: /matters/{id}, /clients/{id}, /matters/{matterId}/documents/{id}, /matters/{matterId}/tasks/{id}, etc., so backend can return path strings and app can navigate.

### Data Model

No new collections. Reuse existing Firestore queries; add composite indexes if needed for list-by-org with ordering (likely already exist from Slices 2, 3, 4, 5, 7, 8).

---

## 🔐 Security & Permissions

- Every entity type must respect existing permissions: case access for matter-scoped data, org membership, role-based visibility (e.g. tasks restrictedToAssignee).
- Do not return private matters or documents to users without access.
- Rate limit: optional cap on search calls per user per minute to avoid abuse.

---

## 📝 Backend Endpoints (Summary)

| Function | Request | Success |
|----------|---------|---------|
| globalSearch | orgId, query, limitPerType?, types? | { results: { matter, client, document, task, event, note } } |

---

## 🧪 Testing Strategy

- Unit: Given mock list of matters, filter by query "test" returns correct subset.
- Integration: Create matter "Test Matter"; search "Test" → appears; user without access to private "Test Matter" does not see it.
- Frontend: Type "invoice", see documents and matters containing "invoice"; tap document → navigates to document details.

---

## 📚 References

- MASTER_SPEC_V2.0.md §7 (Slice 21)
- SLICE_2_BUILD_CARD.md (Case list, visibility)
- Firestore query limitations (consider Algolia for scale later)

---

**Last Updated:** 2026-01-30
