# Setup Git and Push to GitHub
# This script will initialize git, connect to GitHub, and push all code

Write-Host "🔧 Setting up Git repository..." -ForegroundColor Cyan

# Initialize git repository
Write-Host "📦 Initializing git repository..." -ForegroundColor Yellow
git init

# Add remote (remove if exists first)
Write-Host "🔗 Setting up remote..." -ForegroundColor Yellow
git remote remove origin 2>$null
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git

# Verify remote
Write-Host "✅ Remote configured:" -ForegroundColor Green
git remote -v

# Add all files
Write-Host "📝 Adding all files..." -ForegroundColor Yellow
git add .

# Commit
Write-Host "💾 Committing changes..." -ForegroundColor Yellow
git commit -m "Initial commit: Slice 0 implementation (Org + Entitlements Engine)"

# Fetch from remote to see what's there
Write-Host "📥 Fetching from remote..." -ForegroundColor Yellow
git fetch origin

# Force push to overwrite existing data
Write-Host "🚀 Pushing to GitHub (this will overwrite existing data)..." -ForegroundColor Yellow
Write-Host "⚠️  WARNING: This will delete all existing data in the GitHub repository!" -ForegroundColor Red
git push -f origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "🌐 Repository: https://github.com/TaimurCEMS/Legal-AI-App" -ForegroundColor Cyan
} else {
    Write-Host "❌ Push failed. You may need to:" -ForegroundColor Red
    Write-Host "   1. Set default branch: git branch -M main" -ForegroundColor Yellow
    Write-Host "   2. Try push again: git push -f origin main" -ForegroundColor Yellow
}
