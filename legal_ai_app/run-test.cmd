@echo off
cd /d "%~dp0"
echo Testing Flutter...
echo.
flutter --version
echo.
echo If you see Flutter version above, it's working!
echo.
echo Press any key to continue...
pause >nul
flutter pub get
echo.
echo Press any key to exit...
pause
