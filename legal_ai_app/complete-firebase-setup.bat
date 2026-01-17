@echo off
title Complete Firebase Setup
color 0A
echo ========================================
echo Complete Firebase Setup Checklist
echo ========================================
echo.

cd /d "%~dp0"

echo ✅ Step 1: User exists in Firebase
echo    User: test-17jan@test.com
echo    Password: 123456
echo    Status: CONFIRMED (you showed me the Firebase Console)
echo.

echo ⚠️  Step 2: Check Email/Password Authentication
echo ----------------------------------------
echo.
echo Please verify in Firebase Console:
echo   1. Go to: Authentication → Sign-in method tab
echo   2. Click on "Email/Password"
echo   3. Make sure the FIRST toggle is ENABLED (green)
echo   4. Click "Save"
echo.
set /p email_enabled="Is Email/Password enabled? (y/n): "
if /i "%email_enabled%"=="n" (
    echo.
    echo ❌ Email/Password must be enabled!
    echo    Go enable it now, then run this script again.
    pause
    exit /b 1
)
echo.

echo ⚠️  Step 3: Fix Firebase Configuration (CRITICAL)
echo ----------------------------------------
echo.
echo PROBLEM: App is using placeholder Firebase keys
echo   Error: key=placeholder-web-api-key
echo.
echo This is why login fails even though user exists!
echo.
echo Checking current configuration...
findstr /C:"placeholder" "lib\firebase_options.dart" >nul
if %ERRORLEVEL% EQU 0 (
    echo ❌ Firebase NOT configured - THIS IS THE PROBLEM!
    echo.
    echo Solution: Run flutterfire configure
    echo.
    echo Press any key to configure Firebase now...
    pause >nul
    echo.
    echo Installing FlutterFire CLI (if needed)...
    dart pub global activate flutterfire_cli
    echo.
    echo Running flutterfire configure...
    echo.
    echo IMPORTANT: When prompted:
    echo   1. Select project: legal-ai-app-1203e
    echo   2. Select platform: web (press Space, then Enter)
    echo.
    pause
    flutterfire configure
    set CONFIG_OK=%ERRORLEVEL%
    echo.
    if %CONFIG_OK% EQU 0 (
        echo ✅ Configuration completed!
        echo.
        echo Verifying...
        findstr /C:"placeholder" "lib\firebase_options.dart" >nul
        if %ERRORLEVEL% EQU 0 (
            echo ❌ Still has placeholders - try again
        ) else (
            echo ✅ Configuration successful - no placeholders found!
        )
    ) else (
        echo ❌ Configuration failed
        echo    Error code: %CONFIG_OK%
    )
) else (
    echo ✅ Firebase already configured!
)
echo.

echo Step 4: Update Dependencies
echo ----------------------------------------
flutter pub get
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Next: Test Login
echo   1. Run: flutter run -d chrome
echo   2. Enter email: test-17jan@test.com
echo   3. Enter password: 123456
echo   4. Click Sign In
echo.
echo If it still fails, check:
echo   - Browser console (F12) for error messages
echo   - Make sure Email/Password is enabled
echo   - Make sure Firebase config has no placeholders
echo.
pause
