@echo off
title Setting up Web Support
color 0B
echo ========================================
echo Setting up Web Support for Flutter
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] Adding web platform support...
flutter create . --platforms=web
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to add web support
    pause
    exit /b 1
)
echo ✅ Web support added
echo.

echo [2/3] Updating dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to update dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies updated
echo.

echo [3/3] Verifying setup...
flutter doctor
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo You can now run the app with:
echo   flutter run -d chrome
echo.
pause
