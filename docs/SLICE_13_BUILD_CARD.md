# Slice 13: AI Contract Analysis - Build Card

**Status:** 🔄 IN PROGRESS  
**Priority:** 🟡 HIGH  
**Started:** 2026-01-29  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 4 ✅, Slice 6a ✅, Slice 6b ✅

---

## 1) Overview

### 1.1 Purpose
Enable AI-powered contract analysis to automatically identify clauses, flag risks, and provide structured insights. This is a key differentiator that helps lawyers quickly understand contract terms, spot potential issues, and make informed decisions.

### 1.2 MVP Scope (this slice)
- **Backend:** Callable function to analyze a contract document (clause identification, risk flagging)
- **Frontend:** "Analyze Contract" button on document details, results display with clauses and risks
- **Storage:** Contract analysis results stored in Firestore (linked to document)
- **AI:** Structured output parsing (clauses with types, risks with severity levels)

### 1.3 Key Features
- **Clause Identification:** Extract and categorize contract clauses (termination, payment, liability, etc.)
- **Risk Flagging:** Identify potential risks with severity levels (high/medium/low)
- **Summary:** High-level contract overview
- **Document Linking:** Analysis tied to specific document (case access enforced)

---

## 2) Data Model

### 2.1 Storage Location
Contract analyses stored under:
```
organizations/{orgId}/contract_analyses/{analysisId}
```

### 2.2 Contract Analysis Document Shape
```typescript
interface ContractAnalysisDocument {
  id: string;
  orgId: string;
  documentId: string;  // Link to document
  caseId?: string | null;  // Optional case linkage
  status: 'pending' | 'processing' | 'completed' | 'failed';
  error?: string | null;
  
  // Analysis results (when completed)
  summary?: string | null;  // High-level overview
  clauses?: Clause[] | null;
  risks?: Risk[] | null;
  
  // Metadata
  createdAt: Timestamp;
  completedAt?: Timestamp | null;
  createdBy: string;
  model: string;  // e.g., "gpt-4o-mini"
  tokensUsed?: number | null;
  processingTimeMs?: number | null;
}

interface Clause {
  id: string;  // Generated client-side or server-side
  type: string;  // e.g., "termination", "payment", "liability", "confidentiality"
  title: string;  // Short title/name
  content: string;  // Relevant text excerpt
  pageNumber?: number | null;  // If available
  startChar?: number | null;  // Character offset in document
  endChar?: number | null;
}

interface Risk {
  id: string;
  severity: 'high' | 'medium' | 'low';
  category: string;  // e.g., "liability", "termination", "payment"
  title: string;  // Short description
  description: string;  // Detailed explanation
  clauseIds?: string[];  // Related clause IDs
  recommendation?: string | null;  // Suggested action
}
```

### 2.3 Document Model Extension (Flutter)
Add optional contract analysis fields to `DocumentModel`:
```dart
final ContractAnalysisModel? contractAnalysis;  // Latest analysis
final String? contractAnalysisStatus;  // 'none', 'pending', 'completed', 'failed'
```

---

## 3) Backend (Cloud Functions)

### 3.1 Functions to Deploy

**1. `contractAnalyze`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, documentId, options?: { model?: string } }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`CONTRACT_ANALYSIS` feature + `contract.analyze` permission)
  - Verify document exists and user has access (case access check if linked)
  - Verify document has extracted text (`extractionStatus === 'completed'`)
  - Create analysis record with `status: 'pending'`
  - Queue AI analysis job (or process immediately for MVP)
  - Call OpenAI with contract analysis prompt
  - Parse structured response (clauses + risks)
  - Update analysis record with results (`status: 'completed'`)
  - Create audit event
- **Output:** `{ analysisId, status, summary?, clauses?, risks?, metadata? }`

**2. `contractAnalysisGet`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, analysisId }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`contract.analyze` permission)
  - Fetch analysis record
  - Verify document access (case access check)
  - Return analysis with clauses and risks
- **Output:** Full analysis document

**3. `contractAnalysisList`** (exported in `functions/src/index.ts`)
- **Input:** `{ orgId, documentId?, caseId?, limit?, offset? }`
- **Process:**
  - Validate auth + org membership
  - Check entitlement (`contract.analyze` permission)
  - Filter by documentId or caseId (if provided)
  - Apply case access filtering for PRIVATE cases
  - Return paginated list
- **Output:** `{ analyses: [...], total, hasMore }`

### 3.2 AI Service Extension

**Add to `functions/src/services/ai-service.ts`:**

