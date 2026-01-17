@echo off
title Commit and Push Slice 1 Changes
color 0A
echo ========================================
echo Commit and Push to GitHub
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Checking Git status...
echo ----------------------------------------
git status --short
echo.

echo Step 2: Staging all changes...
echo ----------------------------------------
git add .
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to stage changes
    pause
    exit /b 1
)
echo ✅ Changes staged
echo.

echo Step 3: Creating commit...
echo ----------------------------------------
echo.
echo Commit message:
echo   "feat: Complete Slice 1 - Navigation Shell + UI System
echo   
echo   - Flutter app structure and navigation
echo   - Theme system and reusable widgets
echo   - Firebase Auth integration
echo   - Organization management
echo   - Cloud Functions integration
echo   - All tests passing
echo   - Documentation updated
echo   - Development learnings documented"
echo.
git commit -m "feat: Complete Slice 1 - Navigation Shell + UI System

- Flutter app structure and navigation
- Theme system and reusable widgets  
- Firebase Auth integration
- Organization management
- Cloud Functions integration
- All tests passing
- Documentation updated
- Development learnings documented"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Commit failed
    pause
    exit /b 1
)
echo ✅ Commit created
echo.

echo Step 4: Pushing to GitHub...
echo ----------------------------------------
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Push failed
    echo.
    echo Common issues:
    echo   - Not authenticated with GitHub
    echo   - Network connectivity
    echo   - Remote not configured
    echo.
    echo To set remote:
    echo   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
    echo.
    pause
    exit /b 1
)
echo.
echo ✅ Successfully pushed to GitHub!
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.

echo ========================================
echo Summary
echo ========================================
echo.
echo ✅ All changes committed
echo ✅ Pushed to GitHub
echo.
echo What was committed:
echo   - Slice 1 implementation (Flutter app)
echo   - Updated documentation
echo   - Development learnings
echo   - Configuration fixes
echo   - Test scripts and helpers
echo.
pause
