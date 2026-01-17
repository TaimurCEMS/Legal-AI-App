# Slice 1 Testing Guide

**Status:** Ready for Testing  
**Date:** 2026-01-17

---

## Prerequisites

1. **Flutter SDK** installed and configured
   - Verify: `flutter doctor`
   - Should show no critical issues

2. **Firebase CLI** installed
   - Verify: `firebase --version`

3. **FlutterFire CLI** installed
   - Install: `dart pub global activate flutterfire_cli`
   - Verify: `flutterfire --version`

4. **Firebase Project** ready
   - Project ID: `legal-ai-app-1203e`
   - Slice 0 functions deployed and working

---

## Step 1: Initial Setup

### 1.1 Navigate to Flutter App Directory
```bash
cd legal_ai_app
```

### 1.2 Install Dependencies
```bash
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in legal_ai_app...
Resolving dependencies...
Got dependencies!
```

### 1.3 Configure Firebase
```bash
flutterfire configure
```

**Configuration Steps:**
1. Select platforms: 
   - ✅ Android
   - ✅ iOS (if on Mac)
   - ✅ Web (optional, for browser testing)

2. Select Firebase project:
   - Choose: `legal-ai-app-1203e`

3. Follow prompts for each platform

**Expected Result:**
- `lib/firebase_options.dart` file is created
- Platform-specific config files updated

### 1.4 Verify Firebase Configuration
Check that `lib/firebase_options.dart` exists:
```bash
ls lib/firebase_options.dart
```

---

## Step 2: Static Analysis

### 2.1 Run Flutter Analyze
```bash
flutter analyze
```

**Expected:** 
- 0 errors
- 0 warnings (or only minor style warnings)

**If errors occur:**
- Check import paths
- Verify all files are saved
- Run `flutter clean` then `flutter pub get`

### 2.2 Check for Compilation Errors
```bash
flutter build apk --debug
```
(For Android) or
```bash
flutter build ios --debug --no-codesign
```
(For iOS)

**Expected:** Build completes successfully

---

## Step 3: Run the App

### 3.1 Start Emulator/Device

**Android:**
```bash
# List available devices
flutter devices

# Start Android emulator (if installed)
# Or connect physical device via USB
```

**iOS (Mac only):**
```bash
# List available devices
flutter devices

# Start iOS simulator
open -a Simulator
```

**Web:**
```bash
# No emulator needed, runs in browser
```

### 3.2 Run the App

**Android:**
```bash
flutter run
```

**iOS:**
```bash
flutter run -d ios
```

**Web:**
```bash
flutter run -d chrome
```

**Expected:**
- App compiles successfully
- App launches
- Splash screen appears
- App redirects to appropriate screen

---

## Step 4: Test User Flows

### Test Flow 1: New User Registration ✅

**Steps:**
1. **Splash Screen**
   - [ ] App launches
   - [ ] Shows "Legal AI App" logo/text
   - [ ] Shows loading spinner
   - [ ] Automatically redirects to Login screen

2. **Login Screen**
   - [ ] Screen displays correctly
   - [ ] "Welcome Back" heading visible
   - [ ] Email field is present
   - [ ] Password field is present
   - [ ] "Forgot Password?" link visible
   - [ ] "Sign Up" link visible
   - [ ] "Sign In" button visible

3. **Navigate to Signup**
   - [ ] Tap "Sign Up" link
   - [ ] Navigates to Signup screen

4. **Signup Screen**
   - [ ] "Create Account" heading visible
   - [ ] Email field present
   - [ ] Password field present
   - [ ] Confirm Password field present
   - [ ] "Sign Up" button visible
   - [ ] "Sign In" link visible

5. **Create Account**
   - [ ] Enter valid email (e.g., `test@example.com`)
   - [ ] Enter password (min 6 chars, e.g., `password123`)
   - [ ] Enter matching confirm password
   - [ ] Tap "Sign Up" button
   - [ ] Button shows loading state
   - [ ] Account created successfully
   - [ ] Navigates to Org Create screen

6. **Create Organization**
   - [ ] "Create Organization" heading visible
   - [ ] Organization Name field present
   - [ ] Description field present (optional)
   - [ ] Enter org name (e.g., "Test Law Firm")
   - [ ] Tap "Create Organization" button
   - [ ] Button shows loading state
   - [ ] Organization created successfully
   - [ ] Navigates to Home screen

