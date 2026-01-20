# Firestore Indexes for Cases - Setup Guide

## Problem
The `caseList` function is returning `INTERNAL_ERROR: Failed to list cases` because required Firestore composite indexes are missing.

## Root Cause
The `caseList` function queries Firestore with multiple `where` clauses followed by an `orderBy`. Firestore requires composite indexes for such queries.

## Required Indexes

The following indexes have been added to `firestore.indexes.json`:

### 1. Base ORG_WIDE Query
- Collection: `cases` (subcollection of `organizations/{orgId}/cases`)
- Fields:
  - `visibility` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `updatedAt` (DESCENDING)

### 2. ORG_WIDE with Status Filter
- Collection: `cases`
- Fields:
  - `visibility` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `status` (ASCENDING)
  - `updatedAt` (DESCENDING)

### 3. ORG_WIDE with Client Filter
- Collection: `cases`
- Fields:
  - `visibility` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `clientId` (ASCENDING)
  - `updatedAt` (DESCENDING)

### 4. Base PRIVATE Query
- Collection: `cases`
- Fields:
  - `visibility` (ASCENDING)
  - `createdBy` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `updatedAt` (DESCENDING)

### 5. PRIVATE with Status Filter
- Collection: `cases`
- Fields:
  - `visibility` (ASCENDING)
  - `createdBy` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `status` (ASCENDING)
  - `updatedAt` (DESCENDING)

### 6. PRIVATE with Client Filter
- Collection: `cases`
- Fields:
  - `visibility` (ASCENDING)
  - `createdBy` (ASCENDING)
  - `deletedAt` (ASCENDING)
  - `clientId` (ASCENDING)
  - `updatedAt` (DESCENDING)

## Deployment Steps

### Option 1: Deploy via Firebase CLI (Recommended)

1. **Deploy indexes:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Wait for indexes to build:**
   - Go to Firebase Console → Firestore → Indexes
   - Wait for all indexes to show "Enabled" status
   - This can take a few minutes

3. **Verify deployment:**
   ```bash
   firebase firestore:indexes
   ```

### Option 2: Create via Firebase Console

1. Go to Firebase Console → Firestore → Indexes
2. Click "Create Index"
3. For each index above:
   - Collection ID: `cases`
   - Query scope: Collection
   - Add fields in the order specified
   - Click "Create"

## Verification

After indexes are deployed and built:

1. **Test the function:**
   - Go to Firebase Console → Functions → Logs
   - Call `caseList` from the app
   - Check logs for errors

2. **Check index status:**
   - Firebase Console → Firestore → Indexes
   - All indexes should show "Enabled" status

## Expected Behavior After Fix

- `caseList` function should return cases successfully
- No more `INTERNAL_ERROR` responses
- Cases should load in the Flutter app
- Filtering by status/client should work

## Troubleshooting

### Indexes not building
- Check Firebase Console for error messages
- Verify field names match exactly (case-sensitive)
- Ensure collection path is correct

### Still getting errors
- Check Firebase Functions logs for detailed error messages
- Verify Firestore security rules allow read access
- Check that cases collection exists and has data

## Notes

- Indexes are required for queries with multiple `where` clauses + `orderBy`
- Indexes can take several minutes to build
- Once built, queries will be fast
- Indexes are automatically used by Firestore when queries match
