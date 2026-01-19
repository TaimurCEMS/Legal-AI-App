@echo off
REM Launcher that checks setup first, then runs the app
title Legal AI App - Setup Check & Run
color 0B

cd /d "%~dp0"

echo ========================================
echo Legal AI App - Setup Check & Run
echo ========================================
echo.

REM Check Flutter
echo [1/4] Checking Flutter...
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found in PATH
    echo.
    echo Please:
    echo   1. Install Flutter, OR
    echo   2. Use run-with-flutter-path.bat instead
    echo.
    pause
    exit /b 1
)
echo ✅ Flutter OK
echo.

REM Install dependencies
echo [2/4] Installing dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

REM Check Firebase
echo [3/4] Checking Firebase configuration...
if not exist "lib\firebase_options.dart" (
    echo ⚠️  Firebase not configured
    echo    (App may not work without Firebase config)
    echo.
) else (
    echo ✅ Firebase configured
    echo.
)

REM Check web support
echo [4/4] Checking web platform...
if not exist "web\index.html" (
    echo ⚠️  Web platform not set up
    echo    Setting up web support...
    flutter create . --platforms=web
    echo.
)
echo ✅ Web platform ready
echo.

echo ========================================
echo Starting app...
echo ========================================
echo.
echo App will open in Chrome browser
echo.
echo Test Credentials (if needed):
echo   Email: test-17jan@test.com
echo   Password: 123456
echo.
echo ========================================
echo.

flutter run -d chrome

pause
