# PowerShell Script for Testing Slice 2
# This script helps verify state persistence and functionality

param(
    [switch]$FullTest,
    [switch]$QuickTest,
    [string]$FlutterPath = "legal_ai_app"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Slice 2 Testing Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
Write-Host "[1/5] Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter not found. Please install Flutter." -ForegroundColor Red
    exit 1
}

# Navigate to Flutter app directory
Write-Host ""
Write-Host "[2/5] Navigating to Flutter app..." -ForegroundColor Yellow
$appPath = Join-Path $PSScriptRoot $FlutterPath
if (-not (Test-Path $appPath)) {
    Write-Host "❌ Flutter app directory not found: $appPath" -ForegroundColor Red
    exit 1
}
Set-Location $appPath
Write-Host "✅ In directory: $(Get-Location)" -ForegroundColor Green

# Install dependencies
Write-Host ""
Write-Host "[3/5] Installing dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dependencies installed" -ForegroundColor Green

# Check for compilation errors
Write-Host ""
Write-Host "[4/5] Checking for compilation errors..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos 2>&1 | Out-String | ForEach-Object {
    if ($_ -match "error|Error") {
        Write-Host "⚠️  Compilation issues found:" -ForegroundColor Yellow
        Write-Host $_ -ForegroundColor Yellow
    }
}
Write-Host "✅ Compilation check complete" -ForegroundColor Green

# Run tests
Write-Host ""
Write-Host "[5/5] Running tests..." -ForegroundColor Yellow
if ($FullTest) {
    Write-Host "Running full test suite..." -ForegroundColor Cyan
    flutter test
} elseif ($QuickTest) {
    Write-Host "Running quick tests..." -ForegroundColor Cyan
    flutter test --no-sound-null-safety 2>&1 | Select-Object -First 20
} else {
    Write-Host "Skipping tests (use -FullTest or -QuickTest to run)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter run -d chrome" -ForegroundColor White
Write-Host "2. Test manually:" -ForegroundColor White
Write-Host "   - Create org → Refresh (F5) → Org should persist" -ForegroundColor Gray
Write-Host "   - Create cases → Switch tabs → Cases should persist" -ForegroundColor Gray
Write-Host "   - Create case → Refresh → Case should reload from backend" -ForegroundColor Gray
Write-Host ""
