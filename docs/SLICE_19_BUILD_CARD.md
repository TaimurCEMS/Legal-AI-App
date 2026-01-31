# Slice 19 Build Card: Client Portal v1

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (depends on P2 + permission hooks per MASTER_SPEC_V2.0 §6)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 4 ✅, Slice 7 ✅, Slice 11 ✅, **P2 Notification Engine**  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §6.2, §7

---

## 📋 Overview

Slice 19 delivers **Client Portal v1**: a distinct permission domain where **clients** (external parties linked to matters) can sign in and see a limited view of their matters, documents, calendar, and invoices. All access must check entity permissions first; client portal is a separate permission domain from internal firm users.

**Key Features:**
1. **Client identity** – Clients authenticate via invite link (magic link or one-time token) or email/password; identity linked to `clients` collection and matter access.
2. **Client-scoped data** – Client sees only matters they are the client of; within those, view matter summary, shared documents, upcoming events, and their invoices (read-only or pay link).
3. **Firm controls** – Firm users decide which matters/documents/events are "client-visible"; optional toggle per matter or per document.
4. **Notifications** – Clients can receive P2 notifications (e.g. "New document shared", "Invoice ready") if P2 supports client_user audience.

**Out of Scope (v1):**
- Full document upload from client (future: client upload to matter).
- Client messaging/chat (future).
- Client-initiated matter intake (Slice 22).

---

## 🎯 Success Criteria

### Backend
- **Client auth:** Invite flow creates client user (Firebase Auth or custom token) linked to clientId and orgId; role or claim `client_user`; scope limited to matters where client is the designated client.
- **Client APIs:** `clientPortalMatterList`, `clientPortalMatterGet`, `clientPortalDocumentList`, `clientPortalEventList`, `clientPortalInvoiceList` (or single combined "portal" endpoint) – all filter by "this client's matters" and "client-visible" flag.
- **Visibility:** Documents/events marked "client visible" or matter-level "client portal enabled"; enforce in backend so client never sees internal-only data.
- **Permissions:** New permission domain `client_user`; no access to firm admin, members, or non-client matters.

### Frontend
- **Client portal app or route** – Separate entry (e.g. `/portal` or subdomain) with client login (magic link or password).
- **Client dashboard:** List of "My matters" with summary; drill into matter → documents (shared), events (upcoming), invoices (view + pay link if Slice 18).
- **Firm side:** Matter settings – "Enable client portal for this matter"; document/event toggles – "Visible to client".

### Testing
- Backend: Client can only list/read matters they are client of; document/event visibility enforced.
- Frontend: Client login → see only assigned matters and client-visible items.
- Security: Client cannot access other clients' matters or firm-only APIs.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. Client Identity & Invite
- **`clientPortalInvite`** – Firm user (with permission) creates invite for a client (email, matterIds, optional message). Store invite token; send email (P2 or SendGrid) with magic link or one-time login link.
- **`clientPortalAcceptInvite`** – Client clicks link with token; create or link Firebase Auth user; set custom claim `client_user`, `orgId`, `clientId`, allowed matterIds; return session.
- **`clientPortalAuth`** – Optional: client login with email/password (if client already has account); validate client_user claim and matter access.

#### 2. Client-Scoped Read APIs
- **`clientPortalMatterList`** – Request: (auth as client_user). Returns matters where clientId = this client and matter.clientPortalEnabled = true.
- **`clientPortalMatterGet`** – Request: matterId. Verify client has access; return matter summary (no internal notes).
- **`clientPortalDocumentList`** – Request: matterId. Return documents where clientVisible = true (or matter-level default).
- **`clientPortalDocumentGet`** – Request: matterId, documentId. Return metadata + download URL if client visible.
- **`clientPortalEventList`** – Request: matterId, fromDate?, toDate?. Return events where clientVisible = true.
- **`clientPortalInvoiceList`** – Request: (client scope). Return invoices for this client's matters; client can view and use payment link (Slice 18).

#### 3. Data Model Extensions
- **Matter:** `clientPortalEnabled: boolean`; optional `clientVisibleDefault` for new docs/events.
- **Document:** `clientVisible?: boolean`.
- **Event:** `clientVisible?: boolean`.
- **Client:** Already exists; ensure `userId` or `portalInviteId` for linking Auth to client record.
- **Collection:** `organizations/{orgId}/client_portal_invites/{inviteId}` – token, email, matterIds, status, expiresAt.

### Frontend (Flutter)

- **Portal entry:** `/portal` route; ClientLoginScreen (magic link or password).
- **Client dashboard:** PortalDashboardScreen – cards for each matter; click → Matter detail (documents, events, invoices).
- **Firm side:** Matter details – "Client portal" section: enable/disable; list shared docs/events; toggle visibility per item.
- **Separate build or flavor (optional):** Client portal as separate app or same app with role-based home.

---

## 🔐 Security & Permissions

- **client_user** cannot call any firm-only functions (member list, org settings, audit, etc.).
- All client portal APIs validate: token has client_user claim, clientId matches, matterId in allowed list, and document/event has clientVisible.
- Firestore rules: separate rules for `client_portal_*` and read-only client-visible subcollections or use Cloud Functions only (no direct client Firestore for portal data if preferred).

---

## 📝 Backend Endpoints (Summary)

| Function | Auth | Request | Success |
|----------|------|---------|---------|
| clientPortalInvite | Firm (permission) | orgId, clientId, email, matterIds | { inviteLink, expiresAt } |
| clientPortalAcceptInvite | Token in URL | token | { customToken, clientId } |
| clientPortalMatterList | client_user | - | { matters: [...] } |
| clientPortalMatterGet | client_user | matterId | matter summary |
| clientPortalDocumentList | client_user | matterId | { documents: [...] } |
| clientPortalDocumentGet | client_user | matterId, documentId | { downloadUrl, ... } |
| clientPortalEventList | client_user | matterId, from?, to? | { events: [...] } |
| clientPortalInvoiceList | client_user | - | { invoices: [...] } |

---

## 🧪 Testing Strategy

- Unit: Client access helper – given clientId and matterId, return allowed.
- Integration: Create invite → accept → list matters (only assigned); try to access other matter → 403.
- Frontend: Client login → dashboard → open matter → documents and invoices visible.

---

## 📚 References

- MASTER_SPEC_V2.0.md §6 (Permission hooks; client_user)
- SLICE_18_BUILD_CARD.md (Payment link for invoices)
- SLICE_P2_BUILD_CARD.md (Notifications for clients)

---

**Last Updated:** 2026-01-30
