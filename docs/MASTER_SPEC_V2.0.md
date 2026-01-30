# MASTER_SPEC_V2.0.md (Delta-Focused)

## 0. Purpose of V2.0
This document is a delta over the frozen v1.0 spec. It adds platform foundations needed for:
- Notifications (in-app + email now, SMS/push later)
- Activity feed (user-facing)
- Audit log (compliance, immutable)
- Future integrations/webhooks and reliable event-driven flows

This is not a full rewrite of v1.0. Anything not explicitly changed here remains as v1.0.

---

## 1. Terminology Layer (UI vs Backend)
### 1.1 UI Terminology
- Organization => **Firm** (UI label)
- Case => **Matter** (UI label)

### 1.2 Backend Naming (No migrations in v2.0)
To avoid disruptive database migrations:
- Backend collection/model names remain: `organizations`, `cases`
- UI displays: Firm, Matter
- API responses may include `displayTerms` mapping if needed by frontend

### 1.3 Enforcement
- All UI strings must use Firm and Matter
- All backend identifiers can remain org/case internally

---

## 2. Domain Event Model (P1)
### 2.1 Why Events
Events provide a consistent backbone for:
- Notifications
- Activity feed
- Audit events
- Webhooks and integrations
- Reliable retries with idempotency via outbox

### 2.2 Event Envelope (Standard Shape)
Every event must follow this minimal schema:

```
eventId: string (uuid)
orgId: string
matterId?: string
eventType: string (namespace.action)
entityType: string
entityId: string
actor: {
  actorType: "user" | "system"
  actorId: string
}
timestamp: ISO string
visibility: {
  audience: "internal" | "client" | "both"
  rolesAllowed?: string[]
}
payload: object (event-specific, minimal, no sensitive content)
```

### 2.3 Event Type Naming Convention
Use namespaced action patterns:
- `matter.created`
- `matter.updated`
- `task.assigned`
- `document.uploaded`
- `invoice.created`
- `payment.received`
- `comment.added`
- `auth.2fa.enabled`
- `notification.sent`
- `notification.failed`

---

## 3. Outbox + Idempotency + Status Visibility (P1)
### 3.1 Design Goal
Guarantee:
- **Durable intent:** the system records that something must happen
- **Idempotency:** retries do not cause duplicates
- **Visibility:** pending/sent/failed is observable

### 3.2 Outbox Record (Generic)
Outbox is an internal queue stored in Firestore:

**Collection:** `outbox`

**Fields:**

```
id: string (idempotency key)
orgId: string
eventId: string
jobType: "notification_dispatch" | future
status: "pending" | "processing" | "sent" | "failed" | "dead"
attempts: number
maxAttempts: number (default 5)
nextAttemptAt: timestamp
lockedAt?: timestamp
lockOwner?: string
lastError?: { code?: string, message: string, at: timestamp }
createdAt: timestamp
updatedAt: timestamp
```

### 3.3 Idempotency Key Rules
Idempotency key must be deterministic per intent. Example:
- `notif:<orgId>:<eventType>:<entityType>:<entityId>:<recipientId>:<channel>:<templateId>`

If a record with the same id exists, do not create a new one. Update status only if needed.

---

## 4. Notification Model (P2)
### 4.1 Components
- Preference model (per user, per org, optional per matter)
- Routing rules from events => notifications
- In-app notifications (bell UI)
- Email notifications (SendGrid adapter v1)
- Templates with versioning
- Suppression list to block send for bounced/complained addresses

### 4.2 Notification Record (User-Facing)
**Collection:** `notifications`

**Fields:**

```
notificationId: string
orgId: string
recipientUserId: string
matterId?: string
eventId: string
eventType: string
channel: "in_app" | "email"
templateId: string
templateVersion: number
subject?: string (email only)
bodyPreview?: string (short snippet)
status: "queued" | "sent" | "failed" | "suppressed"
readAt?: timestamp (in-app)
sentAt?: timestamp
error?: { message: string, at: timestamp }
createdAt: timestamp
```

### 4.3 Preferences
**Collection:** `notification_preferences`

**Fields:**

```
orgId: string
userId: string
categories: {
  matter: { in_app: boolean, email: boolean }
  task: { in_app: boolean, email: boolean }
  document: { in_app: boolean, email: boolean }
  invoice: { in_app: boolean, email: boolean }
  payment: { in_app: boolean, email: boolean }
  comment: { in_app: boolean, email: boolean }
}
digest?: { enabled: boolean, frequency: "daily" | "weekly" }
quietHours?: { enabled: boolean, startLocal: "HH:mm", endLocal: "HH:mm", tz: string }
updatedAt: timestamp
```

### 4.4 Template Versioning
**Collection:** `notification_templates`

**Fields:**

```
templateId: string
name: string
channel: "email" | "in_app"
currentVersion: number
versions: {
  [versionNumber]: {
    subject?: string
    body: string
    variables: string[]
    createdAt: timestamp
  }
}
```

---

## 5. Audit vs Activity (P1 + P2 + Slice 16)
### 5.1 Activity Feed
User-facing narrative timeline. Derived from domain events.
Collection: `activity_feed` (optional materialization) OR computed queries from events.
Minimum: show who did what, on which matter, when.

### 5.2 Audit Log
Immutable compliance log for sensitive operations.
**Collection:** `audit_events`

**Fields:**

```
auditId: string
orgId: string
actor: { actorType, actorId }
action: string
entityType: string
entityId: string
matterId?: string
timestamp: timestamp
ip?: string
userAgent?: string
metadata: object (minimal, no sensitive payload)
hash?: string (optional future hardening)
```

**Guideline:**
- Audit events must not be editable by standard application flows.
- Only append.

---

## 6. Permission Hooks (Inheritance Rules)
New modules must inherit matter-level permissions.

### 6.1 Notification Visibility
A user can receive a notification only if:
- They have permission to view the underlying entity in the event
- The event visibility audience and role rules allow it

### 6.2 Comments, Client Portal, Activity Feed
- All must check entity permissions first
- Client portal is a distinct permission domain (future)
- For v2.0, define placeholder roles: `client_user`

---

## 7. Revised Slice Roadmap (Dependencies)
### Platform Slices
- **P1:** Domain Events + Outbox (thin backbone)
- **P2:** Notification Engine (routing, preferences, in-app, email adapter, templates, suppression)
- **P3:** Deliverability + Compliance Hardening (SPF/DKIM/DMARC guidance, bounce/complaint webhooks, suppression sync, unsubscribe handling)

### Feature Slices (after P1 + P2)
- **16:** Comments + Activity Feed (depends on P1, P2)
- **17:** Two-Factor Authentication (independent but required for world-class launch)
- **18:** Online Payments (Stripe) (product-wise depends on P2)
- **19:** Client Portal v1 (depends on P2 + permission hooks)
- **20:** Calendar Sync
- **21:** Global Search
- **22:** Matter Intake Workflow

---

## 8. World-Class Launch Criteria (Go/No-Go)
**Must have:**
- P1 + P2 live with idempotency and visibility
- 2FA enabled for firm accounts
- Activity feed visible for core actions
- Payment collection for invoicing workflow (if monetizing)
- AI differentiators polished and stable

**Deferable:**
- P3 hardening can be post-launch if email volume is low, but suppression basics must exist in P2.
