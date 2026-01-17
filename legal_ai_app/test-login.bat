@echo off
title Test Login
color 0A
echo ========================================
echo Test Login Helper
echo ========================================
echo.
echo Test Credentials:
echo   Email: test-17jan@test.com
echo   Password: 123456
echo.
echo ========================================
echo.
echo This script will help you test the login.
echo.
echo Prerequisites:
echo   1. Firebase must be configured (run configure-firebase.bat)
echo   2. User must be created in Firebase Console
echo   3. Email/Password authentication must be enabled
echo.
echo ========================================
echo.
echo Choose an option:
echo.
echo [1] Run the app (to test login manually)
echo [2] Check Firebase configuration
echo [3] Open Firebase Console (to create user)
echo [4] Exit
echo.
set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" goto :run_app
if "%choice%"=="2" goto :check_config
if "%choice%"=="3" goto :open_console
if "%choice%"=="4" goto :end

echo Invalid choice. Please try again.
pause
goto :end

:run_app
echo.
echo Starting the app...
echo.
cd /d "%~dp0"
flutter run -d chrome
goto :end

:check_config
echo.
echo Checking Firebase configuration...
echo.
cd /d "%~dp0"
if exist "lib\firebase_options.dart" (
    findstr /C:"placeholder" "lib\firebase_options.dart" >nul
    if %ERRORLEVEL% EQU 0 (
        echo ❌ Firebase not configured (still has placeholders)
        echo    Run configure-firebase.bat first
    ) else (
        echo ✅ Firebase configured
    )
) else (
    echo ❌ firebase_options.dart not found
    echo    Run configure-firebase.bat first
)
echo.
pause
goto :end

:open_console
echo.
echo Opening Firebase Console...
echo.
start https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/users
echo.
echo In Firebase Console:
echo   1. Click "Add user"
echo   2. Email: test-17jan@test.com
echo   3. Password: 123456
echo   4. Click "Add user"
echo.
pause
goto :end

:end
echo.
echo ========================================
echo.
echo Test Credentials:
echo   Email: test-17jan@test.com
echo   Password: 123456
echo.
echo Press any key to exit...
pause >nul
