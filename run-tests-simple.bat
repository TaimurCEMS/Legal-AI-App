@echo off
REM Simple test runner that definitely stays open
title Testing - Legal AI App
color 0B

cd /d "%~dp0"

echo ========================================
echo Running Tests
echo ========================================
echo.

cd legal_ai_app

echo Installing dependencies...
call flutter pub get
echo.

echo Running all tests...
call flutter test
echo.

echo ========================================
echo Tests Complete
echo ========================================
echo.
echo Press any key to close...
pause
