@echo off
REM Creates a junction (symlink) to the project with a clean path (no apostrophes)
REM This fixes Flutter test failures when project path contains special characters
title Create Test Junction
color 0E

echo ========================================
echo Creating Junction for Flutter Tests
echo ========================================
echo.
echo This will create a junction (symlink) at:
echo   C:\LegalAIApp
echo.
echo That points to your project directory.
echo This avoids path issues with apostrophes.
echo.

set "JUNCTION_PATH=C:\LegalAIApp"
set "TARGET_PATH=%~dp0"

REM Remove trailing backslash
set "TARGET_PATH=%TARGET_PATH:~0,-1%"

echo Target: %TARGET_PATH%
echo Junction: %JUNCTION_PATH%
echo.

REM Check if junction already exists
if exist "%JUNCTION_PATH%" (
    echo Junction already exists at: %JUNCTION_PATH%
    echo.
    choice /C YN /M "Do you want to remove it and recreate"
    if errorlevel 2 goto :end
    if errorlevel 1 (
        echo Removing existing junction...
        rmdir "%JUNCTION_PATH%" 2>nul
        if exist "%JUNCTION_PATH%" (
            echo ❌ Failed to remove existing junction
            echo Please remove it manually: rmdir "%JUNCTION_PATH%"
            pause
            exit /b 1
        )
    )
)

echo Creating junction...
mklink /J "%JUNCTION_PATH%" "%TARGET_PATH%"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to create junction
    echo.
    echo This requires administrator privileges.
    echo Please run this script as Administrator.
    pause
    exit /b 1
)

echo.
echo ✅ Junction created successfully!
echo.
echo You can now run tests from:
echo   cd %JUNCTION_PATH%\legal_ai_app
echo   flutter test
echo.
echo Or use the run-tests-clean.bat script.
echo.
pause

:end
