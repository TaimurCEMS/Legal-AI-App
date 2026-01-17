@echo off
title Configure Firebase for Flutter
color 0B
setlocal enabledelayedexpansion

echo ========================================
echo Firebase Configuration for Flutter
echo ========================================
echo.

cd /d "%~dp0"
echo Current directory: %CD%
echo.

echo Your Firebase project: legal-ai-app-1203e
echo.

echo [1/3] Checking FlutterFire CLI...
echo ----------------------------------------
dart pub global list | findstr flutterfire_cli >nul
set CLI_INSTALLED=%ERRORLEVEL%
if !CLI_INSTALLED! NEQ 0 (
    echo FlutterFire CLI not found. Installing...
    echo.
    dart pub global activate flutterfire_cli
    set INSTALL_OK=%ERRORLEVEL%
    if !INSTALL_OK! NEQ 0 (
        echo.
        echo ❌ Failed to install FlutterFire CLI
        echo.
        echo Please install manually:
        echo   dart pub global activate flutterfire_cli
        echo.
        goto :end
    )
    echo.
    echo ✅ FlutterFire CLI installed
) else (
    echo ✅ FlutterFire CLI already installed
)
echo.

echo [2/3] Configuring Firebase...
echo ----------------------------------------
echo.
echo IMPORTANT: When prompted:
echo   1. Select your Firebase project: legal-ai-app-1203e
echo   2. Select platforms: web (press space to select, Enter to confirm)
echo   3. This will generate firebase_options.dart
echo.
echo Press any key to start configuration...
pause >nul
echo.
echo Running flutterfire configure...
echo.
flutterfire configure
set CONFIG_OK=%ERRORLEVEL%
echo.
if !CONFIG_OK! NEQ 0 (
    echo ❌ Configuration failed (Error code: !CONFIG_OK!)
    echo.
    echo You can also configure manually:
    echo   1. Go to Firebase Console
    echo   2. Project Settings → General
    echo   3. Add web app and copy config
    echo   4. Update lib/firebase_options.dart
    echo.
) else (
    echo ✅ Firebase configuration completed!
    echo.
)

echo [3/3] Verifying configuration...
echo ----------------------------------------
if exist "lib\firebase_options.dart" (
    findstr /C:"placeholder" "lib\firebase_options.dart" >nul
    set HAS_PLACEHOLDER=%ERRORLEVEL%
    if !HAS_PLACEHOLDER! EQU 0 (
        echo ⚠️  Warning: firebase_options.dart still has placeholders
        echo    Please configure manually or run flutterfire configure again
    ) else (
        echo ✅ firebase_options.dart configured correctly
    )
) else (
    echo ❌ firebase_options.dart not found
)
echo.

:end
echo ========================================
echo Next Steps:
echo ========================================
echo.
echo 1. Enable Email/Password Authentication:
echo    - Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/authentication
echo    - Click "Get Started" or "Sign-in method"
echo    - Enable "Email/Password"
echo.
echo 2. Create a test user (choose one):
echo    Option A: Via Firebase Console
echo      - Go to Authentication → Users → Add user
echo    Option B: Via App
echo      - Run the app and use Sign Up screen
echo.
echo 3. Run the app:
echo    flutter run -d chrome
echo.
echo ========================================
echo.
echo Press any key to exit...
pause >nul