```typescript
export interface ContractAnalysisResult {
  summary: string;
  clauses: Clause[];
  risks: Risk[];
}

/**
 * Analyze contract document for clauses and risks
 */
export async function analyzeContract(
  documentText: string,
  documentName: string,
  options?: {
    model?: 'gpt-4o-mini' | 'gpt-4o';
    jurisdiction?: {
      country?: string;
      state?: string;
      region?: string;
    };
  }
): Promise<{
  result: ContractAnalysisResult;
  tokensUsed: number;
  model: string;
  processingTimeMs: number;
}> {
  const startTime = Date.now();
  const model = options?.model || 'gpt-4o-mini';
  
  const client = getOpenAIClient();
  
  // Build contract analysis system prompt
  const systemPrompt = buildContractAnalysisPrompt({
    jurisdiction: options?.jurisdiction,
  });
  
  // Build user prompt with document text
  const userPrompt = buildContractAnalysisUserPrompt(documentText, documentName);
  
  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ];
  
  try {
    const response = await client.chat.completions.create({
      model,
      messages,
      max_tokens: 4096,
      temperature: 0.2, // Lower temperature for more structured output
      response_format: { type: 'json_object' }, // Force JSON output
    });
    
    const content = response.choices[0]?.message?.content || '{}';
    const tokensUsed = response.usage?.total_tokens || 0;
    const processingTimeMs = Date.now() - startTime;
    
    // Parse JSON response
    const parsed = JSON.parse(content) as {
      summary: string;
      clauses: Clause[];
      risks: Risk[];
    };
    
    // Validate and normalize structure
    const result: ContractAnalysisResult = {
      summary: parsed.summary || 'No summary available.',
      clauses: Array.isArray(parsed.clauses) ? parsed.clauses : [],
      risks: Array.isArray(parsed.risks) ? parsed.risks : [],
    };
    
    return {
      result,
      tokensUsed,
      model,
      processingTimeMs,
    };
  } catch (error) {
    functions.logger.error('Contract analysis error:', error);
    throw new Error('Failed to analyze contract. Please try again.');
  }
}

function buildContractAnalysisPrompt(options?: {
  jurisdiction?: {
    country?: string;
    state?: string;
    region?: string;
  };
}): string {
  let prompt = `You are an expert legal AI assistant specializing in contract analysis. Your task is to analyze contracts and provide structured insights.

YOUR TASK:
1. Identify and extract key contract clauses
2. Flag potential risks and issues
3. Provide a high-level summary

OUTPUT FORMAT (JSON):
{
  "summary": "Brief overview of the contract (2-3 sentences)",
  "clauses": [
    {
      "id": "clause-1",
      "type": "termination|payment|liability|confidentiality|indemnification|warranty|intellectual_property|governing_law|dispute_resolution|other",
      "title": "Short clause title",
      "content": "Relevant text excerpt (100-300 characters)",
      "pageNumber": 1,
      "startChar": 100,
      "endChar": 400
    }
  ],
  "risks": [
    {
      "id": "risk-1",
      "severity": "high|medium|low",
      "category": "liability|termination|payment|confidentiality|indemnification|other",
      "title": "Short risk description",
      "description": "Detailed explanation of the risk",
      "clauseIds": ["clause-1"],
      "recommendation": "Suggested action or consideration"
    }
  ]
}

CLAUSE TYPES:
- termination: Termination, cancellation, renewal terms
- payment: Payment terms, pricing, fees, penalties
- liability: Liability limitations, disclaimers, damages caps
- confidentiality: NDA, confidentiality, non-disclosure terms
- indemnification: Indemnification, hold harmless clauses
- warranty: Warranties, representations, guarantees
- intellectual_property: IP ownership, licensing, rights
- governing_law: Choice of law, jurisdiction, venue
- dispute_resolution: Arbitration, mediation, litigation terms
- other: Other important clauses

RISK SEVERITY:
- high: Critical issues that could cause significant harm or liability
- medium: Important concerns that should be addressed
- low: Minor issues or areas to monitor

RISK CATEGORIES:
- liability: Excessive liability, uncapped damages, broad disclaimers
- termination: Unfavorable termination terms, auto-renewal traps
- payment: Unclear payment terms, penalties, late fees
- confidentiality: Overly broad confidentiality, data security concerns
- indemnification: One-sided indemnification, broad hold harmless
- other: Other risk categories`;

  if (options?.jurisdiction) {
    const { country, state, region } = options.jurisdiction;
    const jurisdictionParts: string[] = [];
    if (state) jurisdictionParts.push(state);
    if (region) jurisdictionParts.push(region);
    if (country) jurisdictionParts.push(country);
    
    if (jurisdictionParts.length > 0) {
      const jurisdictionStr = jurisdictionParts.join(', ');
      prompt += `\n\nJURISDICTION CONTEXT:
