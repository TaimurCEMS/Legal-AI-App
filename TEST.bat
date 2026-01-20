@echo off
title Testing - Legal AI App
color 0B
cd /d "%~dp0legal_ai_app"

echo ========================================
echo Running All Tests
echo ========================================
echo.

flutter pub get
echo.

echo Running tests...
flutter test
echo.

echo ========================================
echo Done - Check results above
echo ========================================
echo.
pause
