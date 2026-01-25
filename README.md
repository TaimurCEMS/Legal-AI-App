# Legal AI App

Legal practice management application with AI-powered research and document drafting capabilities.

## 📁 Repository Structure

```
Legal AI App/
├── docs/                    # Documentation
│   ├── status/             # Slice status and progress
│   ├── reports/            # Test results, cleanup reports
│   ├── slices/             # Slice implementation details
│   ├── MASTER_SPEC V1.3.2.md  # Master specification (source of truth)
│   ├── SLICE_0_BUILD_CARD.md  # Slice 0 build card
│   ├── SLICE_1_BUILD_CARD.md  # Slice 1 build card
│   └── SLICE_2_BUILD_CARD.md  # Slice 2 build card
├── scripts/                 # Utility scripts
│   ├── dev/                # Development scripts (git, commits)
│   └── ops/                # Operations scripts (deployment, checks)
├── functions/               # Firebase Cloud Functions (TypeScript)
│   ├── src/                # Source code
│   └── lib/                # Compiled JavaScript
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

### Master Specification
- **[Master Spec](docs/MASTER_SPEC%20V1.3.2.md)** - Complete project specification (source of truth)
  - Includes repository structure guidelines (Section 2.7)

### Slice Status
- **[Slice Status](docs/status/SLICE_STATUS.md)** - Current slice progress and deployment status

### Build Cards
- **[Slice 0 Build Card](docs/SLICE_0_BUILD_CARD.md)** - Slice 0 implementation details
- **[Slice 1 Build Card](docs/SLICE_1_BUILD_CARD.md)** - Slice 1 implementation details
- **[Slice 2 Build Card](docs/SLICE_2_BUILD_CARD.md)** - Slice 2 implementation details
- **[Slice 3 Build Card](docs/SLICE_3_BUILD_CARD.md)** - Slice 3 implementation details

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

## 🔐 Security

- All writes go through Cloud Functions
- Firestore security rules enforce org-scoped access
- Role-based permissions (ADMIN, LAWYER, PARALEGAL, VIEWER)
- Plan-based feature gating (FREE, BASIC, PRO, ENTERPRISE)

## 📝 License

Proprietary - All rights reserved

---

**Last Updated:** 2026-01-24  
**Project:** legal-ai-app-1203e  
**Region:** us-central1
