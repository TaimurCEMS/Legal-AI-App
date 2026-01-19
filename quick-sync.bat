@echo off
REM Quick sync - minimal prompts, just sync
title Quick GitHub Sync
color 0A

cd /d "%~dp0"

echo Syncing with GitHub...
echo.

REM Fetch and pull
git fetch origin >nul 2>&1
git pull origin main >nul 2>&1

REM Stage, commit, push
git add . >nul 2>&1
git diff --cached --quiet
if %ERRORLEVEL% NEQ 0 (
    git commit -m "chore: sync changes" >nul 2>&1
)

git push origin main >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ✅ Synced successfully
) else (
    echo ❌ Sync failed - run sync-to-github.bat for details
)
