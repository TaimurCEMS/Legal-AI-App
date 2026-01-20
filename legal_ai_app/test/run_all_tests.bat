@echo off
REM Run all Flutter tests
title Running All Tests - Legal AI App
color 0B

cd /d "%~dp0"

echo ========================================
echo Running All Flutter Tests
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

echo [4/4] Running state persistence tests...
flutter test test/state_persistence_test.dart
set PERSISTENCE_TEST=%ERRORLEVEL%
echo.

echo ========================================
echo Test Summary
echo ========================================
echo.

if %STATE_TEST% EQU 0 (
    echo ✅ State Management Tests: PASSED
) else (
    echo ❌ State Management Tests: FAILED
)

if %UI_TEST% EQU 0 (
    echo ✅ UI Component Tests: PASSED
) else (
    echo ❌ UI Component Tests: FAILED
)

if %PERSISTENCE_TEST% EQU 0 (
    echo ✅ State Persistence Tests: PASSED
) else (
    echo ❌ State Persistence Tests: FAILED
)

echo.

if %STATE_TEST% EQU 0 if %UI_TEST% EQU 0 if %PERSISTENCE_TEST% EQU 0 (
    echo ✅ ALL TESTS PASSED - Ready to run in Chrome!
    echo.
    echo Next step: flutter run -d chrome
) else (
    echo ❌ SOME TESTS FAILED - Fix issues before running app
)

echo.
pause