7. **Home Screen**
   - [ ] App bar shows organization name
   - [ ] Organization card displays:
     - [ ] Org name
     - [ ] User role (ADMIN)
     - [ ] Plan (FREE)
   - [ ] Bottom navigation bar visible
   - [ ] Home tab selected

**Expected Result:** ✅ New user can register, create org, and access home screen

---

### Test Flow 2: Existing User Login ✅

**Prerequisites:** User account exists from Test Flow 1

**Steps:**
1. **Sign Out** (if already logged in)
   - [ ] Tap user menu (top right)
   - [ ] Tap "Sign Out"
   - [ ] Navigates to Login screen

2. **Login**
   - [ ] Enter email from Test Flow 1
   - [ ] Enter password
   - [ ] Tap "Sign In" button
   - [ ] Button shows loading state
   - [ ] Login successful
   - [ ] Navigates to Org Selection (or Home if single org)

3. **Organization Selection**
   - [ ] Screen displays
   - [ ] "Your Organizations" heading visible
   - [ ] "Create New Organization" button visible
   - [ ] (If org list implemented) Organizations displayed

4. **Navigate to Home**
   - [ ] Select organization (or create new)
   - [ ] Navigates to Home screen

**Expected Result:** ✅ Existing user can log in and access their organization

---

### Test Flow 3: Password Reset ✅

**Steps:**
1. **From Login Screen**
   - [ ] Tap "Forgot Password?" link
   - [ ] Navigates to Password Reset screen

2. **Password Reset Screen**
   - [ ] "Reset Password" heading visible
   - [ ] Email field present
   - [ ] "Send Reset Link" button visible
   - [ ] "Back to Login" link visible

3. **Request Password Reset**
   - [ ] Enter valid email address
   - [ ] Tap "Send Reset Link" button
   - [ ] Button shows loading state
   - [ ] Success message appears:
     - [ ] Checkmark icon visible
     - [ ] "Email Sent" message
     - [ ] Confirmation text with email address
   - [ ] "Back to Login" button visible

4. **Return to Login**
   - [ ] Tap "Back to Login"
   - [ ] Navigates to Login screen

**Expected Result:** ✅ Password reset email sent successfully

**Note:** Check email inbox for password reset link (may take a few minutes)

---

### Test Flow 4: Organization Management ✅

**Prerequisites:** User is logged in

**Steps:**
1. **Switch Organization**
   - [ ] From Home screen, tap user menu (top right)
   - [ ] Tap "Switch Organization"
   - [ ] Navigates to Org Selection screen

2. **Create New Organization**
   - [ ] Tap "Create New Organization" button
   - [ ] Navigates to Org Create screen
   - [ ] Enter new org name
   - [ ] Tap "Create Organization"
   - [ ] Organization created
   - [ ] Navigates to Home screen
   - [ ] Home screen shows new organization

3. **Verify Org Context**
   - [ ] App bar shows new org name
   - [ ] Organization card shows new org details
   - [ ] User role is ADMIN (for creator)

**Expected Result:** ✅ User can create multiple organizations and switch between them

---

### Test Flow 5: Sign Out ✅

**Steps:**
1. **From Home Screen**
   - [ ] Tap user menu (top right)
   - [ ] Menu shows:
     - [ ] "Switch Organization" option
     - [ ] "Sign Out" option

2. **Sign Out**
   - [ ] Tap "Sign Out"
   - [ ] Auth state cleared
   - [ ] Navigates to Login screen

3. **Verify Sign Out**
   - [ ] Login screen displays
   - [ ] User cannot access home without logging in
   - [ ] Try navigating to `/home` directly (should redirect to login)

**Expected Result:** ✅ Sign out works correctly, user is logged out

---

### Test Flow 6: Error Handling ✅

**Steps:**
1. **Invalid Login**
   - [ ] Enter invalid email/password
   - [ ] Tap "Sign In"
   - [ ] Error message displays (red snackbar)
   - [ ] Error message is user-friendly

2. **Invalid Signup**
   - [ ] Enter invalid email format
   - [ ] Tap "Sign Up"
   - [ ] Validation error shows in field
   - [ ] Password too short shows error

3. **Network Error** (if offline)
   - [ ] Turn off internet/WiFi
   - [ ] Try to sign in
   - [ ] Network error message displays

