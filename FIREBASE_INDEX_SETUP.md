# Firebase Index Setup for memberListMyOrgs

## Issue
The `memberListMyOrgs` function requires a Firestore index for collection group queries.

## Solution: Create Index in Firebase Console

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/legal-ai-app-1203e/firestore/indexes

2. **The index will be created automatically when you:**
   - Run the query from the console, OR
   - Click the link in the error message (if provided)

3. **Manual Creation (if needed):**
   - Collection ID: `members` (collection group)
   - Fields to index:
     - Field: `uid`
     - Order: Ascending
   - Query scope: Collection group

4. **Wait for index to build:**
   - Index creation can take a few minutes
   - You'll see "Building" status, then "Enabled" when ready

## Alternative: Use the Error Link
When the function fails, check the Firebase Console logs - Firestore often provides a direct link to create the required index.

## After Index is Created
Once the index is enabled, the `memberListMyOrgs` function will work and your organizations will appear in the list.
