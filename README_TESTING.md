# Testing Guide

## Quick Start

**Run this ONE command:**
```cmd
test-all.bat
```

This will:
- ✅ Check Flutter installation
- ✅ Install dependencies
- ✅ Check compilation
- ✅ Run all automated tests
- ✅ Show summary
- ✅ **Keep window open** so you can see results

---

## What Gets Tested

1. **State Management** - OrgProvider, CaseProvider
2. **UI Components** - Buttons, text fields, loading, empty states
3. **State Persistence** - SharedPreferences save/load
4. **Critical Logic** - Case loading, org initialization
5. **Model Serialization** - CaseModel, OrgModel parsing

---

## After Tests Pass

```cmd
cd legal_ai_app
flutter run -d chrome
```

Then test manually:
- Create org → Refresh (F5) → Org should persist
- Create cases → Switch tabs → Cases should persist
- Create case → Refresh → Case should reload

---

## Troubleshooting

**Window closes immediately?**
- Use `test-all.bat` (new version with better error handling)
- Check if Flutter is installed: `flutter --version`

**Tests fail?**
- Check error messages in output
- Run `flutter pub get` manually
- Check for compilation errors: `flutter analyze`

---

**Last Updated:** 2026-01-19
