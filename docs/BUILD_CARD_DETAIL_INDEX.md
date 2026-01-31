# Build Card Detail Index (Slice 1–4 Style)

This index tracks which slice build cards have been brought up to **Slice 1, 2, 3, 4 style**: explicit **Scope In ✅**, **Scope Out ❌**, **Dependencies** (External + Slice deps + No deps on), and **per-endpoint Backend** (Request Payload JSON, Success Response JSON, Error Responses list, Implementation Flow numbered steps).

---

## Slice 1–4 style checklist (per build card)

| Section | Slice 1 | Slice 2 | Slice 3 | Slice 4 |
|--------|---------|---------|---------|---------|
| 1) Purpose | ✅ | ✅ | ✅ | ✅ |
| 2) Scope In ✅ | ✅ | ✅ (Backend/Frontend/Data) | ✅ | ✅ |
| 3) Scope Out ❌ | ✅ | ✅ | ✅ | ✅ |
| 4) Dependencies | ✅ (as 12) | ✅ | ✅ | ✅ |
| 5) Backend Endpoints | N/A (UI only) | ✅ Per-endpoint JSON + Flow | ✅ | ✅ |
| Firestore / Frontend / Permissions / Testing / Success | ✅ (Flutter structure) | ✅ | ✅ | ✅ |

---

## Status by slice

| Slice | Build Card | Scope In/Out | Dependencies | Per-endpoint Backend (Slice 4 style) | Notes |
|-------|------------|--------------|--------------|--------------------------------------|-------|
| **0** | SLICE_0_BUILD_CARD.md | ✅ | ✅ (sect 10) | ✅ 4.1–4.4 | Already detailed |
| **1** | SLICE_1_BUILD_CARD.md | ✅ | ✅ (sect 12) | N/A (UI shell) | Already detailed |
| **2** | SLICE_2_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Reference standard |
| **3** | SLICE_3_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Reference standard |
| **4** | SLICE_4_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Reference standard |
| **5** | SLICE_5_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Already detailed |
| **5.5** | SLICE_5_5_CASE_PARTICIPANTS_BUILD_CARD.md | ✅ | ✅ | ✅ 7.1–7.3 | Updated this pass |
| **6a** | SLICE_6A_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.2 | Already detailed |
| **6b** | SLICE_6B_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Already detailed |
| **7** | SLICE_7_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Already detailed |
| **8** | SLICE_8_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.5 | Updated this pass |
| **9** | SLICE_9_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.9 | Updated this pass |
| **10** | SLICE_10_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.6 | Updated this pass |
| **11** | SLICE_11_BUILD_CARD.md | ✅ | ✅ | ✅ 5.1–5.6 | Updated this pass |
| **12** | SLICE_12_BUILD_CARD.md | ✅ | ✅ 2.5 | ✅ 3.3.1–3.3.2 | Updated this pass |
| **13** | SLICE_13_BUILD_CARD.md | ✅ | ✅ (header) | ✅ 3.4.1–3.4.3 | Updated this pass |
| **14** | SLICE_14_BUILD_CARD.md | ✅ | ✅ | ✅ 3.4.1–3.4.3 | Updated earlier |
| **15** | SLICE_15_BUILD_CARD.md | ✅ | ✅ | ✅ (Technical Architecture) | Advanced Admin; detailed |
| **P1** | SLICE_P1_BUILD_CARD.md | ✅ | ✅ | ✅ (Data Model + Processing) | Domain Events + Outbox |
| **P2** | SLICE_P2_BUILD_CARD.md | ✅ | ✅ | ✅ (Data Model + Routing) | Notification Engine |
| **P3** | SLICE_P3_BUILD_CARD.md | ✅ | ✅ | ✅ (In Scope + Webhook) | Deliverability hardening |
| **16** | SLICE_16_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Comments + Activity Feed; v2.0 |
| **17** | SLICE_17_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | 2FA; v2.0 |
| **18** | SLICE_18_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Online Payments (Stripe); v2.0 |
| **19** | SLICE_19_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Client Portal v1; v2.0 |
| **20** | SLICE_20_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Calendar Sync; v2.0 |
| **21** | SLICE_21_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Global Search; v2.0 |
| **22** | SLICE_22_BUILD_CARD.md | ✅ | ✅ | ✅ (Backend Endpoints summary) | Matter Intake Workflow; v2.0 |
| **—** | TERMINOLOGY_FIRM_MATTER_BUILD_CARD.md | ✅ | ✅ | N/A (UI only) | Firm/Matter UI labels |
| **—** | SLICE_UI_REFINEMENT_BUILD_CARD.md | ✅ | ✅ | N/A (Flutter only) | UI refinement & polish |

---

## Template for future slices (15+)

For each slice that still needs Slice 1–4 level detail:

1. **Scope In ✅**  
   - Backend (Cloud Functions): list each callable and main behavior.  
   - Frontend (Flutter): list screens, providers, services.  
   - Data Model: collection path(s) and main fields.

2. **Scope Out ❌**  
   - Explicit non-goals (e.g. “No X in MVP”, “Future slice”).

