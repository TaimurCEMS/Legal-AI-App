@echo off
REM Check deployed Firebase Functions for legacy "api" function
echo Checking deployed Firebase Functions...
echo.

firebase functions:list --project legal-ai-app-1203e

echo.
echo.
echo If you see "api" in the list above, run this command to delete it:
echo   firebase functions:delete api --region us-central1 --project legal-ai-app-1203e
echo.
echo If "api" is NOT in the list, you're already clean! ✅
echo.

pause
