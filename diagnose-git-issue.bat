@echo off
title Diagnose Git Issue
color 0E
echo ========================================
echo Git Issue Diagnostic
echo ========================================
echo.

cd /d "%~dp0"

echo [1/5] Checking if Git is initialized...
echo ----------------------------------------
if exist ".git" (
    echo ✅ Git repository found
) else (
    echo ❌ Git not initialized
    echo    Run: git init
    pause
    exit /b 1
)
echo.

echo [2/5] Checking Git status...
echo ----------------------------------------
git status
echo.

echo [3/5] Checking remote configuration...
echo ----------------------------------------
git remote -v
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  No remote configured
    echo    You may need to add remote:
    echo    git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
) else (
    echo ✅ Remote configured
)
echo.

echo [4/5] Checking for uncommitted changes...
echo ----------------------------------------
git status --short
if %ERRORLEVEL% EQU 0 (
    echo ✅ Status check successful
) else (
    echo ⚠️  Status check had issues
)
echo.

echo [5/5] Testing Git commands...
echo ----------------------------------------
echo Testing: git add .
git add . --dry-run 2>&1 | findstr /C:"error" /C:"fatal" /C:"warning"
if %ERRORLEVEL% EQU 0 (
    echo ⚠️  Issues detected with git add
) else (
    echo ✅ git add should work
)
echo.

echo ========================================
echo What error did you see?
echo ========================================
echo.
echo Please share:
echo   1. The exact error message
echo   2. Which step failed (add, commit, or push)
echo   3. Any output from the batch file
echo.
pause
