@echo off
REM Commit Slice 0 cleanup changes
echo Staging all changes...
git add .

echo.
echo Committing with detailed message...
echo.

git commit -F COMMIT_MESSAGE.txt

echo.
echo Commit complete!
echo.
echo To verify, run: git log -1
echo.
pause
