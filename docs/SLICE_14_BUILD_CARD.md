# Slice 14: AI Document Summarization - Build Card

**Status:** ✅ COMPLETE  
**Priority:** 🟡 RECOMMENDED  
**Completed:** 2026-01-29  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 4 ✅, Slice 6a ✅

**Slice 4 style:** This build card includes **Scope In/Out**, **Dependencies**, and **per-endpoint specs** (Request Payload, Success Response, Error Responses, Implementation Flow) in Section 3.4, matching the Slice 4 Document Hub build card format.

---

## 1) Overview

### 1.1 Purpose
One-click document summaries so users can quickly get a concise overview of any document with extracted text, without running full contract analysis. This complements Slice 13 (Contract Analysis) by offering a lighter-weight summary for any document type.

### 1.2 Scope In ✅
- **Backend (Cloud Functions):** `summarizeDocument`, `documentSummaryGet`, `documentSummaryList`; entitlement checks; case access; audit events
- **Frontend (Flutter):** Document Details – "Document Summary" section (Summarize button, summary text, re-summarize); DocumentSummaryModel, DocumentSummaryService, DocumentSummaryProvider
- **Storage:** `organizations/{orgId}/document_summaries/{summaryId}` in Firestore; composite indexes (documentId+createdAt, caseId+createdAt)
- **AI:** OpenAI summarization (~300 words, plain language) via `ai-service.ts` `summarizeDocument()`

### 1.3 Key Features
- **Summarize:** Generate a concise summary from extracted document text (~300 words)
- **Get/List:** Retrieve a summary by id or list by documentId/caseId (pagination, orderBy createdAt desc)
- **Entitlements:** DOCUMENT_SUMMARY feature, `document.summarize` permission (ADMIN, LAWYER, PARALEGAL)
- **Case access:** Enforced via `canUserAccessCase` for case-linked documents/summaries

### 1.4 Scope Out ❌
- Summary length presets (short/medium/long) – future
- Multi-document summary (e.g. case folder) – future
- Export summary to PDF/DOCX – future
- Summary history UI (browse past summaries per document) – future
- Jurisdiction-aware summaries – future

### 1.5 Dependencies
- **Slice 0:** Auth, org, entitlements engine
- **Slice 1:** Flutter shell, navigation, providers
- **Slice 4:** Document Hub (documents with extracted text)
- **Slice 6a:** Document extraction (extractedText, extractionStatus)

**No dependency on:** Slice 6b (AI Chat), Slice 13 (Contract Analysis) – summary is independent.

---

## 2) Data Model

### 2.1 Storage Location
Document summaries stored under:
```
organizations/{orgId}/document_summaries/{summaryId}
```

### 2.2 Document Summary Document Shape
```typescript
interface DocumentSummaryDocument {
  id: string;
  orgId: string;
  documentId: string;  // Link to document
  caseId?: string | null;  // Optional case linkage (from document)
  summary: string;  // Plain-language summary text
  createdAt: Timestamp;
  createdBy: string;
  model: string;  // e.g., "gpt-4o-mini"
  tokensUsed?: number | null;
  processingTimeMs?: number | null;
}
```

### 2.3 Firestore Indexes
- **document_summaries** (documentId ASC, createdAt DESC) – for listing by document
- **document_summaries** (caseId ASC, createdAt DESC) – for listing by case

---

## 3) Backend (Cloud Functions)

### 3.1 Functions to Deploy

**1. `summarizeDocument`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, documentId, options?: { model?: string, maxLength?: number } }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`DOCUMENT_SUMMARY` feature + `document.summarize` permission)
  - Verify document exists and user has access (case access check if linked)
  - Verify document has extracted text (`extractionStatus === 'completed'`)
  - Call AI service `summarizeDocument(documentText, documentName, options)`
  - Create summary record in `document_summaries`
  - Create audit event (`document.summarized`)
  - Return full summary object (summaryId, summary, createdAt, createdBy, model, etc.)
