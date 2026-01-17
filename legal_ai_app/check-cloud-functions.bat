@echo off
title Check Cloud Functions
color 0B
echo ========================================
echo Cloud Functions Status Check
echo ========================================
echo.

cd /d "%~dp0\.."

echo Checking if Cloud Functions are deployed...
echo.

firebase functions:list --project legal-ai-app-1203e

echo.
echo ========================================
echo Expected Functions:
echo ========================================
echo.
echo Should see:
echo   - org.create
echo   - org.join
echo   - member.getMyMembership
echo.
echo If functions are missing, deploy them:
echo   cd functions
echo   npm install
echo   npm run build
echo   firebase deploy --only functions
echo.
pause
