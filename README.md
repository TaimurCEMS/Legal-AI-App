# Legal AI App

Legal practice management application with AI-powered research and document drafting capabilities.

## 📁 Repository Structure

```
Legal AI App/
├── docs/                    # Documentation
│   ├── status/             # Slice status and progress
│   ├── reports/            # Test results, cleanup reports
│   ├── slices/             # Slice implementation details
│   ├── MASTER_SPEC V1.4.0.md  # Master specification (source of truth)
│   ├── FEATURE_ROADMAP.md    # Comprehensive roadmap
│   ├── ARCHITECTURE_SCALABILITY_ASSESSMENT.md  # Architecture review
│   ├── DEVELOPMENT_LEARNINGS.md  # Key learnings and best practices
│   └── SLICE_*_BUILD_CARD.md  # Slice build cards
├── scripts/                 # Utility scripts
│   ├── dev/                # Development scripts (git, commits)
│   └── ops/                # Operations scripts (deployment, checks)
├── functions/               # Firebase Cloud Functions (TypeScript)
│   ├── src/                # Source code
│   │   ├── functions/     # Cloud Functions (case, client, document, task, ai-chat)
│   │   ├── services/      # Service layer (ai-service, extraction-service)
│   │   ├── constants/     # Constants (entitlements, errors, permissions)
│   │   └── utils/         # Utilities (audit, case-access)
│   └── lib/                # Compiled JavaScript
├── legal_ai_app/            # Flutter app (Dart)
│   └── lib/                # Source code
│       ├── core/          # Core models and services
│       └── features/      # Feature modules (cases, clients, documents, tasks, ai_chat)
├── firebase.json            # Firebase configuration
├── firestore.rules          # Firestore security rules
└── firestore.indexes.json   # Firestore indexes
```

## 🚀 Quick Start

### Prerequisites
- Node.js 22+
- Firebase CLI
- Firebase project: `legal-ai-app-1203e`

### Setup
```bash
# Install dependencies
cd functions
npm install

# Build
npm run build

# Deploy
firebase deploy --only functions
```

## 📚 Documentation

### Documentation Index
- **[Documentation Index](docs/DOCUMENTATION_INDEX.md)** – Single entry point to all docs (handoff, specs, build cards, status, reports)

### Master Specification
- **[Master Spec](docs/MASTER_SPEC%20V1.4.0.md)** - Complete project specification (source of truth)
  - Includes repository structure guidelines (Section 2.7)

### Strategic Documents
- **[Feature Roadmap](docs/FEATURE_ROADMAP.md)** - Comprehensive roadmap and competitive analysis
- **[Architecture Assessment](docs/ARCHITECTURE_SCALABILITY_ASSESSMENT.md)** - Scalability and architecture review

### Slice Status
- **[Slice Status](docs/status/SLICE_STATUS.md)** - Current slice progress and deployment status

### Build Cards
- **[Slice 0 Build Card](docs/SLICE_0_BUILD_CARD.md)** - Slice 0 implementation details
- **[Slice 1 Build Card](docs/SLICE_1_BUILD_CARD.md)** - Slice 1 implementation details
- **[Slice 2 Build Card](docs/SLICE_2_BUILD_CARD.md)** - Slice 2 implementation details
- **[Slice 3 Build Card](docs/SLICE_3_BUILD_CARD.md)** - Slice 3 implementation details
- **[Slice 4–14 Build Cards](docs/)** - SLICE_4_BUILD_CARD.md through SLICE_14_BUILD_CARD.md

### Reports
- **[Cleanup Report](docs/reports/CLEANUP_REPORT.md)** - Slice 0 cleanup and hardening
- **[Test Results](docs/reports/TEST_SLICE_0.md)** - Testing guide and results
- **[Slice 2 Completion Report](docs/reports/SLICE_2_COMPLETION_REPORT.md)** - Slice 2 completion summary
- **[Slice 3 Completion Report](docs/reports/SLICE_3_COMPLETION_REPORT.md)** - Slice 3 completion summary

