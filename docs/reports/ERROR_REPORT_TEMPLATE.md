# Error Report Template

Please fill this out and share the details:

## What command did you run?
```
[Paste the command here]
```

## What error message did you get?
```
[Paste the full error message here]
```

## Which step failed?
- [ ] Lint check
- [ ] Build check
- [ ] Test check
- [ ] Functions list check
- [ ] Other: ___________

## System Information
- Node.js version: `node --version`
- npm version: `npm --version`
- Operating System: Windows 10/11

## Quick Checks
Run these and share the results:

```bash
# 1. Check Node.js
node --version

# 2. Check npm
npm --version

# 3. Check if functions directory exists
dir functions

# 4. Check if node_modules exists
dir functions\node_modules

# 5. Try lint manually
cd functions
npm run lint
```

## Additional Context
Any other information that might help:
- Did this work before the reorganization?
- What changed recently?
- Any error messages in the console?
