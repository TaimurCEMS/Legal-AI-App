@echo off
setlocal enabledelayedexpansion
title Check GitHub Sync Status - DEBUG
color 0E

cd /d "%~dp0"

echo.
echo ========================================
echo GitHub Sync Status Check - DEBUG MODE
echo ========================================
echo.
echo Current directory: %CD%
echo.

echo [DEBUG] Checking if .git exists...
if exist ".git" (
    echo [DEBUG] .git folder FOUND
) else (
    echo [DEBUG] .git folder NOT FOUND
    echo [ERROR] Not a Git repository
    echo.
    pause
    exit /b
)
echo.

echo [DEBUG] About to run: git status --short
echo [Step 1/4] Checking local changes...
echo ----------------------------------------
git status --short
echo [DEBUG] git status returned: %ERRORLEVEL%
echo.

echo [DEBUG] About to run: git remote -v
echo [Step 2/4] Checking remote configuration...
echo ----------------------------------------
git remote -v
echo [DEBUG] git remote returned: %ERRORLEVEL%
echo.

echo [DEBUG] About to run: git fetch origin
echo [Step 3/4] Fetching latest info from GitHub...
echo ----------------------------------------
git fetch origin
echo [DEBUG] git fetch returned: %ERRORLEVEL%
echo.

echo [DEBUG] About to run: git status -sb
echo [Step 4/4] Checking branch sync status...
echo ----------------------------------------
git status -sb
echo [DEBUG] git status -sb returned: %ERRORLEVEL%
echo.

echo [DEBUG] About to check ahead/behind status...
set BEHIND=0
set AHEAD=0

echo [DEBUG] Running: git rev-list --count HEAD..origin/main
for /f %%i in ('git rev-list --count HEAD..origin/main 2^>nul') do (
    echo [DEBUG] Behind count result: %%i
    set BEHIND=%%i
)
if "!BEHIND!"=="" set BEHIND=0
echo [DEBUG] Final BEHIND value: !BEHIND!

echo [DEBUG] Running: git rev-list --count origin/main..HEAD
for /f %%i in ('git rev-list --count origin/main..HEAD 2^>nul') do (
    echo [DEBUG] Ahead count result: %%i
    set AHEAD=%%i
)
if "!AHEAD!"=="" set AHEAD=0
echo [DEBUG] Final AHEAD value: !AHEAD!
echo.

echo ========================================
echo Sync Status Summary
echo ========================================
echo.

if !BEHIND! GTR 0 (
    echo [WARNING] Local is !BEHIND! commit(s) BEHIND remote
) else if !AHEAD! GTR 0 (
    echo [WARNING] Local is !AHEAD! commit(s) AHEAD of remote
) else (
    echo [OK] Local and remote are in sync
)
echo.

echo ========================================
echo DEBUG COMPLETE
echo ========================================
echo.
echo Press any key to close...
pause >nul
