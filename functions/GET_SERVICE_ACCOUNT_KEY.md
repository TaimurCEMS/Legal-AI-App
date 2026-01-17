# How to Get Firebase Service Account Key

## Step-by-Step Instructions

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com
2. Select your project: **legal-ai-app-1203e**

### Step 2: Navigate to Service Accounts
1. Click the **gear icon** (⚙️) next to "Project Overview" in the left sidebar
2. Click **"Project settings"**
3. Click the **"Service accounts"** tab at the top

### Step 3: Generate Private Key
1. You'll see a section titled **"Firebase Admin SDK"**
2. You'll see code examples for Node.js, Python, etc.
3. Look for the **"Generate new private key"** button (usually at the bottom of the Node.js section)
4. Click **"Generate new private key"**

### Step 4: Download and Save
1. A dialog will appear warning you to keep the key secure
2. Click **"Generate key"**
3. A JSON file will download automatically (e.g., `legal-ai-app-1203e-firebase-adminsdk-xxxxx-xxxxxxxxxx.json`)

### Step 5: Save the File
1. Move the downloaded JSON file to your project's `functions` folder
2. Rename it to something simple like: `firebase-service-account.json`
3. **IMPORTANT**: Add this file to `.gitignore` to avoid committing it to GitHub!

### Step 6: Set Environment Variable
In PowerShell:
```powershell
cd functions
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\Taimur Ahmad\OneDrive - CEMS\Taimur's In Progress Tasks\App Dev\Legal AI App\functions\firebase-service-account.json"
```

Or use a relative path:
```powershell
cd functions
$env:GOOGLE_APPLICATION_CREDENTIALS="$PWD\firebase-service-account.json"
```

## Visual Guide

**Navigation Path:**
```
Firebase Console
  → Select Project (legal-ai-app-1203e)
  → ⚙️ Project Settings (gear icon)
  → Service Accounts tab
  → Generate new private key button
  → Generate key
  → Download JSON file
```

## Security Warning

⚠️ **IMPORTANT**: The service account key gives full admin access to your Firebase project. 

**DO:**
- ✅ Keep it secure and private
- ✅ Add it to `.gitignore`
- ✅ Never commit it to GitHub
- ✅ Only use it for local development/testing

**DON'T:**
- ❌ Share it publicly
- ❌ Commit it to version control
- ❌ Include it in client-side code
- ❌ Upload it to public repositories

## File Structure After Setup

```
functions/
├── firebase-service-account.json  ← Your service account key (NOT in git)
├── package.json
├── src/
└── ...
```

## Verify Setup

After setting the environment variable, verify it's set:
```powershell
echo $env:GOOGLE_APPLICATION_CREDENTIALS
```

You should see the path to your JSON file.

## Next Steps

Once you have the key:
1. Set the environment variable (see Step 6 above)
2. Run the test: `cmd /c run-slice0-tests.bat`
3. The test should now be able to authenticate with Firebase Admin SDK

## Troubleshooting

**If you can't find "Service accounts" tab:**
- Make sure you're in Project Settings (not App Settings)
- Look for tabs: General, Usage and billing, Service accounts, etc.

**If "Generate new private key" button is missing:**
- Make sure you have Owner or Editor permissions on the project
- Try refreshing the page

**If download doesn't work:**
- Check your browser's download settings
- Try a different browser
- Check if pop-up blockers are enabled
