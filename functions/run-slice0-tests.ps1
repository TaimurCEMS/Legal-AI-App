# PowerShell script to run Slice 0 tests
Write-Host "Setting environment variables..." -ForegroundColor Cyan
$env:FIREBASE_API_KEY = "AIzaSyCyMLidl_iXmQG0fLOhi4Vl_netaa_7ZAY"
$env:GCLOUD_PROJECT = "legal-ai-app-1203e"

# Set service account key path (auto-detect if exists)
$serviceAccountKey = "legal-ai-app-1203e-firebase-adminsdk-fbsvc-e37a15e13c.json"
if (Test-Path $serviceAccountKey) {
    $env:GOOGLE_APPLICATION_CREDENTIALS = (Resolve-Path $serviceAccountKey).Path
    Write-Host "Service account key found: $env:GOOGLE_APPLICATION_CREDENTIALS" -ForegroundColor Green
} else {
    Write-Host "WARNING: Service account key not found!" -ForegroundColor Yellow
    Write-Host "Please ensure the key file is in the functions directory." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Running Slice 0 tests..." -ForegroundColor Cyan
Write-Host ""

npm run test:slice0

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Tests completed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Tests failed. Check the error messages above." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
