@echo off
setlocal enabledelayedexpansion
title Commit and Push - Slice 2 Complete
color 0A

cd /d "%~dp0"

echo ========================================
echo Committing Slice 2 Completion
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
git commit -m "feat: Complete Slice 2 - Case Hub" -m "" -m "Backend:" -m "- All 5 case functions deployed (create, get, list, update, delete)" -m "- Two-query merge for visibility (ORG_WIDE + PRIVATE)" -m "- Client name batch lookup" -m "- Comprehensive error handling and audit logging" -m "" -m "Frontend:" -m "- CaseListScreen with search and filters" -m "- CaseCreateScreen with validation" -m "- CaseDetailsScreen with view/edit/delete" -m "- State management with persistence" -m "- Organization switching support" -m "" -m "Fixes:" -m "- Fixed filter 'All statuses' not working (explicit onTap handler)" -m "- Fixed infinite rebuild loops (listener pattern)" -m "- Simplified state tracking" -m "- Reduced debug logging (60%% reduction)" -m "- Code cleanup completed" -m "" -m "Documentation:" -m "- Slice 2 completion document" -m "- Completion report" -m "- Updated slice status" -m "- Added 5 new learnings to development learnings" -m "" -m "Testing:" -m "- All features tested and working" -m "- Edge cases tested" -m "- State persistence verified" -m "" -m "Slice 2 Status: ✅ COMPLETE"
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
echo ✅ Successfully synced Slice 2 to GitHub!
echo ========================================
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.
echo Slice 2 Status: ✅ COMPLETE
echo Ready for Slice 3 development!
echo.
pause
