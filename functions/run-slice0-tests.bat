@echo off
REM Run Slice 0 Terminal Tests
echo Setting environment variables...
set FIREBASE_API_KEY=AIzaSyCyMLidl_iXmQG0fLOhi4Vl_netaa_7ZAY
set GCLOUD_PROJECT=legal-ai-app-1203e

REM Set service account key path (auto-detect if exists)
if exist "legal-ai-app-1203e-firebase-adminsdk-fbsvc-e37a15e13c.json" (
    set GOOGLE_APPLICATION_CREDENTIALS=%~dp0legal-ai-app-1203e-firebase-adminsdk-fbsvc-e37a15e13c.json
    echo Service account key found: %GOOGLE_APPLICATION_CREDENTIALS%
) else (
    echo WARNING: Service account key not found!
    echo Please ensure the key file is in the functions directory.
)

echo.
echo Running Slice 0 tests...
echo.

npm run test:slice0

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Tests completed successfully!
) else (
    echo.
    echo ❌ Tests failed. Check the error messages above.
)

pause
