# Legal AI App - Session Notes

**Last Updated:** 2026-01-28

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

### Git Status
- **Branch:** main
- **Status:** Local changes present (Slices 9–10 code + docs updates)
- **Deployments:** Functions deployed during Slice 9–10 work (latest: 2026-01-28)

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

### Deployments
- ✅ Cloud Functions deployed to `legal-ai-app-1203e` (`us-central1`) on 2026-01-28.
- Non-blocking Firebase CLI warning: `firebase-functions` SDK is outdated (upgrade in maintenance/polish pass).

---

## Next Steps

### Slice 11: Billing & Invoicing (Next Slice)
**Priority:** 🟡 HIGH  
**Rationale:** Critical for revenue + depends on Slice 10 time capture.

Expected scope (high level):
- Hourly rates, invoice generation, invoice line items (from time entries)
- Approval workflow + export (PDF) + audit trail
- Reporting views (billed vs unbilled, by case/client/user)

### Future Priorities
| Slice | Priority | Description |
|-------|----------|-------------|
| 11 | 🟡 HIGH | Billing/Invoicing |
| 12 | 🟡 MEDIUM | Audit Trail UI |

### UI Polish Items (Deferred)
- Calendar UI refinements
- Month view event display improvements
- Week view time slot interactions

### Slice 9/10 Polish Backlog (Deferred)
- Standardize “All …” filters everywhere (avoid null/hint state; use explicit sentinel values).
- Replace deprecated Flutter form-field `value` usage with `initialValue` where applicable.
- Improve team time display (“By user” should prefer displayName/email when available).

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
