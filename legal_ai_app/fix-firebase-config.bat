@echo off
title Fix Firebase Configuration
color 0C
echo ========================================
echo FIXING FIREBASE CONFIGURATION
echo ========================================
echo.
echo PROBLEM DETECTED:
echo   Firebase is using placeholder values!
echo   Error: key=placeholder-web-api-key
echo.
echo This means flutterfire configure hasn't run yet.
echo.
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Installing FlutterFire CLI (if needed)...
echo ----------------------------------------
dart pub global list | findstr flutterfire_cli >nul
if %ERRORLEVEL% NEQ 0 (
    echo Installing FlutterFire CLI...
    dart pub global activate flutterfire_cli
    echo.
) else (
    echo ✅ FlutterFire CLI already installed
    echo.
)

echo Step 2: Configuring Firebase...
echo ----------------------------------------
echo.
echo IMPORTANT: Follow these steps carefully:
echo.
echo 1. You will see a list of Firebase projects
echo 2. Select: legal-ai-app-1203e
echo    (Use arrow keys, press Enter)
echo.
echo 3. You will see platform options
echo 4. Select: web
echo    (Press Space to select, then Enter)
echo.
echo 5. Wait for configuration to complete
echo.
echo Press any key to start configuration...
pause >nul
echo.

flutterfire configure
set CONFIG_RESULT=%ERRORLEVEL%

echo.
echo ========================================
if %CONFIG_RESULT% EQU 0 (
    echo ✅ Configuration completed!
    echo.
    echo Step 3: Verifying configuration...
    echo ----------------------------------------
    findstr /C:"placeholder" "lib\firebase_options.dart" >nul
    if %ERRORLEVEL% EQU 0 (
        echo ❌ Still has placeholders - configuration may have failed
        echo    Please check the output above for errors
    ) else (
        echo ✅ Configuration looks good - no placeholders found
        echo.
        echo Step 4: Updating dependencies...
        flutter pub get
        echo.
        echo ✅ Ready to test login!
    )
) else (
    echo ❌ Configuration failed (Error code: %CONFIG_RESULT%)
    echo.
    echo Troubleshooting:
    echo   1. Make sure you're logged into Firebase CLI
    echo   2. Run: firebase login
    echo   3. Then try: flutterfire configure again
)

echo.
echo ========================================
echo Next Steps:
echo ========================================
echo.
echo 1. Make sure Email/Password is enabled in Firebase Console
echo 2. Make sure user test-17jan@test.com exists
echo 3. Run the app: flutter run -d chrome
echo 4. Try logging in again
echo.
echo ========================================
pause
