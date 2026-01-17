@echo off
echo Testing After Reorganization
echo ========================================
echo.

echo Step 1: Checking if functions directory exists...
cd ..\..
if not exist "functions" (
    echo ERROR: functions directory not found!
    cd scripts\dev
    pause
    exit /b 1
)
echo OK: functions directory exists
echo.

echo Step 2: Checking if package.json exists...
if not exist "functions\package.json" (
    echo ERROR: package.json not found!
    cd scripts\dev
    pause
    exit /b 1
)
echo OK: package.json exists
echo.

echo Step 3: Checking if source files exist...
if not exist "functions\src\index.ts" (
    echo ERROR: src\index.ts not found!
    cd scripts\dev
    pause
    exit /b 1
)
if not exist "functions\src\functions\org.ts" (
    echo ERROR: src\functions\org.ts not found!
    cd scripts\dev
    pause
    exit /b 1
)
if not exist "functions\src\functions\member.ts" (
    echo ERROR: src\functions\member.ts not found!
    cd scripts\dev
    pause
    exit /b 1
)
echo OK: All source files exist
echo.

echo Step 4: Checking if node_modules exists...
if not exist "functions\node_modules" (
    echo WARNING: node_modules not found. Run 'npm install' in functions directory first.
) else (
    echo OK: node_modules exists
)
echo.

echo ========================================
echo File structure check complete!
echo.
echo Next: Run these commands manually:
echo   1. cd functions
echo   2. npm run lint
echo   3. npm run build
echo   4. npm run test:slice0
echo ========================================
cd scripts\dev
pause
