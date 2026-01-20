@echo off
REM Run tests using the clean junction path (no apostrophes)
REM This avoids Flutter test path parsing issues
title Running Tests (Clean Path)
color 0B

set "JUNCTION_PATH=C:\LegalAIApp"

REM Check if junction exists
if not exist "%JUNCTION_PATH%" (
    echo ❌ Junction not found at: %JUNCTION_PATH%
    echo.
    echo Please run create-test-junction.bat first to create the junction.
    echo.
    pause
    exit /b 1
)

echo ========================================
echo Running Tests (Using Clean Path)
echo ========================================
echo.
echo Using junction: %JUNCTION_PATH%
echo.

cd /d "%JUNCTION_PATH%\legal_ai_app"

if not exist "pubspec.yaml" (
    echo ❌ Flutter app not found in junction
    echo Junction may be broken. Please recreate it.
    pause
    exit /b 1
)

echo [1/3] Installing dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo [2/3] Running all tests...
flutter test
set TEST_RESULT=%ERRORLEVEL%
echo.

echo [3/3] Test Summary
echo ========================================
if %TEST_RESULT% EQU 0 (
    echo ✅ ALL TESTS PASSED!
    echo.
    echo Ready to run app in Chrome:
    echo   cd %JUNCTION_PATH%\legal_ai_app
    echo   flutter run -d chrome
) else (
    echo ❌ Tests failed (exit code: %TEST_RESULT%)
    echo.
    echo Fix test failures before running app.
)
echo.
pause