### Implementation Details
- **[Slice 0 Complete](docs/slices/SLICE_0_COMPLETE.md)** - Slice 0 implementation summary
- **[Slice 0 Implementation](docs/slices/SLICE_0_IMPLEMENTATION.md)** - Detailed implementation notes
- **[Slice 1 Complete](docs/slices/SLICE_1_COMPLETE.md)** - Slice 1 implementation summary
- **[Slice 2 Complete](docs/slices/SLICE_2_COMPLETE.md)** - Slice 2 implementation summary
- **[Slice 3 Complete](docs/slices/SLICE_3_COMPLETE.md)** - Slice 3 implementation summary

### Development Learnings
- **[Development Learnings](docs/DEVELOPMENT_LEARNINGS.md)** - Key learnings, insights, and solutions discovered during development
  - Firebase & Cloud Functions learnings
  - Flutter development insights
  - Common pitfalls and solutions
  - Best practices

## 🧪 Testing

### Run Slice 0 Tests
```bash
cd functions
npm run test:slice0
```

Test results are saved to `functions/lib/__tests__/slice0-test-results.json`

## 🔧 Development Scripts

### Git Operations & Sync
- `sync-to-github.bat` - **Full sync** (pull, commit, push) with prompts
- `quick-sync.bat` - **Quick sync** (minimal prompts, fast)
- `check-sync-status.bat` - **Check status** (no changes, just shows info)
- `scripts/dev/push-to-github.bat` - Push changes to GitHub
- `scripts/dev/verify-push.bat` - Verify git push status

**📖 See [Sync Workflow Guide](scripts/dev/sync-workflow.md) for detailed sync strategies**

### Operations
- `scripts/ops/check-deployed-functions.bat` - Check deployed Firebase functions
- `scripts/ops/delete-legacy-api.bat` - Delete legacy functions

## 📦 Current Status

### Slice 0: Foundation ✅ LOCKED
- **Status:** Complete & Deployed
- **Functions:**
  - `orgCreate` - Create organization
  - `orgJoin` - Join organization
  - `memberGetMyMembership` - Get membership info
- **Tests:** ✅ All passing (3/3)

See [Slice Status](docs/status/SLICE_STATUS.md) for details.

### Slice 1: Navigation Shell + UI System ✅ COMPLETE
- **Status:** Complete & Tested
- **Features:**
  - Flutter UI Shell with navigation
  - Firebase Auth integration
  - Organization management
  - Theme system & reusable widgets
- **Tests:** ✅ All passing

### Slice 2: Case Hub ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ All 5 functions deployed
- **Frontend:** ✅ All screens implemented
- **See:** [Slice 2 Build Card](docs/SLICE_2_BUILD_CARD.md) for details

### Slice 3: Client Hub ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ All 5 functions deployed
- **Frontend:** ✅ All screens implemented
- **Features:** Client management, search, client-case linking
- **See:** [Slice 3 Build Card](docs/SLICE_3_BUILD_CARD.md) for details

### Slice 4: Document Hub ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ All 5 functions deployed
- **Frontend:** ✅ All screens implemented
- **Features:** Document upload, metadata, case linking
- **See:** [Slice 4 Build Card](docs/SLICE_4_BUILD_CARD.md) for details

### Slice 5: Task Hub ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ All 5 functions deployed
- **Frontend:** ✅ All screens implemented
- **Features:** Task management, assignments, case linking, priorities
- **See:** [Slice 5 Build Card](docs/SLICE_5_BUILD_CARD.md) for details

### Slice 5.5: Case Participants ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ 3 new functions + modifications to existing
- **Frontend:** ✅ Participant management UI, task visibility toggle
- **Features:** Private case sharing, task-level visibility control
- **See:** [Slice 5.5 Build Card](docs/SLICE_5_5_CASE_PARTICIPANTS_BUILD_CARD.md) for details

### Slice 6a: Document Text Extraction ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ 3 new functions (documentExtract, documentGetExtractionStatus, extractionProcessJob)
- **Frontend:** ✅ Extraction UI in document details
- **Features:** PDF/DOCX/TXT/RTF text extraction, job queue, status tracking
- **See:** [Slice 6a Build Card](docs/SLICE_6A_BUILD_CARD.md) for details

