# How to Run Slice 0 Tests

## Option 1: Run the PowerShell Script (Easiest for PowerShell)

Run from PowerShell:
```powershell
cd functions
.\run-slice0-tests.ps1
```

## Option 1b: Run the Batch Script (For CMD)

Double-click: `run-slice0-tests.bat`

Or run from Command Prompt:
```cmd
cd functions
run-slice0-tests.bat
```

Or from PowerShell:
```powershell
cd functions
cmd /c run-slice0-tests.bat
```

## Option 2: Manual PowerShell Commands

Open PowerShell in the `functions` directory and run:

```powershell
$env:FIREBASE_API_KEY="AIzaSyCyMLidl_iXmQG0fL0hi4Vl_netaa_7ZAY"
$env:GCLOUD_PROJECT="legal-ai-app-1203e"
npm run test:slice0
```

## Option 3: Manual Command Prompt

Open CMD in the `functions` directory and run:

```cmd
set FIREBASE_API_KEY=AIzaSyCyMLidl_iXmQG0fL0hi4Vl_netaa_7ZAY
set GCLOUD_PROJECT=legal-ai-app-1203e
npm run test:slice0
```

## What to Expect

The test will:
1. Build TypeScript code
2. Authenticate with Firebase
3. Test `orgCreate` function
4. Test `orgJoin` function  
5. Test `memberGetMyMembership` function
6. Print formatted results

## Troubleshooting

If you get errors:
- Make sure you're in the `functions` directory
- Make sure `npm install` has been run
- Check that Firebase functions are deployed
- Verify the API key is correct
