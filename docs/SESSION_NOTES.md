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

### Git Status
- **Branch:** main
- **Status:** 1 commit ahead of origin/main (not pushed)
- **Last Commit:** `751fabc` - feat(slice-6b): Complete AI Chat/Research with jurisdiction-aware legal opinions

---

## Recent Session (2026-01-25/26)

### Work Completed

**Slice 5.5 - Case Participants**
- Created `functions/src/functions/case-participants.ts`
- Functions: `caseListParticipants`, `caseAddParticipant`, `caseRemoveParticipant`
- Uses `canUserAccessCase` helper for PRIVATE vs ORG_WIDE visibility
- Only case creator (or admin) can manage participants

**Slice 6b - AI Chat/Research**
- Backend: `ai-chat.ts` (5 functions), `ai-service.ts` (OpenAI integration)
- Frontend: ChatThreadModel, AIChatProvider, CaseAIChatScreen, ChatThreadScreen
- Features: Jurisdiction-aware legal opinions (50+ countries/regions)
- Jurisdiction persists at thread level

**Bug Fixes**
- Task deletion showing "task not found" even on success
- Case details page loading issues
- Participant "Add" button not appearing for case creators
- Flutter layout error (render box with no size)

**Documentation Updates**
- SLICE_STATUS.md - enhanced with Slice 6b details
- FEATURE_ROADMAP.md - competitive analysis (Clio, Harvey.ai)
- MASTER_SPEC V1.4.0 - updated
- DEVELOPMENT_LEARNINGS.md - added learnings 49-52
- ARCHITECTURE_SCALABILITY_ASSESSMENT.md - updated to 75% complete

---

## Next Steps

### Immediate: Slice 7 - Calendar & Court Dates
**Priority:** 🔴 HIGH  
**Rationale:** Lawyers live by deadlines - missing court dates = malpractice liability

**Planned Features:**
- Court date management (hearings, trials, filing deadlines)
- Statute of limitations tracking
- Reminder notifications (email, in-app)
- Calendar views (day, week, month)
- Case-event linking
- Recurring events

**Technical Scope:**
- Backend: `eventCreate`, `eventGet`, `eventList`, `eventUpdate`, `eventDelete`
- Frontend: Calendar widget, event forms, case integration
- Notifications: Firebase Cloud Messaging

### Future Priorities
| Slice | Priority | Description |
|-------|----------|-------------|
| 7 | 🔴 HIGH | Calendar & Court Dates |
| 8 | 🔴 HIGH | Notes/Memos on Cases |
| 9 | 🔴 HIGH | AI Document Drafting |
| 10 | 🟡 HIGH | Time Tracking |
| 11 | 🟡 MEDIUM | Billing/Invoicing |

### AI UX Enhancements (Post-Slice 7)
| Enhancement | Priority | Impact | Effort |
|-------------|----------|--------|--------|
| Markdown Rendering | High | High | Low |
| Streaming Responses | High | High | Medium |
| Export Chat to PDF | Medium | Medium | Low |
| Citation Links | Medium | Medium | Low |

---

## Key Architecture Decisions

1. **Firestore Structure:** `organizations/{orgId}/cases/{caseId}/...`
2. **Case Visibility:** PRIVATE (explicit participants) vs ORG_WIDE (all members)
3. **AI Integration:** OpenAI GPT-4 via Cloud Functions
4. **Jurisdiction Model:** Country + optional state/region, persisted per chat thread
5. **Entitlements:** Feature flags checked via `checkEntitlement()` helper

---

## Development Patterns

- **Backend:** Firebase Cloud Functions (TypeScript), callable functions return `successResponse`/`errorResponse`
- **Frontend:** Flutter with Provider pattern
- **Naming:** `{entity}{Action}` (e.g., `caseCreate`, `taskList`)
- **Timestamps:** Firestore Timestamps converted to ISO strings in responses

---

## How to Use This Document

1. **At start of new chat:** Share this file or reference `@docs/SESSION_NOTES.md`
2. **After significant work:** Update the "Recent Session" and "Current State" sections
3. **When starting new slice:** Add to "Next Steps" with technical scope

---

*This document should be updated after each development session.*
