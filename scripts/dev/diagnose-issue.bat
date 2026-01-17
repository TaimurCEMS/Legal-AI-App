@echo off
echo ========================================
echo Diagnostic Check
echo ========================================
echo.

cd ..\..

echo [1] Checking Node.js...
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Node.js not found in PATH
    echo    Please install Node.js or add it to PATH
) else (
    node --version
    echo ✅ Node.js found
)
echo.

echo [2] Checking npm...
where npm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ npm not found in PATH
) else (
    npm --version
    echo ✅ npm found
)
echo.

echo [3] Checking functions directory...
if not exist "functions" (
    echo ❌ functions directory not found!
) else (
    echo ✅ functions directory exists
)
echo.

echo [4] Checking source files...
if not exist "functions\src\index.ts" (
    echo ❌ functions\src\index.ts not found!
) else (
    echo ✅ index.ts exists
)

if not exist "functions\src\functions\org.ts" (
    echo ❌ functions\src\functions\org.ts not found!
) else (
    echo ✅ org.ts exists
)

if not exist "functions\src\functions\member.ts" (
    echo ❌ functions\src\functions\member.ts not found!
) else (
    echo ✅ member.ts exists
)
echo.

echo [5] Checking node_modules...
if not exist "functions\node_modules" (
    echo ⚠️  node_modules not found
    echo    Run: cd functions && npm install
) else (
    echo ✅ node_modules exists
)
echo.

echo [6] Checking package.json...
if not exist "functions\package.json" (
    echo ❌ package.json not found!
) else (
    echo ✅ package.json exists
)
echo.

echo ========================================
echo Diagnostic complete!
echo.
echo Please share the error message you got
echo when running scripts\dev\test-reorganization.bat
echo ========================================
cd scripts\dev
pause
