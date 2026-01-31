# Legal AI App – Documentation Index

**Last Updated:** 2026-01-30  
**Purpose:** Single entry point to all project documentation. Use this index to find specs, build cards, status, and handoff context.

---

## 1. Start Here (Handoff & Context)

| Document | Purpose |
|----------|---------|
| **[HANDOFF_CONTEXT.md](HANDOFF_CONTEXT.md)** | Full context for continuing in a new chat: project overview, slices 0–14, Slice 13/14 details, conventions, key paths, next steps |
| **[HANDOFF_FOR_NEXT_CHAT.md](HANDOFF_FOR_NEXT_CHAT.md)** | Copy-paste block and quick reference for next chat (deployment, paths, tests) |
| **[SESSION_NOTES.md](SESSION_NOTES.md)** | Current state, recent sessions, completed slices table, next steps, architecture decisions |

---

## 2. Specification & Roadmap

| Document | Purpose |
|----------|---------|
| **[MASTER_SPEC_V1.0_FROZEN.md](MASTER_SPEC_V1.0_FROZEN.md)** | Frozen v1.0 master spec; repository structure guidelines |
| **[MASTER_SPEC_V2.0.md](MASTER_SPEC_V2.0.md)** | v2.0 delta: events, outbox, notifications, audit, terminology (Firm/Matter), slice roadmap 16–22 |
| **[FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)** | Feature roadmap, competitive analysis, implemented vs planned slices |
| **[ARCHITECTURE_SCALABILITY_ASSESSMENT.md](ARCHITECTURE_SCALABILITY_ASSESSMENT.md)** | Architecture and scalability review |

---

## 3. Slice Status & Build Cards

| Document | Purpose |
|----------|---------|
| **[status/SLICE_STATUS.md](status/SLICE_STATUS.md)** | Per-slice status (0–14): backend/frontend, deployment, tests, documentation links |
| **Build cards (SLICE_*_BUILD_CARD.md)** | Per-slice scope, data model, backend endpoints, frontend, security, testing, deployment |

**Build cards by slice:**  
[Slice 0](SLICE_0_BUILD_CARD.md) · [Slice 1](SLICE_1_BUILD_CARD.md) · [Slice 2](SLICE_2_BUILD_CARD.md) · [Slice 3](SLICE_3_BUILD_CARD.md) · [Slice 4](SLICE_4_BUILD_CARD.md) · [Slice 5](SLICE_5_BUILD_CARD.md) · [Slice 5.5](SLICE_5_5_CASE_PARTICIPANTS_BUILD_CARD.md) · [Slice 6a](SLICE_6A_BUILD_CARD.md) · [Slice 6b](SLICE_6B_BUILD_CARD.md) · [Slice 7](SLICE_7_BUILD_CARD.md) · [Slice 8](SLICE_8_BUILD_CARD.md) · [Slice 9](SLICE_9_BUILD_CARD.md) · [Slice 10](SLICE_10_BUILD_CARD.md) · [Slice 11](SLICE_11_BUILD_CARD.md) · [Slice 12](SLICE_12_BUILD_CARD.md) · [Slice 13](SLICE_13_BUILD_CARD.md) · [Slice 14](SLICE_14_BUILD_CARD.md) · [Slice 15](SLICE_15_BUILD_CARD.md) · [P1](SLICE_P1_BUILD_CARD.md) · [P2](SLICE_P2_BUILD_CARD.md) · [P3](SLICE_P3_BUILD_CARD.md) · [Slice 16](SLICE_16_BUILD_CARD.md) · [Slice 17](SLICE_17_BUILD_CARD.md) · [Slice 18](SLICE_18_BUILD_CARD.md) · [Slice 19](SLICE_19_BUILD_CARD.md) · [Slice 20](SLICE_20_BUILD_CARD.md) · [Slice 21](SLICE_21_BUILD_CARD.md) · [Slice 22](SLICE_22_BUILD_CARD.md) · [Terminology](TERMINOLOGY_FIRM_MATTER_BUILD_CARD.md) · [UI Refinement](SLICE_UI_REFINEMENT_BUILD_CARD.md)

**Build card index:** [BUILD_CARD_DETAIL_INDEX.md](BUILD_CARD_DETAIL_INDEX.md)

---

## 4. Slice Completion Summaries (slices/)

| Document | Purpose |
|----------|---------|
| **[slices/SLICE_0_COMPLETE.md](slices/SLICE_0_COMPLETE.md)** | Slice 0 completion summary |
| **[slices/SLICE_1_COMPLETE.md](slices/SLICE_1_COMPLETE.md)** | Slice 1 completion summary |
| **[slices/SLICE_2_COMPLETE.md](slices/SLICE_2_COMPLETE.md)** | Slice 2 completion summary |
| **[slices/SLICE_3_COMPLETE.md](slices/SLICE_3_COMPLETE.md)** | Slice 3 completion summary |
| **[slices/SLICE_4_COMPLETE.md](slices/SLICE_4_COMPLETE.md)** | Slice 4 completion summary |
| **[slices/SLICE_7_COMPLETE.md](slices/SLICE_7_COMPLETE.md)** | Slice 7 completion summary |
| **[slices/SLICE_8_COMPLETE.md](slices/SLICE_8_COMPLETE.md)** | Slice 8 completion summary |
| **[slices/SLICE_12_COMPLETE.md](slices/SLICE_12_COMPLETE.md)** | Slice 12 completion summary |
| **[slices/SLICE_14_COMPLETE.md](slices/SLICE_14_COMPLETE.md)** | Slice 14 (AI Document Summarization) completion summary |

---

## 5. Testing & Reports

| Document | Purpose |
|----------|---------|
| **[TEST_RESULTS.md](TEST_RESULTS.md)** | Test results and coverage |
| **[TESTING_GUIDE.md](TESTING_GUIDE.md)** | How to run tests |
| **[TESTING_ACCEPTANCE_CRITERIA.md](TESTING_ACCEPTANCE_CRITERIA.md)** | Acceptance criteria for testing |
| **[TEST_COVERAGE_GAPS.md](TEST_COVERAGE_GAPS.md)** | Known test coverage gaps |
| **reports/** | Slice completion reports, error report template, troubleshooting |

---

## 6. Risk & Guidelines

| Document | Purpose |
|----------|---------|
| **[RISK_REGISTER.md](RISK_REGISTER.md)** | Project risk register |
| **[RISK_REGISTER_GUIDELINES.md](RISK_REGISTER_GUIDELINES.md)** | How to maintain the risk register |
| **[DEVELOPMENT_LEARNINGS.md](DEVELOPMENT_LEARNINGS.md)** | Key learnings, Firebase/Flutter insights, best practices |
| **[EXPERT_RECOMMENDATIONS_2026-01-23.md](EXPERT_RECOMMENDATIONS_2026-01-23.md)** | Expert recommendations (Jan 2026) |

---

## 7. Deployment & Operations

- **Cloud Functions:** 67 functions deployed to `legal-ai-app-1203e` (us-central1)
- **Verify:** `firebase functions:list` from repo root
- **Deploy:** `firebase deploy --only functions`; `firebase deploy --only firestore:indexes` for indexes
- **Repo:** https://github.com/TaimurCEMS/Legal-AI-App

---

## 8. Repository Root

- **[../README.md](../README.md)** – Project README: structure, quick start, slice status summary, documentation links

---

*Use HANDOFF_CONTEXT.md and SESSION_NOTES.md at the start of a new chat for full context.*
