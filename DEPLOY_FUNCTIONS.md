# Deploy Cloud Functions to Fix CORS Error

## Problem
CORS error when calling Cloud Functions from Flutter web app:
```
Access to fetch at 'https://us-central1-legal-ai-app-1203e.cloudfunctions.net/org.create' 
from origin 'http://localhost:64940' has been blocked by CORS policy
```

## Solution
Deploy the Cloud Functions to Firebase. Firebase callable functions handle CORS automatically once deployed.

## Quick Deploy

### Option 1: Use Batch File
Double-click: `deploy-functions.bat` (in project root)

### Option 2: Manual Commands

1. **Open Command Prompt**

2. **Navigate to functions folder:**
   ```cmd
   cd "C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\functions"
   ```

3. **Install dependencies:**
   ```cmd
   npm install
   ```

4. **Build functions:**
   ```cmd
   npm run build
   ```

5. **Deploy to Firebase:**
   ```cmd
   firebase deploy --only functions --project legal-ai-app-1203e
   ```

6. **Wait for deployment** (takes 2-3 minutes)

7. **Verify deployment:**
   ```cmd
   firebase functions:list --project legal-ai-app-1203e
   ```
   
   You should see:
   - `orgCreate`
   - `orgJoin`
   - `memberGetMyMembership`

## After Deployment

1. **Hot restart Flutter app:**
   - Press `R` (capital R) in Flutter terminal
   - Or stop and restart: `flutter run -d chrome`

2. **Try creating organization again**

3. **CORS error should be gone!**

## Troubleshooting

### "firebase: command not found"
Install Firebase CLI:
```cmd
npm install -g firebase-tools
firebase login
```

### "Not logged in"
```cmd
firebase login
```

### "Project not found"
```cmd
firebase use legal-ai-app-1203e
```

### Deployment fails
- Check you're in the `functions` folder
- Make sure `npm install` completed successfully
- Check `npm run build` works
- Verify Firebase project: `firebase projects:list`
