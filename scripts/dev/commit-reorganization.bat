@echo off
echo ========================================
echo Committing Reorganization Changes
echo ========================================
echo.

cd ..\..

echo [1/3] Checking git status...
git status
echo.

echo [2/3] Staging all changes...
git add .
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to stage changes
    cd scripts\dev
    pause
    exit /b 1
)
echo ✅ Changes staged
echo.

echo [3/3] Creating commit...
git commit -F scripts\dev\REORGANIZATION_COMMIT_MESSAGE.txt
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Commit failed
    cd scripts\dev
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ Commit created successfully!
echo ========================================
echo.
echo To verify, run: git log -1
echo.
cd scripts\dev
pause
