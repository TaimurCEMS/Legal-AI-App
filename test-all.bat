@echo off
REM Comprehensive testing script - keeps window open
setlocal enabledelayedexpansion
title Testing - Legal AI App
color 0B

cd /d "%~dp0"

echo ========================================
echo Pre-Commit Testing - Legal AI App
echo ========================================
echo.

set ERRORS=0
set WARNINGS=0

REM Step 1: Check Flutter
echo [1/7] Checking Flutter...
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found
    set /a ERRORS+=1
) else (
    echo ✅ Flutter found
)
echo.

REM Step 2: Check directory
echo [2/7] Checking directories...
if not exist "legal_ai_app" (
    echo ❌ legal_ai_app not found
    set /a ERRORS+=1
) else (
    echo ✅ legal_ai_app found
)
echo.

REM Step 3: Install dependencies
echo [3/7] Installing dependencies...
cd /d "%~dp0legal_ai_app"
if %ERRORLEVEL% EQU 0 (
    flutter pub get >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✅ Dependencies installed
    ) else (
        echo ❌ Failed to install dependencies
        set /a ERRORS+=1
    )
) else (
    echo ❌ Failed to navigate to legal_ai_app
    set /a ERRORS+=1
)
echo.

REM Step 4: Compilation check
echo [4/7] Checking compilation...
cd /d "%~dp0legal_ai_app"
flutter analyze --no-fatal-infos 2>&1 | findstr /i "error" >nul
if %ERRORLEVEL% EQU 0 (
    echo ⚠️  Compilation issues found
    set /a WARNINGS+=1
) else (
    echo ✅ No compilation errors
)
echo.

REM Step 5: Common checks
echo [5/7] Checking common issues...
cd /d "%~dp0legal_ai_app"
findstr /i "shared_preferences" pubspec.yaml >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ shared_preferences in pubspec.yaml
) else (
    echo ❌ shared_preferences missing
    set /a ERRORS+=1
)
echo.

REM Step 6: Run tests
echo [6/7] Running tests...
cd /d "%~dp0legal_ai_app"
echo.
echo Running state management tests...
flutter test test/state_management_test.dart 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ State management: PASSED
) else (
    echo ❌ State management: FAILED
    set /a ERRORS+=1
)
echo.

echo Running UI component tests...
flutter test test/ui_components_test.dart 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ UI components: PASSED
) else (
    echo ❌ UI components: FAILED
    set /a ERRORS+=1
)
echo.

echo Running persistence tests...
flutter test test/state_persistence_test.dart 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Persistence: PASSED
) else (
    echo ❌ Persistence: FAILED
    set /a ERRORS+=1
)
echo.

echo Running critical logic tests...
flutter test test/critical_logic_test.dart 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Critical logic: PASSED
) else (
    echo ❌ Critical logic: FAILED
    set /a ERRORS+=1
)
echo.

echo Running model tests...
flutter test test/model_serialization_test.dart 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Model serialization: PASSED
) else (
    echo ❌ Model serialization: FAILED
    set /a ERRORS+=1
)
echo.

REM Step 7: Backend check
echo [7/7] Checking backend...
cd /d "%~dp0functions"
if exist "src\functions\case.ts" (
    echo ✅ Backend functions found
) else (
    echo ⚠️  Backend functions not found
    set /a WARNINGS+=1
)
echo.

REM Summary
cd /d "%~dp0"
echo.
echo ========================================
echo SUMMARY
echo ========================================
echo.
if %ERRORS% EQU 0 (
    echo ✅ ALL TESTS PASSED!
    echo.
    echo Ready to run: cd legal_ai_app ^&^& flutter run -d chrome
) else (
    echo ❌ %ERRORS% test suite(s) failed
    echo Fix errors before running app.
)
echo.
echo ========================================
echo.
echo Press any key to close...
pause
echo.
echo If you see this, the script completed.
timeout /t 5 >nul
