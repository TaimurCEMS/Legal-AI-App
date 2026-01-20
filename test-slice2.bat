@echo off
REM Batch script for testing Slice 2 - works around PowerShell execution policy issues
title Slice 2 Testing
color 0B

cd /d "%~dp0"

echo ========================================
echo Slice 2 Testing Script
echo ========================================
echo.

echo [1/4] Checking Flutter...
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found. Please install Flutter.
    pause
    exit /b 1
)
echo ✅ Flutter found
echo.

echo [2/4] Navigating to Flutter app...
cd /d "%~dp0legal_ai_app"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter app directory not found
    pause
    exit /b 1
)
echo ✅ In directory: %CD%
echo.

echo [3/4] Installing dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo [4/4] Checking for compilation errors...
flutter analyze --no-fatal-infos 2>&1 | findstr /i "error" >nul
if %ERRORLEVEL% EQU 0 (
    echo ⚠️  Compilation issues found (check output above)
) else (
    echo ✅ No critical compilation errors
)
echo.

echo ========================================
echo Testing Complete
echo ========================================
echo.
echo Next steps:
echo   1. Run: flutter run -d chrome
echo   2. Test manually:
echo      - Create org → Refresh (F5) → Org should persist
echo      - Create cases → Switch tabs → Cases should persist
echo      - Create case → Refresh → Case should reload from backend
echo.

pause
