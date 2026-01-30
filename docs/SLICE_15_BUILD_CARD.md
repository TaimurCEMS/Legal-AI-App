# Slice 15 Build Card: Advanced Admin Features

**Status:** 🟡 IN PROGRESS  
**Priority:** Medium (Enterprise Features)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2.5 ✅  
**Date Created:** 2026-01-29

---

## 📋 Overview

Slice 15 adds **Advanced Admin Features** to make the Legal AI App enterprise-ready. These features are essential for larger law firms and organizations that need granular control over team management, organization settings, and data governance.

**Key Features:**
1. **Member Invitations** - Email-based invitation workflow with invite codes
2. **Organization Settings** - Comprehensive org configuration (name, timezone, defaults)
3. **Member Profiles** - Professional profiles (bio, specialties, bar admission, photo)
4. **Organization Data Export** - Export all organization data to CSV/JSON
5. **Organization Statistics** - Dashboard with org metrics and insights

**Deferred to Future:**
- Bulk operations (bulk delete, bulk archive) - needs careful UX design
- Custom role definitions - requires permissions matrix refactoring

---

## 🎯 Success Criteria

### Backend
- ✅ Member invitation system (create, accept, revoke, list)
- ✅ Organization settings CRUD (update, get)
- ✅ Member profile management (update profile, get profile)
- ✅ Organization data export (all entities to JSON)
- ✅ Organization statistics (counts, activity metrics)
- ✅ Proper entitlement checks (ADMIN-only)
- ✅ Audit logging for all admin actions

### Frontend
- ✅ Member invitation screen (send invites, view pending invites)
- ✅ Organization settings screen (edit org details)
- ✅ Member profile screen (view/edit member profiles)
- ✅ Organization export screen (trigger export, download)
- ✅ Organization dashboard (statistics and insights)
- ✅ Navigation integration (Settings → Advanced Admin)

### Testing
- ✅ Backend: Terminal tests for all functions
- ✅ Frontend: Manual testing of all screens
- ✅ Integration: End-to-end invitation flow

---

## 🏗️ Technical Architecture

### Backend Functions (Cloud Functions)

#### 1. Member Invitations
- **`invitationCreate`** - Create email-based invitation (generates invite code)
- **`invitationAccept`** - Accept invitation using invite code (adds user to org)
- **`invitationRevoke`** - Revoke pending invitation (ADMIN-only)
- **`invitationList`** - List pending/accepted/revoked invitations

**Data Model:**
```typescript
interface Invitation {
  invitationId: string;
  orgId: string;
  email: string;
  role: Role; // LAWYER, PARALEGAL, VIEWER (not ADMIN by default)
  inviteCode: string; // Unique 8-char code
  status: 'pending' | 'accepted' | 'revoked' | 'expired';
  invitedBy: string; // uid
  invitedAt: Timestamp;
  acceptedAt?: Timestamp;
  acceptedBy?: string; // uid
  revokedAt?: Timestamp;
  revokedBy?: string; // uid
  expiresAt: Timestamp; // 7 days from invitedAt
}
```

#### 2. Organization Settings
- **`orgUpdate`** - Update organization settings
- **`orgGetSettings`** - Get organization settings (with defaults)

**Extended Org Model:**
```typescript
interface OrganizationSettings {
  // Existing fields
  name: string;
  description?: string;
  plan: Plan;
  
  // New fields
  timezone?: string; // e.g., "America/New_York"
  businessHours?: {
    start: string; // e.g., "09:00"
    end: string; // e.g., "17:00"
  };
  defaultCaseVisibility?: 'ORG_WIDE' | 'PRIVATE';
  defaultTaskVisibility?: boolean; // restrictedToAssignee default
  logo?: string; // Storage URL
  website?: string;
  address?: {
    street?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
}
```

#### 3. Member Profiles
- **`memberUpdateProfile`** - Update member profile (self or ADMIN)
- **`memberGetProfile`** - Get member profile (with privacy controls)

