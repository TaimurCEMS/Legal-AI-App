# Flutter Installation Guide for Windows

## Step-by-Step Installation

### Step 1: Download Flutter SDK

1. Go to: **https://flutter.dev/docs/get-started/install/windows**
2. Click "Download Flutter SDK"
3. Download the latest **stable** version (ZIP file)
   - File will be named something like: `flutter_windows_3.x.x-stable.zip`

### Step 2: Extract Flutter

1. **Extract the ZIP file** to a location like:
   - `C:\src\flutter` ✅ **Recommended**
   - `C:\flutter` ✅ Also OK
   - **DO NOT** extract to:
     - `C:\Program Files\` ❌ (permissions issues)
     - `C:\Users\YourName\AppData\` ❌ (hidden folder)

2. After extraction, you should have:
   ```
   C:\src\flutter\
   ├── bin\
   │   └── flutter.bat  ← This is what we need
   ├── packages\
   ├── README.md
   └── ...
   ```

### Step 3: Add Flutter to PATH

**Method 1: Using System Settings (Recommended)**

1. Press `Win + X` → Click **"System"**
2. Click **"Advanced system settings"** (on the right)
3. Click **"Environment Variables"** button (at the bottom)
4. Under **"User variables"** section, find **"Path"** and click **"Edit"**
5. Click **"New"**
6. Add: `C:\src\flutter\bin` (or wherever you extracted Flutter)
7. Click **"OK"** on all dialogs
8. **Close and reopen Command Prompt/PowerShell**

**Method 2: Using Command Prompt (Temporary - only for current session)**

```cmd
set PATH=%PATH%;C:\src\flutter\bin
```

### Step 4: Verify Installation

1. **Open a NEW Command Prompt** (important - must be new after adding to PATH)
2. Run:
   ```cmd
   flutter doctor
   ```

**Expected Output:**
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.x.x, ...)
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] Visual Studio - develop for Windows
[✓] Android Studio (version x.x)
[✓] VS Code (version x.x)
[✓] Connected device (x available)
[✓] Network resources

! Some checks failed (these are warnings, not errors)
```

**If you see Flutter version info**, installation is successful! ✅

### Step 5: Accept Android Licenses (If Developing for Android)

```cmd
flutter doctor --android-licenses
```

Press `y` to accept all licenses.

---

## After Installation

### Test Flutter Works

```cmd
flutter --version
```

Should show Flutter version.

### Then Test Your App

```cmd
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
flutter pub get
flutterfire configure
flutter run
```

---

## Common Issues

### Issue: "flutter is not recognized" after adding to PATH

**Solution:**
1. **Close ALL Command Prompt/PowerShell windows**
2. **Open a NEW Command Prompt**
3. Try `flutter doctor` again

### Issue: "Android toolchain" shows errors

**Solution:**
- Install Android Studio: https://developer.android.com/studio
- Or use Flutter for Web only (no Android Studio needed)

### Issue: "Visual Studio" shows errors

**Solution:**
- Install Visual Studio 2022 with "Desktop development with C++" workload
- Or use Flutter for Web/Android only

### Issue: Can't extract to C:\src\flutter

**Solution:**
- Create the folder first: `mkdir C:\src`
- Then extract Flutter ZIP to `C:\src\flutter`

---

## Quick Installation Checklist

- [ ] Downloaded Flutter SDK ZIP
- [ ] Extracted to `C:\src\flutter` (or similar)
- [ ] Added `C:\src\flutter\bin` to PATH
- [ ] Opened NEW Command Prompt
- [ ] Ran `flutter doctor` successfully
- [ ] Accepted Android licenses (if needed)

---

## Next Steps After Installation

1. **Install FlutterFire CLI:**
   ```cmd
   dart pub global activate flutterfire_cli
   ```

2. **Navigate to your app:**
   ```cmd
   cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
   ```

3. **Run the test script:**
   ```cmd
   test-slice1-verbose.bat
   ```

---

## Installation Time Estimate

- Download: 5-10 minutes (depends on internet speed)
- Extraction: 1-2 minutes
- PATH setup: 2 minutes
- Verification: 1 minute
- **Total: ~10-15 minutes**

---

**Need help?** Check Flutter's official docs: https://flutter.dev/docs/get-started/install/windows
