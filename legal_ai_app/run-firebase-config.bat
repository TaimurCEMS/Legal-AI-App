@echo off
title Configure Firebase
color 0A
echo ========================================
echo Firebase Configuration
echo ========================================
echo.
echo Since Email/Password is already enabled
echo and the user exists, we just need to
echo configure Firebase in the app.
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Installing FlutterFire CLI...
dart pub global activate flutterfire_cli
echo.

echo Step 2: Configuring Firebase...
echo.
echo When prompted:
echo   1. Select project: legal-ai-app-1203e
echo   2. Select platform: web (press Space, then Enter)
echo.
pause
flutterfire configure
echo.

echo Step 3: Verifying configuration...
findstr /C:"placeholder" "lib\firebase_options.dart" >nul
if %ERRORLEVEL% EQU 0 (
    echo ❌ Still has placeholders - configuration may have failed
) else (
    echo ✅ Configuration successful!
    echo.
    echo Step 4: Updating dependencies...
    flutter pub get
    echo.
    echo ✅ Ready to test login!
    echo.
    echo Run: flutter run -d chrome
    echo Then login with: test-17jan@test.com / 123456
)

echo.
echo ========================================
pause
