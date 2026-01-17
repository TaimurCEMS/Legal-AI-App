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
│   └── SLICE_0_BUILD_CARD.md  # Slice 0 build card
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

### Reports
- **[Cleanup Report](docs/reports/CLEANUP_REPORT.md)** - Slice 0 cleanup and hardening
- **[Test Results](docs/reports/TEST_SLICE_0.md)** - Testing guide and results

### Implementation Details
- **[Slice 0 Complete](docs/slices/SLICE_0_COMPLETE.md)** - Slice 0 implementation summary
- **[Slice 0 Implementation](docs/slices/SLICE_0_IMPLEMENTATION.md)** - Detailed implementation notes

## 🧪 Testing

### Run Slice 0 Tests
```bash
cd functions
npm run test:slice0
```

Test results are saved to `functions/lib/__tests__/slice0-test-results.json`

## 🔧 Development Scripts

### Git Operations
- `scripts/dev/setup-git.bat` - Initialize git and connect to GitHub
- `scripts/dev/push-to-github.bat` - Push changes to GitHub
- `scripts/dev/verify-push.bat` - Verify git push status

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

### Next: Slice 1
- Flutter UI Shell
- Firebase Auth integration
- Organization selection/gate

## 🔐 Security

- All writes go through Cloud Functions
- Firestore security rules enforce org-scoped access
- Role-based permissions (ADMIN, LAWYER, PARALEGAL, VIEWER)
- Plan-based feature gating (FREE, BASIC, PRO, ENTERPRISE)

## 📝 License

Proprietary - All rights reserved

---

**Last Updated:** 2026-01-17  
**Project:** legal-ai-app-1203e  
**Region:** us-central1
