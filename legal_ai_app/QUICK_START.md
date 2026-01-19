# Quick Start Guide - Slice 1 Testing

## 🚀 Fastest Way to Run the App

### Option 1: Quick Run (Recommended)
**Double-click this file:**
```
legal_ai_app\quick-run.bat
```
Runs the app immediately with minimal checks.

### Option 2: Run with Setup Check
**Double-click this file:**
```
legal_ai_app\run-app-with-setup.bat
```
Checks Flutter, dependencies, Firebase, and web setup before running.

### Option 3: Simple Run
**Double-click this file:**
```
legal_ai_app\run-app.bat
```
Runs the app with basic checks.

---

## 🧪 Testing & Setup Scripts

### Run Setup Checks
**Double-click this file:**
```
legal_ai_app\test-slice1-verbose.bat
```

This will:
- ✅ Check Flutter installation
- ✅ Install dependencies
- ✅ Check Firebase configuration
- ✅ Run code analysis
- ✅ Show you what to do next

**The window will stay open** so you can see all the output!

---

## 📋 Manual Steps (If Script Doesn't Work)

### 1. Open Command Prompt
Press `Win + R`, type `cmd`, press Enter

### 2. Navigate to Flutter App
```cmd
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\Software Development\Github-cems-suite\Legal-AI-App\legal_ai_app"
```

### 3. Install Dependencies
```cmd
flutter pub get
```

### 4. Configure Firebase
```cmd
flutterfire configure
```
- Select project: `legal-ai-app-1203e`
- Select platforms: Android, iOS (or Web)

### 5. Run the App
```cmd
flutter run
```

---

## 🐛 Troubleshooting

### "Flutter not found"
- Install Flutter: https://flutter.dev/docs/get-started/install
- Add Flutter to PATH
- Restart Command Prompt

### "firebase_options.dart not found"
- Run: `flutterfire configure`
- Make sure you select the correct Firebase project

### "Package not found"
- Run: `flutter clean`
- Then: `flutter pub get`

---

## ✅ Success Indicators

When everything works, you should see:
- ✅ Flutter OK
- ✅ Dependencies installed
- ✅ Firebase configured
- ✅ No analysis errors
- App launches on your device/emulator

---

**Need help?** Check `TESTING_GUIDE.md` for detailed instructions.
