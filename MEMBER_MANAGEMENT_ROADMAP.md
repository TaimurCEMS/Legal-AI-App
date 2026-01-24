# Member Management & Role Assignment - Implementation Roadmap

**Date:** January 21, 2026  
**Status:** Not Yet Implemented - Planned for Future Slice

---

## Current Status

### ✅ What's Working:
- **Role-based permissions are enforced** in backend (VIEWER, PARALEGAL, LAWYER, ADMIN)
- **Default role assignment:**
  - Org creator → ADMIN
  - New members → VIEWER
- **Permission checks** work correctly (VIEWER can't create, ADMIN can do everything)
- **Backend infrastructure** is ready (entitlements engine, permissions matrix)

### ❌ What's Missing:
- **No `memberUpdate` Cloud Function** to change user roles
- **No admin UI** to view organization members
- **No UI** to assign/change roles
- **No member list endpoint** (only `memberListMyOrgs` exists)

---

## According to Master Specifications

### Slice 0 Build Card Reference:
**File:** `docs/SLICE_0_BUILD_CARD.md` (Line 26)

> **Scope Out:**
> - Admin panel UI (Slice 15)

This indicates that **member management UI is planned for Slice 15**.

### Slice 0 Notes:
**File:** `docs/SLICE_0_BUILD_CARD.md` (Line 510)

> **Slice 0 Usage:**
> - Log org creation in `org.create` endpoint
> - Log membership creation in `org.join` endpoint
> - **Log membership changes (future, when role assignment is added)**

This confirms that role assignment is **explicitly deferred** to a future slice.

### Slice 0 Role Assignment Rules:
**File:** `docs/SLICE_0_BUILD_CARD.md` (Line 530-533)

> **Role Assignment Rules:**
> - Org creator automatically gets `ADMIN` role
> - New members joining org get `VIEWER` role by default
> - **Role changes must go through Cloud Functions (not in Slice 0 scope, but structure must support it)**

The structure is ready, but the functionality is **not in Slice 0 scope**.

---

## Implementation Plan

### Option 1: Wait for Slice 15 (Admin Panel)
**Timeline:** According to master spec, this is planned for Slice 15

**Pros:**
- Follows the planned roadmap
- Part of comprehensive admin panel
- Can include other admin features together

**Cons:**
- Users need role assignment now (VIEWER users can't create cases/documents)
- Blocks testing with multiple users
- May delay other development

### Option 2: Implement as Mini-Slice (Recommended)
**Timeline:** Can be implemented now (4-5 hours)

**Scope:**
1. **Backend:** `memberUpdate` Cloud Function (1-2 hours)
   - Verify requester is ADMIN
   - Update member role
   - Create audit event
   - Validate role is valid (ADMIN, LAWYER, PARALEGAL, VIEWER)

2. **Frontend:** Member Management Screen (2-3 hours)
   - List all organization members
   - Show current role for each member
   - Allow ADMIN to change roles via dropdown
   - Show role permissions matrix
   - Accessible from Settings or Organization menu

**Why This Makes Sense:**
- Role assignment is a **blocking issue** for multi-user testing
- Infrastructure is already in place (just needs the function + UI)
- Small, focused scope (not a full admin panel)
- Can be done without affecting other slices

---

## Recommended Implementation

### Backend: `memberUpdate` Function

**Location:** `functions/src/functions/member.ts`

**Function Signature:**
```typescript
export const memberUpdate = functions.https.onCall(async (data, context) => {
  // 1. Verify auth
  // 2. Verify requester is ADMIN of the org
  // 3. Validate target user is member of org
  // 4. Validate new role is valid
  // 5. Update member role
  // 6. Create audit event
  // 7. Return success
});
```

**Request:**
```json
{
  "orgId": "string",
  "memberUid": "string",
  "role": "ADMIN" | "LAWYER" | "PARALEGAL" | "VIEWER"
}
```

**Permissions:**
- Only ADMIN can change roles
- Cannot change own role (prevent lockout)
- Cannot remove last ADMIN

### Frontend: Member Management Screen

**Location:** `legal_ai_app/lib/features/home/screens/member_management_screen.dart`

**Features:**
- List all org members with:
  - Name/Email
  - Current role
  - Joined date
  - Role dropdown (ADMIN only)
- Role permissions matrix display
- Success/error messages

**Navigation:**
- Accessible from Settings screen
- Or from Organization menu (if user is ADMIN)

---

## Estimated Effort

- **Backend Function:** 1-2 hours
- **Frontend Screen:** 2-3 hours
- **Testing:** 1 hour
- **Total:** 4-6 hours

---

## Decision Needed

**Question:** Should we implement member management now, or wait for Slice 15?

**Recommendation:** Implement now as a **mini-slice** because:
1. It's blocking multi-user testing
2. Infrastructure is ready
3. Small, focused scope
4. Doesn't conflict with Slice 15 (can enhance later)

---

## Next Steps (If Approved)

1. Create `memberUpdate` Cloud Function
2. Add `memberList` function (list all members of an org)
3. Create Member Management screen
4. Add navigation from Settings
5. Test role assignment flow
6. Deploy and verify

---

**Last Updated:** January 21, 2026
