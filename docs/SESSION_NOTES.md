# Legal AI App - Session Notes

**Last Updated:** 2026-01-30

This document captures the current development state, recent decisions, and next steps. Reference this file at the start of new chat sessions to provide context.

---

## Current State

### Completed Slices
| Slice | Status | Description |
|-------|--------|-------------|
| 0 | ✅ Complete | Project Setup, Firebase, Auth |
| 1 | ✅ Complete | Organization & Member Management |
| 2 | ✅ Complete | Case Hub (CRUD, visibility) |
| 2.5 | ✅ Complete | Member Management Enhancements |
| 3 | ✅ Complete | Client Management |
| 4 | ✅ Complete | Document Management |
| 5 | ✅ Complete | Task Management |
| 5.5 | ✅ Complete | Case Participants (PRIVATE case access control) |
| 6a | ✅ Complete | Document Extraction (AI-powered) |
| 6b | ✅ Complete | AI Chat/Research with jurisdiction-aware legal opinions |
| 7 | ✅ Complete | Calendar & Court Dates (events, views, visibility) |
| 8 | ✅ Complete | Notes/Memos on Cases (case-linked notes + private-to-me toggle) |
| 9 | ✅ Complete | AI Document Drafting (templates, drafts, AI generate, export to Documents) |
| 10 | ✅ Complete | Time Tracking (timer + manual entries + filters + permissions) |
| 11 | ✅ Complete | Billing & Invoicing (MVP) |
| 12 | ✅ Complete | Audit Trail UI (ADMIN-only compliance visibility) |
| 13 | ✅ Complete | AI Contract Analysis (clause identification, risk flagging) |
| 14 | ✅ Complete | AI Document Summarization (one-click document summaries) |

### Git Status
- **Branch:** main
- **Last commit:** feat: Implement Slice 14 - AI Document Summarization
- **Deployments:** ✅ **67 Cloud Functions deployed** to `legal-ai-app-1203e` (us-central1). Slice 14 functions (summarizeDocument, documentSummaryGet, documentSummaryList) and all prior slices confirmed live. Firestore indexes for document_summaries and contract_analyses deployed and built.

---

## Recent Session (2026-01-27)

### Work Completed

**Slice 8 - Notes/Memos on Cases**
- Backend: `noteCreate`, `noteGet`, `noteList`, `noteUpdate`, `noteDelete`
- Frontend: Notes list/details/form screens + provider/service/model
- Key features:
  - Notes linked to cases, with categories + pinning
  - Notes inherit case visibility via `canUserAccessCase`
  - **Private-to-me toggle** (`isPrivate`) hides a note from other users even with case access
  - Org-wide notes list (filters by case access per note; cached per request)
  - Case Details integration (notes visible in case context)
  - **Edit note includes case selector** (move note to another case; backend validates access to target case)

**Stability fixes (notes):**
- Notes load reliably after sign-in/refresh (wait for org readiness before loading)
- Notes state cleared on sign-out (prevents cross-session state leakage)

---

## Recent Session (2026-01-28)

### Work Completed

**Slice 9 - AI Document Drafting (MVP)**
- Drafting flow implemented end-to-end with exports to Document Hub (DOCX/PDF).
- Case access enforced server-side; Firestore rules include case-access defense-in-depth for drafts/templates.

**Slice 10 - Time Tracking (MVP + polish)**
- UI/UX:
  - Billable defaults to ON and persists as a user preference.
  - Date range filters have clear active highlighting.
  - “All cases” filter fixed (explicit sentinel value instead of null/hint state).
  - “Mine” filter is an explicit on/off toggle (mine-only vs team/overall view).
  - Admin: optional user filter (All users vs specific user) when member list is available.
- Backend:
  - `timeEntryUpdate` allows clearing description to empty string (prevents VALIDATION_ERROR on edit).
  - `timeEntryList` hardened:
    - Only ADMIN can filter by another `userId`
    - VIEWER restricted to mine-only (defense-in-depth)
    - In team view, “no-case” entries are only visible to admin/owner

**Slice 11 - Billing & Invoicing (MVP complete)**
- Backend (Cloud Functions):
  - `invoiceCreate`, `invoiceList`, `invoiceGet`, `invoiceUpdate`, `invoiceRecordPayment`, `invoiceExport`
  - Invoice generation from unbilled billable time entries (case-scoped) + payment tracking
  - Export to PDF saved into Document Hub (server-side export pattern)
  - Invoice PDF Storage path now stored under a dedicated prefix (grouped by case):
    - `organizations/{orgId}/documents/invoices/{CaseName}__{caseId}/{documentId}/{filename}`
  - Exported Document metadata includes:
    - `category: "invoice"`
    - `folderPath: "Invoices/<Case Name>"` (for future UI foldering)
  - Added `BILLING_INVOICING` feature flag and Firestore rules/indexes for invoices
