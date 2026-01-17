# Slice 1 File Locations

## Project Root Path
```
C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App
```

## Flutter App Location
```
C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app\
```

## Key Files

### Main Entry Points
- `legal_ai_app/lib/main.dart` - App entry point
- `legal_ai_app/lib/app.dart` - App widget with providers

### Configuration
- `legal_ai_app/pubspec.yaml` - Dependencies and project config
- `legal_ai_app/.gitignore` - Git ignore rules

### Documentation
- `legal_ai_app/README.md` - Project overview
- `legal_ai_app/SETUP.md` - Setup instructions
- `legal_ai_app/TESTING_GUIDE.md` - Testing guide
- `legal_ai_app/SLICE_1_COMPLETION_CHECKLIST.md` - Completion checklist

### Test Scripts
- `legal_ai_app/test-slice1.bat` - Windows test script
- `legal_ai_app/test-slice1.ps1` - PowerShell test script

## Full Directory Structure

```
C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\
├── legal_ai_app\                    ← Flutter app is HERE
│   ├── lib\
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core\
│   │   │   ├── theme\              (4 files)
│   │   │   ├── routing\            (2 files)
│   │   │   ├── services\           (2 files)
│   │   │   ├── models\             (2 files)
│   │   │   └── constants\          (1 file)
│   │   └── features\
│   │       ├── auth\               (5 files)
│   │       ├── home\               (5 files)
│   │       └── common\              (7 widget files)
│   ├── pubspec.yaml
│   ├── .gitignore
│   ├── README.md
│   ├── SETUP.md
│   ├── TESTING_GUIDE.md
│   ├── SLICE_1_COMPLETION_CHECKLIST.md
│   ├── test-slice1.bat
│   └── test-slice1.ps1
├── functions\                       ← Backend (Slice 0)
├── docs\                            ← Documentation
├── scripts\                         ← Utility scripts
└── [other root files]
```

## To Navigate to Flutter App

**From Command Prompt:**
```cmd
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
```

**From PowerShell:**
```powershell
cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\legal_ai_app"
```

**Or from project root:**
```cmd
cd legal_ai_app
```

## Quick Commands

```bash
# Navigate to Flutter app
cd legal_ai_app

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run the app
flutter run
```
