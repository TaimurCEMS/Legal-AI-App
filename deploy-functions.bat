@echo off
title Deploy Cloud Functions
color 0A
echo ========================================
echo Deploy Cloud Functions to Fix CORS
echo ========================================
echo.

cd /d "%~dp0\functions"

echo Step 1: Installing dependencies...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo Step 2: Building functions...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to build functions
    pause
    exit /b 1
)
echo ✅ Functions built
echo.

echo Step 3: Deploying functions...
echo.
echo This will deploy:
echo   - org.create
echo   - org.join  
echo   - member.getMyMembership
echo.
echo Project: legal-ai-app-1203e
echo Region: us-central1
echo.
pause

firebase deploy --only functions --project legal-ai-app-1203e

echo.
echo ========================================
echo Deployment Complete!
echo ========================================
echo.
echo Next steps:
echo   1. Hot restart Flutter app (press R)
echo   2. Try creating organization again
echo.
pause
