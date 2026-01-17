@echo off
REM Delete legacy "api" function from Firebase
echo Deleting legacy "api" function...
echo.

firebase functions:delete api --region us-central1 --project legal-ai-app-1203e

echo.
echo Verification: Listing remaining functions...
echo.
firebase functions:list --project legal-ai-app-1203e

echo.
echo Done!
pause
