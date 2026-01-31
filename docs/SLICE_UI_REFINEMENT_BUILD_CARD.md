# Slice: UI Refinement & Polish - Build Card

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (can run in parallel with P1/P2 or after feature slices)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅ (and all feature slices to be refined)  
**Date Created:** 2026-01-30

---

## 📋 Overview

This build card covers **detailed UI refinement and enhancements** across the Legal AI App so the product feels consistent, accessible, and production-ready. It is not a single feature slice but a **cross-cutting polish pass** that can be scheduled after major features (e.g. after Slice 15) or in parallel with platform work (P1/P2).

**Goals:**
- Consistent layout, spacing, and typography across all screens.
- Reliable loading and empty states; clear error handling and recovery.
- Responsive behavior and basic accessibility.
- Small UX improvements (animations, feedback, navigation clarity) without changing scope of features.

---

## 🎯 Success Criteria

### 1) Design System Consistency
- All screens use the same spacing scale (e.g. 4/8/16/24/32) and typography scale from Slice 1 theme.
- Primary/secondary actions use shared button styles (PrimaryButton, SecondaryButton); no one-off button styling.
- Cards, lists, and forms use AppCard, AppTextField, and shared list tile patterns where applicable.
- Color usage: primary for main actions, semantic colors for success/warning/error only where defined.

### 2) Loading States
- Every screen that fetches data shows a loading indicator (LoadingSpinner or skeleton) until data is ready; no blank content flash.
- Buttons that trigger async actions (save, submit, delete) show loading state and are disabled during request (or use overlay spinner).
- Pull-to-refresh and "Load more" have clear loading feedback.

### 3) Empty States
- Every list screen has a dedicated empty state: icon + message + optional primary action (e.g. "No matters yet" + "Create matter").
- EmptyStateWidget (or equivalent) used consistently; copy reviewed for tone and clarity.
- Forms: required fields clearly marked; validation messages shown inline without replacing entire form.

### 4) Error Handling & Recovery
- Network or server errors show user-friendly message (e.g. "Something went wrong. Please try again.") with optional Retry action.
- Validation errors shown next to fields or at top of form; not only in debug console.
- No uncaught exceptions that leave the user on a blank or broken screen; global error boundary or fallback where appropriate.

### 5) Responsive Layout
- Web: Layout adapts to narrow (e.g. 360px) and wide (e.g. 1200px) viewports; navigation (bottom nav or drawer) remains usable.
- Key screens (Home, Matter list, Matter details) do not overflow horizontally; tables or grids wrap or scroll.
- Optional: breakpoints for tablet (e.g. side-by-side list + detail) documented for future.

### 6) Accessibility (Basics)
- Interactive elements have semantic labels (or Semantics widget) so screen readers can announce purpose.
- Focus order is logical (form fields, buttons); no trap focus in dialogs.
- Color contrast meets minimum (e.g. WCAG AA for text); error state not conveyed by color alone (icon or text too).
- Optional: minimum touch target size (e.g. 44pt) for primary actions on mobile.

### 7) Navigation & Feedback
- App bar titles match current screen; back button where expected.
- Success feedback after create/update/delete (e.g. SnackBar "Matter created" or brief toast); optional undo for delete where applicable.
- Destructive actions (delete) use confirmation dialog with clear "Cancel" and "Delete" (or "Remove").

### 8) Specific Areas (Checklist)
- **Matter list:** Loading skeleton, empty state, error + retry, consistent row height and tap target.
- **Matter details:** Tabs/sections (Documents, Tasks, Notes, etc.) with loading per section if needed; empty states per section.
- **Document upload:** Progress indicator, success/error message, clear "Upload another" or "View document."
- **AI Chat:** Markdown rendering in AI messages (if not already done); citation links; loading "AI is thinking" state.
- **Settings / Admin:** Grouped sections; dangerous actions (e.g. export, revoke invite) with confirmation.
- **Forms (Create/Edit):** Required field indicators, validation on submit and optionally on blur; disabled submit until valid where appropriate.

---

## 🏗️ Technical Approach

### No New Backend
- All work is Flutter-only: widgets, theme, layout, semantics, error handling.
- Optional: backend may add `displayTerms` or minor response fields if needed for UI (e.g. Firm/Matter labels); otherwise no API changes.

### Suggested Order of Work
1. **Audit** – Walk every screen; list missing loading/empty/error handling and layout issues.
2. **Design system** – Document spacing/typography and ensure one source (Theme + constants); fix any screen that diverges.
3. **Loading** – Add or standardize LoadingSpinner/skeleton on list and detail screens; disable buttons during submit.
4. **Empty states** – Add or refine EmptyStateWidget usage and copy.
5. **Errors** – Add try/catch and user-facing error message + Retry where data is fetched; validation messages in forms.
6. **Responsive** – Test at 360px and 1200px; fix overflow and nav.
7. **Accessibility** – Add semantics and focus order; check contrast.
8. **Feedback** – SnackBars for success; confirmation for destructive actions.

### Files / Areas to Touch
- `legal_ai_app/lib/core/theme/` – Ensure one theme and spacing constants.
- `legal_ai_app/lib/core/widgets/` – LoadingSpinner, EmptyStateWidget, ErrorMessage, retry pattern.
- Each feature screen under `lib/features/` – Add loading, empty, error; ensure AppCard/buttons from design system.
- Router – Ensure app bar title and back button set per route.
- Optional: `legal_ai_app/lib/core/error_handler.dart` – Global error handling or fallback widget.

---

## 🔐 Security & Permissions

No change to permissions or backend security; only presentation and UX.

---

## 🧪 Testing

- **Manual:** Full pass on every screen: load, empty, error, submit success, delete confirm, resize window.
- **Automated:** Optional widget tests for EmptyStateWidget, ErrorMessage, and key screens with loading state; optional golden tests for critical layouts.

---

## 📝 Out of Scope

- New features or new screens (only refinement of existing).
- Full WCAG AAA or full screen reader parity (basics only).
- Redesign or rebrand (consistency with existing Slice 1 theme).

---

## 📚 References

- SLICE_1_BUILD_CARD.md (Theme, widgets, navigation)
- MASTER_SPEC_V1.0_FROZEN.md §2 (UI rules, consistency)
- FEATURE_ROADMAP.md (Immediate UX enhancements for Slice 6b+)

---

**Last Updated:** 2026-01-30
