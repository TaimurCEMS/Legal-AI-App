@echo off
echo ========================================
echo Testing After Reorganization
echo ========================================
echo.

echo [1/4] Running lint check...
cd ..\..\functions
call npm run lint
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Lint failed!
    cd ..\..\scripts\dev
    pause
    exit /b 1
)
echo ✅ Lint passed
echo.

echo [2/4] Running build...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Build failed!
    cd ..\..\scripts\dev
    pause
    exit /b 1
)
echo ✅ Build passed
echo.

echo [3/4] Running tests...
call npm run test:slice0
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Tests failed!
    cd ..\..\scripts\dev
    pause
    exit /b 1
)
echo ✅ Tests passed
cd ..\..\scripts\dev
echo.

echo [4/4] Checking deployed functions...
cd ..\..
firebase functions:list --project legal-ai-app-1203e
cd scripts\dev
echo.

echo ========================================
echo ✅ All checks passed!
echo ========================================
pause