### Slice 6b: AI Chat/Research ✅ COMPLETE (Enhanced)
- **Status:** Complete & Deployed
- **Backend:** ✅ 5 new functions (aiChatCreate, aiChatSend, aiChatList, aiChatGetMessages, aiChatDelete)
- **Frontend:** ✅ AI chat screens, jurisdiction selector, chat history
- **Features:**
  - Document-based Q&A with citations
  - **Jurisdiction-aware legal opinions** (50+ countries/regions)
  - **Jurisdiction persistence** per thread
  - Chat history and thread management
  - Comprehensive legal AI system prompt
- **See:** [Slice 6b Build Card](docs/SLICE_6B_BUILD_CARD.md) for details

### Slice 7: Calendar & Court Dates ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ eventCreate, eventGet, eventList, eventUpdate, eventDelete
- **Frontend:** ✅ Calendar (day/week/month/agenda), event form, visibility (ORG, CASE_ONLY, PRIVATE)
- **See:** [Slice 7 Build Card](docs/SLICE_7_BUILD_CARD.md)

### Slice 8: Notes/Memos on Cases ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ noteCreate, noteGet, noteList, noteUpdate, noteDelete (private-to-me support)
- **Frontend:** ✅ Notes list/details/form, case selector, private toggle
- **See:** [Slice 8 Build Card](docs/SLICE_8_BUILD_CARD.md)

### Slice 9: AI Document Drafting ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ draftTemplateList, draftCreate, draftGenerate, draftProcessJob, draftGet, draftList, draftUpdate, draftDelete, draftExport
- **Frontend:** ✅ Templates, drafts list, draft editor, export to Document Hub
- **See:** [Slice 9 Build Card](docs/SLICE_9_BUILD_CARD.md)

### Slice 10: Time Tracking ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ timeEntryCreate, timeEntryStartTimer, timeEntryStopTimer, timeEntryUpdate, timeEntryDelete, timeEntryList
- **Frontend:** ✅ Timer, manual entries, filters (range, case, billable, mine)
- **See:** [Slice 10 Build Card](docs/SLICE_10_BUILD_CARD.md)

### Slice 11: Billing & Invoicing ✅ COMPLETE (MVP)
- **Status:** Complete & Deployed
- **Backend:** ✅ invoiceCreate, invoiceList, invoiceGet, invoiceUpdate, invoiceRecordPayment, invoiceExport
- **Frontend:** ✅ Billing tab (ADMIN-only), create invoice, record payment, export PDF
- **See:** [Slice 11 Build Card](docs/SLICE_11_BUILD_CARD.md)

### Slice 12: Audit Trail UI ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ auditList, auditExport
- **Frontend:** ✅ Settings → Audit Trail (ADMIN-only), filters, export CSV
- **See:** [Slice 12 Build Card](docs/SLICE_12_BUILD_CARD.md)

### Slice 13: AI Contract Analysis ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ contractAnalyze, contractAnalysisGet, contractAnalysisList
- **Frontend:** ✅ Document Details → Contract Analysis (summary, clauses, risks by severity)
- **See:** [Slice 13 Build Card](docs/SLICE_13_BUILD_CARD.md)

### Slice 14: AI Document Summarization ✅ COMPLETE
- **Status:** Complete & Deployed
- **Backend:** ✅ summarizeDocument, documentSummaryGet, documentSummaryList
- **Frontend:** ✅ Document Details → Document Summary (Summarize, re-summarize, summary text)
- **See:** [Slice 14 Build Card](docs/SLICE_14_BUILD_CARD.md)

## 📦 Deployment Summary

- **Cloud Functions:** 67 functions deployed to `legal-ai-app-1203e` (us-central1)
- **Firestore:** Indexes and rules deployed (contract_analyses, document_summaries, etc.)
- **Verify:** `firebase functions:list` from repo root

## 🔐 Security

- All writes go through Cloud Functions
- Firestore security rules enforce org-scoped access
- Role-based permissions (ADMIN, LAWYER, PARALEGAL, VIEWER)
- Plan-based feature gating (FREE, BASIC, PRO, ENTERPRISE)

## 📝 License

Proprietary - All rights reserved

---

**Last Updated:** 2026-01-29  
**Project:** legal-ai-app-1203e  
**Region:** us-central1  
**Deployed Functions:** 67 (Slices 0–14)
