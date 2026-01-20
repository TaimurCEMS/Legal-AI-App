# Development Learnings & Insights

**Purpose:** Capture key learnings, insights, and solutions discovered during development to prevent repeating mistakes and share knowledge.

**Last Updated:** 2026-01-20

---

## Table of Contents

1. [Firebase & Cloud Functions](#firebase--cloud-functions)
2. [Flutter Development](#flutter-development)
3. [Development Environment](#development-environment)
4. [Error Handling & Debugging](#error-handling--debugging)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)

---

## Firebase & Cloud Functions

### Learning 1: Firebase Callable Function Names
**Date:** 2026-01-17  
**Context:** Slice 1 - Organization creation failing with CORS errors

**Issue:**
- Code was calling functions as `org.create`, `org.join`, `member.getMyMembership`
- Functions are exported as `orgCreate`, `orgJoin`, `memberGetMyMembership`
- This mismatch caused function not found errors

**Solution:**
- Firebase callable functions use the **export name directly**, not a custom callable name
- If you export `export const orgCreate = functions.https.onCall(...)`, call it as `orgCreate`
- The comment "Callable Name: org.create" is just documentation, not the actual name

**Lesson:**
- Always check the actual export name in `functions/src/index.ts`
- Use the exact export name when calling from Flutter
- Don't rely on comments for function names

**Files:**
- `functions/src/index.ts` - Check exports
- `legal_ai_app/lib/core/services/cloud_functions_service.dart` - Use correct names

---

### Learning 17: Explicit Soft Delete Endpoints
**Date:** 2026-01-19  
**Context:** Slice 2 - Case Hub design review

**Issue:**
- Soft delete was modeled via `deletedAt` field and UI delete button
- But no dedicated backend endpoint (`case.delete`) was defined
- Risk of overloading `case.update` with hidden delete semantics

**Solution:**
- Introduce a dedicated `caseDelete` callable function (`case.delete`)
- Keep delete behavior explicit and auditable:
  - Validates orgId + caseId
  - Enforces entitlements (`case.delete` permission)
  - Applies visibility rules (only creator for PRIVATE in Slice 2)
  - Sets `deletedAt`, updates `updatedAt`/`updatedBy`
  - Writes a `case.deleted` audit event

**Lesson:**
- **Never hide soft delete inside generic update logic**
- Critical lifecycle transitions (create / update / delete) deserve explicit endpoints
- Makes permissions, audit logs, and UI flows much clearer and safer

**Files:**
- `functions/src/functions/case.ts` - `caseDelete` implementation
- `functions/src/constants/permissions.ts` - `case.delete` role permissions
- `docs/SLICE_2_BUILD_CARD.md` - Section 5.5

---

### Learning 18: Firestore OR Logic via Two-Query Merge
**Date:** 2026-01-19  
**Context:** Slice 2 - Listing ORG_WIDE + PRIVATE cases

**Issue:**
- Requirement: show both:
  - ORG_WIDE cases (visible to all org members)
  - PRIVATE cases (visible only to creator in Slice 2)
- Naïve spec said: \"visibility == ORG_WIDE OR (visibility == PRIVATE AND createdBy == uid)\"
- Firestore cannot express this as a single query

**Solution:**
- Lock the design to a **two-query merge**:
  1. Query ORG_WIDE cases with filters + updatedAt sort
  2. Query PRIVATE cases where `createdBy == uid` with same filters + sort
  3. Merge both result sets in memory, sort by updatedAt desc, then paginate

**Lesson:**
- When spec’ing Firestore queries, **design for its constraints explicitly**:
  - No naive OR conditions across fields
  - Document the exact multi-query and merge strategy
- Locking this pattern early prevents inconsistent implementations later

**Files:**
- `docs/SLICE_2_BUILD_CARD.md` - Section 5.3 `case.list`
- Future: `functions/src/functions/case.ts` - `caseList` implementation

---

### Learning 19: Cursor-Based vs Offset Pagination
**Date:** 2026-01-19  
**Context:** Slice 2 - Case list pagination strategy

**Issue:**
- Initial design used `limit/offset` pagination
- Firestore must scan and skip `offset` docs on every query
- This becomes expensive and slow as collections grow

**Solution:**
- Treat **cursor-based pagination** as the primary design:
  - Use `startAfter(lastUpdatedAt, lastCaseId)` with `orderBy(updatedAt, desc)`
  - Return `lastCaseId` (and/or `lastUpdatedAt`) from each page
  - Works well with infinite scroll UX
- Offset can be kept **only as an MVP fallback** and explicitly marked as tech debt

**Lesson:**
- For anything that should scale, **design cursor-based pagination from day one**
- If offset is used for MVP, document the migration path and thresholds (e.g. \"replace when >10k cases\")
- Think in terms of cursors, not pages, for Firestore/NoSQL

**Files:**
- `docs/SLICE_2_BUILD_CARD.md` - Pagination note in Section 5.3
- Future: `legal_ai_app/lib/features/cases/providers/case_provider.dart` - `loadMoreCases` using cursors

---

### Learning 20: Being Honest About Search Scope
**Date:** 2026-01-19  
**Context:** Slice 2 - Case search requirements

**Issue:**
- Spec language implied search across both title and description
- Firestore only supports simple prefix filtering on a single field without extra infra
- Risk of overpromising full-text search that doesn't exist

**Solution:**
- Define Slice 2 search as **title-only prefix search**:
  - `where('title', '>=', search)` and `where('title', '<=', search + '\\uf8ff')`
  - Case-sensitive, no fuzzy matching, no description search
- Explicitly document limitations and plan full-text search as a later slice (e.g. via searchTokens/Algolia)

**Lesson:**
- Specs must **tell the truth about capabilities**, especially around search
- Clearly state: what is searchable, how, and what is deferred
- Avoid vague \"search\" requirements when only prefix match is implemented

**Files:**
- `docs/SLICE_2_BUILD_CARD.md` - Search section in `case.list`
- Future: dedicated search slice build card

---

### Learning 21: Security Rules Must Be Concrete, Not Aspirational
**Date:** 2026-01-19  
**Context:** Slice 2 - Cases Firestore rules

**Issue:**
- Slice 0 defined concrete rules for orgs/members/audit_events
- Slice 2 initially just said \"add security rules for cases\" without specifics
- Risk: new collections shipped without proper defense-in-depth

**Solution:**
- Write explicit Firestore rules for `organizations/{orgId}/cases/{caseId}`:
  - `isOrgMember(orgId)` helper reused from Slice 0
  - Read allowed iff:\n    - User is org member AND\n    - (visibility == ORG_WIDE OR createdBy == request.auth.uid) AND\n    - deletedAt == null\n  - All client writes denied (Cloud Functions own the writes)
- Add a testing checklist for rules (member vs non-member, ORG_WIDE vs PRIVATE, soft-deleted, direct write attempts)

**Lesson:**
- For every new collection, **security rules are part of the spec, not an afterthought**
- Document rule expressions and test cases alongside the data model
- Keep Cloud Functions and Firestore rules aligned (defense-in-depth)

**Files:**
- `firestore.rules` - cases collection rules
- `docs/SLICE_2_BUILD_CARD.md` - Section 6.2

---

### Learning 22: State Persistence is a First-Class Requirement, Not a Nice-to-Have
**Date:** 2026-01-19  
**Context:** Slice 2 - Cases and organization disappearing after refresh

**Issue:**
- Organization had to be recreated on every refresh
- Cases list disappeared when switching tabs or refreshing
- No explicit requirements for state persistence in build card
- Assumed "session-only" state was acceptable

**Solution:**
- Added `SharedPreferences` for org persistence (save/load on app start)
- Used `IndexedStack` for tab navigation to preserve widget state
- Added explicit state persistence requirements to build card
- Created comprehensive testing/acceptance criteria document
- Added `user_id` persistence for org loading

**Lesson:**
- **State persistence must be explicitly specified in build cards**, not assumed
- Always test with browser refresh (F5) - catches most persistence issues
- Always test tab navigation - catches state preservation issues
- Use `IndexedStack` for tab navigation to preserve state
- Save critical state (org selection, user preferences) to `SharedPreferences`
- Reference [Testing & Acceptance Criteria](../TESTING_ACCEPTANCE_CRITERIA.md) for every slice
- **Don't assume "session-only" is acceptable** - ask explicitly about persistence requirements

**Files:**
- `docs/TESTING_ACCEPTANCE_CRITERIA.md` - Comprehensive testing framework
- `docs/SLICE_2_BUILD_CARD.md` - Updated with state persistence requirements
- `legal_ai_app/lib/features/home/providers/org_provider.dart` - Org persistence
- `legal_ai_app/lib/features/home/widgets/app_shell.dart` - IndexedStack for tabs
- `legal_ai_app/lib/features/auth/providers/auth_provider.dart` - User ID persistence

---

### Learning 23: PopupMenuButton onSelected May Not Fire for Null Values
**Date:** 2026-01-20  
**Context:** Slice 2 - "All statuses" filter not working after applying another filter

**Issue:**
- `PopupMenuButton` with `onSelected` callback
- "All statuses" option has `value: null`
- When switching from a filter (e.g., CLOSED) to "All statuses" (null), `onSelected` sometimes doesn't fire
- Filter state gets stuck, cases don't reload
- Multiple attempts to fix with state tracking variables didn't work

**Root Cause:**
- `PopupMenuButton.onSelected` may not reliably fire when:
  - The value is `null`
  - The value hasn't "changed" from Flutter's perspective
  - The menu item is tapped but the value is already considered selected

**Solution:**
- **Always add explicit `onTap` handler** to `PopupMenuItem` for critical actions
- Use `Future.microtask` or `Future.delayed` to ensure menu closes first
- Create a dedicated handler method (`_handleFilterChange`) that:
  - Updates state
  - Resets ALL tracking variables (org, filter, search)
  - Clears cases list
  - Triggers reload
- Don't rely solely on `onSelected` callback

**Code Pattern:**
```dart
PopupMenuItem<CaseStatus?>(
  value: null,
  onTap: () {
    // Explicit handler ensures it always fires
    Future.microtask(() {
      if (mounted) {
        _handleFilterChange(null);
      }
    });
  },
  child: const Text('All statuses'),
),
```

**Lesson:**
- **Never rely solely on `onSelected` for critical state changes**
- Always provide explicit `onTap` handlers for menu items that must work reliably
- When a filter/action "must work", use explicit handlers, not callbacks
- Test filter transitions thoroughly: A → B → A → All → B → All
- **Simple solutions are better** - don't overcomplicate with multiple tracking variables

**Time Lost:** ~4 hours debugging and multiple failed attempts

**Files:**
- `legal_ai_app/lib/features/cases/screens/case_list_screen.dart` - Filter handling with explicit `onTap`

---

### Learning 24: State Tracking Variables Can Cause More Problems Than They Solve
**Date:** 2026-01-20  
**Context:** Slice 2 - Cases list reload logic with multiple tracking variables

**Issue:**
- Added `_lastLoadedOrgId`, `_lastLoadedStatusFilter`, `_lastLoadedSearch` to prevent duplicate loads
- Complex logic to detect "what changed" before reloading
- When filter changed from CLOSED → null ("All statuses"), the change detection failed
- Multiple attempts to fix by resetting variables in different places
- Code became complex and hard to debug

**Root Cause:**
- Over-engineering the reload prevention logic
- Trying to be too clever about when to reload vs when to skip
- State tracking variables can get out of sync with actual state
- The "optimization" of preventing duplicate loads caused more bugs than it solved

**Solution:**
- **Simplify: Reset ALL tracking variables when filter changes**
- Don't try to be clever about detecting "what changed"
- When user explicitly changes filter, always reload (it's a user action, not a background refresh)
- Keep tracking variables only for preventing duplicate loads during the SAME filter/org/search combination
- When filter changes, reset everything and reload

**Code Pattern:**
```dart
void _handleFilterChange(CaseStatus? newStatus) {
  setState(() {
    _statusFilter = newStatus;
  });
  
  // Reset ALL tracking - simple and reliable
  _lastLoadedOrgId = null;
  _lastLoadedStatusFilter = null;
  _lastLoadedSearch = null;
  
  // Clear and reload
  caseProvider.clearCases();
  _loadInitial();
}
```

**Lesson:**
- **Simple solutions are better than clever optimizations**
- When user explicitly changes something (filter, search), always reload - don't try to optimize
- State tracking variables should prevent accidental duplicate loads, not prevent intentional reloads
- If tracking variables cause bugs, simplify or remove them
- **User actions should always trigger reloads** - don't try to be too smart

**Time Lost:** ~6 hours debugging complex state tracking logic

**Files:**
- `legal_ai_app/lib/features/cases/screens/case_list_screen.dart` - Simplified filter change handling

---

### Learning 25: didChangeDependencies Can Cause Infinite Rebuild Loops
**Date:** 2026-01-20  
**Context:** Slice 2 - Cases list flickering and infinite loading loops

**Issue:**
- Used `context.watch<OrgProvider>()` inside `didChangeDependencies`
- Every time provider changed, `didChangeDependencies` fired again
- This triggered another load, which updated provider, which fired `didChangeDependencies` again
- Result: Infinite loop, flickering UI, cases loading multiple times
- Multiple attempts to fix with flags (`_hasLoaded`, `_isLoading`, `_isHandlingOrgChange`)

**Root Cause:**
- `didChangeDependencies` fires when:
  - Inherited widgets change (theme, locale)
  - Parent rebuilds
  - Provider tree changes
  - Provider notifies listeners
- Using `context.watch()` inside `didChangeDependencies` creates a dependency that triggers rebuilds
- This creates a cycle: watch → change → didChangeDependencies → watch → change

**Solution:**
- **Use `context.read()` instead of `context.watch()` in lifecycle methods**
- Use `addListener()` pattern for reactive updates:
  ```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orgProvider = context.read<OrgProvider>();
      orgProvider.addListener(_onOrgChanged);
      // Initial load
      _checkAndLoadCases();
    });
  }
  
  void _onOrgChanged() {
    // React to org changes
    final org = context.read<OrgProvider>().selectedOrg;
    if (org?.orgId != _lastLoadedOrgId) {
      _handleOrgChange(org!.orgId);
    }
  }
  ```
- Remove `didChangeDependencies` entirely if using listener pattern
- Use listener pattern for reactive state changes, not lifecycle methods

**Lesson:**
- **Never use `context.watch()` in `didChangeDependencies`** - it creates rebuild loops
- Use `context.read()` for one-time reads in lifecycle methods
- Use `addListener()` pattern for reactive updates to providers
- **Listener pattern is cleaner than `didChangeDependencies` for provider changes**
- Test with browser refresh (F5) - catches most lifecycle issues

**Time Lost:** ~8 hours debugging infinite loops and flickering

**Files:**
- `legal_ai_app/lib/features/cases/screens/case_list_screen.dart` - Switched to listener pattern

---

### Learning 26: Excessive Debug Logging Slows Development
**Date:** 2026-01-20  
**Context:** Slice 2 - 86 debugPrint statements across codebase

**Issue:**
- Added verbose debug logging to track every step of execution
- Logs like "START loading", "END loaded", "Change check - org: true, search: false"
- Console flooded with logs, hard to find actual errors
- Made debugging harder, not easier
- Slowed down development trying to parse through logs

**Solution:**
- **Keep only error logs** - remove verbose trace logs
- Remove logs for:
  - Normal flow (START/END of operations)
  - State tracking details
  - Change detection details
- Keep logs for:
  - Errors and exceptions
  - Critical state changes (org changed, auth failed)
  - Warnings (missing data, unexpected states)
- Reduced from 86 to 34 debug statements (60% reduction)
- Code is cleaner and easier to debug

**Lesson:**
- **Less is more with logging** - verbose logs create noise
- Log errors, not normal flow
- Use structured logging if needed (log levels: ERROR, WARN, INFO, DEBUG)
- Clean up debug logs before committing
- **Production code should have minimal logging** - only errors and warnings

**Time Lost:** ~2 hours cleaning up excessive logs

**Files:**
- All provider and screen files - reduced verbose logging

---

### Learning 27: Test Edge Cases Early, Not After Multiple Fixes
**Date:** 2026-01-20  
**Context:** Slice 2 - Filter issues discovered late in development

**Issue:**
- Implemented filter functionality
- Tested basic flow: select filter → cases load
- Didn't test edge cases:
  - Filter A → Filter B → Filter A
  - Filter A → "All statuses" → Filter B → "All statuses"
  - Filter → Refresh → Filter
  - Filter → Switch org → Filter
- Discovered "All statuses" not working after multiple fixes to other issues
- Had to debug complex state tracking that was already in place

**Root Cause:**
- Testing only "happy path" scenarios
- Not testing filter transitions
- Not testing edge cases early
- Assumed if basic flow works, edge cases would work too

**Solution:**
- **Create test checklist for every feature:**
  - Basic flow (A works)
  - Transitions (A → B → A)
  - Edge cases (A → null → B → null)
  - State persistence (A → refresh → A)
  - Context changes (A → switch org → A)
- Test edge cases immediately after implementing feature
- Don't move on until edge cases work
- Document edge cases in build card

**Test Checklist for Filters:**
- [ ] Select filter → cases load correctly
- [ ] Select filter A → Select filter B → cases update
- [ ] Select filter → Select "All statuses" → all cases show
- [ ] Select "All statuses" → Select filter → filtered cases show
- [ ] Select filter → Refresh → filter persists and cases reload
- [ ] Select filter → Switch org → filter resets, cases load for new org
- [ ] Select filter → Search → filter + search work together
- [ ] Select filter → Clear search → filter still works

**Lesson:**
- **Test edge cases immediately, not after "everything works"**
- Create test checklist for every feature
- Don't assume edge cases will work if basic flow works
- **Edge cases are where bugs hide** - test them first
- Document edge cases in build card acceptance criteria

**Time Lost:** ~6 hours debugging edge cases that should have been tested earlier

**Files:**
- `docs/TESTING_ACCEPTANCE_CRITERIA.md` - Add filter edge case tests

---
### Learning 1: Firebase Callable Function Names
**Date:** 2026-01-17  
**Context:** Slice 1 - Organization creation failing with CORS errors

**Issue:**
- Code was calling functions as `org.create`, `org.join`, `member.getMyMembership`
- Functions are exported as `orgCreate`, `orgJoin`, `memberGetMyMembership`
- This mismatch caused function not found errors

**Solution:**
- Firebase callable functions use the **export name directly**, not a custom callable name
- If you export `export const orgCreate = functions.https.onCall(...)`, call it as `orgCreate`
- The comment "Callable Name: org.create" is just documentation, not the actual name

**Lesson:**
- Always check the actual export name in `functions/src/index.ts`
- Use the exact export name when calling from Flutter
- Don't rely on comments for function names

**Files:**
- `functions/src/index.ts` - Check exports
- `legal_ai_app/lib/core/services/cloud_functions_service.dart` - Use correct names

---

### Learning 2: Firebase Configuration for Flutter Web
**Date:** 2026-01-17  
**Context:** Slice 1 - Login failing with placeholder API keys

**Issue:**
- `firebase_options.dart` had placeholder values
- App couldn't connect to Firebase
- Error: `key=placeholder-web-api-key`

**Solution:**
- Must run `flutterfire configure` to generate real config
- Or manually update `firebase_options.dart` with values from Firebase Console
- Web app config is in: Firebase Console → Project Settings → General → Your apps → Web app

**Lesson:**
- Never use placeholder values in production
- Always verify `firebase_options.dart` has real API keys
- Check for "placeholder" strings before deploying

**Files:**
- `legal_ai_app/lib/firebase_options.dart` - Must have real values
- Firebase Console → Project Settings → General

---

### Learning 3: Cloud Functions Region Configuration
**Date:** 2026-01-17  
**Context:** Slice 1 - CORS errors when calling functions

**Issue:**
- Functions deployed to `us-central1`
- Flutter app not specifying region
- CORS errors occurring

**Solution:**
- Must specify region in `CloudFunctionsService`:
  ```dart
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  ```
- Region must match where functions are deployed

**Lesson:**
- Always specify the region explicitly
- Match the region to where functions are deployed
- Default region might not be `us-central1`

**Files:**
- `legal_ai_app/lib/core/services/cloud_functions_service.dart`

---

### Learning 4: CORS with Firebase Callable Functions
**Date:** 2026-01-17  
**Context:** Slice 1 - CORS policy blocking requests

**Issue:**
- CORS errors when calling Cloud Functions from localhost
- Error: "No 'Access-Control-Allow-Origin' header"

**Solution:**
- Firebase callable functions (`onCall`) handle CORS automatically
- But functions must be **deployed** to Firebase
- Local/emulator functions may have CORS issues
- Ensure functions are deployed: `firebase deploy --only functions`

**Lesson:**
- Callable functions handle CORS automatically when deployed
- Always deploy functions before testing from web app
- Check deployment status: `firebase functions:list`

**Files:**
- `functions/src/index.ts` - Functions must be exported
- Deployment: `firebase deploy --only functions`

---

## Flutter Development

### Learning 5: Flutter Web Platform Support
**Date:** 2026-01-17  
**Context:** Slice 1 - App not configured for web

**Issue:**
- Error: "This application is not configured to build on the web"
- `flutter run -d chrome` failing

**Solution:**
- Must add web platform: `flutter create . --platforms=web`
- Or use: `flutter create .` (adds all platforms)

**Lesson:**
- Web support not added by default in some Flutter versions
- Always add platform support before first run
- Check `web/` folder exists

**Files:**
- `legal_ai_app/web/` - Must exist for web builds

---

### Learning 6: Firebase Package Version Compatibility
**Date:** 2026-01-17  
**Context:** Slice 1 - Compilation errors with Firebase packages

**Issue:**
- Old Firebase package versions incompatible with Flutter 3.38.7
- Errors: `Type 'PromiseJsImpl' not found`, `Method 'handleThenable' not found`

**Solution:**
- Updated to compatible versions:
  - `firebase_core: ^3.6.0` (was ^2.24.0)
  - `firebase_auth: ^5.3.1` (was ^4.10.0)
  - `cloud_functions: ^5.1.6` (was ^4.6.0)

**Lesson:**
- Always check Flutter/package version compatibility
- Use `flutter pub outdated` to check for updates
- Test after updating major versions

**Files:**
- `legal_ai_app/pubspec.yaml` - Check package versions

---

### Learning 7: Hot Restart vs Hot Reload
**Date:** 2026-01-17  
**Context:** Slice 1 - Firebase config changes not taking effect

**Issue:**
- Updated `firebase_options.dart` but changes not reflected
- Hot reload (`r`) didn't pick up changes

**Solution:**
- Hot reload (`r`) doesn't reload Firebase initialization
- Must use hot restart (`R`) or full restart
- Configuration changes require full app restart

**Lesson:**
- Use hot restart (`R`) for:
  - Firebase configuration changes
  - Provider initialization changes
  - Route configuration changes
- Use hot reload (`r`) for:
  - UI changes
  - Widget styling
  - Simple state changes

---

### Learning 8: Error Message Visibility
**Date:** 2026-01-17  
**Context:** Slice 1 - Generic error messages not helpful

**Issue:**
- Error messages too generic ("Error", "Login failed")
- Hard to debug issues
- Browser console had more details

**Solution:**
- Added `debugPrint()` statements for detailed logging
- Enhanced error handling with specific error codes
- Show detailed errors in UI (with user-friendly messages)
- Always check browser console (F12) for full error details

**Lesson:**
- Always log detailed errors for debugging
- Show user-friendly messages in UI
- Check browser console for full error stack
- Use `debugPrint()` instead of `print()` in Flutter

**Files:**
- `legal_ai_app/lib/core/services/auth_service.dart`
- `legal_ai_app/lib/core/services/cloud_functions_service.dart`
- `legal_ai_app/lib/features/auth/providers/auth_provider.dart`

---

## Development Environment

### Learning 9: PowerShell Execution Issues
**Date:** 2026-01-17  
**Context:** Multiple attempts to run PowerShell scripts

**Issue:**
- PowerShell scripts failing with syntax errors
- Errors: `Missing ')'`, `Unexpected token '{'`
- Scripts not executing properly

**Solution:**
- Created `.bat` files instead of `.ps1` for Windows
- `.bat` files more reliable for simple automation
- Use `cmd /c` wrapper when needed
- Provide manual command alternatives

**Lesson:**
- `.bat` files more reliable than `.ps1` for simple tasks
- Always provide manual command alternatives
- Test scripts before sharing
- Consider cross-platform compatibility

**Files:**
- Various `.bat` files in `legal_ai_app/` and root

---

### Learning 10: Flutter PATH Configuration
**Date:** 2026-01-17  
**Context:** Flutter not found in PATH

**Issue:**
- Flutter installed but not accessible
- Error: `'flutter' is not recognized`

**Solution:**
- Add Flutter to PATH: `C:\src\flutter\bin`
- Use `setx PATH` or Environment Variables UI
- Must close and reopen terminal after PATH change
- Verify: `flutter --version`

**Lesson:**
- Always verify PATH after installation
- Close/reopen terminal after PATH changes
- Provide verification commands
- Create helper scripts to check installation

**Files:**
- `legal_ai_app/add-flutter-to-path.bat`
- `legal_ai_app/check-flutter.bat`

---

### Learning 11: Git Repository Scope
**Date:** 2026-01-17  
**Context:** Git trying to track files outside project

**Issue:**
- Git initialized in parent directory
- Trying to track files outside project
- Permission errors

**Solution:**
- Initialize Git in project directory only
- Use `.gitignore` to exclude unwanted files
- Check Git root: `git rev-parse --show-toplevel`

**Lesson:**
- Always initialize Git in project root
- Check Git root before committing
- Use `.gitignore` properly
- Verify what files Git is tracking

---

## Error Handling & Debugging

### Learning 12: Browser Console is Essential
**Date:** 2026-01-17  
**Context:** Debugging CORS and Firebase errors

**Issue:**
- App errors not showing full details
- Generic error messages

**Solution:**
- Always check browser console (F12 → Console)
- Browser console shows:
  - Full error stack traces
  - Network request details
  - CORS errors
  - Firebase errors
- Use `debugPrint()` to log to console

**Lesson:**
- Browser console is the best debugging tool for web apps
- Always check console when errors occur
- Log important events with `debugPrint()`
- Network tab shows API call details

---

### Learning 13: Error Message Patterns
**Date:** 2026-01-17  
**Context:** Identifying error types

**Common Error Patterns:**
- `key=placeholder-*` → Firebase not configured
- `CORS policy` → Functions not deployed or region mismatch
- `user-not-found` → User doesn't exist in Firebase
- `wrong-password` → Password incorrect
- `Type 'PromiseJsImpl' not found` → Package version mismatch
- `internal` → Usually CORS or function not found

**Lesson:**
- Learn to recognize error patterns
- Create error handling for common patterns
- Provide specific solutions for each pattern

---

## Best Practices

### Learning 14: Repository Organization
**Date:** 2026-01-17  
**Context:** Root directory getting cluttered

**Best Practice:**
- Keep root directory clean
- Organize by purpose:
  - `docs/` - All documentation
  - `scripts/dev/` - Development scripts
  - `scripts/ops/` - Operations scripts
- Only essential config files in root

**Lesson:**
- Plan folder structure early
- Enforce organization rules
- Update Master Spec with structure guidelines
- Review structure regularly

**Files:**
- `docs/MASTER_SPEC V1.3.2.md` - Section 2.7

---

### Learning 15: Documentation as You Go
**Date:** 2026-01-17  
**Context:** Forgetting what was done

**Best Practice:**
- Document issues and solutions immediately
- Update completion docs with learnings
- Keep troubleshooting guides updated
- Create learnings document (this file)

**Lesson:**
- Don't wait to document
- Capture learnings while fresh
- Link related documents
- Make documentation searchable

---

### Learning 16: Test User Management
**Date:** 2026-01-17  
**Context:** Need consistent test credentials

**Best Practice:**
- Create dedicated test users
- Document test credentials
- Use consistent naming: `test-{date}@test.com`
- Keep test users in Firebase Console

**Lesson:**
- Standardize test user creation
- Document credentials clearly
- Don't use production users for testing
- Create users via Console or app

---

## Common Pitfalls

### Pitfall 1: Assuming Functions Auto-Handle Everything
**Issue:** Assuming Firebase handles all configuration automatically  
**Reality:** Many things need manual configuration  
**Solution:** Always verify configuration, don't assume

### Pitfall 2: Not Checking Browser Console
**Issue:** Only looking at app error messages  
**Reality:** Browser console has full error details  
**Solution:** Always check F12 → Console first

### Pitfall 3: Not Verifying Deployment
**Issue:** Assuming functions are deployed  
**Reality:** Functions might not be deployed or need redeploy  
**Solution:** Always verify: `firebase functions:list`

### Pitfall 4: Using Placeholder Values
**Issue:** Forgetting to replace placeholder config  
**Reality:** Placeholders cause runtime errors  
**Solution:** Always verify no placeholders before testing

### Pitfall 5: Function Name Mismatches
**Issue:** Using wrong function names  
**Reality:** Export names must match call names exactly  
**Solution:** Always check `functions/src/index.ts` for actual names

---

## Quick Reference

### Firebase Configuration Checklist
- [ ] Run `flutterfire configure`
- [ ] Verify `firebase_options.dart` has real values (no placeholders)
- [ ] Check Email/Password is enabled in Firebase Console
- [ ] Verify functions are deployed: `firebase functions:list`
- [ ] Check region matches: `us-central1`

### Flutter Setup Checklist
- [ ] Flutter installed and in PATH
- [ ] Web platform added: `flutter create . --platforms=web`
- [ ] Dependencies installed: `flutter pub get`
- [ ] No analysis errors: `flutter analyze`
- [ ] App runs: `flutter run -d chrome`

### Debugging Checklist
- [ ] Check browser console (F12)
- [ ] Check Flutter terminal output
- [ ] Verify Firebase configuration
- [ ] Check function deployment status
- [ ] Verify function names match
- [ ] Check region configuration

---

## How to Use This Document

1. **Before Starting New Work:**
   - Review relevant learnings section
   - Check common pitfalls
   - Review quick reference

2. **When Encountering Issues:**
   - Search this document for similar issues
   - Check if solution exists
   - Add new learning if new issue found

3. **After Completing Work:**
   - Document any new learnings
   - Update relevant sections
   - Add to quick reference if needed

---

## Contributing to This Document

When you discover a new learning:

1. **Add to appropriate section** (or create new section)
2. **Include:**
   - Date
   - Context (what you were doing)
   - Issue (what went wrong)
   - Solution (how you fixed it)
   - Lesson (what to remember)
   - Related files

3. **Update table of contents** if adding new section

4. **Link from related documents** if relevant

---

**Last Updated:** 2026-01-20  
**Next Review:** After Slice 3 completion
