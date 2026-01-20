# Manual Firestore Index Creation (If Script Fails)

If the batch script fails, create the index manually:

## Steps:

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/firestore/indexes

2. **Click "Create Index"**

3. **Configure the Index:**
   - **Collection ID:** `members`
   - **Collection type:** Select "Collection group" (important!)
   - **Fields:**
     - Field: `uid`
     - Order: Ascending
   - **Query scope:** Collection group

4. **Click "Create"**

5. **Wait for Index to Build:**
   - Status will show "Building" (takes 1-5 minutes)
   - When ready, status changes to "Enabled"

6. **Verify:**
   - Refresh your Flutter app
   - Organization list should now appear

## Why Manual Creation?

Firebase sometimes requires collection group indexes to be created manually, especially for single-field indexes. The CLI deployment may fail with "this index is not necessary" even though it's required for the query.

## Troubleshooting:

- **Index not appearing:** Check you selected "Collection group" not "Collection"
- **Still getting errors:** Wait a few more minutes for index to fully build
- **Different error:** Check Firebase Console logs for the function