**Extended Member Model:**
```typescript
interface MemberProfile {
  // Existing fields
  uid: string;
  role: Role;
  joinedAt: Timestamp;
  
  // New fields
  bio?: string;
  title?: string; // e.g., "Senior Associate", "Partner"
  specialties?: string[]; // e.g., ["Corporate Law", "M&A"]
  barAdmissions?: Array<{
    jurisdiction: string; // e.g., "New York"
    barNumber?: string;
    admittedYear?: number;
  }>;
  education?: Array<{
    institution: string;
    degree: string;
    year?: number;
  }>;
  phoneNumber?: string;
  photoUrl?: string; // Storage URL
  isPublic?: boolean; // Show profile to org members
}
```

#### 4. Organization Data Export
- **`orgExport`** - Export all organization data to JSON
  - Cases, clients, documents (metadata only), tasks, events, notes
  - Time entries, invoices, audit logs
  - Members (anonymized sensitive data)
  - Generates download URL for JSON file

#### 5. Organization Statistics
- **`orgGetStats`** - Get organization statistics
  - Member count, case count, document count, task count
  - Activity metrics (last 30 days)
  - Storage usage (document totals)

### Frontend Screens (Flutter)

#### 1. Admin Settings Hub (`AdminSettingsScreen`)
- Navigation entry point for all admin features
- Cards for: Invitations, Org Settings, Member Profiles, Data Export, Statistics

#### 2. Member Invitations (`InvitationManagementScreen`)
- **Send Invite** - Email + role selection, generates invite code
- **Pending Invites** - List with revoke action
- **Invite History** - Accepted/revoked invites

#### 3. Organization Settings (`OrganizationSettingsScreen`)
- **General** - Name, description, logo, website
- **Location** - Address fields
- **Business** - Timezone, business hours
- **Defaults** - Default case/task visibility

#### 4. Member Profiles (`MemberProfileScreen`)
- **View Mode** - Display member profile (bio, specialties, bar admissions)
- **Edit Mode** - Edit own profile or member profiles (ADMIN)
- **Photo Upload** - Upload profile photo to Storage

#### 5. Organization Export (`OrganizationExportScreen`)
- **Export Options** - Select entities to export (all by default)
- **Export Status** - Progress indicator
- **Download** - Download JSON file

#### 6. Organization Dashboard (`OrganizationDashboardScreen`)
- **Statistics Cards** - Member count, case count, document count
- **Activity Chart** - Recent activity (last 30 days)
- **Storage Usage** - Document storage totals

---

## 🔐 Security & Permissions

### Permissions Required
- **Member Invitations:** `admin.manage_users` (ADMIN-only)
- **Organization Settings:** `admin.manage_org` (new permission, ADMIN-only)
- **Member Profiles:** Self (own profile) or `admin.manage_users` (others)
- **Data Export:** `admin.data_export` (new permission, ADMIN-only)
- **Statistics:** `admin.view_stats` (new permission, ADMIN-only)

### Safety Checks
1. **Invitation Limits:** Check plan limits (e.g., max 5 users on FREE plan)
2. **Email Validation:** Verify email format before sending invite
3. **Duplicate Prevention:** Don't allow duplicate pending invites for same email
4. **Expiration:** Invitations expire after 7 days
5. **Role Restrictions:** Cannot invite as ADMIN role (must upgrade after joining)

### Firestore Rules
```javascript
// Invitations (ADMIN-only read/write)
match /organizations/{orgId}/invitations/{invitationId} {
  allow read: if isOrgMember(orgId) && isAdmin();
  allow write: if isOrgMember(orgId) && isAdmin();
}

// Member profiles (self or ADMIN)
match /organizations/{orgId}/members/{uid}/profile {
  allow read: if isOrgMember(orgId);
  allow write: if isOrgMember(orgId) && (request.auth.uid == uid || isAdmin());
}
```

---

## 📊 Data Flow

### Member Invitation Flow
1. **ADMIN sends invite:**
   - Frontend: InvitationManagementScreen → "Send Invite" form
   - Backend: `invitationCreate` → Generate invite code → Store in Firestore
   - (Optional: Send email with invite link via SendGrid/Postmark)
2. **Invitee accepts:**
   - Frontend: Public invitation accept page (no auth required)
   - Backend: `invitationAccept` → Verify code → Add user to org → Mark invitation accepted
3. **ADMIN revokes:**
   - Frontend: InvitationManagementScreen → "Revoke" button
   - Backend: `invitationRevoke` → Mark invitation revoked → Audit log

