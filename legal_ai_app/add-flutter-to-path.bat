@echo off
echo Adding Flutter to PATH...

:: Get current user PATH
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%B"

:: Check if Flutter is already in PATH
echo %CURRENT_PATH% | findstr /C:"C:\src\flutter\bin" >nul
if %errorlevel% equ 0 (
    echo Flutter is already in PATH.
) else (
    :: Add Flutter to PATH
    setx PATH "%CURRENT_PATH%;C:\src\flutter\bin"
    echo Flutter added to PATH!
    echo.
    echo IMPORTANT: Close and reopen this terminal window for changes to take effect.
)

:: Also add to current session
set PATH=%PATH%;C:\src\flutter\bin

echo.
echo Testing Flutter installation...
C:\src\flutter\bin\flutter.bat --version

pause
