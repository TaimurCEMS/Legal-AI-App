@echo off
REM Deploy Firestore Index for memberListMyOrgs
REM This script attempts to deploy the collection group index via Firebase CLI
REM If it fails, you'll need to create it manually in Firebase Console

echo ========================================
echo Firestore Index Deployment Script
echo ========================================
echo.

echo Checking Firebase CLI...
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Firebase CLI not found!
    echo Please install Firebase CLI: npm install -g firebase-tools
    pause
    exit /b 1
)

echo Firebase CLI found.
echo.

echo Attempting to deploy Firestore index...
echo This may take a few moments...
echo.

firebase deploy --only firestore:indexes

if errorlevel 1 (
    echo.
    echo ========================================
    echo DEPLOYMENT FAILED
    echo ========================================
    echo.
    echo The index needs to be created manually in Firebase Console.
    echo.
    echo Follow these steps:
    echo 1. Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/firestore/indexes
    echo 2. Click "Create Index"
    echo 3. Configure:
    echo    - Collection ID: members (select "Collection group")
    echo    - Field: uid
    echo    - Order: Ascending
    echo    - Query scope: Collection group
    echo 4. Click "Create"
    echo 5. Wait for status to change from "Building" to "Enabled"
    echo.
    echo See FIREBASE_INDEX_SETUP.md for detailed instructions.
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo ========================================
    echo SUCCESS!
    echo ========================================
    echo.
    echo The index has been deployed.
    echo It may take a few minutes to build.
    echo.
    echo Check status at:
    echo https://console.firebase.google.com/project/legal-ai-app-1203e/firestore/indexes
    echo.
    echo Once the index status is "Enabled", refresh your Flutter app.
    echo.
)

pause
