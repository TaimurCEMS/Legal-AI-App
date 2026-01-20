@echo off
setlocal enabledelayedexpansion
title Deploy Slice 2 Backend (Functions + Firestore Rules)
color 0A

echo ========================================
echo Deploy Slice 2 Backend
echo ========================================
echo.

REM Move to project root
cd /d "%~dp0"

echo Current directory: %CD%
echo.

echo [1/4] Installing functions dependencies...
cd /d "%CD%\functions"
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Failed to install dependencies
    echo.
    goto :error
)
echo ✅ Dependencies installed
echo.

echo [2/4] Building Cloud Functions (TypeScript -^> lib)...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Failed to build Cloud Functions
    echo.
    goto :error
)
echo ✅ Functions built
echo.

echo [3/4] Deploying Cloud Functions (including case.* endpoints)...
echo Project: legal-ai-app-1203e
echo Region:  us-central1
echo.
firebase deploy --only functions --project legal-ai-app-1203e
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Failed to deploy Cloud Functions
    echo.
    goto :error
)
echo ✅ Functions deployed
echo.

echo [4/4] Deploying Firestore rules (including cases collection rules)...
firebase deploy --only firestore:rules --project legal-ai-app-1203e
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Failed to deploy Firestore rules
    echo.
    goto :error
)
echo ✅ Firestore rules deployed
echo.

echo ========================================
echo ✅ Slice 2 backend deployed successfully!
echo ========================================
echo.
echo Next steps:
echo   1. In a new terminal:
echo        cd "legal_ai_app"
echo        flutter pub get
echo        flutter run -d chrome
echo   2. In Chrome, log in and:
echo        - Select/create an organization
echo        - Open the Cases tab
echo        - Create a new case and confirm it appears in the list
echo.
goto :end

:error
echo.
echo ========================================
echo ❌ Deployment failed
echo ========================================
echo.
echo Check the error messages above for details.
echo.

:end
echo.
echo Script completed. This window will stay open.
echo Type 'exit' to close, or just close this window.
cmd /k
