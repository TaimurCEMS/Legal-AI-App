@echo off
REM Run Flutter commands using full path (if Flutter not in PATH)
title Slice 1 Test (Using Flutter Path)
color 0A

echo ========================================
echo Slice 1 Testing (Using Flutter Path)
echo ========================================
echo.

cd /d "%~dp0"

REM Try to find Flutter
set FLUTTER_PATH=

if exist "C:\src\flutter\bin\flutter.bat" (
    set FLUTTER_PATH=C:\src\flutter\bin
    echo ✅ Found Flutter at: C:\src\flutter
) else if exist "C:\flutter\bin\flutter.bat" (
    set FLUTTER_PATH=C:\flutter\bin
    echo ✅ Found Flutter at: C:\flutter
) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    set FLUTTER_PATH=%USERPROFILE%\flutter\bin
    echo ✅ Found Flutter at: %USERPROFILE%\flutter
) else (
    echo ❌ Flutter not found in common locations
    echo.
    echo Please specify Flutter path:
    echo   Example: C:\src\flutter\bin
    set /p FLUTTER_PATH="Enter Flutter bin path: "
    if not exist "%FLUTTER_PATH%\flutter.bat" (
        echo ❌ Invalid Flutter path
        pause
        exit /b 1
    )
)

echo.
echo Using Flutter from: %FLUTTER_PATH%
echo.

echo [1/5] Checking Flutter installation...
echo ----------------------------------------
"%FLUTTER_PATH%\flutter" doctor
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter check failed
    pause
    exit /b 1
)
echo ✅ Flutter OK
echo.

echo [2/5] Installing dependencies...
echo ----------------------------------------
"%FLUTTER_PATH%\flutter" pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo [3/5] Checking Firebase configuration...
echo ----------------------------------------
if not exist "lib\firebase_options.dart" (
    echo ⚠️  Firebase not configured
    echo.
    echo Run: "%FLUTTER_PATH%\flutter" fire configure
    echo.
) else (
    echo ✅ Firebase configured
)
echo.

echo [4/5] Running static analysis...
echo ----------------------------------------
"%FLUTTER_PATH%\flutter" analyze
echo.

echo [5/5] Ready to run!
echo ========================================
echo.
echo To run the app, use:
echo   "%FLUTTER_PATH%\flutter" run
echo.
echo Or add Flutter to PATH to use 'flutter' directly
echo.
pause
