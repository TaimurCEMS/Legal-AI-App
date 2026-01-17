@echo off
REM Test script that definitely stays open
title Slice 1 Testing Script
color 0A

REM Keep window open even on error
setlocal enabledelayedexpansion

echo ========================================
echo Slice 1 Testing Script
echo ========================================
echo.

cd /d "%~dp0"
echo Current directory: %CD%
echo.

echo [1/5] Checking Flutter installation...
echo ----------------------------------------
flutter --version
set FLUTTER_OK=%ERRORLEVEL%
if %FLUTTER_OK% NEQ 0 (
    echo.
    echo ❌ ERROR: Flutter command failed!
    echo Error code: %FLUTTER_OK%
    echo.
) else (
    echo.
    echo ✅ Flutter OK
    echo.
)

echo [2/5] Installing dependencies...
echo ----------------------------------------
flutter pub get
set DEPS_OK=%ERRORLEVEL%
if %DEPS_OK% NEQ 0 (
    echo.
    echo ❌ ERROR: Failed to install dependencies
    echo Error code: %DEPS_OK%
    echo.
) else (
    echo.
    echo ✅ Dependencies installed
    echo.
)

echo [3/5] Checking Firebase configuration...
echo ----------------------------------------
if not exist "lib\firebase_options.dart" (
    echo.
    echo ⚠️  WARNING: Firebase not configured yet (this is OK)
    echo.
    echo To configure later: flutterfire configure
    echo.
) else (
    echo ✅ Firebase configured
    echo.
)

echo [4/5] Running static analysis...
echo ----------------------------------------
flutter analyze
set ANALYZE_OK=%ERRORLEVEL%
if %ANALYZE_OK% NEQ 0 (
    echo.
    echo ⚠️  WARNING: Analysis found issues
    echo Error code: %ANALYZE_OK%
    echo.
) else (
    echo.
    echo ✅ No analysis errors
    echo.
)

echo [5/5] Summary
echo ========================================
echo.
echo Flutter check: 
if %FLUTTER_OK% EQU 0 (echo   ✅ PASSED) else (echo   ❌ FAILED)
echo Dependencies: 
if %DEPS_OK% EQU 0 (echo   ✅ PASSED) else (echo   ❌ FAILED)
echo Firebase: 
if exist "lib\firebase_options.dart" (echo   ✅ CONFIGURED) else (echo   ⚠️  NOT CONFIGURED)
echo Analysis: 
if %ANALYZE_OK% EQU 0 (echo   ✅ PASSED) else (echo   ⚠️  ISSUES FOUND)
echo.
echo ========================================
echo.
echo IMPORTANT: This window will stay open.
echo Press any key to close...
pause
echo.
echo Closing...
