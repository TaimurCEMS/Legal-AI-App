@echo off
REM Git Setup Script for Windows
echo 🔧 Setting up Git repository...

echo 📦 Initializing git repository...
git init

echo 🔗 Setting up remote...
git remote remove origin 2>nul
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git

echo ✅ Remote configured:
git remote -v

echo 📝 Adding all files...
git add .

echo 💾 Committing changes...
git commit -m "Initial commit: Slice 0 implementation (Org + Entitlements Engine)"

echo 📥 Fetching from remote...
git fetch origin

echo 🚀 Pushing to GitHub (this will overwrite existing data)...
echo ⚠️  WARNING: This will delete all existing data in the GitHub repository!
git branch -M main
git push -f origin main

if %ERRORLEVEL% EQU 0 (
    echo ✅ Successfully pushed to GitHub!
    echo 🌐 Repository: https://github.com/TaimurCEMS/Legal-AI-App
) else (
    echo ❌ Push failed. Check the error message above.
    pause
)
