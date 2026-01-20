# Testing & Acceptance Criteria Framework

**Purpose:** Comprehensive, reusable acceptance criteria for all slices to ensure nothing is missed.

**Last Updated:** 2026-01-19

---

## Table of Contents

1. [Core State Persistence Requirements](#core-state-persistence-requirements)
2. [Navigation & Tab State Requirements](#navigation--tab-state-requirements)
3. [Data Loading & Refresh Requirements](#data-loading--refresh-requirements)
4. [Authentication & Session Requirements](#authentication--session-requirements)
5. [Error Handling & Edge Cases](#error-handling--edge-cases)
6. [Performance Requirements](#performance-requirements)
7. [Testing Checklist Template](#testing-checklist-template)

---

## Core State Persistence Requirements

### ✅ Organization State
**Must persist across:**
- Browser refresh (F5)
- Tab close/reopen
- App restart
- Navigation away and back

**Must NOT persist across:**
- User logout
- Different user login

**Implementation Requirements:**
- Save to `SharedPreferences` (or equivalent)
- Load on app initialization (SplashScreen)
- Clear on logout
- Verify org still exists and user is still a member on load

**Test Cases:**
1. ✅ Create org → Refresh page → Org still selected
2. ✅ Create org → Close tab → Reopen app → Org still selected
3. ✅ Create org → Logout → Login → Org still selected (if same user)
4. ✅ Create org → Logout → Different user login → Org NOT selected
5. ✅ Create org → Delete org → Refresh → Org selection screen shown

---

### ✅ User Session State
**Must persist across:**
- Browser refresh (F5)
- Tab close/reopen
- App restart

**Must NOT persist across:**
- Explicit logout
- Session expiration

**Implementation Requirements:**
- Firebase Auth handles session persistence
- Save `user_id` to `SharedPreferences` for org loading
- Clear `user_id` on logout

**Test Cases:**
1. ✅ Login → Refresh → Still logged in
2. ✅ Login → Close tab → Reopen → Still logged in
3. ✅ Login → Logout → Refresh → Login screen shown
4. ✅ Login → Wait for session expiry → Refresh → Login screen shown

---

### ✅ Data List State (Cases, Clients, etc.)
**Must persist across:**
- Tab navigation (switching between tabs)
- Screen navigation (going to details and back)

**Must reload from backend:**
- After browser refresh
- After app restart
- On explicit refresh (pull-to-refresh)

**Must NOT reload unnecessarily:**
- When switching tabs (if data already loaded)
- When navigating to details and back (if data already loaded)

**Implementation Requirements:**
- Use `IndexedStack` for tab navigation (preserves widget state)
- Store data in Provider (in-memory state)
- Load from backend on first access or after refresh
- Implement pull-to-refresh for manual reload

**Test Cases:**
1. ✅ Load cases → Switch to Clients tab → Switch back to Cases → Cases still visible
2. ✅ Load cases → Click case details → Go back → Cases still visible
3. ✅ Load cases → Refresh page → Cases reload from backend
4. ✅ Load cases → Close tab → Reopen → Cases reload from backend
5. ✅ Create case → Cases list updates immediately (no refresh needed)
6. ✅ Create case → Switch tabs → Switch back → New case still in list

---

## Navigation & Tab State Requirements

### ✅ Tab Navigation
**Requirements:**
- Switching tabs does NOT clear data
- Switching tabs does NOT reload data unnecessarily
- Tab state preserved using `IndexedStack`

**Test Cases:**
1. ✅ Cases tab → Clients tab → Cases tab → Cases still visible
2. ✅ Cases tab (with search/filter) → Clients tab → Cases tab → Search/filter preserved
3. ✅ Cases tab (scrolled to position) → Clients tab → Cases tab → Scroll position preserved

---

### ✅ Screen Navigation
**Requirements:**
- Navigating to details and back preserves list state
- Navigation history works correctly
- Deep links work (if implemented)

**Test Cases:**
1. ✅ Case list → Case details → Back → Case list unchanged
2. ✅ Case list (scrolled) → Case details → Back → Scroll position preserved
3. ✅ Case list (filtered) → Case details → Back → Filter preserved

---

## Data Loading & Refresh Requirements

### ✅ Initial Load
**Requirements:**
- Data loads automatically when screen first appears
- Loading state shown while fetching
- Error state shown if fetch fails
- Empty state shown if no data

**Test Cases:**
1. ✅ Open Cases tab → Loading spinner → Cases appear
2. ✅ Open Cases tab → Loading spinner → Error message if fetch fails
3. ✅ Open Cases tab → Loading spinner → Empty state if no cases

---

### ✅ Refresh Behavior
**Requirements:**
- Pull-to-refresh reloads data from backend
- Browser refresh (F5) reloads data from backend
- Data persists in memory during session (until refresh)

**Test Cases:**
1. ✅ Cases list → Pull down → Refresh → Cases reload
2. ✅ Cases list → F5 → Cases reload from backend
3. ✅ Cases list → Create case → Cases list updates (no refresh needed)

---

### ✅ Data Consistency
**Requirements:**
- Created items appear immediately in list
- Updated items reflect changes immediately
- Deleted items disappear immediately
- Changes sync across tabs (if applicable)

**Test Cases:**
1. ✅ Create case → Case appears in list immediately
2. ✅ Update case → Changes visible in list immediately
3. ✅ Delete case → Case disappears from list immediately
4. ✅ Create case in tab 1 → Switch to tab 2 → Switch back → Case still visible

---

## Authentication & Session Requirements

### ✅ Login Flow
**Requirements:**
- User can login with email/password
- Session persists across refresh
- User redirected to appropriate screen after login

**Test Cases:**
1. ✅ Login → Redirected to org selection or home
2. ✅ Login → Refresh → Still logged in
3. ✅ Login → Close tab → Reopen → Still logged in

---

### ✅ Logout Flow
**Requirements:**
- Logout clears all user data from memory
- Logout clears persisted org selection
- Logout redirects to login screen
- Different user can login after logout

**Test Cases:**
1. ✅ Logout → Redirected to login
2. ✅ Logout → Refresh → Login screen shown
3. ✅ Logout → Different user login → No data from previous user

---

### ✅ Org Selection Flow
**Requirements:**
- User can create org
- User can select existing org (if multiple)
- Selected org persists across refresh
- Org selection required before accessing app features

**Test Cases:**
1. ✅ No org → Redirected to org selection
2. ✅ Create org → Org selected automatically
3. ✅ Create org → Refresh → Org still selected
4. ✅ Select org → Refresh → Org still selected

---

## Error Handling & Edge Cases

### ✅ Network Errors
**Requirements:**
- Network errors shown to user
- Retry mechanism available
- Graceful degradation

**Test Cases:**
1. ✅ No internet → Error message shown
2. ✅ Network error → Retry button works
3. ✅ Slow network → Loading state shown

---

### ✅ Backend Errors
**Requirements:**
- Backend errors shown to user
- Error messages are user-friendly
- Errors don't crash the app

**Test Cases:**
1. ✅ Invalid input → Error message shown
2. ✅ Permission denied → Error message shown
3. ✅ Server error → Error message shown (not crash)

---

### ✅ Edge Cases
**Requirements:**
- Empty states handled
- Null/undefined data handled
- Invalid data handled
- Concurrent operations handled

**Test Cases:**
1. ✅ No cases → Empty state shown
2. ✅ Invalid case ID → Error message shown
3. ✅ Create case while list loading → No duplicate creation
4. ✅ Delete case while viewing details → Redirected to list

---

## Performance Requirements

### ✅ Loading Performance
**Requirements:**
- Initial load < 2 seconds
- Navigation < 500ms
- Data refresh < 1 second

**Test Cases:**
1. ✅ App startup → Home screen in < 2 seconds
2. ✅ Tab switch → New tab in < 500ms
3. ✅ Pull refresh → Data loaded in < 1 second

---

### ✅ Memory Performance
**Requirements:**
- No memory leaks
- Efficient state management
- Proper cleanup on dispose

**Test Cases:**
1. ✅ Navigate between screens → No memory leaks
2. ✅ Switch tabs repeatedly → No performance degradation
3. ✅ Create/delete many items → No memory issues

---

## Testing Checklist Template

### For Each New Slice:

#### State Persistence
- [ ] Organization persists across refresh
- [ ] User session persists across refresh
- [ ] Data lists persist across tab navigation
- [ ] Data reloads from backend after refresh

#### Navigation
- [ ] Tab navigation preserves state
- [ ] Screen navigation preserves state
- [ ] Back navigation works correctly

#### Data Operations
- [ ] Create → Appears immediately
- [ ] Update → Changes visible immediately
- [ ] Delete → Disappears immediately
- [ ] List loads on first access
- [ ] List reloads on refresh

#### Error Handling
- [ ] Network errors handled
- [ ] Backend errors handled
- [ ] Empty states shown
- [ ] Invalid data handled

#### Performance
- [ ] Initial load < 2 seconds
- [ ] Navigation < 500ms
- [ ] No memory leaks
- [ ] Efficient state management

---

## Implementation Guidelines

### State Persistence Pattern
```dart
// Save to SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', value);

// Load on initialization
final value = prefs.getString('key');
```

### Tab Navigation Pattern
```dart
// Use IndexedStack to preserve state
IndexedStack(
  index: _selectedIndex,
  children: _screens,
)
```

### Data Loading Pattern
```dart
// Load on first access or after refresh
if (!_hasLoaded || data.isEmpty) {
  await loadData();
  _hasLoaded = true;
}
```

---

## Notes

- **Always test with browser refresh (F5)** - This catches most persistence issues
- **Always test tab navigation** - This catches state preservation issues
- **Always test logout/login** - This catches session management issues
- **Always test empty states** - This catches edge cases
- **Always test error scenarios** - This catches error handling issues

---

**Next Steps:**
1. Use this checklist for every new slice
2. Update this document as new patterns emerge
3. Reference this document in build cards
