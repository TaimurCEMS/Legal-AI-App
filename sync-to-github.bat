@echo off
REM Comprehensive GitHub sync script - Pull, Commit, Push
title GitHub Sync - Legal AI App
color 0B
setlocal enabledelayedexpansion

echo ========================================
echo GitHub Sync - Legal AI App
echo ========================================
echo.

cd /d "%~dp0"

REM Check if Git is initialized
if not exist ".git" (
    echo ❌ Git not initialized!
    echo    This folder doesn't appear to be a Git repository.
    echo.
    echo    If using GitHub Desktop, make sure you've cloned the repo.
    pause
    exit /b 1
)
echo ✅ Git repository found
echo.

REM Step 1: Check current status
echo [Step 1/5] Checking current status...
echo ----------------------------------------
git status --short
echo.

REM Step 2: Fetch latest changes (don't merge yet)
echo [Step 2/5] Fetching latest changes from GitHub...
echo ----------------------------------------
git fetch origin
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  Fetch failed (might not have remote configured)
    echo    Continuing anyway...
    echo.
) else (
    echo ✅ Fetched latest changes
    echo.
)

REM Step 3: Check if we're behind
echo [Step 3/5] Checking if local is behind remote...
echo ----------------------------------------
git rev-list --count HEAD..origin/main >nul 2>&1
set BEHIND=%ERRORLEVEL%
if !BEHIND! EQU 0 (
    git rev-list --count HEAD..origin/main > temp_behind.txt
    set /p BEHIND_COUNT=<temp_behind.txt
    del temp_behind.txt
    if !BEHIND_COUNT! GTR 0 (
        echo ⚠️  Local branch is !BEHIND_COUNT! commit(s) behind remote
        echo.
        echo Options:
        echo   [1] Pull changes first (recommended)
        echo   [2] Continue without pulling (may cause conflicts)
        echo.
        set /p PULL_CHOICE="Choose (1 or 2): "
        if "!PULL_CHOICE!"=="1" (
            echo.
            echo Pulling changes...
            git pull origin main
            if !ERRORLEVEL! NEQ 0 (
                echo ❌ Pull failed - there may be conflicts
                echo    Resolve conflicts in GitHub Desktop, then try again
                pause
                exit /b 1
            )
            echo ✅ Pulled latest changes
            echo.
        )
    ) else (
        echo ✅ Local is up to date with remote
        echo.
    )
) else (
    echo ✅ Local is up to date (or remote not configured)
    echo.
)

REM Step 4: Stage and commit local changes
echo [Step 4/5] Staging local changes...
echo ----------------------------------------
git add .
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to stage changes
    pause
    exit /b 1
)

REM Check if there are changes to commit
git diff --cached --quiet
if %ERRORLEVEL% EQU 0 (
    echo ✅ No new changes to commit
    echo.
) else (
    echo ✅ Changes staged
    echo.
    echo Staged changes:
    git status --short
    echo.
    
    REM Prompt for commit message
    echo Enter commit message (or press Enter for default):
    echo   Default: "chore: sync changes"
    echo.
    set /p COMMIT_MSG="Commit message: "
    
    if "!COMMIT_MSG!"=="" (
        set COMMIT_MSG=chore: sync changes
    )
    
    echo.
    echo Creating commit: !COMMIT_MSG!
    git commit -m "!COMMIT_MSG!"
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ Commit failed
        pause
        exit /b 1
    )
    echo ✅ Commit created
    echo.
)

REM Step 5: Push to GitHub
echo [Step 5/5] Pushing to GitHub...
echo ----------------------------------------
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Push failed
    echo.
    echo Common issues:
    echo   1. Not authenticated (use GitHub Desktop to authenticate)
    echo   2. Branch name mismatch (check: git branch)
    echo   3. Network connectivity
    echo.
    echo Trying alternative push method...
    git push -u origin main
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ❌ Push still failed
        echo.
        echo Recommendation: Use GitHub Desktop to push instead
        echo   1. Open GitHub Desktop
        echo   2. Review changes
        echo   3. Commit and push from there
        echo.
        pause
        exit /b 1
    )
)

echo.
echo ========================================
echo ✅ Successfully synced with GitHub!
echo ========================================
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.
echo Summary:
git status --short
echo.

pause
