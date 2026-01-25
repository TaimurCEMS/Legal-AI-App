# SLICE 6A: Document Text Extraction - Build Card

**Last Updated:** January 24, 2026  
**Status:** 🔄 IN PROGRESS  
**Owner:** Taimur (CEMS)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 4 ✅

---

## 1) Purpose

Build the document text extraction foundation that enables AI features. This slice adds the ability to extract text from uploaded documents (PDF, DOCX, TXT, RTF) and store it for future AI processing (research, drafting, semantic search).

Text extraction is the **prerequisite** for all AI features:
- AI research needs document text to provide context
- AI drafting needs to reference existing documents
- Semantic search requires extracted text for embeddings

---

## 2) Scope In ✅

### Backend (Cloud Functions):
- `documentExtract` - Trigger text extraction for a document
- `documentGetExtractionStatus` - Check extraction job status
- Text extraction service (PDF, DOCX, TXT, RTF parsing)
- Job queue system in Firestore for async processing
- Extraction status tracking on documents
- Entitlement checks (`OCR_EXTRACTION` feature)
- Error handling and retry logic
- Audit logging for extraction operations

### Frontend (Flutter):
- "Extract Text" button on document details screen
- Extraction status indicator (pending, processing, completed, failed)
- Extracted text preview (expandable section)
- Page count and word count display
- Error display for failed extractions
- Re-extract option for failed extractions

### Data Model Extensions:
- Document extraction fields (extractedText, extractionStatus, etc.)
- Job queue collection for async processing

---

## 3) Scope Out ❌

- OCR for scanned images (Slice 6a.1 - requires Google Document AI)
- Embeddings generation (Slice 6b)
- AI chat/research (Slice 6b)
- AI drafting (Slice 6c)
- Semantic search (Slice 6b)
- Batch extraction (future)
- Extraction analytics (future)

---

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0
- Cloud Storage (required) - from Slice 4

**NPM Packages (New):**
- `pdf-parse` - PDF text extraction
- `mammoth` - DOCX text extraction
- `openai` - For future AI features (install now)

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org, membership, entitlements)
- ✅ **Slice 1**: Required (Flutter UI shell)
- ✅ **Slice 4**: Required (document upload, storage)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `documentExtract` (Callable Function)

**Function Name (Export):** `documentExtract`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `OCR_EXTRACTION` (BASIC+ plans)  
**Required Permission:** `document.read`

**Request:**
```typescript
{
  orgId: string;        // Organization ID
  documentId: string;   // Document to extract
  forceReExtract?: boolean;  // Re-extract even if already done
}
```

**Response (Success):**
```typescript
{
  success: true;
  data: {
    jobId: string;           // Job ID for status tracking
    documentId: string;
    status: 'PENDING';
  }
}
```

**Response (Errors):**
- `ORG_REQUIRED` - Missing orgId
- `NOT_AUTHORIZED` - User not org member or lacks permission
- `PLAN_LIMIT` - OCR_EXTRACTION not available on plan
- `NOT_FOUND` - Document not found
- `VALIDATION_ERROR` - Document already has extraction (use forceReExtract)

**Behavior:**
1. Validate auth and org membership
2. Check `OCR_EXTRACTION` entitlement
3. Load document, verify it exists and is not deleted
4. Check if extraction already exists (unless forceReExtract)
5. Create job document in `organizations/{orgId}/jobs/{jobId}`
6. Update document status to 'pending'
7. Return job ID for status tracking

---

### 5.2 `documentGetExtractionStatus` (Callable Function)

**Function Name (Export):** `documentGetExtractionStatus`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `document.read`

**Request:**
```typescript
{
  orgId: string;
  documentId: string;
}
```

**Response (Success):**
```typescript
{
  success: true;
  data: {
    documentId: string;
    extractionStatus: 'none' | 'pending' | 'processing' | 'completed' | 'failed';
    extractedAt?: string;      // ISO timestamp
    extractionError?: string;
    pageCount?: number;
    wordCount?: number;
    hasExtractedText: boolean;
  }
}
```

---

### 5.3 `extractionProcessJob` (Firestore Trigger)

**Function Name (Export):** `extractionProcessJob`  
**Type:** Firestore onCreate trigger  
**Path:** `organizations/{orgId}/jobs/{jobId}`  
**Condition:** `job.type === 'EXTRACTION' && job.status === 'PENDING'`

**Behavior:**
1. Update job status to 'PROCESSING'
2. Load document metadata from Firestore
3. Download file from Cloud Storage
4. Extract text based on file type:
   - PDF: Use `pdf-parse`
   - DOCX: Use `mammoth`
   - TXT/RTF: Read as text
5. Calculate page count and word count
6. Update document with extracted text and metadata
7. Update job status to 'COMPLETED'
8. On error: Update job and document to 'FAILED' with error message

---

## 6) Data Model

### 6.1 Document Model Extensions

Add to existing `DocumentDocument` interface:

```typescript
interface DocumentDocument {
  // ... existing fields ...
  
  // Text extraction fields
  extractedText?: string | null;
  extractionStatus: 'none' | 'pending' | 'processing' | 'completed' | 'failed';
  extractionError?: string | null;
  extractedAt?: FirestoreTimestamp | null;
  pageCount?: number | null;
  wordCount?: number | null;
}
```