**Expected Result:** ✅ Error handling works correctly, user-friendly messages shown

---

### Test Flow 7: Navigation ✅

**Steps:**
1. **Bottom Navigation**
   - [ ] From Home screen
   - [ ] Tap "Cases" tab
   - [ ] Shows placeholder screen
   - [ ] Tap "Clients" tab
   - [ ] Shows placeholder screen
   - [ ] Tap "Documents" tab
   - [ ] Shows placeholder screen
   - [ ] Tap "Home" tab
   - [ ] Returns to Home screen

2. **Back Navigation**
   - [ ] From Org Create screen
   - [ ] Tap back button/gesture
   - [ ] Returns to previous screen

**Expected Result:** ✅ Navigation works correctly between all screens

---

### Test Flow 8: UI Consistency ✅

**Steps:**
1. **Theme Consistency**
   - [ ] All screens use same color scheme
   - [ ] Typography is consistent
   - [ ] Spacing is consistent
   - [ ] Buttons have same styling

2. **Widget Consistency**
   - [ ] All text fields look the same
   - [ ] All buttons look the same
   - [ ] All cards have same styling
   - [ ] Loading states are consistent

**Expected Result:** ✅ UI is consistent across all screens

---

## Step 5: Verify Integration with Slice 0

### 5.1 Test Cloud Functions Integration

**Test org.create:**
- [ ] Create organization via UI
- [ ] Check Firebase Console → Firestore
- [ ] Verify organization document created in `organizations/{orgId}`
- [ ] Verify membership created in `organizations/{orgId}/members/{uid}`
- [ ] Verify audit event created

**Test org.join:**
- [ ] (If you have another test account) Join existing org
- [ ] Verify membership created
- [ ] Verify audit event created

**Test member.getMyMembership:**
- [ ] Home screen loads org details
- [ ] Verify role and plan displayed correctly

**Expected Result:** ✅ All Slice 0 functions work correctly from Flutter app

---

## Step 6: Performance & Responsiveness

### 6.1 Loading States
- [ ] All async operations show loading indicators
- [ ] Loading states don't block UI unnecessarily
- [ ] Transitions are smooth

### 6.2 Responsive Layout
- [ ] Test on different screen sizes (if possible)
- [ ] UI adapts to screen size
- [ ] Text is readable
- [ ] Buttons are tappable

---

## Common Issues & Troubleshooting

### Issue: "firebase_options.dart not found"
**Solution:**
```bash
flutterfire configure
```

### Issue: "Package not found" errors
**Solution:**
```bash
flutter clean
flutter pub get
```

### Issue: Build fails
**Solution:**
```bash
flutter doctor
# Fix any issues shown
flutter clean
flutter pub get
flutter run
```

### Issue: Cloud Functions not working
**Solution:**
- Verify Slice 0 functions are deployed
- Check Firebase project ID matches
- Verify region is `us-central1`
- Check network connection

### Issue: Auth not working
**Solution:**
- Verify Firebase Auth is enabled in Firebase Console
- Check `firebase_options.dart` is correct
- Verify email/password auth is enabled

---

## Test Results Template

```
Slice 1 Testing Results
Date: ___________
Tester: ___________

Test Flow 1: New User Registration
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 2: Existing User Login
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 3: Password Reset
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 4: Organization Management
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 5: Sign Out
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 6: Error Handling
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 7: Navigation
- [ ] Pass
- [ ] Fail (Notes: ___________)

Test Flow 8: UI Consistency
- [ ] Pass
- [ ] Fail (Notes: ___________)

Slice 0 Integration
- [ ] Pass
- [ ] Fail (Notes: ___________)

Overall Status: [ ] PASS [ ] FAIL

Issues Found:
1. ___________
2. ___________
3. ___________
```

---

## Quick Test Commands

```bash
# Full test sequence
cd legal_ai_app
flutter pub get
flutterfire configure
flutter analyze
flutter run

# After testing, verify build
flutter build apk --debug  # Android
flutter build ios --debug --no-codesign  # iOS
```

---

## Success Criteria

Slice 1 testing is successful when:
- ✅ All 8 test flows pass
- ✅ Slice 0 integration works
- ✅ No critical errors
- ✅ UI is consistent
- ✅ Navigation works smoothly
- ✅ Error handling is user-friendly

---

**Ready to test! Follow the steps above and document any issues found.**
