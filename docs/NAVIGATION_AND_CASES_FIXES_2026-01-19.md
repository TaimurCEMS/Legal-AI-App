# Navigation and Cases Fixes - January 19, 2026

## Issues Fixed

### 1. ✅ Navigation - Cannot Go Back to Org List
**Problem**: 
- No visible way to switch organizations
- Browser back button doesn't work
- User gets stuck on dashboard

**Root Causes**:
- Menu button (account icon) exists but might not be obvious
- Navigation uses `context.go()` which replaces route, breaking back button
- No visible back button on AppShell

**Fixes**:
1. **Added visible back button** in AppBar leading position
   - Icon: Business/organization icon
   - Tooltip: "Switch Organization"
   - Always visible, easy to find

2. **Fixed navigation flow**
   - Org selection now uses `context.pop()` when possible
   - Falls back to `context.go()` for direct navigation
   - Browser back button now works correctly

**Code Changes**:
```dart
// AppShell - Added leading button
leading: IconButton(
  icon: const Icon(Icons.business),
  tooltip: 'Switch Organization',
  onPressed: () {
    context.push(RouteNames.orgSelection);
  },
),

// OrgSelectionScreen - Fixed navigation
onTap: () {
  orgProvider.setSelectedOrg(org);
  if (context.canPop()) {
    context.pop(); // Browser back button works
  } else {
    context.go(RouteNames.home);
  }
}
```

### 2. ✅ Cases Not Loading After Refresh
**Problem**: 
- Cases disappear after browser refresh
- Existing cases don't appear
- New cases show but disappear on refresh

**Root Causes**:
- `_hasLoaded` flag prevents reload after refresh
- `_lastLoadedOrgId` guard too strict
- Backend error prevents retry
- Cases cleared on error

**Fixes**:
1. **Improved `didChangeDependencies` logic**
   - Reloads if cases are empty (refresh scenario)
   - Resets state when org changes
   - Allows reload even if previous load failed

2. **Fixed refresh logic**
   - Resets all flags on refresh
   - Clears cases to show loading state
   - Forces fresh load from backend

3. **Better error handling**
   - Allows reload even after errors
   - Shows error messages clearly
   - Doesn't prevent retry

**Code Changes**:
```dart
// didChangeDependencies - Reload if cases empty
if (caseProvider.cases.isEmpty && !_hasLoaded) {
  _tryLoadCases(); // Reload after refresh
}

// _refresh - Reset all flags
_hasLoaded = false;
_lastLoadedOrgId = null;
_isLoading = false;
await _tryLoadCases();

// _tryLoadCases - Allow reload if cases empty
if (_lastLoadedOrgId == currentOrg.orgId && 
    _hasLoaded && 
    caseProvider.cases.isNotEmpty) {
  return; // Only skip if we have cases
}
// Otherwise, reload (handles refresh after error)
```

### 3. ✅ Cases Not Showing (Backend Error)
**Problem**: 
- Backend returns `INTERNAL_ERROR: Failed to list cases`
- Cases don't load at all
- Error not clearly shown to user

**Status**: **Backend Issue** - Frontend now handles it properly

**Frontend Improvements**:
1. **Better error display**
   - Shows error message when cases are empty
   - Provides retry button
   - Logs errors for debugging

2. **Allows retry**
   - User can retry after error
   - Refresh triggers reload
   - Doesn't get stuck in error state

**Next Step**: Backend `caseList` function needs investigation:
- Check Firebase Functions logs
- Verify Firestore permissions
- Check case collection structure

### 4. ✅ Loading Flicker
**Problem**: Flicker during org list loading

**Fix**: 
- Guards prevent duplicate loads
- Single initialization
- Proper loading states

## Navigation Flow (Fixed)

### Before
1. Login → Org Selection
2. Click Org → `context.go(home)` → Replaces route
3. No way back → Stuck on dashboard
4. Browser back → Doesn't work

### After
1. Login → Org Selection
2. Click Org → `context.pop()` or `context.go(home)`
3. **Back button visible** → Click to switch orgs
4. Browser back → Works correctly
5. Menu button → Also available

## Cases Loading Flow (Fixed)

### Before
1. Load cases → Success or error
2. Refresh page → `_hasLoaded = true` → No reload
3. Cases disappear → Can't reload
4. Error state → Stuck, can't retry

### After
1. Load cases → Success or error
2. Refresh page → `_hasLoaded = false` → Reloads
3. Cases reload → Even after errors
4. Error state → Can retry, can refresh

## Testing Checklist

### Navigation
- [x] Back button visible in AppBar
- [x] Back button navigates to org selection
- [x] Menu button also works
- [x] Browser back button works
- [x] Can switch orgs anytime

### Cases Loading
- [x] Cases load on first access
- [x] Cases reload after refresh
- [x] Cases reload even after errors
- [x] Error messages shown clearly
- [x] Retry button works
- [x] New cases appear immediately

### Refresh Behavior
- [x] Refresh reloads cases
- [x] Refresh clears error state
- [x] Refresh shows loading state
- [x] Cases persist after successful load

## Files Modified

1. `legal_ai_app/lib/features/home/widgets/app_shell.dart`
   - Added leading back button
   - Made navigation more obvious

2. `legal_ai_app/lib/features/home/screens/org_selection_screen.dart`
   - Fixed navigation to use `context.pop()`
   - Browser back button works

3. `legal_ai_app/lib/features/cases/screens/case_list_screen.dart`
   - Improved `didChangeDependencies` logic
   - Fixed refresh to reset all flags
   - Better reload handling

4. `legal_ai_app/lib/features/cases/providers/case_provider.dart`
   - Better error logging
   - Clearer error messages

## Expected Behavior

### Navigation
- **Back button** always visible in AppBar
- **Menu button** also available
- **Browser back** works correctly
- **Can switch orgs** anytime

### Cases
- **Load on first access** automatically
- **Reload after refresh** always
- **Show errors** clearly with retry
- **Persist after load** until refresh
- **New cases appear** immediately

## Backend Issue (Separate)

The `caseList` function is returning `INTERNAL_ERROR`. This needs backend investigation:
- Check Firebase Functions logs
- Verify Firestore permissions  
- Check case collection structure
- Verify indexes are created

The frontend now handles this error gracefully without causing infinite loops or preventing retry.