- Frontend (Flutter):
  - New **Billing** tab (ADMIN-only UI) with invoice list, create invoice flow, invoice details, record payment, export PDF
  - Converted Slice 10 time dropdowns to `initialValue` (fix deprecated FormField `value`) and improved member loading in team view
- Tests:
  - Added `functions/src/__tests__/slice11-terminal-test.ts` + `npm run test:slice11`
  - Added `functions/src/__tests__/task-terminal-test.ts` + task access hardening test coverage

**Slice 12 - Audit Trail UI (COMPLETE)**
- Backend:
  - New callables: `auditList`, `auditExport` (lists/exports audit events with filtering)
  - Audit visibility is **ADMIN-only** via `audit.view` permission
  - PRIVATE-case audit events are filtered via `canUserAccessCase` (no existence leakage)
  - Audit events persist optional top-level `caseId` when available (for scoping/filtering)
- Frontend (Flutter):
  - New Settings entry: **Audit Trail** (ADMIN-only UI)
  - Screen supports search + entity type filter + pagination + event detail dialog
- Tests:
  - Added `functions/src/__tests__/slice12-terminal-test.ts` + `npm run test:slice12` (requires deployed functions)
- **Deployed:** 2026-01-28

**Documents UI note (2026-01-28):**
- A folder-tree UI was attempted for Documents, but deferred after UX issues (e.g. confusing “undefined” grouping).
- Documents page remains a flat list for now; folder metadata is retained for a future, cleaner folder UX.

### Deployments
- ✅ Cloud Functions deployed to `legal-ai-app-1203e` (`us-central1`) on 2026-01-28.
- Non-blocking Firebase CLI warning: `firebase-functions` SDK is outdated (upgrade in maintenance/polish pass).

---

## Recent Session (2026-01-29)

### Work Completed

**Slice 12 - Audit Trail UI (Enhancements + Deploy)**
- Backend enhancements:
  - Added `auditExport` callable function (returns CSV with same filters as `auditList`)
  - Both functions support `actorUid` filter for per-user audit queries
- Frontend enhancements:
  - **Date range filter** – From/To date pickers (passed as `fromAt`/`toAt`)
  - **User filter** – Dropdown populated from org members to filter by actor
  - **Export CSV** – App bar download button exports filtered events to clipboard
  - **Human-readable labels** – `actionDisplayLabel` and `entityTypeDisplayLabel` for cleaner UX
  - **Collapsible metadata** – Technical details hidden by default, expandable "Technical Details" section
- Cloud Functions deployed: 2026-01-29 (59 functions total, including `auditExport`)

### Deployments
- ✅ Cloud Functions deployed to `legal-ai-app-1203e` (`us-central1`) on 2026-01-29.
- All 59 functions deployed successfully (some hit quota throttling but auto-retried).

---

## Recent Session (2026-01-29 – Slice 13 Complete)

### Work Completed

**Slice 13 - AI Contract Analysis (COMPLETE)**
- Backend (Cloud Functions):
  - `contractAnalyze` – Triggers OpenAI analysis on extracted document text; returns full analysis shape (analysisId, documentId, caseId, createdBy, model, summary, clauses, risks).
  - `contractAnalysisGet` – Get analysis by analysisId.
  - `contractAnalysisList` – List analyses by documentId or caseId, pagination, orderBy createdAt desc.
  - AI service: contract analysis prompts (handles contract vs non-contract docs), structured JSON output.
  - Entitlements: CONTRACT_ANALYSIS feature, `contract.analyze` permission (ADMIN, LAWYER, PARALEGAL).
- Frontend (Flutter):
  - Document Details: Contract Analysis section with Analyze button, summary, expandable clauses by type, risks by severity (color-coded).
  - ContractAnalysisModel, Clause, Risk (null-safe fromJson); ContractAnalysisService; ContractAnalysisProvider.
  - UI messages for non-contract documents (“No contract clauses identified”) and when no risks found.
- Fixes applied:
  - Backend contractAnalyze response shape aligned with get (documentId, caseId, createdBy, model at top level).
  - Frontend fromJson and list parsing made null-safe (no TypeError on null fields).
  - Firestore composite indexes added for contract_analyses (documentId+createdAt, caseId+createdAt); deployed via `firebase deploy --only firestore:indexes`.
- Tests: `npm run test:slice13` (backend), contract_analysis_model_test.dart (8 tests); slice13-full-integration-test requires service account.

### Deployments
- ✅ Cloud Functions deployed (contractAnalyze, contractAnalysisGet, contractAnalysisList).
- ✅ Firestore indexes deployed and built for contract_analyses.

