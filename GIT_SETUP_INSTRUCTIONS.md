# Git Setup Instructions - Connect to GitHub

## Goal
Connect your local project to https://github.com/TaimurCEMS/Legal-AI-App and overwrite existing data.

## ⚠️ WARNING
This will **DELETE ALL EXISTING DATA** in the GitHub repository and replace it with your local code.

## Steps to Execute

### Option 1: Run PowerShell Script (Recommended)
```powershell
.\setup-git.ps1
```

### Option 2: Manual Commands

Open PowerShell or Git Bash in your project directory and run:

```powershell
# 1. Initialize git repository
git init

# 2. Add remote repository
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git

# 3. Add all files
git add .

# 4. Commit all changes
git commit -m "Initial commit: Slice 0 implementation (Org + Entitlements Engine)"

# 5. Set default branch to main
git branch -M main

# 6. Force push to overwrite GitHub repository
git push -f origin main
```

### Option 3: Using Git Bash (if PowerShell has issues)

If PowerShell is having issues, use Git Bash:

```bash
git init
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git
git add .
git commit -m "Initial commit: Slice 0 implementation (Org + Entitlements Engine)"
git branch -M main
git push -f origin main
```

## What Will Be Pushed

- ✅ All source code (functions/src/)
- ✅ Compiled code (functions/lib/)
- ✅ Configuration files (firebase.json, tsconfig.json, etc.)
- ✅ Documentation (docs/, *.md files)
- ✅ Firestore rules and indexes
- ❌ node_modules/ (excluded by .gitignore)
- ❌ .firebase/ (excluded by .gitignore)

## After Pushing

1. Visit https://github.com/TaimurCEMS/Legal-AI-App
2. Verify all files are present
3. Check that the repository structure matches your local project

## Troubleshooting

### Error: "remote origin already exists"
```powershell
git remote remove origin
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git
```

### Error: "Authentication failed"
- You may need to authenticate with GitHub
- Use a Personal Access Token if 2FA is enabled
- Or use SSH: `git remote set-url origin git@github.com:TaimurCEMS/Legal-AI-App.git`

### Error: "Permission denied"
- Make sure you have write access to the repository
- Check that you're logged into the correct GitHub account

## Next Steps After Setup

1. Set up branch protection (optional)
2. Configure GitHub Actions for CI/CD (future)
3. Add collaborators (if needed)
