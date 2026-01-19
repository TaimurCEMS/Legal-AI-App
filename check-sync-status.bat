@echo off
setlocal enabledelayedexpansion
title Check GitHub Sync Status
color 0E

cd /d "%~dp0"

echo.
echo ========================================
echo GitHub Sync Status Check
echo ========================================
echo.
echo Current directory: %CD%
echo.

if not exist ".git" (
    echo [ERROR] Not a Git repository
    echo This folder doesn't appear to be a Git repository.
    echo.
    pause
    exit /b
)

echo [OK] Git repository found
echo.
echo.

echo [Step 1/4] Checking local changes...
echo ----------------------------------------
git status --short
echo.

echo [Step 2/4] Checking remote configuration...
echo ----------------------------------------
git remote -v
echo.

echo [Step 3/4] Fetching latest info from GitHub...
echo ----------------------------------------
git fetch origin
echo.

echo [Step 4/4] Checking branch sync status...
echo ----------------------------------------
git status -sb
echo.

echo ========================================
echo Summary
echo ========================================
echo.
echo Check the output above for your sync status.
echo.
echo Next steps:
echo   - To sync: Run sync-to-github.bat
echo   - To quick sync: Run quick-sync.bat
echo.
echo ========================================
echo.
echo Press any key to close...
pause
