# Development Learnings & Insights

**Purpose:** Capture key learnings, insights, and solutions discovered during development to prevent repeating mistakes and share knowledge.

**Last Updated:** 2026-01-17

---

## Table of Contents

1. [Firebase & Cloud Functions](#firebase--cloud-functions)
2. [Flutter Development](#flutter-development)
3. [Development Environment](#development-environment)
4. [Error Handling & Debugging](#error-handling--debugging)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)

---

## Firebase & Cloud Functions

### Learning 1: Firebase Callable Function Names
**Date:** 2026-01-17  
**Context:** Slice 1 - Organization creation failing with CORS errors

**Issue:**
- Code was calling functions as `org.create`, `org.join`, `member.getMyMembership`
- Functions are exported as `orgCreate`, `orgJoin`, `memberGetMyMembership`
- This mismatch caused function not found errors

**Solution:**
- Firebase callable functions use the **export name directly**, not a custom callable name
- If you export `export const orgCreate = functions.https.onCall(...)`, call it as `orgCreate`
- The comment "Callable Name: org.create" is just documentation, not the actual name

**Lesson:**
- Always check the actual export name in `functions/src/index.ts`
- Use the exact export name when calling from Flutter
- Don't rely on comments for function names

**Files:**
- `functions/src/index.ts` - Check exports
- `legal_ai_app/lib/core/services/cloud_functions_service.dart` - Use correct names

---

### Learning 2: Firebase Configuration for Flutter Web
**Date:** 2026-01-17  
**Context:** Slice 1 - Login failing with placeholder API keys

**Issue:**
- `firebase_options.dart` had placeholder values
- App couldn't connect to Firebase
- Error: `key=placeholder-web-api-key`

**Solution:**
- Must run `flutterfire configure` to generate real config
- Or manually update `firebase_options.dart` with values from Firebase Console
- Web app config is in: Firebase Console → Project Settings → General → Your apps → Web app

**Lesson:**
- Never use placeholder values in production
- Always verify `firebase_options.dart` has real API keys
- Check for "placeholder" strings before deploying

**Files:**
- `legal_ai_app/lib/firebase_options.dart` - Must have real values
- Firebase Console → Project Settings → General

---

### Learning 3: Cloud Functions Region Configuration
**Date:** 2026-01-17  
**Context:** Slice 1 - CORS errors when calling functions

**Issue:**
- Functions deployed to `us-central1`
- Flutter app not specifying region
- CORS errors occurring

**Solution:**
- Must specify region in `CloudFunctionsService`:
  ```dart
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  ```
- Region must match where functions are deployed

**Lesson:**
- Always specify the region explicitly
- Match the region to where functions are deployed
- Default region might not be `us-central1`

**Files:**
- `legal_ai_app/lib/core/services/cloud_functions_service.dart`

---

### Learning 4: CORS with Firebase Callable Functions
**Date:** 2026-01-17  
**Context:** Slice 1 - CORS policy blocking requests

**Issue:**
- CORS errors when calling Cloud Functions from localhost
- Error: "No 'Access-Control-Allow-Origin' header"

**Solution:**
- Firebase callable functions (`onCall`) handle CORS automatically
- But functions must be **deployed** to Firebase
- Local/emulator functions may have CORS issues
- Ensure functions are deployed: `firebase deploy --only functions`

**Lesson:**
- Callable functions handle CORS automatically when deployed
- Always deploy functions before testing from web app
- Check deployment status: `firebase functions:list`

**Files:**
- `functions/src/index.ts` - Functions must be exported
- Deployment: `firebase deploy --only functions`

---

## Flutter Development

### Learning 5: Flutter Web Platform Support
**Date:** 2026-01-17  
**Context:** Slice 1 - App not configured for web

**Issue:**
- Error: "This application is not configured to build on the web"
- `flutter run -d chrome` failing

**Solution:**
- Must add web platform: `flutter create . --platforms=web`
- Or use: `flutter create .` (adds all platforms)

**Lesson:**
- Web support not added by default in some Flutter versions
- Always add platform support before first run
- Check `web/` folder exists

**Files:**
- `legal_ai_app/web/` - Must exist for web builds

---

### Learning 6: Firebase Package Version Compatibility
**Date:** 2026-01-17  
**Context:** Slice 1 - Compilation errors with Firebase packages

**Issue:**
- Old Firebase package versions incompatible with Flutter 3.38.7
- Errors: `Type 'PromiseJsImpl' not found`, `Method 'handleThenable' not found`

**Solution:**
- Updated to compatible versions:
  - `firebase_core: ^3.6.0` (was ^2.24.0)
  - `firebase_auth: ^5.3.1` (was ^4.10.0)
  - `cloud_functions: ^5.1.6` (was ^4.6.0)

**Lesson:**
- Always check Flutter/package version compatibility
- Use `flutter pub outdated` to check for updates
- Test after updating major versions

**Files:**
- `legal_ai_app/pubspec.yaml` - Check package versions

---

### Learning 7: Hot Restart vs Hot Reload
**Date:** 2026-01-17  
**Context:** Slice 1 - Firebase config changes not taking effect

**Issue:**
- Updated `firebase_options.dart` but changes not reflected
- Hot reload (`r`) didn't pick up changes

**Solution:**
- Hot reload (`r`) doesn't reload Firebase initialization
- Must use hot restart (`R`) or full restart
- Configuration changes require full app restart

**Lesson:**
- Use hot restart (`R`) for:
  - Firebase configuration changes
  - Provider initialization changes
  - Route configuration changes
- Use hot reload (`r`) for:
  - UI changes
  - Widget styling
  - Simple state changes

---

### Learning 8: Error Message Visibility
**Date:** 2026-01-17  
**Context:** Slice 1 - Generic error messages not helpful

**Issue:**
- Error messages too generic ("Error", "Login failed")
- Hard to debug issues
- Browser console had more details

**Solution:**
- Added `debugPrint()` statements for detailed logging
- Enhanced error handling with specific error codes
- Show detailed errors in UI (with user-friendly messages)
- Always check browser console (F12) for full error details

**Lesson:**
- Always log detailed errors for debugging
- Show user-friendly messages in UI
- Check browser console for full error stack
- Use `debugPrint()` instead of `print()` in Flutter

**Files:**
- `legal_ai_app/lib/core/services/auth_service.dart`
- `legal_ai_app/lib/core/services/cloud_functions_service.dart`
- `legal_ai_app/lib/features/auth/providers/auth_provider.dart`

---

## Development Environment

### Learning 9: PowerShell Execution Issues
**Date:** 2026-01-17  
**Context:** Multiple attempts to run PowerShell scripts

**Issue:**
- PowerShell scripts failing with syntax errors
- Errors: `Missing ')'`, `Unexpected token '{'`
- Scripts not executing properly

**Solution:**
- Created `.bat` files instead of `.ps1` for Windows
- `.bat` files more reliable for simple automation
- Use `cmd /c` wrapper when needed
- Provide manual command alternatives

**Lesson:**
- `.bat` files more reliable than `.ps1` for simple tasks
- Always provide manual command alternatives
- Test scripts before sharing
- Consider cross-platform compatibility

**Files:**
- Various `.bat` files in `legal_ai_app/` and root

---

### Learning 10: Flutter PATH Configuration
**Date:** 2026-01-17  
**Context:** Flutter not found in PATH

**Issue:**
- Flutter installed but not accessible
- Error: `'flutter' is not recognized`

**Solution:**
- Add Flutter to PATH: `C:\src\flutter\bin`
- Use `setx PATH` or Environment Variables UI
- Must close and reopen terminal after PATH change
- Verify: `flutter --version`

**Lesson:**
- Always verify PATH after installation
- Close/reopen terminal after PATH changes
- Provide verification commands
- Create helper scripts to check installation

**Files:**
- `legal_ai_app/add-flutter-to-path.bat`
- `legal_ai_app/check-flutter.bat`

---

### Learning 11: Git Repository Scope
**Date:** 2026-01-17  
**Context:** Git trying to track files outside project

**Issue:**
- Git initialized in parent directory
- Trying to track files outside project
- Permission errors

**Solution:**
- Initialize Git in project directory only
- Use `.gitignore` to exclude unwanted files
- Check Git root: `git rev-parse --show-toplevel`

**Lesson:**
- Always initialize Git in project root
- Check Git root before committing
- Use `.gitignore` properly
- Verify what files Git is tracking

---

## Error Handling & Debugging

### Learning 12: Browser Console is Essential
**Date:** 2026-01-17  
**Context:** Debugging CORS and Firebase errors

**Issue:**
- App errors not showing full details
- Generic error messages

**Solution:**
- Always check browser console (F12 → Console)
- Browser console shows:
  - Full error stack traces
  - Network request details
  - CORS errors
  - Firebase errors
- Use `debugPrint()` to log to console

**Lesson:**
- Browser console is the best debugging tool for web apps
- Always check console when errors occur
- Log important events with `debugPrint()`
- Network tab shows API call details

---

### Learning 13: Error Message Patterns
**Date:** 2026-01-17  
**Context:** Identifying error types

**Common Error Patterns:**
- `key=placeholder-*` → Firebase not configured
- `CORS policy` → Functions not deployed or region mismatch
- `user-not-found` → User doesn't exist in Firebase
- `wrong-password` → Password incorrect
- `Type 'PromiseJsImpl' not found` → Package version mismatch
- `internal` → Usually CORS or function not found

**Lesson:**
- Learn to recognize error patterns
- Create error handling for common patterns
- Provide specific solutions for each pattern

---

## Best Practices

### Learning 14: Repository Organization
**Date:** 2026-01-17  
**Context:** Root directory getting cluttered

**Best Practice:**
- Keep root directory clean
- Organize by purpose:
  - `docs/` - All documentation
  - `scripts/dev/` - Development scripts
  - `scripts/ops/` - Operations scripts
- Only essential config files in root

**Lesson:**
- Plan folder structure early
- Enforce organization rules
- Update Master Spec with structure guidelines
- Review structure regularly

**Files:**
- `docs/MASTER_SPEC V1.3.2.md` - Section 2.7

---

### Learning 15: Documentation as You Go
**Date:** 2026-01-17  
**Context:** Forgetting what was done

**Best Practice:**
- Document issues and solutions immediately
- Update completion docs with learnings
- Keep troubleshooting guides updated
- Create learnings document (this file)

**Lesson:**
- Don't wait to document
- Capture learnings while fresh
- Link related documents
- Make documentation searchable

---

### Learning 16: Test User Management
**Date:** 2026-01-17  
**Context:** Need consistent test credentials

**Best Practice:**
- Create dedicated test users
- Document test credentials
- Use consistent naming: `test-{date}@test.com`
- Keep test users in Firebase Console

**Lesson:**
- Standardize test user creation
- Document credentials clearly
- Don't use production users for testing
- Create users via Console or app

---

## Common Pitfalls

### Pitfall 1: Assuming Functions Auto-Handle Everything
**Issue:** Assuming Firebase handles all configuration automatically  
**Reality:** Many things need manual configuration  
**Solution:** Always verify configuration, don't assume

### Pitfall 2: Not Checking Browser Console
**Issue:** Only looking at app error messages  
**Reality:** Browser console has full error details  
**Solution:** Always check F12 → Console first

### Pitfall 3: Not Verifying Deployment
**Issue:** Assuming functions are deployed  
**Reality:** Functions might not be deployed or need redeploy  
**Solution:** Always verify: `firebase functions:list`

### Pitfall 4: Using Placeholder Values
**Issue:** Forgetting to replace placeholder config  
**Reality:** Placeholders cause runtime errors  
**Solution:** Always verify no placeholders before testing

### Pitfall 5: Function Name Mismatches
**Issue:** Using wrong function names  
**Reality:** Export names must match call names exactly  
**Solution:** Always check `functions/src/index.ts` for actual names

---

## Quick Reference

### Firebase Configuration Checklist
- [ ] Run `flutterfire configure`
- [ ] Verify `firebase_options.dart` has real values (no placeholders)
- [ ] Check Email/Password is enabled in Firebase Console
- [ ] Verify functions are deployed: `firebase functions:list`
- [ ] Check region matches: `us-central1`

### Flutter Setup Checklist
- [ ] Flutter installed and in PATH
- [ ] Web platform added: `flutter create . --platforms=web`
- [ ] Dependencies installed: `flutter pub get`
- [ ] No analysis errors: `flutter analyze`
- [ ] App runs: `flutter run -d chrome`

### Debugging Checklist
- [ ] Check browser console (F12)
- [ ] Check Flutter terminal output
- [ ] Verify Firebase configuration
- [ ] Check function deployment status
- [ ] Verify function names match
- [ ] Check region configuration

---

## How to Use This Document

1. **Before Starting New Work:**
   - Review relevant learnings section
   - Check common pitfalls
   - Review quick reference

2. **When Encountering Issues:**
   - Search this document for similar issues
   - Check if solution exists
   - Add new learning if new issue found

3. **After Completing Work:**
   - Document any new learnings
   - Update relevant sections
   - Add to quick reference if needed

---

## Contributing to This Document

When you discover a new learning:

1. **Add to appropriate section** (or create new section)
2. **Include:**
   - Date
   - Context (what you were doing)
   - Issue (what went wrong)
   - Solution (how you fixed it)
   - Lesson (what to remember)
   - Related files

3. **Update table of contents** if adding new section

4. **Link from related documents** if relevant

---

**Last Updated:** 2026-01-17  
**Next Review:** After Slice 2 completion
