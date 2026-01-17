# Delete legacy "api" function from Firebase
Write-Host "Deleting legacy 'api' function..." -ForegroundColor Yellow
Write-Host ""

firebase functions:delete api --region us-central1 --project legal-ai-app-1203e

Write-Host ""
Write-Host "Verification: Listing remaining functions..." -ForegroundColor Cyan
Write-Host ""
firebase functions:list --project legal-ai-app-1203e

Write-Host ""
Write-Host "Done! ✅" -ForegroundColor Green
Write-Host ""