- **Output:** `{ summaryId, documentId, caseId?, summary, createdAt, createdBy, model, tokensUsed?, processingTimeMs? }`

**2. `documentSummaryGet`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, summaryId }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`document.summarize` permission)
  - Fetch summary record
  - Verify case access if summary is linked to a case
  - Return summary document
- **Output:** Full summary document

**3. `documentSummaryList`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, documentId?, caseId?, limit?, offset? }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`document.summarize` permission)
  - Filter by documentId or caseId (if provided); verify case access for caseId
  - Apply case access filtering for PRIVATE cases when listing without caseId
  - Order by createdAt desc; apply pagination (limit/offset)
  - Return paginated list
- **Output:** `{ summaries: [...], total, hasMore }`

### 3.2 AI Service Extension

**In `functions/src/services/ai-service.ts`:**

- **`summarizeDocument(documentText, documentName, options?)`**
  - Uses OpenAI chat completion with a system prompt for legal/business document summarization
  - Target length ~300 words (configurable via `maxLength`)
  - Returns: `{ summary, tokensUsed, model, processingTimeMs }`
  - Truncates document text to 50,000 chars if needed

### 3.3 Key Files
- `functions/src/functions/document-summary.ts` (new)
- `functions/src/services/ai-service.ts` (extend with `summarizeDocument`)
- `functions/src/constants/permissions.ts` (add `document.summarize`)
- `functions/src/constants/entitlements.ts` (add `DOCUMENT_SUMMARY` feature)
- `functions/src/index.ts` (export new functions)
- `functions/src/__tests__/slice14-terminal-test.ts` (new)

### 3.4 Backend Endpoints (Slice 4 style)

Per-endpoint specs with Request Payload, Success Response, Error Responses, and Implementation Flow (same format as Slice 4).

---

#### 3.4.1 `summarizeDocument` (Callable Function)

**Function Name (Export):** `summarizeDocument`  
**Type:** Firebase Callable Function

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.summarize` (from ROLE_PERMISSIONS)
- ADMIN: ✅ | LAWYER: ✅ | PARALEGAL: ✅ | VIEWER: ❌

**Plan Gating:** `DOCUMENT_SUMMARY` feature must be enabled (FREE/BASIC/PRO/ENTERPRISE)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (required)",
  "options": {
    "model": "string (optional, 'gpt-4o-mini' | 'gpt-4o', default 'gpt-4o-mini')",
    "maxLength": "number (optional, approximate max summary words, default 300)"
  }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "summaryId": "string",
    "documentId": "string",
    "caseId": "string | null",
    "summary": "string",
    "createdAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "model": "string",
    "tokensUsed": "number | null",
    "processingTimeMs": "number | null"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or documentId
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `document.summarize`, or plan doesn't have DOCUMENT_SUMMARY
- `NOT_FOUND` (404): Document not found or soft-deleted
- `VALIDATION_ERROR` (400): Document has no extracted text or extractionStatus !== 'completed'
- `NOT_AUTHORIZED` (403): User does not have case access (document linked to PRIVATE case)
- `INTERNAL_ERROR` (500): AI service failure or Firestore write failure

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Validate documentId (required, non-empty)
4. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'DOCUMENT_SUMMARY', requiredPermission: 'document.summarize' })`
5. Fetch document from `organizations/{orgId}/documents/{documentId}`
6. Verify document exists and is not soft-deleted (`deletedAt == null`)
7. Verify document has extracted text: `extractedText` present and `extractionStatus === 'completed'`
8. If document.caseId present: `canUserAccessCase(orgId, document.caseId, uid)` must allow
9. Call AI service: `summarizeDocument(document.extractedText, document.name, { model, maxLength })`
10. Create summary doc in `organizations/{orgId}/document_summaries/{summaryId}` (id, orgId, documentId, caseId, summary, createdAt, createdBy, model, tokensUsed, processingTimeMs)
11. Create audit event: `document.summarized`, entityType `document_summary`, metadata { documentId, documentName, tokensUsed }
12. Return successResponse with summaryId, documentId, caseId, summary, createdAt, createdBy, model, tokensUsed, processingTimeMs
13. On AI or write error: update audit `document.summarize_failed`, return errorResponse(INTERNAL_ERROR, message)

