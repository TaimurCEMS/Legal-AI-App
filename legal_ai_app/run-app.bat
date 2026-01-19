@echo off
REM Simple launcher to run the Flutter app directly
title Legal AI App - Running
color 0A

cd /d "%~dp0"

echo ========================================
echo Legal AI App - Starting...
echo ========================================
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found in PATH
    echo.
    echo Trying alternative method...
    echo.
    call run-with-flutter-path.bat
    exit /b
)

echo ✅ Flutter found
echo.

REM Install dependencies if needed
echo Installing/updating dependencies...
flutter pub get
echo.

REM Run the app
echo Starting app in Chrome...
echo.
flutter run -d chrome

pause
