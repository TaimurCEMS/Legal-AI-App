@echo off
title Flutter Status Check
color 0B
echo ========================================
echo Flutter Status Check
echo ========================================
echo.

cd /d "%~dp0"
echo Current directory: %CD%
echo.

echo Checking Flutter command...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Flutter command failed!
    echo.
) else (
    echo.
    echo ✅ Flutter command works!
    echo.
)

echo Checking if we're in the right directory...
if exist "pubspec.yaml" (
    echo ✅ pubspec.yaml found
) else (
    echo ❌ pubspec.yaml NOT found - wrong directory!
)
echo.

echo Checking if lib folder exists...
if exist "lib" (
    echo ✅ lib folder exists
    dir /b lib
) else (
    echo ❌ lib folder NOT found!
)
echo.

echo Checking Firebase configuration...
if exist "lib\firebase_options.dart" (
    echo ✅ Firebase configured
) else (
    echo ⚠️  Firebase not configured (this is OK for now)
)
echo.

echo ========================================
echo.
echo Press any key to exit...
pause >nul
