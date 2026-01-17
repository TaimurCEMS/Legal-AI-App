# Flutter Setup Guide

## Issue: 'flutter' is not recognized

This means Flutter is either:
1. Not installed
2. Installed but not in your PATH

---

## Solution 1: Install Flutter (If Not Installed)

### Step 1: Download Flutter
1. Go to: https://flutter.dev/docs/get-started/install/windows
2. Download Flutter SDK (latest stable version)
3. Extract to a location like: `C:\src\flutter`
   - **Important:** Don't install in `C:\Program Files\` (permissions issues)

### Step 2: Add Flutter to PATH

**Option A: Using System Settings (Recommended)**
1. Press `Win + X` → System
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", find "Path" and click "Edit"
5. Click "New"
6. Add: `C:\src\flutter\bin` (or wherever you extracted Flutter)
7. Click "OK" on all dialogs
8. **Restart Command Prompt/PowerShell**

**Option B: Using Command Prompt (Temporary)**
```cmd
set PATH=%PATH%;C:\src\flutter\bin
```
(Only works for current session)

### Step 3: Verify Installation
Open a **NEW** Command Prompt and run:
```cmd
flutter doctor
```

You should see Flutter information, not an error.

---

## Solution 2: Flutter Already Installed (Just Not in PATH)

### Find Flutter Installation

**Common locations:**
- `C:\src\flutter`
- `C:\flutter`
- `C:\Users\YourName\flutter`
- `C:\Users\YourName\AppData\Local\flutter`

### Add to PATH

1. Find where Flutter is installed
2. Add `[flutter_path]\bin` to your PATH (see Solution 1, Step 2)

### Verify
```cmd
flutter doctor
```

---

## Solution 3: Use Flutter from Specific Location

If you know where Flutter is installed, you can use the full path:

```cmd
C:\src\flutter\bin\flutter doctor
C:\src\flutter\bin\flutter pub get
C:\src\flutter\bin\flutter run
```

---

## Quick Check: Is Flutter Installed?

Run this in Command Prompt:
```cmd
where flutter
```

If Flutter is in PATH, it will show the path.
If not, it will say "INFO: Could not find files for the given pattern(s)."

---

## After Adding Flutter to PATH

1. **Close all Command Prompt/PowerShell windows**
2. **Open a new Command Prompt**
3. Run: `flutter doctor`
4. If it works, navigate to the app and run the test script again

---

## Alternative: Use Android Studio / VS Code

If you have Android Studio or VS Code with Flutter extension:
- They might have Flutter bundled
- Check: Android Studio → File → Settings → Languages & Frameworks → Flutter
- The Flutter SDK path is shown there

---

## Need Help?

1. Check if Flutter is installed: `where flutter`
2. If not installed: Follow Solution 1
3. If installed but not in PATH: Follow Solution 2
4. After setup: Restart Command Prompt and try again
