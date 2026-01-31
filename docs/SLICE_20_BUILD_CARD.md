# Slice 20 Build Card: Calendar Sync (External Calendars)

**Status:** 🟡 NOT STARTED  
**Priority:** Medium (after launch criteria or in parallel as capacity allows)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 7 ✅ (Calendar & Court Dates)  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §7

---

## 📋 Overview

Slice 20 adds **Calendar Sync** with external calendar providers (Google Calendar, Microsoft Outlook/Office 365). Internal calendar (Slice 7) remains the source of truth; sync pushes events to external calendars and optionally pulls external events into a unified view.

**Key Features:**
1. **Outbound sync** – Push Slice 7 events (hearings, deadlines, etc.) to user's Google/Outlook calendar so they appear in their preferred calendar app.
2. **OAuth connection** – User connects their Google or Microsoft account (OAuth 2.0); store refresh token securely per user (or per org member).
3. **Sync engine** – On event create/update/delete (Slice 7), enqueue or immediately push to connected external calendar; support create/update/delete of external event.
4. **Optional inbound** – (Deferred or MVP-limited) Show external events in app calendar view (read-only) to avoid double-booking; or one-way outbound only for MVP.

**Out of Scope (MVP):**
- Two-way full sync with conflict resolution.
- Apple iCal / CalDAV (future).
- Recurring event mapping to external recurrence rules (map to single or simple recurrence).

---

## 🎯 Success Criteria

### Backend
- **OAuth:** Endpoints or callables to initiate Google/Outlook OAuth and handle callback; store encrypted refresh token in `organizations/{orgId}/members/{uid}/calendar_connections` or user-private store.
- **Sync:** On Slice 7 event create/update/delete, call sync service to push to Google/Outlook API (create/update/delete external event); map our event fields to provider format (title, start, end, description, location).
- **Callables:** `calendarConnectionList`, `calendarConnectionDisconnect`, `calendarSyncTrigger` (manual sync now) – all require org member and calendar feature.
- **Idempotency:** Store external event ID per our event so we can update/delete the right external event.

### Frontend
- **Settings → Calendar:** "Connect Google Calendar" / "Connect Outlook" – OAuth flow; show connected account and "Disconnect".
- **Calendar screen:** Indicator "Synced to Google Calendar" (or Outlook); optional "Sync now" button.
- **Event form:** Optional "Sync to my external calendar" (default on when connected).

### Testing
- Backend: OAuth flow stores token; sync creates event in Google (test account); update/delete propagate.
- Frontend: Connect Google → create event in app → verify event appears in Google Calendar.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. OAuth & Connections
- **`calendarAuthUrl`** – Request: `{ orgId, provider: "google" | "microsoft" }`. Return authorization URL for OAuth; state param includes orgId, uid.
- **`calendarOAuthCallback`** – HTTPS callback; exchange code for tokens; store refresh token (encrypted) in Firestore; return redirect to app "Connected successfully".
- **`calendarConnectionList`** – Request: orgId. Return list of connected providers for current user.
- **`calendarConnectionDisconnect`** – Request: orgId, provider. Remove token for provider.

#### 2. Sync
- **Event trigger or callable:** On Slice 7 `eventCreate`/`eventUpdate`/`eventDelete`, call **sync service** which:
  - Loads user's calendar connections for event owner (or org default).
  - For each connection: create/update/delete event via Google Calendar API or Microsoft Graph.
  - Store `externalEventId` on our event document (e.g. `googleEventId`, `outlookEventId`) for future updates.
- **`calendarSyncTrigger`** – Request: orgId, optional matterId. Re-sync recent events for current user's connections (catch-up).

#### 3. Data Model
- **Collection:** `organizations/{orgId}/members/{uid}/calendar_connections/{provider}`  
  - provider: "google" | "microsoft"  
  - refreshToken: encrypted  
  - externalCalendarId?: string (primary calendar)  
  - connectedAt: Timestamp  
- **Event document (Slice 7):** Add optional `externalIds: { google?: string, microsoft?: string }`.

### Frontend (Flutter)

- **Calendar connection UI** – Settings → Integrations → Calendar; buttons "Connect Google", "Connect Outlook"; show connected and disconnect.
- **OAuth:** Open browser or in-app WebView for OAuth; handle redirect with token/code; call backend to complete.
- **Sync status** – On event save, show "Syncing to Google Calendar…" or checkmark when synced.

### Security

- Refresh tokens stored encrypted (use Cloud KMS or env-based encryption key).
- Only the user (uid) can add/remove their own calendar connections.
- Sync only pushes events owned by or visible to the user (respect Slice 7 visibility when deciding what to sync).

---

## 📝 Backend Endpoints (Summary)

| Function | Request | Success |
|----------|---------|---------|
| calendarAuthUrl | orgId, provider | { authUrl } |
| calendarOAuthCallback | (HTTPS GET with code, state) | Redirect to app |
| calendarConnectionList | orgId | { connections: [{ provider, connectedAt }] } |
| calendarConnectionDisconnect | orgId, provider | { success } |
| calendarSyncTrigger | orgId, matterId? | { synced: number } |

---

## 🧪 Testing Strategy

- OAuth: Use test Google/Microsoft app; complete flow and verify token stored.
- Sync: Create event in app → verify in Google Calendar; update event → verify update; delete → verify delete.
- Security: Another user cannot read another user's refresh token.

---

## 📚 References

- SLICE_7_BUILD_CARD.md (Calendar & Court Dates)
- Google Calendar API, Microsoft Graph Calendar API
- MASTER_SPEC_V2.0.md §7 (Slice 20)

---

**Last Updated:** 2026-01-30
