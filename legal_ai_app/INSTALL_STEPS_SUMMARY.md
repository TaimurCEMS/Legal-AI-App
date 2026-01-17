# Flutter Installation - Quick Summary

## 🎯 Fastest Method: Use VS Code

### Step 1: Install VS Code
- Download: https://code.visualstudio.com/
- Install and launch VS Code

### Step 2: Install Flutter Extension
1. Open VS Code
2. Press `Ctrl + Shift + X` (Extensions)
3. Search "Flutter"
4. Click "Install" on Flutter extension

### Step 3: Download Flutter via VS Code
1. Press `Ctrl + Shift + P`
2. Type: `Flutter: New Project`
3. When prompted, click **"Download SDK"**
4. Choose location: `C:\src\flutter`
5. Click "Add SDK to PATH" when prompted
6. **Restart VS Code**

### Step 4: Verify
1. Open terminal in VS Code (`` Ctrl + ` ``)
2. Run: `flutter doctor`
3. If you see Flutter version → ✅ Success!

---

## 📝 Alternative: Manual Installation

If VS Code method doesn't work:

1. **Download Flutter**: https://flutter.dev/docs/get-started/install/windows
2. **Extract to**: `C:\src\flutter`
3. **Add to PATH**: 
   - Win + X → System → Advanced system settings
   - Environment Variables → Edit Path
   - Add: `C:\src\flutter\bin`
4. **Restart Command Prompt**
5. **Verify**: `flutter doctor`

---

## ✅ After Installation

1. Open `legal_ai_app` folder in VS Code
2. Run: `flutter pub get`
3. Run: `flutterfire configure`
4. Run: `flutter run`

---

**Time:** ~15 minutes  
**Difficulty:** Easy with VS Code
