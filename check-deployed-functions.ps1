# Check deployed Firebase Functions for legacy "api" function
Write-Host "Checking deployed Firebase Functions..." -ForegroundColor Cyan
Write-Host ""

firebase functions:list --project legal-ai-app-1203e

Write-Host ""
Write-Host ""
Write-Host "If you see 'api' in the list above, run this command to delete it:" -ForegroundColor Yellow
Write-Host "  firebase functions:delete api --region us-central1 --project legal-ai-app-1203e" -ForegroundColor Yellow
Write-Host ""
Write-Host "If 'api' is NOT in the list, you're already clean! ✅" -ForegroundColor Green
Write-Host ""
