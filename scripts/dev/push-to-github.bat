@echo off
REM Push to GitHub
echo Pushing to GitHub...
echo.

git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Successfully pushed to GitHub!
    echo 🌐 Repository: https://github.com/TaimurCEMS/Legal-AI-App
) else (
    echo.
    echo ❌ Push failed. Check the error messages above.
    echo.
    echo Common issues:
    echo - Authentication required (GitHub credentials)
    echo - Network connectivity
    echo - Remote repository permissions
)

pause
