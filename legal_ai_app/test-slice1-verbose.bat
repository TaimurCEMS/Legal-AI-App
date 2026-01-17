@echo off
REM Verbose test script for Slice 1 - keeps window open
title Slice 1 Testing Script (Verbose)
color 0A
echo ========================================
echo Slice 1 Testing Script
echo ========================================
echo.

cd /d "%~dp0"
echo Current directory: %CD%
echo.

echo [1/5] Checking Flutter installation...
echo ----------------------------------------
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ ERROR: Flutter not found or not configured
    echo.
    echo Please ensure Flutter is installed and added to PATH
    echo.
    goto :end
)
echo.
echo ✅ Flutter OK
echo.
echo [2/5] Installing dependencies...
echo ----------------------------------------
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ ERROR: Failed to install dependencies
    echo.
    goto :end
)
echo.
echo ✅ Dependencies installed
echo.
echo [3/5] Checking Firebase configuration...
echo ----------------------------------------
if not exist "lib\firebase_options.dart" (
    echo.
    echo ⚠️  WARNING: Firebase not configured yet
    echo.
    echo This is expected for now. To configure Firebase later, run:
    echo   flutterfire configure
    echo.
) else (
    echo ✅ Firebase configured
    echo.
)
echo [4/5] Running static analysis...
echo ----------------------------------------
flutter analyze
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️  WARNING: Analysis found issues (check output above)
    echo.
) else (
    echo.
    echo ✅ No analysis errors
    echo.
)
echo [5/5] Summary
echo ========================================
echo.
echo Status: Testing complete
echo.
echo Next steps:
echo   1. If Firebase is not configured, run: flutterfire configure
echo   2. To run the app: flutter run -d chrome
echo   3. To run tests: flutter test
echo.
echo ========================================
:end
echo.
echo Press any key to exit...
pause >nul
