@echo off
title Force Redeploy Functions (Fix CORS)
color 0C
echo ========================================
echo Force Redeploy Functions to Fix CORS
echo ========================================
echo.
echo Functions are deployed but CORS still failing.
echo Forcing redeploy to ensure CORS headers are set.
echo.

cd /d "%~dp0\functions"

echo Step 1: Building functions...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Build failed
    pause
    exit /b 1
)
echo ✅ Build complete
echo.

echo Step 2: Force redeploying functions...
echo.
echo This will force redeploy even if no changes detected.
echo.

firebase deploy --only functions --project legal-ai-app-1203e --force

echo.
echo ========================================
echo If CORS still fails, try:
echo ========================================
echo.
echo 1. Check browser console for exact error
echo 2. Verify function URLs match in Flutter code
echo 3. Make sure you're using callable functions (onCall)
echo 4. Check Firebase Console → Functions to verify deployment
echo.
pause
