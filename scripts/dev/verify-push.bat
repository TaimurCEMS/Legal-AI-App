@echo off
REM Verify git push status
echo Checking git status...
echo.

git status

echo.
echo.
echo Checking recent commits...
echo.

git log --oneline -3

echo.
echo.
echo Checking remote connection...
echo.

git remote -v

echo.
echo.
echo ========================================
echo To verify on GitHub, visit:
echo https://github.com/TaimurCEMS/Legal-AI-App
echo ========================================
echo.

pause
