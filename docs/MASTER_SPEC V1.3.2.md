# LEGAL AI APP - MASTER SPECIFICATION (SOURCE OF TRUTH)
Version: 1.3.2
Owner: Taimur (Product Owner)
Last Updated: 2026-01-17
Status: Active Master Spec (All builds must follow this document)

---

## 0) Purpose of this Document
This is the single, comprehensive Master Specification Document for the Legal AI Application.

It exists to:
- Prevent context loss across chats, tools, and team members
- Keep Cursor outputs consistent across time
- Align work across flowcharts, backend, frontend, security, and release planning
- Define the full roadmap as vertical slices from MVP-0 to production launch

This document is the top-level "constitution".
Slice Build Cards can be created later for execution detail, but this file is the authoritative reference.

---

## 1) Product Summary

### 1.1 What the app is
A world-class Legal AI Application for lawyers and legal teams to:
- Manage cases, clients, and documents
- Extract text from documents (OCR/parse)
- Run AI legal research and drafting with citations
- Store AI outputs back into the case record
- Collaborate, assign tasks, and track activity
- Upgrade plans to unlock features and capacity

### 1.2 Core design philosophy
Backend-first, legally safe, audit-friendly, scalable.

### 1.3 Target users
- Solo lawyers (Free, paid tiers)
- Small law firms (team roles and tasks)
- Larger firms (audit trail, admin controls, billing tiers)

---

## 2) Non-Negotiable Principles (World-Class Rules)

### 2.1 Development approach
- Build one vertical slice at a time
- Each slice must deliver an end-to-end working outcome: UI -> backend -> DB -> output -> saved result
- Avoid module-by-module development that causes integration chaos

### 2.2 UI rules
- UI stays thin
- No business logic in Flutter
- UI is a view layer only
- All permissions and feature gating must be enforced in backend, not only hidden in UI

### 2.3 Backend rules
- Backend is the single source of truth
- Every object is owned by an Organization
- All reads and writes must be scoped to orgId
- Auditability and traceability are first-class concerns

### 2.4 Consistency rules (Cursor must follow)
- One design system (theme, spacing, typography) for all screens
- Reusable widgets only
- Consistent folder structure (see Section 2.7 for repository structure)
- Consistent naming conventions
- Shared data models across app

### 2.5 Security rules
- Never trust the client (Flutter)
- Firestore rules must enforce access boundaries
- Cloud Functions must enforce role permissions and plan entitlements
- Storage access must be scoped to org membership and permissions

### 2.6 Legal & Compliance Requirements
Legal applications handle sensitive data. These requirements are non-negotiable.

**Data Protection:**
- All data encrypted at rest (Firestore, Storage)
- All data encrypted in transit (TLS 1.2+)
- No sensitive data in logs (sanitize PII, case numbers, client names)
- Secure key management (use Firebase/Cloud KMS, never hardcode)

**Data Retention:**
- Cases and documents: Retain per org policy (default: 7 years, configurable)
- Audit logs: Retain minimum 7 years (legal requirement)
- Soft delete: All deletions are soft (deletedAt timestamp) for recovery
- Soft-deleted data is retained for 30 days. After 30 days, admin can trigger hard delete. Data is not permanently removed until hard delete.
- Hard delete: Only after retention period + explicit admin action

**Data Deletion (Right to be Forgotten):**
- Users can request data deletion
- Admin can delete org data (requires confirmation)
- Deletion must cascade: org → cases → documents → related data
- Audit log must record who deleted what and when
- Legal hold: Cases under legal hold cannot be deleted (future feature)

**Data Export:**
- Users can export their case data (JSON/PDF)
- Export includes: cases, documents metadata, AI outputs, audit trail
- Export must be available within 30 days of request

**Jurisdiction & Data Residency:**
- Document where data is stored (region/country)
- Consider GDPR if EU users
- Consider jurisdiction-specific requirements per org location

**Legal Disclaimers:**
- AI outputs must include disclaimer: "AI-generated content. Review before use."
- Citations must be verifiable
- No legal advice claims in UI or marketing

**Compliance Notes:**
- MVP: Basic encryption and retention
- Post-MVP: GDPR compliance, legal hold, advanced export

### 2.7 Repository Structure & Organization

