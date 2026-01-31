# Terminology: Firm / Matter (UI Labels) - Build Card

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (can run in parallel with P1/P2 or right after P2)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §1

---

## 📋 Overview

Align all **user-facing** labels with legal-industry terminology:
- **Organization** → **Firm** (UI only)
- **Case** → **Matter** (UI only)

Backend collection names and API identifiers remain `organizations` and `cases`; no database migrations in v2.0.

---

## 🎯 Success Criteria

### In Scope ✅
- All Flutter UI strings use "Firm" where the app currently shows "Organization" (or "Org").
- All Flutter UI strings use "Matter" where the app currently shows "Case".
- App bar titles, navigation labels, settings, empty states, and form labels updated.
- No backend or Firestore changes (except optional `displayTerms` in API responses if needed by frontend).

### Out of Scope ❌
- Renaming Firestore collections or document fields.
- Changing Cloud Function parameter names (`orgId`, `caseId` remain).
- Changing route path segments (e.g. `/cases/` can stay; label in UI is "Matters").

---

## 🏗️ Technical Approach

### 1) Centralized Strings (Recommended)
- Add or extend a strings/l10n module (e.g. `lib/core/strings.dart` or ARB files).
- Define: `firmLabel = "Firm"`, `matterLabel = "Matter"`.
- Replace every user-visible "Organization"/"Org"/"Case" with these constants (or l10n keys).

### 2) Areas to Update (Checklist)
- **Navigation:** Tab labels, drawer items, "Organization" switcher → "Firm".
- **Screens:** "Cases" → "Matters" (list title, empty state, create button).
- **Case/Matter screens:** "Case details" → "Matter details", "Case name" → "Matter name".
- **Settings:** "Organization settings" → "Firm settings", "Organization export" → "Firm export".
- **Admin:** "Organization dashboard" → "Firm dashboard", "Organization statistics" → "Firm statistics".
- **Invitations:** "Join organization" → "Join firm" (in invite accept flow).
- **Errors/messages:** Any message that says "organization" or "case" in user-facing text.

### 3) API / Backend (Optional)
- If the frontend needs to know display terms from the backend (e.g. for white-label), add optional `displayTerms: { organization: "Firm", case: "Matter" }` to a config or org settings response.
- Not required for this slice if all labels are driven from Flutter constants.

---

## 🔐 Security & Permissions

No change to permissions or security rules.

---

## 🧪 Testing

- **Manual:** Walk every main screen and confirm no "Organization" or "Case" in UI (except in dev/debug if intentional).
- **Search:** Codebase grep for user-facing strings containing "Organization", "Org", "Case" (excluding variable names and API keys).

---

## 📝 Implementation Notes

- Can be done in a single pass or split by feature area (e.g. Cases → Matters first, then Org → Firm).
- Keep backend terminology in logs and internal comments as org/case to avoid confusion with Firestore/API.

---

## 📚 References

- **MASTER_SPEC_V2.0.md** §1 (Terminology Layer)
- **MASTER_SPEC_V1.0_FROZEN.md** (unchanged; backend naming remains)

---

**Last Updated:** 2026-01-30