**Default Values:**
- `extractionStatus`: 'none' (for existing documents)
- All other extraction fields: `null`

### 6.2 Job Queue Collection

**Path:** `organizations/{orgId}/jobs/{jobId}`

```typescript
interface JobDocument {
  jobId: string;
  orgId: string;
  type: 'EXTRACTION' | 'AI_RESEARCH' | 'AI_DRAFT';
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  targetId: string;           // documentId for extraction jobs
  targetType: 'document';
  input?: {
    forceReExtract?: boolean;
  };
  output?: {
    pageCount?: number;
    wordCount?: number;
    textLength?: number;
  };
  error?: string | null;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  completedAt?: FirestoreTimestamp | null;
}
```

---

## 7) Text Extraction Service

### 7.1 Supported File Types

| File Type | Extension | Method | Library |
|-----------|-----------|--------|---------|
| PDF | .pdf | Parse embedded text | pdf-parse |
| Word | .docx | Parse XML content | mammoth |
| Word (old) | .doc | Not supported (MVP) | - |
| Text | .txt | Read as UTF-8 | Native |
| Rich Text | .rtf | Basic text extraction | Native |

### 7.2 Extraction Limits

- **Max file size:** 10MB (existing limit)
- **Max text length:** 500,000 characters (truncate if longer)
- **Timeout:** 60 seconds per extraction

### 7.3 Error Handling

| Error Type | Handling |
|------------|----------|
| File not found | Fail job, set error message |
| Unsupported type | Fail job, suggest supported types |
| Parse error | Fail job, include error details |
| Timeout | Fail job, suggest smaller file |
| Empty text | Complete with warning, set wordCount=0 |

---

## 8) Frontend Changes

### 8.1 Document Model Updates

```dart
class DocumentModel {
  // ... existing fields ...
  
  final String? extractedText;
  final String extractionStatus; // 'none', 'pending', 'processing', 'completed', 'failed'
  final String? extractionError;
  final DateTime? extractedAt;
  final int? pageCount;
  final int? wordCount;
  
  bool get hasExtractedText => extractedText != null && extractedText!.isNotEmpty;
  bool get canExtract => extractionStatus == 'none' || extractionStatus == 'failed';
  bool get isExtracting => extractionStatus == 'pending' || extractionStatus == 'processing';
}
```

### 8.2 Document Service Updates

```dart
// Trigger extraction
Future<Map<String, dynamic>> extractDocument({
  required OrgModel org,
  required String documentId,
  bool forceReExtract = false,
});

// Get extraction status
Future<Map<String, dynamic>> getExtractionStatus({
  required OrgModel org,
  required String documentId,
});
```

### 8.3 Document Details Screen Updates

**New UI Elements:**
1. **Extraction Section** (below document info):
   - Status badge (None/Pending/Processing/Completed/Failed)
   - "Extract Text" button (when canExtract)
   - Progress indicator (when isExtracting)
   - Error message (when failed)
   
2. **Extracted Text Section** (when completed):
   - Page count and word count badges
   - Expandable text preview (first 500 chars)
   - "View Full Text" option (modal or new screen)

---

## 9) Entitlements

### Already Configured (No Changes Needed)

**Feature Flag:** `OCR_EXTRACTION`
- FREE: ❌
- BASIC: ✅
- PRO: ✅
- ENTERPRISE: ✅

**Permission:** `document.read` (reuse existing)
- All roles can read documents they have access to

---

## 10) Implementation Order

1. ✅ Create build card (this document)
2. Add dependencies to `functions/package.json`
3. Create `functions/src/services/extraction-service.ts`
4. Create `functions/src/functions/extraction.ts`
5. Extend document model in `document.ts`
6. Export functions in `index.ts`
7. Update Flutter `DocumentModel`
8. Update Flutter `DocumentService`
9. Update `DocumentDetailsScreen` with extraction UI
10. Deploy and test

---

## 11) Testing Checklist

### Backend
- [ ] `documentExtract` creates job and returns jobId
- [ ] `documentExtract` fails for FREE plan users
- [ ] `documentExtract` fails for non-existent document
- [ ] `documentExtract` respects forceReExtract flag
- [ ] Extraction job processes PDF correctly
- [ ] Extraction job processes DOCX correctly
- [ ] Extraction job processes TXT correctly
- [ ] Failed extraction sets error message
- [ ] Document is updated with extracted text
- [ ] Word count and page count are calculated

### Frontend
- [ ] "Extract Text" button appears for eligible documents
- [ ] Button disabled during extraction
- [ ] Status indicator shows correct state
- [ ] Extracted text preview displays correctly
- [ ] Error message shown for failed extractions
- [ ] Re-extract works for failed extractions

---

## 12) Files to Create/Modify

### Create
- `functions/src/services/extraction-service.ts`
- `functions/src/functions/extraction.ts`
- `docs/SLICE_6A_BUILD_CARD.md`

### Modify
- `functions/package.json` - Add dependencies
- `functions/src/functions/document.ts` - Add extraction fields
- `functions/src/index.ts` - Export new functions
- `legal_ai_app/lib/core/models/document_model.dart` - Add extraction fields
- `legal_ai_app/lib/core/services/document_service.dart` - Add extraction methods
- `legal_ai_app/lib/features/documents/screens/document_details_screen.dart` - Add UI

---

**End of Slice 6A Build Card**
