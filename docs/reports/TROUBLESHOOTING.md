# Troubleshooting Test Errors

## What Error Did You Get?

Please share the exact error message from when you ran `scripts/dev/test-reorganization.bat`.

## Common Issues & Fixes

### Issue 1: "npm is not recognized"
**Fix:** Make sure Node.js is installed and in your PATH.
```bash
node --version
npm --version
```

### Issue 2: "Cannot find module"
**Fix:** Install dependencies:
```bash
cd functions
npm install
```

### Issue 3: "Lint errors"
**Fix:** Check the specific lint errors:
```bash
cd functions
npm run lint
```

### Issue 4: "Build errors"
**Fix:** Check TypeScript compilation:
```bash
cd functions
npm run build
```

### Issue 5: "Test errors"
**Fix:** Check environment variables:
- `FIREBASE_API_KEY` - Required for tests
- `GOOGLE_APPLICATION_CREDENTIALS` - Required for tests

## Quick Diagnostic

Run this simple check first:
```bash
.\scripts\dev\test-simple.bat
```

This will verify:
- ✅ All files exist in correct locations
- ✅ Directory structure is correct
- ✅ Source files are present

## Manual Test Steps

If the batch script fails, run these commands one by one:

```bash
# 1. Navigate to functions
cd functions

# 2. Check if dependencies are installed
npm list --depth=0

# 3. Run lint
npm run lint

# 4. Run build
npm run build

# 5. Run tests (requires env vars)
npm run test:slice0
```

## What to Share

If you're still having issues, please share:
1. The exact error message
2. Which step failed (lint, build, or test)
3. Output of: `node --version` and `npm --version`