3. **Dependencies**  
   - **External Services:** Firebase Auth, Firestore, Cloud Functions (and any other, e.g. Storage).  
   - **Dependencies on Other Slices:** Slice 0, 1, 2, … required for this slice.  
   - **No Dependencies on:** Slices not required.

4. **Backend Endpoints (Slice 4 style)**  
   For each callable function:
   - **Function Name (Export):** e.g. `documentExtract`
   - **Auth Requirement:** Valid Firebase Auth token
   - **Required Permission / Plan Gating:** as applicable
   - **Request Payload:** JSON with types, e.g. `{ "orgId": "string (required)", "documentId": "string (required)" }`
   - **Success Response (200):** JSON shape of `successResponse` data
   - **Error Responses:** List, e.g. `VALIDATION_ERROR` (400), `NOT_FOUND` (404), …
   - **Implementation Flow:** Numbered steps 1–N (validate auth → entitlement → load resource → enforce case access → … → return).

5. **Firestore / Security / Frontend / Testing / Success criteria**  
   Keep or add as in Slice 2/3/4 (collection paths, rules, indexes, Model/Service/Provider/screens, manual test checklist, success criteria).

---

## Files updated in this pass

- **SLICE_5_5_CASE_PARTICIPANTS_BUILD_CARD.md** – Added Scope In (2), Scope Out (3), Dependencies (4), renumbered Data Model (5), Permissions (6), Backend Endpoints Slice 4 style (7), Firestore (8); per-endpoint Request/Success/Errors/Flow for caseAddParticipant, caseRemoveParticipant, caseListParticipants.
- **SLICE_12_BUILD_CARD.md** – Added Dependencies (2.5), Backend Endpoints Slice 4 style (3.3): auditList (3.3.1), auditExport (3.3.2) with Request Payload, Success Response, Error Responses, Implementation Flow.
- **SLICE_13_BUILD_CARD.md** – Added Backend Endpoints Slice 4 style (3.4): contractAnalyze (3.4.1), contractAnalysisGet (3.4.2), contractAnalysisList (3.4.3) with Request/Success/Errors/Flow.
- **SLICE_14_BUILD_CARD.md** – Already had Scope In/Out, Dependencies, and full per-endpoint Slice 4 style (3.4) from earlier.
- **SLICE_8_BUILD_CARD.md** – Added Scope In (2), Scope Out (3), Dependencies (4), Backend Endpoints Slice 4 style (5.1–5.5): noteCreate, noteGet, noteList, noteUpdate, noteDelete with Request Payload, Success Response, Error Responses, Implementation Flow; renumbered Data Model (6), Frontend (7), UI (8), Implementation (9), Security (10), Future (11), Testing (12).
- **SLICE_9_BUILD_CARD.md** – Added Scope In (2), Scope Out (3), Dependencies (4), Backend Endpoints Slice 4 style (5.1–5.9): draftTemplateList, draftCreate, draftGet, draftList, draftUpdate, draftDelete, draftGenerate, draftProcessJob, draftExport; renumbered Data Model (6) through Testing (12).
- **SLICE_10_BUILD_CARD.md** – Added Scope In (2), Scope Out (3), Dependencies (4), Backend Endpoints Slice 4 style (5.1–5.6): timeEntryCreate, timeEntryStartTimer, timeEntryStopTimer, timeEntryList, timeEntryUpdate, timeEntryDelete; renumbered Data Model (6) through Testing (10).
- **SLICE_11_BUILD_CARD.md** – Added Scope In (2), Scope Out (3), Dependencies (4), Backend Endpoints Slice 4 style (5.1–5.6): invoiceCreate, invoiceGet, invoiceList, invoiceUpdate, invoiceRecordPayment, invoiceExport; renumbered Data Model (6) through Testing (9).

---

## New build cards added (2026-01-30)

- **TERMINOLOGY_FIRM_MATTER_BUILD_CARD.md** – Firm/Matter UI labels (MASTER_SPEC_V2.0 §1); no backend changes.
- **SLICE_16_BUILD_CARD.md** – Comments + Activity Feed (P1/P2 dependent); comment CRUD + activityFeedList; backend endpoints summary.
- **SLICE_17_BUILD_CARD.md** – Two-Factor Authentication (2FA); TOTP, backup codes, login flow; backend endpoints summary.
- **SLICE_18_BUILD_CARD.md** – Online Payments (Stripe); payment link, webhook, list payments; backend endpoints summary.
- **SLICE_19_BUILD_CARD.md** – Client Portal v1; client auth, client-scoped APIs, visibility; backend endpoints summary.
- **SLICE_20_BUILD_CARD.md** – Calendar Sync (Google/Outlook); OAuth, sync engine; backend endpoints summary.
- **SLICE_21_BUILD_CARD.md** – Global Search; unified search API, permission-aware; backend endpoints summary.
- **SLICE_22_BUILD_CARD.md** – Matter Intake Workflow; intake request CRUD, approve/reject, convert to matter; backend endpoints summary.
- **SLICE_UI_REFINEMENT_BUILD_CARD.md** – UI refinement & polish; design system, loading/empty/error, responsive, accessibility basics.

---

**Last Updated:** 2026-01-30
