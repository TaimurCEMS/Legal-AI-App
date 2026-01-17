# Testing Slice 0 Deployed Functions

## Quick Verification Steps

### 1. Check Function Logs for Errors

```bash
# View recent logs for all functions
firebase functions:log

# View logs for specific function
firebase functions:log --only orgCreate
firebase functions:log --only orgJoin
firebase functions:log --only memberGetMyMembership
```

**What to look for:**
- ✅ No error messages
- ✅ Functions are being invoked
- ✅ No timeout errors
- ✅ No Firestore permission errors

---

### 2. Test via Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Functions** → Select a function (e.g., `orgCreate`)
4. Click **"Test"** tab
5. Enter test payload:
   ```json
   {
     "name": "Test Organization",
     "description": "Test description"
   }
   ```
6. Click **"Test the function"**

**Expected Results:**
- ✅ Function executes successfully
- ✅ Returns `{ "success": true, "data": { ... } }`
- ✅ No errors in execution log

---

### 3. Test via Flutter App (Recommended)

If you have a Flutter app set up:

```dart
import 'package:cloud_functions/cloud_functions.dart';

// Test orgCreate
Future<void> testOrgCreate() async {
  final callable = FirebaseFunctions.instance.httpsCallable('orgCreate');
  try {
    final result = await callable.call({
      'name': 'Test Org',
      'description': 'Test description',
    });
    print('Success: ${result.data}');
  } catch (e) {
    print('Error: $e');
  }
}
```

---

### 4. Verify Firestore Data

After testing `orgCreate`, check Firestore:

1. Go to Firebase Console → **Firestore Database**
2. Check these collections exist:
   - ✅ `organizations/{orgId}` - Organization document created
   - ✅ `organizations/{orgId}/members/{uid}` - Member document with role: ADMIN
   - ✅ `organizations/{orgId}/audit_events/{eventId}` - Audit event logged

**Expected Data Structure:**

**Organization Document:**
```json
{
  "id": "abc123...",
  "name": "Test Organization",
  "description": "Test description",
  "plan": "FREE",
  "createdAt": "2026-01-16T...",
  "createdBy": "user_uid_here"
}
```

**Member Document:**
```json
{
  "uid": "user_uid_here",
  "orgId": "abc123...",
  "role": "ADMIN",
  "joinedAt": "2026-01-16T...",
  "createdBy": "user_uid_here"
}
```

**Audit Event:**
```json
{
  "id": "event_id_here",
  "orgId": "abc123...",
  "actorUid": "user_uid_here",
  "action": "org.created",
  "entityType": "organization",
  "entityId": "abc123...",
  "timestamp": "2026-01-16T...",
  "metadata": {
    "orgName": "Test Organization"
  }
}
```

---

### 5. Test Error Cases

**Test `orgCreate` with invalid data:**

```json
// Missing name
{}

// Name too long (101 chars)
{ "name": "a".repeat(101) }

// Invalid characters
{ "name": "Test@Org#" }
```

**Expected:** All should return `{ "success": false, "error": { "code": "VALIDATION_ERROR", ... } }`

---

### 6. Test `orgJoin`

**Prerequisites:**
- Create an org first using `orgCreate`
- Get the `orgId` from the response

**Test payload:**
```json
{
  "orgId": "org_id_from_orgCreate"
}
```

**Expected:**
- ✅ Returns `{ "success": true, "data": { "orgId": "...", "role": "VIEWER", ... } }`
- ✅ Creates member document in `organizations/{orgId}/members/{uid}`
- ✅ Creates audit event `member.added`

**Test idempotency:**
- Call `orgJoin` twice with same `orgId`
- ✅ Second call should return success with message "Already a member"

---

### 7. Test `memberGetMyMembership`

**Prerequisites:**
- User must be a member of an org (use `orgCreate` or `orgJoin`)

**Test payload:**
```json
{
  "orgId": "org_id_here"
}
```

**Expected:**
- ✅ Returns `{ "success": true, "data": { "orgId": "...", "role": "...", "plan": "FREE", "orgName": "...", ... } }`

**Test error case:**
- Use non-existent `orgId`
- ✅ Returns `{ "success": false, "error": { "code": "NOT_FOUND", ... } }`

---

## Common Issues to Check

### Issue 1: Firestore Permission Errors
**Symptom:** Functions log shows "Permission denied"
**Fix:** Deploy Firestore security rules:
```bash
firebase deploy --only firestore:rules
```

### Issue 2: Function Timeout
**Symptom:** Functions timeout after 60 seconds
**Fix:** Check for infinite loops or slow Firestore queries

### Issue 3: Missing Audit Events
**Symptom:** Org created but no audit event
**Fix:** Check `createAuditEvent` function and Firestore write permissions

### Issue 4: Wrong Response Format
**Symptom:** Function returns different format than expected
**Fix:** Check `successResponse` and `errorResponse` wrappers

---

## Quick Test Checklist

- [ ] `orgCreate` creates organization document
- [ ] `orgCreate` creates member document with ADMIN role
- [ ] `orgCreate` creates audit event
- [ ] `orgCreate` validates name (length, characters)
- [ ] `orgJoin` creates member document with VIEWER role
- [ ] `orgJoin` is idempotent (can call twice)
- [ ] `orgJoin` creates audit event for new members
- [ ] `memberGetMyMembership` returns correct membership info
- [ ] `memberGetMyMembership` returns NOT_FOUND for non-members
- [ ] All functions return correct response format
- [ ] Firestore security rules are deployed
- [ ] No errors in function logs

---

## Next Steps After Verification

Once all tests pass:
1. ✅ Slice 0 is fully functional
2. ✅ Ready to integrate with Flutter app
3. ✅ Ready for Slice 1 development

If tests fail:
1. Check function logs for specific errors
2. Verify Firestore rules are deployed
3. Check function code matches Build Card specifications
4. Re-deploy if needed: `firebase deploy --only functions`