Analyze this contract within the jurisdiction of: ${jurisdictionStr}
- Consider jurisdiction-specific legal requirements
- Flag clauses that may be unenforceable in this jurisdiction
- Note any conflicts with local law`;
    }
  }
  
  return prompt;
}

function buildContractAnalysisUserPrompt(documentText: string, documentName: string): string {
  // Truncate document if too long (same limit as chat context)
  const MAX_DOC_CHARS = 50000;
  const truncatedText = documentText.length > MAX_DOC_CHARS
    ? documentText.substring(0, MAX_DOC_CHARS) + '\n...[document truncated]'
    : documentText;
  
  return `Analyze the following contract document: "${documentName}"

CONTRACT TEXT:
${truncatedText}

Provide a structured analysis with:
1. A brief summary (2-3 sentences)
2. Key clauses identified and categorized
3. Potential risks flagged with severity levels

Return your analysis as a JSON object matching the specified format.`;
}
```

### 3.3 Key Files
- `functions/src/functions/contract-analysis.ts` (new)
- `functions/src/services/ai-service.ts` (extend with contract analysis)
- `functions/src/constants/permissions.ts` (add `contract.analyze`)
- `functions/src/constants/entitlements.ts` (add `CONTRACT_ANALYSIS` feature)
- `functions/src/index.ts` (export new functions)
- `functions/src/__tests__/slice13-terminal-test.ts` (new)

### 3.4 Backend Endpoints (Slice 4 style)

#### 3.4.1 `contractAnalyze` (Callable Function)

**Function Name (Export):** `contractAnalyze`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `contract.analyze` | **Plan Gating:** `CONTRACT_ANALYSIS`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "documentId": "string (required)",
  "options": { "model": "string (optional, 'gpt-4o-mini' | 'gpt-4o')" }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "analysisId": "string",
    "documentId": "string",
    "caseId": "string | null",
    "status": "completed",
    "error": null,
    "summary": "string",
    "clauses": "[ { id, type, title, content, pageNumber?, ... } ]",
    "risks": "[ { id, severity, category, title, description, clauseIds?, recommendation? } ]",
    "createdAt": "ISO 8601",
    "completedAt": "ISO 8601",
    "createdBy": "string",
    "model": "string",
    "tokensUsed": "number | null",
    "processingTimeMs": "number | null"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or documentId
- `NOT_AUTHORIZED` (403): Not org member or role/plan does not allow
- `NOT_FOUND` (404): Document not found or soft-deleted
- `VALIDATION_ERROR` (400): Document has no extracted text or extractionStatus !== 'completed'
- `NOT_AUTHORIZED` (403): No case access for document's caseId
- `INTERNAL_ERROR` (500): AI or Firestore failure

**Implementation Flow:**
1. Validate auth; validate orgId, documentId
2. Check entitlement: CONTRACT_ANALYSIS + `contract.analyze`
3. Fetch document; verify exists, not deleted, has extractedText and extractionStatus === 'completed'
4. If document.caseId: canUserAccessCase(orgId, caseId, uid) must allow
5. Create analysis record (status processing); audit event contract.analyzed
6. Call analyzeContract(extractedText, name, options); update record with summary, clauses, risks, completedAt; audit contract.analysis_completed
7. Return successResponse (same shape as contractAnalysisGet)
8. On error: update record status failed; audit contract.analysis_failed; return errorResponse

---

#### 3.4.2 `contractAnalysisGet` (Callable Function)

**Request Payload:** `{ "orgId": "string (required)", "analysisId": "string (required)" }`  
**Success Response (200):** Full analysis document (analysisId, documentId, caseId, status, error, summary, clauses, risks, createdAt, completedAt, createdBy, model, tokensUsed, processingTimeMs)  
**Error Responses:** VALIDATION_ERROR (missing fields), NOT_AUTHORIZED (org/role or case access), NOT_FOUND (analysis not found)  
**Implementation Flow:** 1. Validate auth, orgId, analysisId 2. Check entitlement contract.analyze 3. Fetch analysis; if caseId present verify canUserAccessCase 4. Return successResponse with full document

---

#### 3.4.3 `contractAnalysisList` (Callable Function)

**Request Payload:** `{ "orgId": "string (required)", "documentId": "string (optional)", "caseId": "string (optional)", "limit": "number (optional, default 20, max 100)", "offset": "number (optional, default 0)" }`  
**Success Response (200):** `{ "success": true, "data": { "analyses": [ { analysisId, documentId, caseId, status, error, summary, clausesCount, risksCount, createdAt, completedAt, createdBy, model } ], "total": number, "hasMore": boolean } }`  
**Error Responses:** VALIDATION_ERROR, NOT_AUTHORIZED (org/role or case access for caseId filter)  
**Implementation Flow:** 1. Validate auth, orgId; parse limit/offset 2. Check entitlement contract.analyze 3. If caseId: canUserAccessCase must allow 4. Build query contract_analyses (where documentId/caseId if provided), orderBy createdAt desc, limit(+1), offset 5. Filter results by case access for each analysis with caseId 6. Return analyses, total, hasMore. **Requires Firestore composite indexes:** documentId+createdAt, caseId+createdAt.

