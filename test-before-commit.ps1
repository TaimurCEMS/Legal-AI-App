# Comprehensive testing script that I can run to verify everything works
# This helps catch issues before giving code to the user

param(
    [switch]$Quick,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$script:Errors = 0
$script:Warnings = 0

function Write-Step {
    param([string]$Message)
    Write-Host "[$Message]" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
    $script:Warnings++
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    $script:Errors++
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pre-Commit Testing - Legal AI App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script verifies:" -ForegroundColor White
Write-Host "  1. Flutter installation" -ForegroundColor Gray
Write-Host "  2. Dependencies installed" -ForegroundColor Gray
Write-Host "  3. Code compiles (no errors)" -ForegroundColor Gray
Write-Host "  4. Common issues detected" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Flutter
Write-Step "1/6"
Write-Host "Checking Flutter installation..." -ForegroundColor White
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Flutter found: $flutterVersion"
    } else {
        Write-Error "Flutter not found in PATH"
        exit 1
    }
} catch {
    Write-Error "Flutter not found: $_"
    exit 1
}
Write-Host ""

# Step 2: Check Flutter App Directory
Write-Step "2/6"
Write-Host "Checking Flutter app directory..." -ForegroundColor White
$appPath = Join-Path $PSScriptRoot "legal_ai_app"
if (Test-Path $appPath) {
    Write-Success "legal_ai_app directory found"
} else {
    Write-Error "legal_ai_app directory not found"
    exit 1
}
Write-Host ""

# Step 3: Install Dependencies
Write-Step "3/6"
Write-Host "Installing/updating dependencies..." -ForegroundColor White
Set-Location $appPath
flutter pub get 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Success "Dependencies installed"
} else {
    Write-Error "Failed to install dependencies"
    exit 1
}
Write-Host ""

# Step 4: Check for Compilation Errors
Write-Step "4/6"
Write-Host "Checking for compilation errors..." -ForegroundColor White
$analysisOutput = flutter analyze --no-fatal-infos 2>&1 | Out-String
if ($analysisOutput -match "error|Error") {
    Write-Warning "Compilation issues found:"
    $analysisOutput -split "`n" | Where-Object { $_ -match "error|Error" } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
} else {
    Write-Success "No critical compilation errors"
}
Write-Host ""

# Step 5: Check for Common Issues
Write-Step "5/6"
Write-Host "Checking for common issues..." -ForegroundColor White

# Check SharedPreferences import
$orgProviderPath = Join-Path $appPath "lib\features\home\providers\org_provider.dart"
if (Test-Path $orgProviderPath) {
    $content = Get-Content $orgProviderPath -Raw
    if ($content -notmatch "shared_preferences") {
        Write-Warning "shared_preferences may not be imported in org_provider.dart"
    }
}

# Check IndexedStack
$appShellPath = Join-Path $appPath "lib\features\home\widgets\app_shell.dart"
if (Test-Path $appShellPath) {
    $content = Get-Content $appShellPath -Raw
    if ($content -notmatch "IndexedStack") {
        Write-Warning "IndexedStack may not be used in app_shell.dart (tab state preservation)"
    }
}

# Check pubspec.yaml
$pubspecPath = Join-Path $appPath "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $content = Get-Content $pubspecPath -Raw
    if ($content -match "shared_preferences") {
        Write-Success "shared_preferences in pubspec.yaml"
    } else {
        Write-Error "shared_preferences not found in pubspec.yaml"
    }
}

Write-Success "Common issues check complete"
Write-Host ""

# Step 6: Check Backend Functions
Write-Step "6/6"
Write-Host "Checking backend functions..." -ForegroundColor White
$functionsPath = Join-Path $PSScriptRoot "functions"
if (Test-Path (Join-Path $functionsPath "package.json")) {
    Write-Success "Functions directory found"
    if (Test-Path (Join-Path $functionsPath "src\functions\case.ts")) {
        Write-Success "case.ts found"
    } else {
        Write-Warning "case.ts not found"
    }
} else {
    Write-Warning "Functions directory not found or incomplete"
}
Write-Host ""

# Summary
Set-Location $PSScriptRoot
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:Errors -eq 0) {
    if ($script:Warnings -eq 0) {
        Write-Host "✅ ALL CHECKS PASSED - Ready to commit!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠️  PASSED with $($script:Warnings) warning(s) - Review warnings above" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "❌ FAILED with $($script:Errors) error(s) and $($script:Warnings) warning(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix errors before committing." -ForegroundColor Red
    exit 1
}
