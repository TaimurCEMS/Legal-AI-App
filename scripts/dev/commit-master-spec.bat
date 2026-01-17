@echo off
REM Commit Master Spec v1.3.2 update
REM This script commits only the Legal AI App project files

cd /d "%~dp0\..\.."

echo.
echo ========================================
echo Committing Master Spec v1.3.2 Update
echo ========================================
echo.

REM Add only project files (exclude AppData and other system folders)
git add README.md
git add docs/
git add functions/
git add scripts/
git add firebase.json
git add firestore.indexes.json
git add firestore.rules
git add .gitignore

echo.
echo Staged files:
git status --short

echo.
echo Creating commit...
git commit -m "docs: update Master Spec to v1.3.2 with repository structure guidelines

- Add Section 2.7: Repository Structure & Organization
- Document root directory rules, folder structure, and file organization
- Update version to 1.3.2
- Update README to reference new version
- Add update summary document

This establishes repository structure as a non-negotiable principle
and provides clear guidelines for maintaining a clean, professional
repository structure going forward."

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Commit successful!
    echo.
    echo To push to GitHub, run:
    echo   git push origin main
) else (
    echo.
    echo ❌ Commit failed!
    exit /b 1
)
