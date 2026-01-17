@echo off
title Commit Slice 1 Changes
color 0A
echo ========================================
echo Commit Slice 1 Completion
echo ========================================
echo.

cd /d "%~dp0\..\.."

echo Checking Git status...
git status --short
echo.

echo Staging all changes...
git add .
echo ✅ Staged
echo.

echo Committing...
git commit -m "feat: Complete Slice 1 - Navigation Shell + UI System

Implementation:
- Flutter app structure with clean architecture
- Theme system (colors, typography, spacing)
- 7 reusable UI widgets
- Firebase Auth integration
- Cloud Functions integration (orgCreate, orgJoin, memberGetMyMembership)
- Navigation with GoRouter
- State management with Provider
- 7 screens (splash, login, signup, password reset, org selection, org create, home)
- App shell with navigation

Fixes:
- Firebase configuration (real API keys)
- Function name corrections (orgCreate vs org.create)
- CORS issues resolved
- Error handling improvements
- Region configuration (us-central1)

Documentation:
- Slice 1 completion report
- Development learnings document
- Updated slice status
- Updated README

Testing:
- All tests passing
- Login working
- Organization creation working
- Dashboard displaying correctly"
echo.

if %ERRORLEVEL% EQU 0 (
    echo ✅ Commit successful!
    echo.
    echo Next: Push to GitHub
    echo   git push origin main
    echo   OR run: scripts\dev\push-to-github.bat
) else (
    echo ❌ Commit failed
)

echo.
pause
