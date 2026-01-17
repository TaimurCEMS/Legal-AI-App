# Slice 0 Terminal Test Script

## Overview

This test script (`slice0-terminal-test.ts`) tests your deployed Slice 0 Cloud Functions against your real Firebase project.

## Prerequisites

1. **Firebase Project ID**: Automatically detected from `GCLOUD_PROJECT` or `GCP_PROJECT` environment variable, or from Firebase Admin initialization.

2. **Firebase API Key**: Required for authentication. Get it from:
   - Firebase Console → Project Settings → General → Web API Key
   - Set as environment variable: `FIREBASE_API_KEY`

3. **Firebase Admin Credentials**: **REQUIRED** - The script needs Firebase Admin credentials to create test users.

   **Option A: Service Account Key (Recommended for local testing)**
   1. Go to [Firebase Console](https://console.firebase.google.com) → Your Project
   2. Project Settings → Service Accounts
   3. Click "Generate New Private Key"
   4. Save the JSON file (e.g., `service-account-key.json`)
   5. Set environment variable:
      ```powershell
      $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account-key.json"
      ```

   **Option B: gcloud CLI**
   ```bash
   gcloud auth application-default login
   ```

   **Option C: If running in GCP environment**
   - Application Default Credentials (ADC) will be used automatically

## Setup

1. **Set Environment Variables**:
   ```bash
   # Windows PowerShell
   $env:FIREBASE_API_KEY="AIzaSyCyMLidl_iXmQG0fLOhi4Vl_netaa_7ZAY"
   $env:GCLOUD_PROJECT="legal-ai-app-1203e"
   
   # Linux/Mac
   export FIREBASE_API_KEY="AIzaSyCyMLidl_iXmQG0fLOhi4Vl_netaa_7ZAY"
   export GCLOUD_PROJECT="legal-ai-app-1203e"
   ```

   **Note**: The API key is from your `legal-ai-web` app in Firebase Console. Since API keys are project-level, this works for all Cloud Functions in your project.

2. **Build and Run**:
   ```bash
   cd functions
   npm run test:slice0
   ```

## What It Tests

1. **orgCreate**: Creates a new organization
   - Test data: "Smith & Associates Law Firm"
   - Verifies: Returns `orgId`, `name`, `plan`

2. **orgJoin**: Joins the created organization
   - Uses `orgId` from step 1
   - Verifies: Idempotent behavior (can join twice)

3. **memberGetMyMembership**: Retrieves membership info
   - Uses `orgId` from step 1
   - Verifies: Returns `orgName`, `role`, `plan`

## Expected Output

```
🧪 Testing Slice 0 Functions (Deployed)

📋 Project: legal-ai-app-1203e
🌍 Region: us-central1
🔗 Functions URL: https://us-central1-legal-ai-app-1203e.cloudfunctions.net/

🔐 Authenticating test user...
✅ Authentication successful

📝 Testing orgCreate...
✅ orgCreate: PASS
   orgId: abc123def456
   name: Smith & Associates Law Firm
   plan: FREE

👥 Testing orgJoin...
✅ orgJoin: PASS
   message: Already a member
   role: ADMIN

🔍 Testing memberGetMyMembership...
✅ memberGetMyMembership: PASS
   orgName: Smith & Associates Law Firm
   role: ADMIN
   plan: FREE

──────────────────────────────────────────────────
✅ All tests passed! (3/3)
```

## Troubleshooting

### Error: "FIREBASE_API_KEY environment variable required"
- Get your API key from Firebase Console → Project Settings → General
- Set it as an environment variable before running the test

### Error: "Project ID not found"
- Set `GCLOUD_PROJECT` or `GCP_PROJECT` environment variable
- Or ensure Firebase Admin is initialized with project credentials

### Error: "Function returned 401"
- Check that your Firebase API key is correct
- Check that your functions are deployed and accessible
- Verify the function region matches (default: `us-central1`)

### Error: "Function returned 404"
- Verify your functions are deployed: `firebase deploy --only functions`
- Check the function names match: `orgCreate`, `orgJoin`, `memberGetMyMembership`
- Verify the region is correct

## Notes

- The script creates a test user with UID: `test-user-slice0`
- Test data is created in your real Firebase project (Firestore)
- The script cleans up by using idempotent operations (can be run multiple times)
- For production testing, consider using a separate test project
