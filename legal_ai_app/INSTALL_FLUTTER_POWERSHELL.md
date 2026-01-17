# Install Flutter Using PowerShell

## Quick Installation

### Step 1: Open PowerShell

1. Press `Win + X`
2. Select **"Windows PowerShell"** or **"Terminal"**
3. Or press `Win + R`, type `powershell`, press Enter

### Step 2: Navigate to Your App Folder

```powershell
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
```

### Step 3: Run the Installation Script

```powershell
.\install-flutter.ps1
```

**If you get an execution policy error**, run this first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script again:
```powershell
.\install-flutter.ps1
```

---

## What the Script Does

1. ✅ Checks if Flutter is already installed
2. ✅ Downloads Flutter SDK (~1.5 GB)
3. ✅ Extracts to `C:\src\flutter`
4. ✅ Adds Flutter to PATH
5. ✅ Verifies installation

**Time:** ~10-15 minutes (depending on internet speed)

---

## After Installation

### Step 1: Close and Reopen PowerShell

**Important:** Close the current PowerShell window and open a new one for PATH changes to take effect.

### Step 2: Verify Installation

```powershell
flutter doctor
```

You should see Flutter version information.

### Step 3: Test Your App

```powershell
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
flutter pub get
flutterfire configure
flutter run
```

---

## Troubleshooting

### Issue: "Execution Policy" Error

**Error:** `cannot be loaded because running scripts is disabled`

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script again.

### Issue: Download Fails

**Solution:**
- Check your internet connection
- The script will show manual download instructions
- Or download manually from: https://flutter.dev/docs/get-started/install/windows

### Issue: "flutter is not recognized" After Installation

**Solution:**
1. **Close PowerShell completely**
2. **Open a NEW PowerShell window**
3. Try `flutter doctor` again

If still not working:
- Manually add to PATH (see below)

### Issue: Need to Add to PATH Manually

1. Press `Win + X` → System
2. Advanced system settings → Environment Variables
3. Under "User variables", find "Path" → Edit
4. Click "New" → Add: `C:\src\flutter\bin`
5. Click OK on all dialogs
6. **Restart PowerShell**

---

## Manual Installation (If Script Fails)

If the PowerShell script doesn't work, you can install manually:

### Step 1: Download Flutter

```powershell
# Download Flutter
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$output = "$env:TEMP\flutter.zip"
Invoke-WebRequest -Uri $url -OutFile $output
```

### Step 2: Extract

```powershell
# Create directory
New-Item -ItemType Directory -Path "C:\src" -Force

# Extract
Expand-Archive -Path $output -DestinationPath "C:\src" -Force

# Rename folder (if needed)
$extracted = Get-ChildItem "C:\src" -Directory | Where-Object { $_.Name -like "flutter*" } | Select-Object -First 1
if ($extracted.Name -ne "flutter") {
    Rename-Item -Path $extracted.FullName -NewName "flutter"
}
```

### Step 3: Add to PATH

```powershell
# Add to user PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = $currentPath + ";C:\src\flutter\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# Add to current session
$env:Path += ";C:\src\flutter\bin"
```

### Step 4: Verify

```powershell
C:\src\flutter\bin\flutter.bat --version
```

---

## Quick Commands Reference

```powershell
# Check if Flutter is installed
flutter --version

# Check Flutter installation status
flutter doctor

# Navigate to your app
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run the app
flutter run
```

---

**Ready to install?** Run `.\install-flutter.ps1` in PowerShell!
