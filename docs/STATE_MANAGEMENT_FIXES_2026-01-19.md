# State Management Fixes - January 19, 2026

## Overview
Comprehensive fixes for Cases page flickering, org list persistence, and state management issues based on thorough code review.

## Critical Improvements

### 1. Cases Page Flickering - Fixed with Hard Guards

**Problem**: Infinite reload loop caused by `didChangeDependencies` triggering on every rebuild.

**Solution**:
- Added `_lastLoadedOrgId` guard to prevent reloading for the same org
- Moved primary load logic to `initState` with `addPostFrameCallback`
- `didChangeDependencies` now only handles org switching (when org ID changes)
- Multiple guards prevent duplicate loads:
  - `_isLoading` flag
  - `_hasLoaded` flag
  - `_lastLoadedOrgId` comparison

**Key Code**:
```dart
String? _lastLoadedOrgId; // Prevents reload loops

// Only reload if org ID actually changed
if (currentOrgId != null && 
    currentOrgId != _lastLoadedOrgId &&
    !_isLoading) {
  // Load cases
}
```

### 2. Org List Persistence - Fixed with Proper Restoration

**Problem**: Org list disappeared after refresh due to auth token restoration timing.

**Solution**:
- `loadUserOrgs()` now called on every screen visit (via `didChangeDependencies`)
- Org restoration verifies org exists in backend list before restoring
- Stale org IDs are cleared if not found in user's org list
- Comprehensive logging tracks restoration flow

**Key Code**:
```dart
// Verify org exists in loaded list before restoring
final orgExistsInList = _userOrgs.any((o) => o.orgId == orgId);
if (orgExistsInList) {
  // Restore org
} else {
  // Clear stale org
}
```

### 3. Error Handling - Improved with Soft Warnings

**Problem**: Transient errors shown during loading caused flickering.

**Solution**:
- Full error UI only shown when cases are empty
- Soft warnings logged (not shown) when cases exist but error occurred
- Errors cleared on successful loads
- Prevents false error persistence

### 4. Selected Org Persistence - Safer Logic

**Problem**: Adding orgs to list that don't exist in backend could create ghost orgs.

**Solution**:
- `setSelectedOrg` verifies org exists in user orgs list
- Only adds to list if not present (handles newly created/joined orgs)
- Logs warnings when org not found in list

### 5. Comprehensive Logging

**Added logging for**:
- `loadUserOrgs()` start/end with timestamps
- `restoreSelectedOrgId()` with verification steps
- `setSelectedOrg()` with org details
- `loadCases()` start/end with duration and case count
- All operations include orgId and timestamps

**Example Log Output**:
```
OrgProvider.initialize: START at 2026-01-19 10:30:00
OrgProvider.loadUserOrgs: START at 2026-01-19 10:30:01
OrgProvider.loadUserOrgs: END successfully loaded 3 organizations in 250ms
OrgProvider.initialize: Successfully restored org MyOrg (org_123)
CaseListScreen._tryLoadCases: START loading cases at 2026-01-19 10:30:02
CaseListScreen._tryLoadCases: END loaded 15 cases in 180ms
```

## Testing Checklist

### Basic Tests
- [x] Login → Org list appears
- [x] Click org → Navigate to Cases without flickering
- [x] Refresh browser → Org list persists
- [x] Refresh browser → Cases reload automatically
- [x] Switch between tabs → State preserved
- [x] Switch orgs → Smooth navigation

### Killer Tests (Critical Scenarios)

#### 1. Org Switching Test
- Switch org A → org B → org A
- **Expected**: Cases refresh correctly, no remnants from previous org
- **Check logs**: Verify `_lastLoadedOrgId` changes correctly

#### 2. Direct Route Access
- Open Cases directly via route (e.g., `/cases`)
- Refresh on `/cases` route
- **Expected**: Org restored, cases fetched automatically
- **Check logs**: Verify initialization flow

#### 3. Logout/Login Cycle
- Log out, then log back in
- **Expected**: No stale selectedOrg causing blank screen
- **Check logs**: Verify org restoration doesn't use stale data

#### 4. Network Failure Simulation
- Disable internet, open cases
- **Expected**: Correct error displayed, no flicker
- **Check logs**: Verify error handling doesn't trigger reload loops

#### 5. Token Expiry
- Simulate 401 error (token expired)
- **Expected**: Clean redirect to login, no flicker loop
- **Check logs**: Verify auth state changes handled correctly

#### 6. Rapid Org Switching
- Spam click orgs quickly (5-10 clicks in 1 second)
- **Expected**: Debouncing works, final org selected correctly
- **Check logs**: Verify only final org's cases are loaded

## Debugging Guide

### Enable Debug Logging
All critical operations now log with timestamps. Check browser console for:
- `CaseListScreen.*` - Cases loading operations
- `OrgProvider.*` - Org state management
- Look for patterns like:
  - Multiple "START" without "END" = operation stuck
  - Same orgId loaded multiple times = reload loop
  - "Already loaded" messages = guards working correctly

### Common Issues

#### Issue: Cases still flickering
**Check**:
1. Look for multiple `_tryLoadCases: START` logs with same orgId
2. Verify `_lastLoadedOrgId` is being set correctly
3. Check if `didChangeDependencies` is being called repeatedly

#### Issue: Org list disappears
**Check**:
1. Look for `loadUserOrgs: START` logs
2. Verify auth token is available when `loadUserOrgs` runs
3. Check for errors in `loadUserOrgs: ERROR` logs

#### Issue: Wrong org selected after refresh
**Check**:
1. Look for `initialize: Successfully restored org` log
2. Verify restored orgId exists in `loadUserOrgs` results
3. Check if stale orgId was cleared

## Performance Impact

### Before
- Multiple unnecessary reloads
- Cascading rebuild storms
- API calls on every rebuild

### After
- Single load per org
- Minimal rebuilds
- Batched state updates
- Guarded operations prevent duplicate work

## Next Steps

1. **Monitor logs** in production to verify fixes
2. **Add metrics** for:
   - Average cases load time
   - Org switch frequency
   - Error rates
3. **Consider adding**:
   - SnackBar for soft warnings when cases exist but refresh fails
   - Loading indicators during org switches
   - Retry mechanisms for failed loads

## Files Modified

- `legal_ai_app/lib/features/cases/screens/case_list_screen.dart`
- `legal_ai_app/lib/features/home/providers/org_provider.dart`
- `legal_ai_app/lib/features/home/screens/org_selection_screen.dart`
- `legal_ai_app/lib/features/cases/providers/case_provider.dart`

## Verification

Run the app and check browser console for the logging output. All operations should show:
- START/END pairs
- Timestamps
- Org IDs
- Operation durations
- No duplicate loads for same org
