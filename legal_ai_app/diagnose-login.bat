@echo off
title Login Diagnostic Tool
color 0E
echo ========================================
echo Login Error Diagnostic Tool
echo ========================================
echo.

cd /d "%~dp0"

echo [1/4] Checking Firebase Configuration...
echo ----------------------------------------
if exist "lib\firebase_options.dart" (
    findstr /C:"placeholder" "lib\firebase_options.dart" >nul
    if %ERRORLEVEL% EQU 0 (
        echo ❌ PROBLEM FOUND: Firebase not configured!
        echo    firebase_options.dart still has placeholder values
        echo.
        echo    Solution: Run configure-firebase.bat
        echo    OR run: flutterfire configure
        echo.
        set FIREBASE_CONFIGURED=0
    ) else (
        echo ✅ Firebase configuration file looks good
        set FIREBASE_CONFIGURED=1
    )
) else (
    echo ❌ PROBLEM FOUND: firebase_options.dart not found!
    echo    Solution: Run configure-firebase.bat
    set FIREBASE_CONFIGURED=0
)
echo.

echo [2/4] Checking if user exists in Firebase...
echo ----------------------------------------
echo.
echo To check if the user exists:
echo   1. Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/users
echo   2. Look for: test-17jan@test.com
echo   3. If not found, click "Add user" and create it
echo.
set /p user_exists="Does the user exist in Firebase Console? (y/n): "
if /i "%user_exists%"=="y" (
    set USER_EXISTS=1
) else (
    set USER_EXISTS=0
    echo.
    echo ⚠️  User needs to be created in Firebase Console
)
echo.

echo [3/4] Checking Email/Password authentication...
echo ----------------------------------------
echo.
echo To check if Email/Password is enabled:
echo   1. Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/providers
echo   2. Click on "Email/Password"
echo   3. Make sure the first toggle is ENABLED
echo.
set /p email_enabled="Is Email/Password authentication enabled? (y/n): "
if /i "%email_enabled%"=="y" (
    set EMAIL_ENABLED=1
) else (
    set EMAIL_ENABLED=0
    echo.
    echo ⚠️  Email/Password authentication needs to be enabled
)
echo.

echo [4/4] Common Error Messages...
echo ----------------------------------------
echo.
echo Common errors and solutions:
echo.
echo "FirebaseException: [core/no-app]"
echo   → Firebase not configured. Run: flutterfire configure
echo.
echo "FirebaseAuthException: user-not-found"
echo   → User doesn't exist. Create user in Firebase Console
echo.
echo "FirebaseAuthException: wrong-password"
echo   → Password is incorrect. Check password: 123456
echo.
echo "FirebaseAuthException: invalid-email"
echo   → Email format is wrong. Check: test-17jan@test.com
echo.
echo "FirebaseAuthException: network-request-failed"
echo   → Network issue or Firebase not configured properly
echo.
echo "Type 'PromiseJsImpl' not found"
echo   → Firebase packages need updating. Run: flutter pub get
echo.

echo ========================================
echo Summary
echo ========================================
echo.
if %FIREBASE_CONFIGURED%==0 (
    echo ❌ Firebase NOT configured - THIS IS LIKELY THE PROBLEM
    echo    Fix: Run configure-firebase.bat
) else (
    echo ✅ Firebase configured
)
echo.
if %USER_EXISTS%==0 (
    echo ❌ User doesn't exist
    echo    Fix: Create user in Firebase Console
) else (
    echo ✅ User exists
)
echo.
if %EMAIL_ENABLED%==0 (
    echo ❌ Email/Password NOT enabled
    echo    Fix: Enable in Firebase Console
) else (
    echo ✅ Email/Password enabled
)
echo.

echo ========================================
echo Next Steps
echo ========================================
echo.
if %FIREBASE_CONFIGURED%==0 (
    echo 1. FIRST: Configure Firebase
    echo    Run: configure-firebase.bat
    echo    OR: flutterfire configure
    echo.
)
if %USER_EXISTS%==0 (
    echo 2. Create test user in Firebase Console
    echo    Email: test-17jan@test.com
    echo    Password: 123456
    echo.
)
if %EMAIL_ENABLED%==0 (
    echo 3. Enable Email/Password authentication
    echo    Go to Firebase Console → Authentication → Sign-in method
    echo.
)
echo 4. Try logging in again
echo.
echo ========================================
echo.
echo What error message do you see when you try to login?
echo (This will help identify the exact issue)
echo.
pause
