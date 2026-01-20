@echo off
REM Comprehensive test runner - runs all automated tests
REM Uses clean path junction if available to avoid apostrophe issues
title Running All Tests - Legal AI App
color 0B

set "JUNCTION_PATH=C:\LegalAIApp"
set "USE_JUNCTION=0"

REM Check if junction exists and use it
if exist "%JUNCTION_PATH%\legal_ai_app\pubspec.yaml" (
    echo Using clean path junction to avoid apostrophe issues...
    set "USE_JUNCTION=1"
    cd /d "%JUNCTION_PATH%\legal_ai_app"
) else (
    cd /d "%~dp0legal_ai_app"
)

echo ========================================
echo Running All Automated Tests
echo ========================================
echo.
echo This will test:
echo   - State management logic
echo   - UI components
echo   - State persistence
echo ========================================
echo.

echo [1/3] Installing dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo [2/3] Running state management tests...
flutter test test/state_management_test.dart
set STATE_TEST=%ERRORLEVEL%
echo.

echo [3/3] Running UI component tests...
flutter test test/ui_components_test.dart
set UI_TEST=%ERRORLEVEL%
echo.

echo [4/5] Running state persistence tests...
flutter test test/state_persistence_test.dart
set PERSISTENCE_TEST=%ERRORLEVEL%
echo.

echo [5/6] Running critical logic tests...
flutter test test/critical_logic_test.dart
set CRITICAL_TEST=%ERRORLEVEL%
echo.

echo [6/6] Running model serialization tests...
flutter test test/model_serialization_test.dart
set MODEL_TEST=%ERRORLEVEL%
echo.

echo ========================================
echo Test Summary
echo ========================================
echo.

set TOTAL_FAILED=0

if %STATE_TEST% EQU 0 (
    echo ✅ State Management Tests: PASSED
) else (
    echo ❌ State Management Tests: FAILED
    set /a TOTAL_FAILED+=1
)

if %UI_TEST% EQU 0 (
    echo ✅ UI Component Tests: PASSED
) else (
    echo ❌ UI Component Tests: FAILED
    set /a TOTAL_FAILED+=1
)

if %PERSISTENCE_TEST% EQU 0 (
    echo ✅ State Persistence Tests: PASSED
) else (
    echo ❌ State Persistence Tests: FAILED
    set /a TOTAL_FAILED+=1
)

if %CRITICAL_TEST% EQU 0 (
    echo ✅ Critical Logic Tests: PASSED
) else (
    echo ❌ Critical Logic Tests: FAILED
    set /a TOTAL_FAILED+=1
)

if %MODEL_TEST% EQU 0 (
    echo ✅ Model Serialization Tests: PASSED
) else (
    echo ❌ Model Serialization Tests: FAILED
    set /a TOTAL_FAILED+=1
)

echo.

if %TOTAL_FAILED% EQU 0 (
    echo ✅ ALL TESTS PASSED!
    echo.
    echo Ready to run app in Chrome:
    echo   flutter run -d chrome
) else (
    echo ❌ %TOTAL_FAILED% test suite(s) failed
    echo.
    echo Fix test failures before running app.
)

echo.
pause
