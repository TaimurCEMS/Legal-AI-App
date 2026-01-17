@echo off
title Debug Login Issues
color 0C
echo ========================================
echo Login Debugging Guide
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Verify Firebase Configuration
echo ----------------------------------------
findstr /C:"placeholder" "lib\firebase_options.dart" >nul
if %ERRORLEVEL% EQU 0 (
    echo ❌ Firebase still has placeholders!
) else (
    echo ✅ Firebase configured (no placeholders)
)
echo.

echo Step 2: Check Browser Console
echo ----------------------------------------
echo.
echo IMPORTANT: Check the browser console for errors!
echo.
echo 1. Open Chrome DevTools (Press F12)
echo 2. Go to "Console" tab
echo 3. Try logging in
echo 4. Look for error messages (usually in red)
echo.
echo Common errors to look for:
echo   - "400 Bad Request" → Firebase config issue
echo   - "user-not-found" → User doesn't exist
echo   - "wrong-password" → Password incorrect
echo   - "network-request-failed" → Connection issue
echo   - "invalid-api-key" → API key problem
echo.
pause

echo.
echo Step 3: Verify User in Firebase
echo ----------------------------------------
echo.
echo Go to Firebase Console:
echo https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/users
echo.
echo Check:
echo   ✅ User: test-17jan@test.com exists
echo   ✅ Email/Password provider is enabled
echo.
set /p user_exists="Does the user exist? (y/n): "

echo.
echo Step 4: Check Email/Password Authentication
echo ----------------------------------------
echo.
echo Go to:
echo https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/providers
echo.
echo Check:
echo   ✅ Email/Password is enabled (first toggle)
echo.
set /p email_enabled="Is Email/Password enabled? (y/n): "

echo.
echo ========================================
echo What error message do you see?
echo ========================================
echo.
echo In the app (red message at bottom):
set /p app_error="Enter the exact error message: "

echo.
echo In browser console (F12 → Console):
set /p console_error="Enter any console errors: "

echo.
echo ========================================
echo Summary
echo ========================================
echo.
echo Firebase configured: 
findstr /C:"placeholder" "lib\firebase_options.dart" >nul
if %ERRORLEVEL% EQU 0 (echo   ❌ NO) else (echo   ✅ YES)
echo.
echo User exists: 
if /i "%user_exists%"=="y" (echo   ✅ YES) else (echo   ❌ NO)
echo.
echo Email/Password enabled: 
if /i "%email_enabled%"=="y" (echo   ✅ YES) else (echo   ❌ NO)
echo.
echo App error: %app_error%
echo.
echo Console error: %console_error%
echo.
echo ========================================
pause
