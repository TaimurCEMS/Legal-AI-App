@echo off
title Check and Fix Firebase Configuration
color 0E
echo ========================================
echo Firebase Configuration Check
echo ========================================
echo.

cd /d "%~dp0"

echo Checking firebase_options.dart...
findstr /C:"placeholder" "lib\firebase_options.dart" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ❌ PROBLEM FOUND!
    echo ========================================
    echo Firebase is still using PLACEHOLDER values!
    echo.
    echo This is why login fails even though:
    echo   ✅ User exists in Firebase
    echo   ✅ Email/Password is enabled
    echo   ✅ Password is correct
    echo.
    echo The app can't connect to Firebase because
    echo it's using fake API keys instead of real ones.
    echo.
    echo ========================================
    echo SOLUTION: Configure Firebase
    echo ========================================
    echo.
    echo Press any key to configure Firebase now...
    pause >nul
    echo.
    echo Installing FlutterFire CLI...
    dart pub global activate flutterfire_cli
    echo.
    echo Running flutterfire configure...
    echo.
    echo ════════════════════════════════════════
    echo IMPORTANT: Follow these steps:
    echo ════════════════════════════════════════
    echo.
    echo 1. You'll see a list of Firebase projects
    echo 2. Select: legal-ai-app-1203e
    echo    (Use arrow keys ↑↓, press Enter)
    echo.
    echo 3. You'll see platform options
    echo 4. Select: web
    echo    (Press Space to select, then Enter)
    echo.
    echo 5. Wait for it to complete
    echo.
    echo ════════════════════════════════════════
    echo.
    pause
    flutterfire configure
    set CONFIG_RESULT=%ERRORLEVEL%
    echo.
    echo ========================================
    if %CONFIG_RESULT% EQU 0 (
        echo Checking if configuration worked...
        findstr /C:"placeholder" "lib\firebase_options.dart" >nul
        if %ERRORLEVEL% EQU 0 (
            echo ❌ Still has placeholders!
            echo    Configuration may have failed.
            echo    Check the output above for errors.
        ) else (
            echo ✅ SUCCESS! Firebase configured!
            echo    No placeholders found.
            echo.
            echo Updating dependencies...
            flutter pub get
            echo.
            echo ✅ Ready to test login!
            echo.
            echo Next steps:
            echo   1. Run: flutter run -d chrome
            echo   2. Login with: test-17jan@test.com / 123456
        )
    ) else (
        echo ❌ Configuration failed (Error: %CONFIG_RESULT%)
        echo.
        echo Troubleshooting:
        echo   1. Make sure you're logged into Firebase
        echo   2. Run: firebase login
        echo   3. Then try: flutterfire configure again
    )
) else (
    echo ✅ Firebase is configured correctly!
    echo    No placeholders found.
    echo.
    echo If login still fails, check:
    echo   - Browser console (F12) for errors
    echo   - Email/Password is enabled in Firebase
    echo   - User exists in Firebase Console
)

echo.
echo ========================================
pause
