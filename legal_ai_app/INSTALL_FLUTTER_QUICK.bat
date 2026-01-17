@echo off
REM Quick Flutter Installation Helper
title Flutter Installation Helper
color 0B

echo ========================================
echo Flutter Installation Helper
echo ========================================
echo.

echo This script will guide you through Flutter installation.
echo.
echo Step 1: Download Flutter SDK
echo ----------------------------------------
echo.
echo Please download Flutter SDK from:
echo   https://flutter.dev/docs/get-started/install/windows
echo.
echo The download will be a ZIP file (about 1.5 GB)
echo.
pause

echo.
echo Step 2: Extract Flutter
echo ----------------------------------------
echo.
echo Extract the ZIP file to: C:\src\flutter
echo.
echo Instructions:
echo   1. Create folder: C:\src (if it doesn't exist)
echo   2. Extract flutter_windows_*.zip to C:\src\flutter
echo   3. You should have: C:\src\flutter\bin\flutter.bat
echo.
pause

echo.
echo Step 3: Add Flutter to PATH
echo ----------------------------------------
echo.
echo Method 1: Automatic (Recommended)
echo ----------------------------------------
echo.
echo This script can add Flutter to PATH automatically.
echo.
set /p add_path="Add C:\src\flutter\bin to PATH? (Y/N): "
if /i "%add_path%"=="Y" (
    echo.
    echo Adding Flutter to PATH...
    setx PATH "%PATH%;C:\src\flutter\bin"
    if %ERRORLEVEL% EQU 0 (
        echo ✅ Flutter added to PATH
        echo.
        echo ⚠️  IMPORTANT: Close and reopen Command Prompt for changes to take effect!
    ) else (
        echo ❌ Failed to add to PATH automatically
        echo.
        echo Please add manually:
        echo   1. Win + X → System → Advanced system settings
        echo   2. Environment Variables → Edit Path
        echo   3. Add: C:\src\flutter\bin
    )
) else (
    echo.
    echo Manual PATH setup:
    echo   1. Press Win + X → System
    echo   2. Click "Advanced system settings"
    echo   3. Click "Environment Variables"
    echo   4. Under "User variables", find "Path" and click "Edit"
    echo   5. Click "New" and add: C:\src\flutter\bin
    echo   6. Click OK on all dialogs
    echo   7. Close and reopen Command Prompt
)

echo.
echo Step 4: Verify Installation
echo ----------------------------------------
echo.
echo After adding to PATH:
echo   1. CLOSE this Command Prompt window
echo   2. Open a NEW Command Prompt
echo   3. Run: flutter doctor
echo.
echo If you see Flutter version info, installation is successful!
echo.

echo ========================================
echo Installation Guide Complete
echo ========================================
echo.
echo Next steps:
echo   1. Download Flutter SDK
echo   2. Extract to C:\src\flutter
echo   3. Add to PATH (using method above)
echo   4. Open NEW Command Prompt
echo   5. Run: flutter doctor
echo   6. Then run: test-slice1-verbose.bat
echo.
pause