### Organization Settings Flow
1. **ADMIN edits settings:**
   - Frontend: OrganizationSettingsScreen → Edit form
   - Backend: `orgUpdate` → Validate → Update org document → Audit log
2. **User views settings:**
   - Frontend: Load settings on app start
   - Backend: `orgGetSettings` → Return settings with defaults

### Member Profile Flow
1. **User edits own profile:**
   - Frontend: MemberProfileScreen → Edit mode
   - Backend: `memberUpdateProfile` → Update profile subcollection
2. **ADMIN edits member profile:**
   - Frontend: Member list → View profile → Edit
   - Backend: `memberUpdateProfile` → Verify ADMIN permission → Update profile

### Organization Export Flow
1. **ADMIN triggers export:**
   - Frontend: OrganizationExportScreen → "Export Data" button
   - Backend: `orgExport` → Aggregate all collections → Generate JSON → Upload to Storage → Return download URL
2. **ADMIN downloads:**
   - Frontend: Download button → Open download URL

---

## 🧪 Testing Strategy

### Backend Tests
- `npm run test:slice15` - Terminal test for all Slice 15 functions
- Test cases:
  - ✅ Invitation: create, accept (valid code), revoke, list
  - ✅ Organization settings: update (valid), get (with defaults)
  - ✅ Member profiles: update (self), update (other as ADMIN), get
  - ✅ Export: trigger export (ADMIN), verify JSON structure
  - ✅ Statistics: get stats (ADMIN)
  - ✅ Permission checks: Non-ADMIN denied for admin-only functions

### Frontend Tests
- Manual testing of all screens
- Invitation flow: send, accept (via code), revoke
- Organization settings: edit, save, view updated settings
- Member profiles: view, edit, upload photo
- Export: trigger, download JSON
- Statistics: view dashboard

### Integration Tests
- Full invitation flow: send → accept → verify membership
- Organization settings: update → refresh → verify persisted
- Member profiles: update → view from another account → verify visibility

---

## 📝 Implementation Notes

### Phase 1: Backend Foundation (Priority 1)
1. ✅ Define new permissions (`admin.manage_org`, `admin.data_export`, `admin.view_stats`)
2. ✅ Implement invitation functions (`invitationCreate`, `invitationAccept`, `invitationRevoke`, `invitationList`)
3. ✅ Implement organization settings functions (`orgUpdate`, `orgGetSettings`)
4. ✅ Implement member profile functions (`memberUpdateProfile`, `memberGetProfile`)
5. ✅ Implement data export function (`orgExport`)
6. ✅ Implement statistics function (`orgGetStats`)
7. ✅ Write backend tests

### Phase 2: Frontend Implementation (Priority 2)
1. ✅ Create Admin Settings Hub screen
2. ✅ Implement Member Invitations screen
3. ✅ Implement Organization Settings screen
4. ✅ Implement Member Profile screen
5. ✅ Implement Organization Export screen
6. ✅ Implement Organization Dashboard screen
7. ✅ Integrate into Settings navigation

### Phase 3: Testing & Polish (Priority 3)
1. ✅ Manual testing of all flows
2. ✅ Fix issues, refine UX
3. ✅ Update documentation
4. ✅ Deploy to Firebase

---

## 🚧 Known Limitations / Future Enhancements

### Deferred Features (Post-Slice 15)
1. **Email Notifications** - Actual email sending (requires SendGrid/Postmark integration)
2. **Bulk Operations** - Bulk delete, bulk archive (needs careful UX design)
3. **Custom Role Definitions** - User-defined roles (requires permissions matrix refactoring)
4. **SSO Integration** - Single Sign-On (Google Workspace, Microsoft 365)
5. **Advanced Exports** - CSV format, scheduled exports, selective exports

### Technical Debt
- Invitation email sending is stubbed (currently generates code only)
- Export is single-file JSON (no pagination for very large orgs)
- Statistics are calculated on-demand (future: pre-computed aggregations)

---

## 📚 References

- **Master Spec:** Section 4.8 (Permissions Matrix)
- **Feature Roadmap:** `docs/FEATURE_ROADMAP.md`
- **Existing Member Management:** Slice 2.5 (`docs/SLICE_2.5_MEMBER_MANAGEMENT_BUILD_CARD.md`)

---

**Last Updated:** 2026-01-29  
**Next Steps:** Begin Phase 1 (Backend Foundation)
