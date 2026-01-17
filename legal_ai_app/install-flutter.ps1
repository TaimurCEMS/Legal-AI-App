# Flutter Installation Script for Windows (PowerShell)
# This script downloads and installs Flutter automatically

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Installation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  Note: Running without admin privileges" -ForegroundColor Yellow
    Write-Host "   Some steps may require manual confirmation" -ForegroundColor Yellow
    Write-Host ""
}

# Set Flutter installation path
$flutterPath = "C:\src\flutter"
$flutterBinPath = "$flutterPath\bin"

Write-Host "[1/6] Checking if Flutter is already installed..." -ForegroundColor Yellow
if (Test-Path "$flutterBinPath\flutter.bat") {
    Write-Host "✅ Flutter already installed at: $flutterPath" -ForegroundColor Green
    Write-Host ""
    $useExisting = Read-Host "Use existing installation? (Y/N)"
    if ($useExisting -eq "Y" -or $useExisting -eq "y") {
        $skipDownload = $true
    } else {
        $skipDownload = $false
    }
} else {
    $skipDownload = $false
}

if (-not $skipDownload) {
    Write-Host "[2/6] Preparing Flutter installation directory..." -ForegroundColor Yellow
    
    # Create directory if it doesn't exist
    if (-not (Test-Path "C:\src")) {
        Write-Host "Creating C:\src directory..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
    }
    
    # Remove existing Flutter if present
    if (Test-Path $flutterPath) {
        Write-Host "⚠️  Existing Flutter installation found at $flutterPath" -ForegroundColor Yellow
        $remove = Read-Host "Remove existing installation? (Y/N)"
        if ($remove -eq "Y" -or $remove -eq "y") {
            Write-Host "Removing existing installation..." -ForegroundColor Gray
            Remove-Item -Path $flutterPath -Recurse -Force
        } else {
            Write-Host "❌ Installation cancelled" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "[3/6] Downloading Flutter SDK..." -ForegroundColor Yellow
    Write-Host "   This may take several minutes (file is ~1.5 GB)" -ForegroundColor Gray
    Write-Host ""
    
    # Get latest Flutter version URL
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
    
    $zipPath = "$env:TEMP\flutter_windows_stable.zip"
    
    try {
        Write-Host "Downloading from: $flutterUrl" -ForegroundColor Gray
        Write-Host ""
        
        # Download with progress
        $ProgressPreference = 'Continue'
        Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath -UseBasicParsing
        
        Write-Host "✅ Download complete!" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "❌ Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternative: Please download manually from:" -ForegroundColor Yellow
        Write-Host "   https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    
    Write-Host "[4/6] Extracting Flutter SDK..." -ForegroundColor Yellow
    Write-Host "   This may take a few minutes..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Extract ZIP file
        Expand-Archive -Path $zipPath -DestinationPath "C:\src" -Force
        
        # Flutter extracts to C:\src\flutter_windows_3.x.x-stable, rename to flutter
        $extractedPath = Get-ChildItem "C:\src" -Directory | Where-Object { $_.Name -like "flutter_windows*" } | Select-Object -First 1
        
        if ($extractedPath) {
            if (Test-Path $flutterPath) {
                Remove-Item -Path $flutterPath -Recurse -Force
            }
            Rename-Item -Path $extractedPath.FullName -NewName "flutter"
        }
        
        Write-Host "✅ Extraction complete!" -ForegroundColor Green
        Write-Host ""
        
        # Clean up ZIP file
        Remove-Item -Path $zipPath -Force
    } catch {
        Write-Host "❌ Extraction failed: $_" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
} else {
    Write-Host "[2-4/6] Skipping download (using existing installation)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[5/6] Adding Flutter to PATH..." -ForegroundColor Yellow

# Check if Flutter is already in PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$flutterBinPath*") {
    try {
        # Add to user PATH
        $newPath = $currentPath + ";$flutterBinPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        
        # Also add to current session
        $env:Path += ";$flutterBinPath"
        
        Write-Host "✅ Flutter added to PATH!" -ForegroundColor Green
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: Close and reopen PowerShell/Command Prompt for PATH changes to take effect!" -ForegroundColor Yellow
        Write-Host ""
    } catch {
        Write-Host "⚠️  Could not automatically add to PATH: $_" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please add manually:" -ForegroundColor Yellow
        Write-Host "   1. Win + X → System → Advanced system settings" -ForegroundColor Cyan
        Write-Host "   2. Environment Variables → Edit Path" -ForegroundColor Cyan
        Write-Host "   3. Add: $flutterBinPath" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-Host "✅ Flutter already in PATH!" -ForegroundColor Green
    Write-Host ""
}

Write-Host "[6/6] Verifying Flutter installation..." -ForegroundColor Yellow
Write-Host ""

# Refresh PATH in current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Check if flutter command works
try {
    $flutterVersion = & "$flutterBinPath\flutter.bat" --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Flutter installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Flutter version:" -ForegroundColor Cyan
        $flutterVersion | Select-String "Flutter" | ForEach-Object { Write-Host "   $_" -ForegroundColor White }
        Write-Host ""
    } else {
        Write-Host "⚠️  Flutter installed but verification failed" -ForegroundColor Yellow
        Write-Host "   Try running 'flutter doctor' in a new terminal" -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "⚠️  Could not verify Flutter (this is OK if PATH not refreshed)" -ForegroundColor Yellow
    Write-Host "   Please open a NEW terminal and run: flutter doctor" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "   1. Close this PowerShell window" -ForegroundColor White
Write-Host "   2. Open a NEW PowerShell or Command Prompt" -ForegroundColor White
Write-Host "   3. Run: flutter doctor" -ForegroundColor White
Write-Host "   4. Navigate to your app: cd legal_ai_app" -ForegroundColor White
Write-Host "   5. Run: flutter pub get" -ForegroundColor White
Write-Host ""
Write-Host "Flutter location: $flutterPath" -ForegroundColor Gray
Write-Host ""
