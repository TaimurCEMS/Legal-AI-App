@echo off
title Push to GitHub
color 0A
echo ========================================
echo Push to GitHub
echo ========================================
echo.

cd /d "%~dp0"

echo Current directory: %CD%
echo.

echo Step 1: Checking Git status...
git status --short
echo.

echo Step 2: Adding all new files...
git add .
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to add files
    pause
    exit /b 1
)
echo ✅ Files added
echo.

echo Step 3: Committing new changes (if any)...
git status --short
git diff --cached --quiet
if %ERRORLEVEL% NEQ 0 (
    echo Changes detected, creating commit...
    git commit -m "docs: Add Slice 1 completion documentation and development learnings

- Slice 1 completion report
- Development learnings document
- Updated slice status
- Updated README
- Git helper scripts"
    echo ✅ Commit created
) else (
    echo ✅ No new changes to commit
)
echo.

echo Step 4: Pushing to GitHub...
echo.
echo You are ahead by commits. Pushing now...
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Push failed
    echo.
    echo Trying alternative: git push -u origin main
    git push -u origin main
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ❌ Push still failed
        echo.
        echo Check:
        echo   1. Remote configured: git remote -v
        echo   2. Branch name: git branch
        echo   3. Authentication with GitHub
        pause
        exit /b 1
    )
)
echo.
echo ✅ Successfully pushed to GitHub!
echo.
echo Repository: https://github.com/TaimurCEMS/Legal-AI-App
echo.
pause
