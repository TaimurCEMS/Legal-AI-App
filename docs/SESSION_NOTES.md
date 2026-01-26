# Legal AI App - Session Notes

**Last Updated:** 2026-01-26

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

### Git Status
- **Branch:** main
- **Status:** Synced with origin/main
- **Last Commit:** Slice 7 - Calendar & Court Dates complete

---

## Recent Session (2026-01-26)

### Work Completed

**Slice 7 - Calendar & Court Dates**
- Backend: `event.ts` (5 functions: create, get, list, update, delete)
- Frontend: CalendarScreen, EventFormScreen, EventDetailsScreen
- Features:
  - Multiple calendar views (Day, Week, Month, Agenda)
  - Date navigation (previous/next, today button)
  - Event types (HEARING, TRIAL, MEETING, DEADLINE, REMINDER, OTHER)
  - Event statuses (SCHEDULED, COMPLETED, CANCELLED, RESCHEDULED)
  - Priorities (LOW, MEDIUM, HIGH, CRITICAL)
  - **Case linkage** - events can be linked to cases
  - **Smart visibility options:**
    - ORG (Organization-wide) - visible to all org members
    - CASE_ONLY (Team) - visible only to users with case access
    - PRIVATE - visible only to creator
  - **Backend visibility enforcement** - server-side filtering ensures unauthorized users cannot see PRIVATE or CASE_ONLY events

**Key Implementation Details:**
- Click on empty date in Month/Week view → opens new event form with pre-filled date
- Event titles truncated with ellipsis in Month view for clean UI
- Visibility dropdown dynamically adjusts based on case selection
- Backend uses `canUserAccessCase` helper for CASE_ONLY event filtering

**Bug Fixes:**
- Fixed GoRouter navigation issues (was using Navigator APIs)
- Fixed EventModel timestamp parsing for null/missing fields
- Fixed RenderFlex overflow in Month view calendar grid
- Fixed Firebase deployment function naming

---

## Next Steps

### Recommended: Slice 8 - Notes/Memos on Cases
**Priority:** 🔴 HIGH  
**Rationale:** Quick win - lawyers need note-taking for meetings, research, strategy

**Planned Features:**
- Rich text notes attached to cases
- Note categories (client meeting, research, strategy, etc.)
- Note search across all cases
- Pin important notes
- Share notes with team members

**Technical Scope:**
- Backend: `noteCreate`, `noteGet`, `noteList`, `noteUpdate`, `noteDelete`
- Frontend: Note editor, case integration, search
- Storage: Firestore (with rich text support)

### Future Priorities
| Slice | Priority | Description |
|-------|----------|-------------|
| 8 | 🔴 HIGH | Notes/Memos on Cases |
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
