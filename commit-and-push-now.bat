@echo off
setlocal enabledelayedexpansion
title Commit and Push - Ready for Slice 2
color 0A

cd /d "%~dp0"

echo ========================================
echo Committing and Pushing Changes
echo ========================================
echo.

echo [1/4] Staging all changes...
git add .
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to stage changes
    pause
    exit /b 1
)
echo ✅ Changes staged
echo.

echo [2/4] Creating commit...
git commit -m "feat: Add GitHub sync scripts and app launchers" -m "- Add sync-to-github.bat for full sync workflow" -m "- Add quick-sync.bat for fast syncing" -m "- Add check-sync-status.bat to check sync status" -m "- Add app launcher scripts (run-app.bat, quick-run.bat, run-app-with-setup.bat)" -m "- Update README with sync workflow documentation" -m "- Add sync workflow guide (scripts/dev/sync-workflow.md)" -m "- Update QUICK_START.md with new folder path and launchers" -m "" -m "Ready for Slice 2 development."
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Commit failed
    pause
    exit /b 1
)
echo ✅ Commit created
echo.

echo [3/4] Pushing to GitHub...
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Push failed - trying alternative...
    git push -u origin main
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ Push still failed
        echo.
        echo Use GitHub Desktop to push instead, or check authentication
        pause
        exit /b 1
    )
)
echo ✅ Pushed to GitHub
echo.

echo [4/4] Verifying...
git status --short
echo.

echo ========================================
echo ✅ Successfully synced with GitHub!
echo ========================================
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.
echo Ready for Slice 2 development!
echo.
pause
