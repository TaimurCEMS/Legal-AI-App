# LEGAL AI APP - MASTER SPECIFICATION (SOURCE OF TRUTH)
Version: 1.4.0
Owner: Taimur (Product Owner)
Last Updated: 2026-01-25
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

---

## 5) Development Roadmap (Vertical Slices)

This section defines the development roadmap as vertical slices. Each slice delivers an end-to-end working feature: UI → backend → database → output → saved result.

### Completed Slices

- ✅ **Slice 0:** Foundation (Auth + Org + Entitlements Engine) - **LOCKED**
  - Organization creation and joining
  - Membership management
  - Entitlements engine (plans, roles, permissions)
  - Audit logging foundation

- ✅ **Slice 1:** Navigation Shell + UI System
  - Flutter project structure
  - Theme system (Material Design 3)
  - Reusable UI widgets
  - Navigation and routing
  - State management (Provider)

- ✅ **Slice 2:** Case Hub
  - Case CRUD operations
  - Case list with search and filtering
  - Case visibility (ORG_WIDE, PRIVATE)
  - Client-case relationships

- ✅ **Slice 2.5:** Member Management & Role Assignment (Mini-slice)
  - List organization members
  - View member roles
  - Update member roles (ADMIN-only)
  - Safety checks (cannot change own role, cannot remove last ADMIN)
  - **Note:** Moved from Slice 15 due to blocking multi-user testing

- ✅ **Slice 3:** Client Hub
  - Client CRUD operations
  - Client list with search
  - Client-case relationships
  - Conflict checks (cannot delete client with cases)

- ✅ **Slice 4:** Document Hub
  - Document CRUD operations
  - Document upload to Cloud Storage
  - Document-case linking
  - Document list with search and filtering

- ✅ **Slice 5:** Task Hub
  - Task management (CRUD)
  - Task-case relationships
  - Task assignment to team members
  - Task status tracking
  - Priority and due date management

- ✅ **Slice 5.5:** Case Participants & Private Case Sharing (Mini-slice)
  - Add/remove participants to private cases
  - Task-level visibility (`restrictedToAssignee`)
  - Enhanced assignee selection for private cases

- ✅ **Slice 6a:** Document Text Extraction
  - PDF text extraction (pdf-parse)
  - DOCX text extraction (mammoth)
  - TXT/RTF text extraction
  - Job queue pattern for async processing
  - Extraction status tracking

- ✅ **Slice 6b:** AI Chat/Research (Enhanced)
  - OpenAI GPT integration (gpt-4o-mini)
  - Document-based Q&A with context building
  - Citation extraction (references document sources)
  - Thread management (create, list, delete, history)
  - Legal disclaimer handling (with duplicate prevention)
  - **Jurisdiction-aware legal opinions** (country/state/region)
  - **Jurisdiction persistence** (saved per thread, remembered across sessions)
  - **Comprehensive legal AI system prompt** (analysis, research, opinions, guidance, drafting)
  - Modular architecture for future extensions

### Planned Slices (Prioritized Roadmap)

**Priority 1: Critical for Adoption**

- **Slice 7:** Calendar & Court Dates
  - Court date management (hearings, trials, filing deadlines)
  - Statute of limitations tracking
  - Reminder notifications
  - Calendar views (day, week, month)
  - Case-event linking

- **Slice 8:** Notes/Memos on Cases
  - Rich text notes attached to cases
  - Note categories and templates
  - Note search across cases
  - Pin important notes

- **Slice 9:** AI Document Drafting
  - Template library (contracts, letters, motions)
  - AI-powered drafting from prompts
  - Document variables (client name, dates)
  - Export to DOCX/PDF
  - Jurisdiction-aware templates

**Priority 2: Important for Revenue**

- **Slice 10:** Time Tracking
  - Timer (start/stop/pause)
  - Manual time entry
  - Time entries linked to cases/tasks
  - Billable vs non-billable tracking
  - Time entry reports

- **Slice 11:** Billing & Invoicing
  - Invoice generation from time entries
  - Hourly rates per lawyer/client/matter
  - Invoice PDF export
  - Payment tracking
  - Trust account tracking (IOLTA compliance)

- **Slice 12:** Audit Trail UI
  - View audit logs
  - Filter and search audit events
  - Export audit logs
  - Compliance dashboards

**Priority 3: Competitive Differentiators**

- **Slice 13:** AI Contract Analysis
  - Clause identification (indemnity, liability, etc.)
  - Risk flagging (unusual terms, missing clauses)
  - Contract comparison
  - Obligation extraction

- **Slice 14:** AI Summarization
  - One-click document summarization
  - Key points extraction
  - Entity extraction (parties, dates, amounts)

- **Slice 15:** Advanced Admin Features
  - Member invitations (email-based)
  - Bulk member operations
  - Organization settings UI
  - Custom role definitions
  - **Note:** Basic member management already done in Slice 2.5

- **Slice 16:** Reporting Dashboard
  - Case statistics
  - Productivity metrics
  - Time tracking reports (if Slice 10 complete)
  - Custom report builder

**Priority 4: Full Feature Parity**

- **Slice 17:** Contact Management
  - Contact database (beyond clients)
  - Contact categories (opposing counsel, experts)
  - Link contacts to cases

- **Slice 18:** Email Integration
  - Email capture to case record
  - Attachment extraction
  - Email search

- **Slice 19:** Conflict of Interest Checks
  - Automatic conflict check on new case/client
  - Party name matching (fuzzy)
  - Conflict waiver tracking

- **Slice 20:** Vector Search / Embeddings
  - Document embedding generation
  - Semantic search across documents
  - Cross-case document search

**See `docs/FEATURE_ROADMAP.md` for comprehensive feature analysis and competitive comparison.**

### Mini-Slice Pattern

Mini-slices (e.g., Slice 2.5) are inserted when:
- Feature is blocking critical workflows or testing
- Scope is small and manageable (can be completed quickly)
- Can be implemented without breaking changes
- Foundation is already in place (dependencies satisfied)

**Decision Criteria:**
- Does it unblock development or testing?
- Is it small enough to complete in 1-2 days?
- Will it require breaking changes? (If yes, wait for proper slice)
- Are dependencies satisfied?

**Examples:**
- ✅ Slice 2.5: Member management (blocking multi-user testing)
- ❌ Future: Large features should wait for proper slice planning