**Purpose:** Maintain a clean, professional repository structure that scales with the project and prevents root directory clutter.

**Root Directory Rules:**
- Only essential configuration files in root:
  - `README.md` - Project overview and navigation
  - `firebase.json` - Firebase configuration
  - `firestore.rules` - Firestore security rules
  - `firestore.indexes.json` - Firestore indexes
  - `.gitignore` - Git ignore rules
  - `.firebaserc` - Firebase project configuration (if present)
- **NO** documentation files in root
- **NO** script files in root
- **NO** test files in root
- **NO** temporary or report files in root

**Required Folder Structure:**
```
Legal AI App/
├── docs/                          # All documentation
│   ├── status/                   # Slice status and progress tracking
│   ├── reports/                  # Test results, cleanup reports, validation
│   ├── slices/                   # Slice implementation details
│   ├── MASTER_SPEC V1.3.2.md    # Master specification (this file)
│   └── SLICE_*_BUILD_CARD.md     # Build cards for each slice
├── scripts/                       # Utility scripts
│   ├── dev/                     # Development scripts (git, commits, tests)
│   └── ops/                     # Operations scripts (deployment, checks)
├── functions/                     # Firebase Cloud Functions
│   ├── src/                     # TypeScript source code
│   ├── lib/                     # Compiled JavaScript (gitignored)
│   └── [config files]           # package.json, tsconfig.json, etc.
├── [flutter_app]/                # Flutter application (future)
├── firebase.json                  # Firebase config (root only)
├── firestore.rules                # Security rules (root only)
├── firestore.indexes.json         # Indexes (root only)
└── README.md                      # Project README (root only)
```

**File Organization Rules:**

1. **Documentation Files:**
   - Status/progress docs → `docs/status/`
   - Test results, reports, validation → `docs/reports/`
   - Slice implementation details → `docs/slices/`
   - Build cards → `docs/` (root of docs)
   - Setup/instructions → `docs/`

2. **Script Files:**
   - Development scripts (git, commits, tests) → `scripts/dev/`
   - Operations scripts (deployment, checks) → `scripts/ops/`
   - Function-specific scripts → `functions/` (if function-specific)

3. **Test Files:**
   - Unit tests → `functions/src/__tests__/` or `[app]/test/`
   - Integration tests → `functions/src/__tests__/` or `[app]/test/`
   - Test results/output → `docs/reports/` or gitignored

4. **Configuration Files:**
   - Firebase config → root (required by Firebase CLI)
   - Function config → `functions/`
   - App config → `[app]/`

**Naming Conventions:**
- Documentation: `UPPER_SNAKE_CASE.md` or `PascalCase.md` for reports
- Scripts: `kebab-case.bat` or `kebab-case.ps1`
- Source code: `camelCase.ts` or `camelCase.dart`

**Maintenance Rules:**
- Before committing, verify root directory is clean
- New files must go to appropriate folders, not root
- Temporary files should be gitignored or deleted
- Test outputs should be gitignored or moved to `docs/reports/`
- Scripts must be organized by purpose (dev vs ops)

**Enforcement:**
- Code reviews must check repository structure
- CI/CD can validate structure (future)
- Documentation must reference correct paths

**Benefits:**
- Clean, professional repository
- Easy navigation for new developers
- Scalable structure for future growth
- Prevents root directory clutter
- Clear separation of concerns

---

## 3) System Architecture (High Level)

### 3.1 Frontend
- Flutter application
- Uses standard navigation and a consistent AppShell layout
- Calls backend via Cloud Functions endpoints (REST or callable)

### 3.2 Backend
- Firebase Authentication
- Firestore (primary data store)
- Cloud Storage (documents)
- Cloud Functions (API + processing + AI requests)
- Optional: Pub/Sub / task queue for heavy jobs (OCR, chunking)

### 3.3 AI Layer
- LLM provider (OpenAI recommended for initial build)
- Embeddings for retrieval
- Retrieval returns chunks with citations
- Outputs are stored into Firestore as structured drafts/notes/messages

### 3.4 Eventing
- Background processing is job-based
- Job records stored in Firestore
- UI subscribes to job status updates (loading -> completed -> failed)

---

## 4) Identity, Organization, Plans, Roles (Entitlements Engine)
This is the foundation that controls what users can see and do.