---

#### 3.4.2 `documentSummaryGet` (Callable Function)

**Function Name (Export):** `documentSummaryGet`  
**Type:** Firebase Callable Function

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.summarize` (same as summarize – read access)

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "summaryId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "summaryId": "string",
    "documentId": "string",
    "caseId": "string | null",
    "summary": "string",
    "createdAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "model": "string",
    "tokensUsed": "number | null",
    "processingTimeMs": "number | null"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or summaryId
- `NOT_AUTHORIZED` (403): User not a member of org or role doesn't have `document.summarize`
- `NOT_FOUND` (404): Summary not found
- `NOT_AUTHORIZED` (403): Summary linked to case and user does not have case access

**Implementation Flow:**
1. Validate auth token
2. Validate orgId and summaryId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'document.summarize' })`
4. Fetch summary from `organizations/{orgId}/document_summaries/{summaryId}`
5. Verify summary exists
6. If summary.caseId present: `canUserAccessCase(orgId, summary.caseId, uid)` must allow
7. Return successResponse with full summary document (all fields)

---

#### 3.4.3 `documentSummaryList` (Callable Function)

**Function Name (Export):** `documentSummaryList`  
**Type:** Firebase Callable Function

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `document.summarize`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (optional, filter by document)",
  "caseId": "string (optional, filter by case)",
  "limit": "number (optional, default 20, max 100)",
  "offset": "number (optional, default 0)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "summaries": [
      {
        "summaryId": "string",
        "documentId": "string",
        "caseId": "string | null",
        "summary": "string",
        "createdAt": "ISO 8601 timestamp",
        "createdBy": "string (uid)",
        "model": "string",
        "tokensUsed": "number | null",
        "processingTimeMs": "number | null"
      }
    ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId
- `NOT_AUTHORIZED` (403): User not a member of org or role doesn't have `document.summarize`
- `NOT_AUTHORIZED` (403): caseId provided and user does not have case access

**Implementation Flow:**
1. Validate auth token
2. Validate orgId (required)
3. Parse limit (1–100, default 20) and offset (≥ 0, default 0)
4. Check entitlement: `checkEntitlement({ uid, orgId, requiredPermission: 'document.summarize' })`
5. If caseId provided: `canUserAccessCase(orgId, caseId, uid)` must allow
6. Build query: `organizations/{orgId}/document_summaries`; if documentId add `.where('documentId','==',documentId)`; if caseId add `.where('caseId','==',caseId)`; `.orderBy('createdAt','desc')`; apply limit(+1) and offset
7. Execute query (requires composite index: documentId+createdAt or caseId+createdAt)
8. If no caseId filter: for each result with caseId, filter out where `canUserAccessCase` denies
9. Return successResponse with summaries array, total, hasMore

---

## 4) Frontend (Flutter)

### 4.1 UI Entry Point
- **Document Details Screen** → "Document Summary" section (below Contract Analysis, above Download)
- Show only when document has extracted text (same condition as Contract Analysis)

### 4.2 Features Implemented
- **Summarize Button:** Trigger summarization for documents with extracted text
- **Loading State:** Show "Generating summary..." during summarization
- **Results Display:**
  - Summary text in a styled container
  - "Last summarized" hint (e.g. "Just now", "5m ago", "2h ago")
- **Error Handling:** Display errors if summarization fails (SnackBar)
- **Re-summarize:** Allow re-running (creates new summary record; list returns latest)

### 4.3 Key Files
- `legal_ai_app/lib/core/models/document_summary_model.dart` (new)
- `legal_ai_app/lib/core/services/document_summary_service.dart` (new)
- `legal_ai_app/lib/features/document_summary/providers/document_summary_provider.dart` (new)
- `legal_ai_app/lib/features/documents/screens/document_details_screen.dart` (extend with Document Summary section)
- `legal_ai_app/lib/app.dart` (register `DocumentSummaryProvider`)

