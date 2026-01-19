@echo off
REM Quick launcher - minimal checks, just run
title Legal AI App - Quick Run
color 0A

cd /d "%~dp0"

echo Starting Legal AI App...
echo.

flutter pub get >nul 2>&1
flutter run -d chrome