---

## Recent Session (2026-01-29 – Slice 14 Complete)

### Work Completed

**Slice 14 - AI Document Summarization (COMPLETE)**
- Backend (Cloud Functions):
  - `summarizeDocument` – Generate summary from extracted text; store in document_summaries; return full summary object.
  - `documentSummaryGet` – Get summary by summaryId.
  - `documentSummaryList` – List by documentId or caseId, pagination, orderBy createdAt desc.
  - AI service: `summarizeDocument()` in ai-service.ts (plain-language summary ~300 words).
  - Entitlements: DOCUMENT_SUMMARY feature, `document.summarize` permission (ADMIN, LAWYER, PARALEGAL).
- Frontend (Flutter):
  - Document Details: Document Summary section with Summarize button, loading state, summary text, re-summarize.
  - DocumentSummaryModel, DocumentSummaryService, DocumentSummaryProvider.
- Firestore: document_summaries collection; composite indexes (documentId+createdAt, caseId+createdAt); rules for org member + case access.
- Tests: `npm run test:slice14` (documentSummaryList empty, documentSummaryGet NOT_FOUND).

### Deployments
- ✅ **Deployment confirmed:** All 67 Cloud Functions deployed (verified via `firebase functions:list`). Slice 14 (summarizeDocument, documentSummaryGet, documentSummaryList) and Slice 13 (contractAnalyze, contractAnalysisGet, contractAnalysisList) are live. Firestore indexes for document_summaries and contract_analyses deployed and built.

---

## Recent Session (2026-01-30)

### Work Completed

**UI Stability & Loading Reliability (Tabbed Lists + Matter Details)**
- Made tabbed list screens load **only when visible** (no background overfetch).
- Added visibility-aware loading for standalone routes (`/tasks`, `/documents`, `/clients`, `/calendar`).
- Removed redundant org change listeners that caused constant reloads and perceived slowness.
- Fixed matter detail sections (Docs/Tasks/Notes/AI) to load reliably by passing `org` from `_loadProgressively` instead of waiting with arbitrary timeouts.
- Cleaned up unused provider references to avoid compile warnings.

### Deployments
- No Cloud Functions or Firestore deployments required (Flutter/UI-only changes).

---

## Next Steps

### Post-Slice 11 follow-ups (deferred)
- Invoice numbering (org-global + per-case) using transactional counters
- Document Hub folder UX (use `folderPath/category`, with backfill for existing docs)
- Flutter analyzer cleanup (warnings/infos) and incremental UI polish

### Future Priorities
| Slice | Priority | Description |
|-------|----------|-------------|
| 14 | ✅ Done | AI Document Summarization (one-click document summaries) |
| 15 | 🟡 RECOMMENDED | AI Document Q&A or Advanced Admin (invitations, bulk ops) |

### UI Polish Items (Deferred)
- Calendar UI refinements
- Month view event display improvements
- Week view time slot interactions

### Slice 9/10 Polish Backlog (Deferred)
- Standardize “All …” filters everywhere (avoid null/hint state; use explicit sentinel values).

---

## Key Architecture Decisions

1. **Firestore Structure:** `organizations/{orgId}/cases/{caseId}/...`
2. **Case Visibility:** PRIVATE (explicit participants) vs ORG_WIDE (all members)
3. **Event Visibility:** ORG, CASE_ONLY, PRIVATE (enforced at backend)
4. **AI Integration:** OpenAI GPT-4 via Cloud Functions
5. **Jurisdiction Model:** Country + optional state/region, persisted per chat thread
6. **Entitlements:** Feature flags checked via `checkEntitlement()` helper
7. **Notes Visibility:** Notes inherit case access; optional `isPrivate` override hides note from other users

---

## Development Patterns

- **Backend:** Firebase Cloud Functions (TypeScript), callable functions return `successResponse`/`errorResponse`
- **Frontend:** Flutter with Provider pattern, GoRouter for navigation
- **Naming:** `{entity}{Action}` (e.g., `caseCreate`, `eventList`)
- **Timestamps:** Firestore Timestamps converted to ISO strings in responses
- **Visibility Enforcement:** Always at backend, frontend is convenience only

---

## Extensibility Notes

**Saved Filter Views (Future Enhancement):**
- Easy to add with current architecture
- New collection: `orgs/{orgId}/savedViews/{viewId}`
- Store filter parameters (caseId, status, dateRange, etc.)
- ~1-2 hours implementation

---

## How to Use This Document

1. **At start of new chat:** Share this file or reference `@docs/SESSION_NOTES.md`
2. **After significant work:** Update the "Recent Session" and "Current State" sections
3. **When starting new slice:** Add to "Next Steps" with technical scope

---

*This document should be updated after each development session.*
