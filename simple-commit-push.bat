@echo off
title Simple Commit and Push
color 0A
setlocal enabledelayedexpansion

echo ========================================
echo Simple Git Commit and Push
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Checking Git...
if not exist ".git" (
    echo ❌ Git not initialized!
    echo    Run: git init
    pause
    exit /b 1
)
echo ✅ Git initialized
echo.

echo Step 2: Checking what will be committed...
git status --short
echo.

echo Step 3: Staging changes...
git add .
set ADD_OK=%ERRORLEVEL%
if !ADD_OK! NEQ 0 (
    echo ❌ git add failed (Error: !ADD_OK!)
    echo.
    echo This might mean:
    echo   - Git repository not properly initialized
    echo   - Files outside repository
    echo   - Permission issues
    echo.
    pause
    exit /b 1
)
echo ✅ Changes staged
echo.

echo Step 4: Committing...
git commit -m "feat: Complete Slice 1 - Navigation Shell + UI System

- Flutter app structure and navigation
- Theme system and reusable widgets
- Firebase Auth integration
- Organization management
- Cloud Functions integration
- All tests passing
- Documentation updated
- Development learnings documented"
set COMMIT_OK=%ERRORLEVEL%
if !COMMIT_OK! NEQ 0 (
    echo ❌ Commit failed (Error: !COMMIT_OK!)
    echo.
    echo This might mean:
    echo   - No changes to commit
    echo   - Git user not configured
    echo   - Commit message issue
    echo.
    echo Check: git config user.name
    echo Check: git config user.email
    echo.
    pause
    exit /b 1
)
echo ✅ Commit created
echo.

echo Step 5: Pushing to GitHub...
git push origin main
set PUSH_OK=%ERRORLEVEL%
if !PUSH_OK! NEQ 0 (
    echo.
    echo ❌ Push failed (Error: !PUSH_OK!)
    echo.
    echo Common issues:
    echo   1. Remote not configured
    echo      Fix: git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
    echo.
    echo   2. Not authenticated
    echo      Fix: git push -u origin main (first time)
    echo.
    echo   3. Branch name mismatch
    echo      Check: git branch (might be 'master' not 'main')
    echo      Fix: git push origin master (if branch is master)
    echo.
    echo   4. Network/authentication
    echo      Check GitHub credentials
    echo.
    pause
    exit /b 1
)
echo.
echo ✅ Successfully pushed to GitHub!
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.

pause
