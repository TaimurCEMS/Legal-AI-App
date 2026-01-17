# Quick test script for Slice 1
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Slice 1 Testing Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $PSScriptRoot

Write-Host "[1/5] Checking Flutter installation..." -ForegroundColor Yellow
flutter doctor
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter not found or not configured" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Flutter OK" -ForegroundColor Green
Write-Host ""

Write-Host "[2/5] Installing dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Dependencies installed" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] Checking Firebase configuration..." -ForegroundColor Yellow
if (-not (Test-Path "lib\firebase_options.dart")) {
    Write-Host "⚠️  Firebase not configured" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please run: flutterfire configure" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "✅ Firebase configured" -ForegroundColor Green
Write-Host ""

Write-Host "[4/5] Running static analysis..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Analysis found issues (check output above)" -ForegroundColor Yellow
} else {
    Write-Host "✅ No analysis errors" -ForegroundColor Green
}
Write-Host ""

Write-Host "[5/5] Ready to run!" -ForegroundColor Green
Write-Host ""
Write-Host "To run the app, use:" -ForegroundColor Cyan
Write-Host "  flutter run" -ForegroundColor White
Write-Host ""
Write-Host "Or for specific platform:" -ForegroundColor Cyan
Write-Host "  flutter run -d chrome    (Web)" -ForegroundColor White
Write-Host "  flutter run -d android   (Android)" -ForegroundColor White
Write-Host "  flutter run -d ios       (iOS)" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
