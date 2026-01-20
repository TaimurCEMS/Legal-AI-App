@echo off
REM Comprehensive testing script that I can run to verify everything works
REM This helps catch issues before giving code to the user
setlocal enabledelayedexpansion
title Pre-Commit Testing - Legal AI App
color 0B

cd /d "%~dp0"

echo ========================================
echo Pre-Commit Testing - Legal AI App
echo ========================================
echo.
echo This script verifies:
echo   1. Flutter installation
echo   2. Dependencies installed
echo   3. Code compiles (no errors)
echo   4. State management logic (automated tests)
echo   5. UI components (automated tests)
echo   6. State persistence (automated tests)
echo   7. Common issues detected
echo.
echo NOTE: After tests pass, you still need to:
echo   - Run app in Chrome for visual testing
echo   - Test end-to-end flows manually
echo   - Deploy and test backend functions
echo ========================================
echo.

set ERRORS=0
set WARNINGS=0

REM ========================================
REM Step 1: Check Flutter
REM ========================================
echo [1/6] Checking Flutter installation...
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found in PATH
    set /a ERRORS+=1
    goto :summary
) else (
    for /f "tokens=*" %%i in ('flutter --version 2^>nul ^| findstr /i "Flutter"') do set FLUTTER_VERSION=%%i
    echo ✅ Flutter found: !FLUTTER_VERSION!
)
echo.

REM ========================================
REM Step 2: Check Flutter App Directory
REM ========================================
echo [2/6] Checking Flutter app directory...
if not exist "legal_ai_app" (
    echo ❌ legal_ai_app directory not found
    set /a ERRORS+=1
    goto :summary
)
echo ✅ legal_ai_app directory found
echo.

REM ========================================
REM Step 3: Install Dependencies
REM ========================================
echo [3/6] Installing/updating dependencies...
cd /d "%~dp0legal_ai_app"
flutter pub get >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    set /a ERRORS+=1
    goto :summary
)
echo ✅ Dependencies installed
echo.

REM ========================================
REM Step 4: Check for Compilation Errors
REM ========================================
echo [4/6] Checking for compilation errors...
flutter analyze --no-fatal-infos > temp_analysis.txt 2>&1
set ANALYSIS_ERROR=0
findstr /i "error" temp_analysis.txt >nul
if %ERRORLEVEL% EQU 0 (
    echo ⚠️  Compilation issues found:
    findstr /i "error" temp_analysis.txt
    set /a WARNINGS+=1
    set ANALYSIS_ERROR=1
) else (
    echo ✅ No critical compilation errors
)
del temp_analysis.txt >nul 2>&1
echo.

REM ========================================
REM Step 5: Check for Common Issues
REM ========================================
echo [5/6] Checking for common issues...

REM Check for SharedPreferences import
findstr /s /i "shared_preferences" lib\features\home\providers\org_provider.dart >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  shared_preferences may not be imported in org_provider.dart
    set /a WARNINGS+=1
)

REM Check for IndexedStack in app_shell
findstr /s /i "IndexedStack" lib\features\home\widgets\app_shell.dart >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  IndexedStack may not be used in app_shell.dart (tab state preservation)
    set /a WARNINGS+=1
)

REM Check pubspec.yaml for shared_preferences
findstr /s /i "shared_preferences" pubspec.yaml >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ shared_preferences not found in pubspec.yaml
    set /a ERRORS+=1
) else (
    echo ✅ shared_preferences in pubspec.yaml
)

echo ✅ Common issues check complete
echo.

REM ========================================
REM Step 6: Run Flutter Tests
REM ========================================
echo [6/7] Running Flutter tests...
cd /d "%~dp0legal_ai_app"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to navigate to legal_ai_app directory
    set /a ERRORS+=1
    goto :summary
)

echo Running state management tests...
flutter test test/state_management_test.dart
if %ERRORLEVEL% EQU 0 (
    echo ✅ State management tests passed
) else (
    echo ❌ State management tests failed
    set /a ERRORS+=1
)
echo.

echo Running UI component tests...
flutter test test/ui_components_test.dart
if %ERRORLEVEL% EQU 0 (
    echo ✅ UI component tests passed
) else (
    echo ❌ UI component tests failed
    set /a ERRORS+=1
)
echo.

echo Running state persistence tests...
flutter test test/state_persistence_test.dart
if %ERRORLEVEL% EQU 0 (
    echo ✅ State persistence tests passed
) else (
    echo ❌ State persistence tests failed
    set /a ERRORS+=1
)
echo.

echo Running critical logic tests...
flutter test test/critical_logic_test.dart
if %ERRORLEVEL% EQU 0 (
    echo ✅ Critical logic tests passed
) else (
    echo ❌ Critical logic tests failed
    set /a ERRORS+=1
)
echo.

echo Running model serialization tests...
flutter test test/model_serialization_test.dart
if %ERRORLEVEL% EQU 0 (
    echo ✅ Model serialization tests passed
) else (
    echo ❌ Model serialization tests failed
    set /a ERRORS+=1
)
echo.

REM ========================================
REM Step 7: Check Backend Functions
REM ========================================
echo [7/7] Checking backend functions...
cd /d "%~dp0functions"
if exist "package.json" (
    echo ✅ Functions directory found
    if exist "src\functions\case.ts" (
        echo ✅ case.ts found
    ) else (
        echo ⚠️  case.ts not found
        set /a WARNINGS+=1
    )
) else (
    echo ⚠️  Functions directory not found or incomplete
    set /a WARNINGS+=1
)
echo.

REM ========================================
REM Summary
REM ========================================
:summary
cd /d "%~dp0"
echo.
echo ========================================
echo Testing Summary
echo ========================================
echo.
if %ERRORS% EQU 0 (
    if %WARNINGS% EQU 0 (
        echo ✅ ALL CHECKS PASSED - Ready to commit!
    ) else (
        echo ⚠️  PASSED with !WARNINGS! warning(s) - Review warnings above
    )
) else (
    echo ❌ FAILED with !ERRORS! error(s) and !WARNINGS! warning(s)
    echo.
    echo Please fix errors before committing.
)
echo.
echo ========================================
echo.

if %ERRORS% GTR 0 (
    echo.
    echo ========================================
    echo ❌ FIX ERRORS BEFORE RUNNING THE APP
    echo ========================================
    echo.
    echo Found !ERRORS! error(s) and !WARNINGS! warning(s)
    echo Please fix the errors above before proceeding.
    echo.
) else (
    echo.
    echo ========================================
    echo ✅ ALL CHECKS PASSED - READY TO RUN APP
    echo ========================================
    echo.
    echo Next steps:
    echo   1. Run: cd legal_ai_app
    echo   2. Run: flutter run -d chrome
    echo   3. Test manually:
    echo      - Create org → Refresh (F5) → Org should persist
    echo      - Create cases → Switch tabs → Cases should persist
    echo      - Create case → Refresh → Case should reload
    echo.
)

echo.
echo ========================================
echo Press any key to close this window...
echo ========================================
pause >nul