---

## 5) Security & Access Control

### 5.1 Permissions
- **`document.summarize`** – Required to summarize and view summaries
  - ADMIN: ✅
  - LAWYER: ✅
  - PARALEGAL: ✅
  - VIEWER: ❌

### 5.2 Feature Flag
- **`DOCUMENT_SUMMARY`** – Feature availability by plan
  - FREE: ✅ (enabled for testing)
  - BASIC: ✅
  - PRO: ✅
  - ENTERPRISE: ✅

### 5.3 Case Access
- Summary results inherit document's case access
- PRIVATE case documents: summary only visible to users with case access
- Enforced via `canUserAccessCase()` helper in list/get/summarize

### 5.4 Audit Logging
- `document.summarized` – When summarization completes successfully
- `document.summarize_failed` – When summarization fails

### 5.5 Firestore Rules
- **`organizations/{orgId}/document_summaries/{summaryId}`**
  - Read: org member AND (no caseId OR canAccessCase(orgId, caseId))
  - Create/Update/Delete: false (server-only via Cloud Functions)

---

## 6) Testing

### 6.1 Backend Terminal Test (requires deployed functions)
```powershell
cd functions
$env:FIREBASE_API_KEY="AIza...."
npm run build
npm run test:slice14
```

### 6.2 Test Cases (slice14-terminal-test)
- ✅ Create test user + org
- ✅ `documentSummaryList` with no summaries → returns empty list
- ✅ `documentSummaryGet` with invalid summaryId → NOT_FOUND

### 6.3 Manual Testing Checklist

**Backend**
- [x] `summarizeDocument` with extracted text returns summaryId, summary, createdAt, createdBy
- [x] Document without extracted text returns validation error
- [x] Unauthorized access (no org, wrong role) returns NOT_AUTHORIZED
- [x] Case access enforced for PRIVATE case documents
- [x] `documentSummaryList` returns empty list when no summaries; requires Firestore indexes
- [x] `documentSummaryGet` with invalid id returns NOT_FOUND

**Frontend**
- [x] Document Details shows Document Summary section when extraction is complete
- [x] Summarize → loading → summary text and "Last summarized" shown
- [x] Re-summarize creates new summary; latest shown
- [x] Error states: no extracted text (SnackBar), API failure (SnackBar)

---

## 7) Deployment Notes

- **Cloud Functions:** `firebase deploy --only functions` (deploys summarizeDocument, documentSummaryGet, documentSummaryList)
- **Firestore indexes:** `firebase deploy --only firestore:indexes` – composite indexes for document_summaries (documentId+createdAt, caseId+createdAt). Indexes may take a few minutes to build.
- **Firestore rules:** Rules for `document_summaries` are in `firestore.rules`; deploy with `firebase deploy` or `firebase deploy --only firestore:rules` if needed.

---

## 8) Future Enhancements (Out of Scope)

- **Summary length options:** Short / medium / long presets
- **Multi-document summary:** Summarize a set of documents (e.g. case folder)
- **Export summary:** Copy or export summary to PDF/DOCX
- **Summary history:** UI to browse past summaries for a document
- **Jurisdiction-aware summaries:** Optional jurisdiction hint for legal focus

---

## 9) Success Criteria

- ✅ Backend functions: summarizeDocument, documentSummaryGet, documentSummaryList
- ✅ Frontend: Document Summary section on Document Details with Summarize, loading, summary text, re-summarize
- ✅ Case access enforced for PRIVATE cases
- ✅ Error handling for no extracted text and API failures
- ✅ Audit logging for summarization operations
- ✅ Backend terminal test passing (`npm run test:slice14` when deployed)
- ✅ Firestore indexes and rules deployed

**Overall:** ✅ **COMPLETE**

---

**Created:** 2026-01-29  
**Last Updated:** 2026-01-29
