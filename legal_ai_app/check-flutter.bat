@echo off
REM Check if Flutter is installed and in PATH
title Flutter Installation Checker
color 0B

echo ========================================
echo Flutter Installation Checker
echo ========================================
echo.

echo Checking if Flutter is in PATH...
echo ----------------------------------------
where flutter >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ Flutter found in PATH!
    echo.
    where flutter
    echo.
    echo Running flutter doctor...
    echo ----------------------------------------
    flutter doctor
    echo.
    echo ✅ Flutter is ready to use!
) else (
    echo ❌ Flutter NOT found in PATH
    echo.
    echo Flutter is either:
    echo   1. Not installed
    echo   2. Installed but not in PATH
    echo.
    echo ========================================
    echo SOLUTION
    echo ========================================
    echo.
    echo Option 1: Install Flutter
    echo   - Download from: https://flutter.dev/docs/get-started/install/windows
    echo   - Extract to: C:\src\flutter
    echo   - Add C:\src\flutter\bin to PATH
    echo.
    echo Option 2: Find Flutter Installation
    echo   - Check common locations:
    echo     * C:\src\flutter
    echo     * C:\flutter
    echo     * C:\Users\%USERNAME%\flutter
    echo   - Add [flutter_path]\bin to PATH
    echo.
    echo Option 3: Use Full Path
    echo   - If Flutter is at C:\src\flutter, use:
    echo     C:\src\flutter\bin\flutter [command]
    echo.
    echo ========================================
    echo.
    echo Checking common Flutter locations...
    echo ----------------------------------------
    if exist "C:\src\flutter\bin\flutter.bat" (
        echo ✅ Found Flutter at: C:\src\flutter
        echo.
        echo You can use: C:\src\flutter\bin\flutter [command]
        echo Or add C:\src\flutter\bin to PATH
    ) else if exist "C:\flutter\bin\flutter.bat" (
        echo ✅ Found Flutter at: C:\flutter
        echo.
        echo You can use: C:\flutter\bin\flutter [command]
        echo Or add C:\flutter\bin to PATH
    ) else (
        echo ❌ Flutter not found in common locations
        echo.
        echo Please install Flutter or add it to PATH
    )
)

echo.
echo ========================================
echo.
echo Press any key to exit...
pause >nul
