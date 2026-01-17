@echo off
REM ========================================
REM Commit Master Spec v1.3.2 Update
REM ========================================

echo.
echo ========================================
echo Committing Master Spec v1.3.2 Update
echo ========================================
echo.

REM Ensure we're in the project root
cd /d "%~dp0"

REM Check if .git exists in current directory
if not exist ".git" (
    echo [1/4] Initializing git repository in project directory...
    git init
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ Failed to initialize git repository
        pause
        exit /b 1
    )
    echo ✅ Git repository initialized
    echo.
) else (
    echo [1/4] Git repository already exists
    echo.
)

REM Check if we have a remote configured
git remote -v >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [2/4] No remote repository configured
    echo.
    echo To configure GitHub remote, run:
    echo   git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git
    echo.
) else (
    echo [2/4] Remote repository configured
    git remote -v
    echo.
)

echo [3/4] Staging project files...
git add README.md
git add docs/
git add functions/
git add scripts/
git add firebase.json
git add firestore.indexes.json
git add firestore.rules
git add .gitignore

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to stage files
    pause
    exit /b 1
)

echo ✅ Files staged
echo.
echo Staged files:
git status --short
echo.

echo [4/4] Creating commit...
if exist "scripts\dev\MASTER_SPEC_COMMIT_MESSAGE.txt" (
    git commit -F scripts\dev\MASTER_SPEC_COMMIT_MESSAGE.txt
) else (
    git commit -m "docs: update Master Spec to v1.3.2 with repository structure guidelines" -m "- Add Section 2.7: Repository Structure & Organization" -m "- Document root directory rules, folder structure, and file organization" -m "- Update version to 1.3.2" -m "- Update README to reference new version"
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ Commit successful!
    echo ========================================
    echo.
    echo Latest commit:
    git log -1 --oneline
    echo.
    echo To push to GitHub, run:
    echo   git push origin main
    echo.
    echo Or if this is the first push:
    echo   git push -u origin main
    echo.
) else (
    echo.
    echo ❌ Commit failed!
    echo.
    echo Check git status:
    git status
    pause
    exit /b 1
)

pause
