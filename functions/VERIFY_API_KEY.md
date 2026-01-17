# How to Get the Correct Firebase API Key

## The Problem
The test is failing with: **"API key not valid. Please pass a valid API key."**

This means the API key we're using might be:
- Incorrect or expired
- Restricted for certain APIs
- From a different project

## Solution: Get the Correct API Key

### Step 1: Go to Firebase Console
1. Open: https://console.firebase.google.com/project/legal-ai-app-1203e/settings/general
2. Scroll down to **"Your apps"** section
3. Find your **"legal-ai-web"** app (or any web app)

### Step 2: Find the API Key
1. In the **"SDK setup and configuration"** section
2. Look for the `firebaseConfig` object
3. Find the `apiKey` field - it should look like: `AIzaSy...`

### Step 3: Verify It's the Right Key
The API key should:
- Start with `AIza`
- Be about 39 characters long
- Be from the same project (`legal-ai-app-1203e`)

### Step 4: Update the Test Scripts
Once you have the correct API key, update:

**`functions/run-slice0-tests.bat`:**
```batch
set FIREBASE_API_KEY="YOUR_CORRECT_API_KEY_HERE"
```

**`functions/run-slice0-tests.ps1`:**
```powershell
$env:FIREBASE_API_KEY = "YOUR_CORRECT_API_KEY_HERE"
```

## Alternative: Check API Key Restrictions

If the API key is correct but still not working:

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=legal-ai-app-1203e)
2. Find your API key
3. Check **"API restrictions"**:
   - Should be **"Don't restrict key"** OR
   - Should include **"Identity Toolkit API"**
4. Check **"Application restrictions"**:
   - Should allow your usage

## Quick Test

To verify your API key works, you can test it manually:

```powershell
# Replace YOUR_API_KEY with your actual key
$apiKey = "YOUR_API_KEY"
$response = Invoke-RestMethod -Uri "https://identitytoolkit.googleapis.com/v1/projects/legal-ai-app-1203e" -Method Get -Headers @{"X-Goog-Api-Key"=$apiKey}
```

If this works, the API key is valid. If not, you need to get a new one or check restrictions.

## Current API Key Being Used

The test scripts are currently using:
```
AIzaSyCyMLidl_iXmQG0fL0hi4Vl_netaa_7ZAY
```

**Please verify this is correct** by checking Firebase Console.
