# Legal AI App - Session Notes

**Last Updated:** 2026-01-27

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

### Git Status
- **Branch:** main
- **Status:** Local changes present (Slice 8 code + docs updates)
- **Deployments:** Functions deployed during Slice 8 debugging

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

## Next Steps

### Recommended: Slice 9 - AI Document Drafting
**Priority:** 🔴 HIGH  
**Rationale:** Major differentiator; builds on existing documents + extraction + AI foundations

### Future Priorities
| Slice | Priority | Description |
|-------|----------|-------------|
| 9 | 🔴 HIGH | AI Document Drafting |
| 10 | 🟡 HIGH | Time Tracking |
| 11 | 🟡 MEDIUM | Billing/Invoicing |

### UI Polish Items (Deferred)
- Calendar UI refinements
- Month view event display improvements
- Week view time slot interactions

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