---

## 4) Frontend (Flutter)

### 4.1 UI Entry Point
- **Document Details Screen** → "Analyze Contract" button (similar to "Extract Text")
- Show analysis results in expandable sections (Summary, Clauses, Risks)

### 4.2 Features Implemented
- **Analyze Button:** Trigger analysis for documents with extracted text
- **Loading State:** Show progress during analysis
- **Results Display:**
  - Summary section (always visible)
  - Clauses list (grouped by type, expandable)
  - Risks list (grouped by severity, color-coded)
  - Clause → Risk linking (show related risks for each clause)
- **Error Handling:** Display errors if analysis fails
- **Re-analyze:** Allow re-running analysis (creates new analysis record)

### 4.3 Key Files
- `legal_ai_app/lib/core/models/contract_analysis_model.dart` (new)
- `legal_ai_app/lib/core/services/contract_analysis_service.dart` (new)
- `legal_ai_app/lib/features/contract_analysis/providers/contract_analysis_provider.dart` (new)
- `legal_ai_app/lib/features/contract_analysis/widgets/contract_analysis_widget.dart` (new)
- `legal_ai_app/lib/features/documents/screens/document_details_screen.dart` (extend)
- `legal_ai_app/lib/core/routing/route_names.dart` (if needed)
- `legal_ai_app/lib/app.dart` (register provider)

---

## 5) Security & Access Control

### 5.1 Permissions
- **`contract.analyze`** – Required to analyze contracts
  - ADMIN: ✅
  - LAWYER: ✅
  - PARALEGAL: ✅
  - VIEWER: ❌

### 5.2 Feature Flag
- **`CONTRACT_ANALYSIS`** – Feature availability by plan
  - FREE: ❌ (MVP: enable for testing)
  - BASIC: ✅
  - PRO: ✅
  - ENTERPRISE: ✅

### 5.3 Case Access
- Analysis results inherit document's case access
- PRIVATE case documents: analysis only visible to users with case access
- Enforced via `canUserAccessCase()` helper

### 5.4 Audit Logging
- `contract.analyzed` – When analysis is triggered
- `contract.analysis_completed` – When analysis completes
- `contract.analysis_failed` – When analysis fails

---

## 6) Testing

### 6.1 Backend Terminal Test (requires deployed functions)
```bash
cd functions
$env:FIREBASE_API_KEY="AIza...."
npm run test:slice13
```

### 6.2 Test Cases
- ✅ Analyze contract with extracted text
- ✅ Error handling for document without extracted text
- ✅ Error handling for unauthorized access
- ✅ Error handling for AI service failures
- ✅ Case access enforcement (PRIVATE cases)
- ✅ Re-analysis creates new record
- ✅ List analyses by document/case

### 6.3 Manual Testing Checklist

**Backend**
- [x] `contractAnalyze` with extracted text returns analysisId, summary, clauses, risks
- [x] Document without extracted text returns validation error
- [x] Unauthorized access (no org, wrong role) returns NOT_AUTHORIZED
- [x] Case access enforced for PRIVATE case documents
- [x] `contractAnalysisList` returns empty list when no analyses; requires Firestore indexes
- [x] `contractAnalysisGet` with invalid id returns NOT_FOUND

**Frontend**
- [x] Document Details shows Contract Analysis section when extraction is complete
- [x] Analyze Contract → loading → summary, clauses, risks displayed
- [x] Re-analyze creates new analysis; latest shown
- [x] Error states: no extracted text (SnackBar), AI failure (SnackBar)

---

## 7) Deployment Notes

- Cloud Functions: `firebase deploy --only functions`
- Firestore indexes: May need composite index for `contractAnalysisList` queries
- Firestore rules: Add rules for `organizations/{orgId}/contract_analyses/{analysisId}`

---

## 8) Future Enhancements (Out of Scope)

- **Batch Analysis:** Analyze multiple contracts at once
- **Comparison:** Compare two contracts side-by-side
- **Templates:** Contract templates with clause libraries
- **Export:** Export analysis to PDF/DOCX
- **Annotations:** Highlight clauses directly in document viewer
- **Version Tracking:** Track analysis across document versions
- **Custom Risk Rules:** User-defined risk detection rules

---

## 9) Success Criteria

- ✅ Backend function analyzes contracts and returns structured results
- ✅ Frontend displays analysis results with clauses and risks
- ✅ Case access enforced for PRIVATE cases
- ✅ Error handling for all failure scenarios
- ✅ Audit logging for analysis operations
- ✅ Tests passing (backend + manual frontend)

**Overall:** ✅ **COMPLETE** (when all criteria met)

---

**Created:** 2026-01-29  
**Last Updated:** 2026-01-29
