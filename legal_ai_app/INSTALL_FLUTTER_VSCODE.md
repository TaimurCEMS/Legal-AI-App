# Install Flutter Using VS Code (Windows)

This guide will help you install Flutter using VS Code on Windows.

---

## Prerequisites

1. **VS Code** - Download from: https://code.visualstudio.com/
2. **Git** - Download from: https://git-scm.com/download/win

---

## Step 1: Install VS Code (If Not Already Installed)

1. Download VS Code: https://code.visualstudio.com/
2. Run the installer
3. Follow the installation wizard
4. Launch VS Code

---

## Step 2: Install Flutter Extension in VS Code

1. **Open VS Code**
2. **Open Extensions**:
   - Click the Extensions icon in the sidebar (or press `Ctrl + Shift + X`)
   - Or go to: View → Extensions

3. **Search for Flutter**:
   - Type "Flutter" in the search box
   - Look for "Flutter" by Dart Code (official extension)

4. **Install Flutter Extension**:
   - Click "Install" on the Flutter extension
   - This will also install the Dart extension automatically

5. **Reload VS Code** if prompted

---

## Step 3: Install Flutter SDK Using VS Code

### Method 1: Download via VS Code (Recommended)

1. **Open Command Palette**:
   - Press `Ctrl + Shift + P`
   - Or go to: View → Command Palette

2. **Type "Flutter"**:
   - Start typing: `flutter`
   - You should see Flutter commands appear

3. **Select "Flutter: New Project"**:
   - This will prompt you to locate Flutter SDK
   - If Flutter is not found, it will ask to download

4. **Download Flutter SDK**:
   - When prompted, click **"Download SDK"**
   - Choose installation location: `C:\src\flutter` (recommended)
   - Click "Clone Flutter"
   - Wait for download to complete (this takes a few minutes)

5. **Add SDK to PATH**:
   - VS Code will prompt: "Add SDK to PATH"
   - Click **"Yes"** or **"Add SDK to PATH"**

6. **Restart VS Code**:
   - Close VS Code completely
   - Reopen VS Code

### Method 2: Manual Download (If VS Code Method Fails)

1. **Download Flutter SDK manually**:
   - Go to: https://flutter.dev/docs/get-started/install/windows
   - Download the ZIP file
   - Extract to: `C:\src\flutter`

2. **Tell VS Code where Flutter is**:
   - In VS Code, press `Ctrl + Shift + P`
   - Type: `Flutter: Change SDK`
   - Select: `C:\src\flutter`

3. **Add to PATH manually**:
   - Press `Win + X` → System → Advanced system settings
   - Environment Variables → Edit Path
   - Add: `C:\src\flutter\bin`

---

## Step 4: Verify Flutter Installation

1. **Open VS Code Terminal**:
   - Press `` Ctrl + ` `` (backtick) to open terminal
   - Or go to: Terminal → New Terminal

2. **Run Flutter Doctor**:
   ```cmd
   flutter doctor
   ```

3. **Expected Output**:
   ```
   Doctor summary (to see all details, run flutter doctor -v):
   [✓] Flutter (Channel stable, 3.x.x, ...)
   [✓] Windows Version
   [✓] Chrome - develop for the web
   ...
   ```

4. **If you see Flutter version**, installation is successful! ✅

---

## Step 5: Accept Android Licenses (Optional - Only if Developing for Android)

If you plan to develop for Android:

```cmd
flutter doctor --android-licenses
```

Press `y` to accept all licenses.

---

## Step 6: Test Flutter Installation

### Create a Test Project (Optional)

1. **Open Command Palette**: `Ctrl + Shift + P`
2. **Type**: `Flutter: New Project`
3. **Select**: Application template
4. **Choose location**: Any folder
5. **Enter name**: `test_flutter` (or any name)
6. **Wait for project creation**

### Run the Test Project

1. **Open the test project** in VS Code
2. **Select Device**:
   - Press `Ctrl + Shift + P`
   - Type: `Flutter: Select Device`
   - Choose: **Chrome** (for web testing)

3. **Run the App**:
   - Press `F5` (Start Debugging)
   - Or go to: Run → Start Debugging
   - Chrome should open with your Flutter app

---

## Step 7: Use Flutter with Your Legal AI App

Now that Flutter is installed, you can work with your Slice 1 app:

1. **Open Your App in VS Code**:
   - File → Open Folder
   - Navigate to: `legal_ai_app` folder

2. **Install Dependencies**:
   - Open terminal in VS Code (`` Ctrl + ` ``)
   - Run:
     ```cmd
     flutter pub get
     ```

3. **Configure Firebase**:
   ```cmd
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
   - Select project: `legal-ai-app-1203e`
   - Select platforms: Android, iOS, Web

4. **Run Your App**:
   - Press `F5` or go to Run → Start Debugging
   - Select device (Chrome for web, or Android emulator)

---

## Troubleshooting

### Issue: "Flutter SDK not found" in VS Code

**Solution:**
1. Press `Ctrl + Shift + P`
2. Type: `Flutter: Change SDK`
3. Select: `C:\src\flutter` (or wherever you installed Flutter)

### Issue: "flutter is not recognized" in terminal

**Solution:**
1. Add Flutter to PATH manually (see Step 3, Method 2)
2. **Close and reopen VS Code**
3. Open a new terminal in VS Code

### Issue: VS Code doesn't show Flutter commands

**Solution:**
1. Make sure Flutter extension is installed
2. Reload VS Code: `Ctrl + Shift + P` → `Developer: Reload Window`
3. Check if Flutter SDK is configured: `Flutter: Change SDK`

### Issue: Download hangs during installation

**Solution:**
1. Cancel the download
2. Try manual download (Method 2)
3. Or check your internet connection

---

## Quick Checklist

- [ ] VS Code installed
- [ ] Flutter extension installed in VS Code
- [ ] Flutter SDK downloaded (via VS Code or manually)
- [ ] Flutter added to PATH
- [ ] VS Code restarted
- [ ] `flutter doctor` runs successfully
- [ ] Test project created and runs

---

## Next Steps

After Flutter is installed:

1. **Open your Legal AI app** in VS Code
2. **Run the test script**: `test-slice1-verbose.bat`
3. **Or manually**:
   ```cmd
   flutter pub get
   flutterfire configure
   flutter run
   ```

---

**Installation Time:** ~15-20 minutes (depending on download speed)

**Need help?** Check Flutter docs: https://flutter.dev/docs/get-started/install/windows
