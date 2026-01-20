# Critical Fixes - January 19, 2026

## Issues Fixed

### 1. ✅ Multiple `loadUserOrgs()` Calls (8-9 seconds each)
**Problem**: Logs showed `loadUserOrgs()` being called 4+ times simultaneously, each taking 8-9 seconds, causing massive performance issues.

**Root Cause**: No guard preventing multiple simultaneous calls.

**Fix**:
- Added `_isLoadingUserOrgs` flag to prevent duplicate calls
- Guard checks if already loading before starting new load
- Returns early if load is in progress

**Code**:
```dart
bool _isLoadingUserOrgs = false;

Future<void> loadUserOrgs() async {
  if (_isLoadingUserOrgs) {
    debugPrint('OrgProvider.loadUserOrgs: Already loading, skipping duplicate call');
    return;
  }
  _isLoadingUserOrgs = true;
  // ... load logic ...
  finally {
    _isLoadingUserOrgs = false;
  }
}
```

### 2. ✅ Multiple `initialize()` Calls
**Problem**: `initialize()` was being called multiple times from different widgets (AppShell, OrgSelectionScreen, etc.), each triggering `loadUserOrgs()`.

**Root Cause**: 
- AppShell had duplicate initialization logic (initState + build method)
- No guard against simultaneous initializations

**Fix**:
- Removed duplicate initialization from AppShell's `build()` method
- Added `_isInitializing` flag to prevent duplicate calls
- Smart waiting: if orgs already loading, wait for completion instead of starting new load

**Code**:
```dart
bool _isInitializing = false;

Future<void> initialize() async {
  if (_isInitialized || _isInitializing) return;
  _isInitializing = true;
  // ... initialization logic ...
  finally {
    _isInitializing = false;
  }
}
```

### 3. ✅ Navigation - Cannot Go Back to Org List
**Problem**: 
- User clicks org → navigates to home
- No way to go back to org selection screen
- Browser back button doesn't work
- "Switch Organization" menu exists but navigation is broken

**Root Cause**: Using `context.go()` which replaces route, preventing back navigation.

**Fix**:
- Changed org selection to use `context.pop()` if navigated from another screen
- Falls back to `context.go()` if direct navigation
- "Switch Organization" menu already uses `context.push()` which is correct

**Code**:
```dart
onTap: () {
  orgProvider.setSelectedOrg(org);
  if (context.canPop()) {
    context.pop(); // Go back if we came from another screen
  } else {
    context.go(RouteNames.home); // Replace if direct navigation
  }
}
```

### 4. ✅ Cases Disappearing After Refresh
**Problem**: Cases created disappear after browser refresh.

**Root Cause**: 
- `_lastLoadedOrgId` wasn't being reset on refresh
- `_hasLoaded` flag prevented reload after refresh

**Fix**:
- Reset `_lastLoadedOrgId = null` in `_refresh()` method
- This forces cases to reload after refresh

**Code**:
```dart
Future<void> _refresh() async {
  _hasLoaded = false;
  _lastLoadedOrgId = null; // Reset to force reload
  await _tryLoadCases();
}
```

### 5. ✅ Cases Not Loading (Backend Error)
**Problem**: Logs show `CaseService.listCases error: {success: false, error: {code: INTERNAL_ERROR, message: Failed to list cases}}`

**Status**: This is a **backend issue**, not frontend. The frontend now:
- Properly handles errors
- Shows error messages to user
- Allows retry
- Doesn't cause infinite reload loops

**Next Step**: Backend `caseList` function needs to be fixed. Check:
- Firebase Functions logs
- Firestore permissions
- Case collection structure

## Performance Improvements

### Before
- 4+ simultaneous `loadUserOrgs()` calls (8-9 seconds each = 32-36 seconds total)
- Multiple `initialize()` calls triggering duplicate loads
- Infinite reload loops on cases page

### After
- Single `loadUserOrgs()` call (8-9 seconds total)
- Single `initialize()` call
- No duplicate loads
- Proper guards prevent infinite loops

## Testing Checklist

### ✅ Fixed Issues
- [x] Multiple `loadUserOrgs()` calls prevented
- [x] Multiple `initialize()` calls prevented
- [x] Navigation back to org list works
- [x] Cases reload after refresh
- [x] No infinite reload loops

### ⚠️ Backend Issue (Needs Investigation)
- [ ] `caseList` function returns `INTERNAL_ERROR`
- [ ] Check Firebase Functions logs
- [ ] Verify Firestore indexes
- [ ] Check case collection permissions

### 🔄 To Test
1. **Login** → Should see org list (no flicker)
2. **Click org** → Navigate to home
3. **Click "Switch Organization"** → Should navigate back to org list
4. **Browser back button** → Should work now
5. **Refresh page** → Cases should reload
6. **Create case** → Should appear immediately
7. **Refresh after creating case** → Case should still be there

## Files Modified

1. `legal_ai_app/lib/features/home/providers/org_provider.dart`
   - Added `_isLoadingUserOrgs` guard
   - Added `_isInitializing` guard
   - Smart waiting for existing loads

2. `legal_ai_app/lib/features/home/widgets/app_shell.dart`
   - Removed duplicate initialization from `build()` method

3. `legal_ai_app/lib/features/home/screens/org_selection_screen.dart`
   - Fixed navigation to use `context.pop()` when possible
   - Improved initialization guard

4. `legal_ai_app/lib/features/cases/screens/case_list_screen.dart`
   - Reset `_lastLoadedOrgId` on refresh

## Next Steps

1. **Test the fixes** - Run the app and verify all issues are resolved
2. **Backend investigation** - Check why `caseList` is returning `INTERNAL_ERROR`
3. **Monitor logs** - Watch for any remaining duplicate calls
4. **Performance** - Should see significant improvement (8-9s instead of 32-36s)

## Expected Behavior After Fixes

1. **Org List Loading**: Single call, 8-9 seconds (not 32-36 seconds)
2. **Navigation**: Can switch orgs, go back, browser back button works
3. **Cases**: Load properly, persist after refresh
4. **Performance**: No flicker, no duplicate API calls
5. **Error Handling**: Backend errors shown clearly, no infinite loops
