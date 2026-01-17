@echo off
title Fix CORS - Deploy Functions
color 0C
echo ========================================
echo Fix CORS Error - Deploy Cloud Functions
echo ========================================
echo.
echo PROBLEM: CORS error when calling Cloud Functions
echo   Error: No 'Access-Control-Allow-Origin' header
echo.
echo SOLUTION: Redeploy Cloud Functions
echo   Firebase callable functions handle CORS automatically,
echo   but they need to be properly deployed.
echo.
echo ========================================
echo.

cd /d "%~dp0\..\functions"

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
echo Press any key to deploy...
pause >nul
echo.

firebase deploy --only functions --project legal-ai-app-1203e
set DEPLOY_RESULT=%ERRORLEVEL%

echo.
echo ========================================
if %DEPLOY_RESULT% EQU 0 (
    echo ✅ Functions deployed successfully!
    echo.
    echo Step 4: Verifying deployment...
    firebase functions:list --project legal-ai-app-1203e
    echo.
    echo ✅ Ready to test!
    echo.
    echo Next steps:
    echo   1. Hot restart the Flutter app (press R)
    echo   2. Try creating an organization again
) else (
    echo ❌ Deployment failed (Error: %DEPLOY_RESULT%)
    echo.
    echo Troubleshooting:
    echo   1. Make sure you're logged in: firebase login
    echo   2. Check Firebase project: firebase use legal-ai-app-1203e
    echo   3. Try deploying again
)

echo.
echo ========================================
pause
