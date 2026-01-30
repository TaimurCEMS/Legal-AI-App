# SLICE_P2_BUILD_CARD.md
## Slice: P2 Notification Engine (Routing + Preferences + In-App + Email + Templates + Suppression)

### Objective
Deliver a complete, shippable notification system:
- Event => notification routing
- User preferences respected
- In-app bell notifications
- Email notifications via SendGrid adapter
- Template versioning
- Basic suppression to avoid sending to known bad addresses

### Depends On
- P1 Domain Events + Outbox

---

## In Scope
1) Notification routing rules for the minimum event set (P1)
2) Preferences model per user per org
3) In-app notification store and read/unread mechanics
4) Email adapter abstraction + SendGrid provider implementation
5) Template storage + versioning + variable validation
6) Suppression list and suppression-aware sending
7) Write notification records with status

## Out of Scope
- Bounce/complaint webhook ingestion (P3)
- Unsubscribe link handling beyond basic architecture placeholder (P3)
- Digest emails (optional, can be later)

---

## Data Model
### Collections
- notifications
- notification_preferences
- notification_templates
- suppression_list

### suppression_list schema

```
orgId: string
email: string
reason: "bounce" | "complaint" | "manual"
provider?: "sendgrid"
createdAt: timestamp
updatedAt: timestamp
```

---

## Routing Design
### Inputs
- domain_event from P1

### Routing Steps
1) Determine candidate recipients:
   - assigned users, matter participants, firm admins, etc (event-specific)
2) Check permissions:
   - recipient must have permission to view entity referenced by event
3) Apply preferences:
   - category + channel toggles
   - quiet hours (optional v1)
4) Create notification record per recipient per channel
5) Create outbox jobs for email channel dispatch

### Categories mapping
- matter => matter.created/updated
- task => task.assigned/completed
- document => document.uploaded
- invoice => invoice.created/sent
- payment => payment.received/failed
- comment => comment.added (Slice 16 later)

---

## Email Provider Abstraction
### Interface
```
EmailProvider.send({
  to,
  subject,
  html,
  text?,
  headers?,
  idempotencyKey
})
```

### Implementation
- SendGrid adapter initially
- Later SES adapter drops in behind same interface

### Required safety
- Before send, check suppression_list for recipient email
  - If suppressed: mark notification status=suppressed, do not enqueue send

---

## Template System
### Rules
- Each template has versions
- The notification record stores templateId + templateVersion
- Variables must be validated at render time
- Rendering must not crash the worker; failures go to failed with error message

### Minimum templates
- user.invited
- matter.created
- task.assigned
- document.uploaded
- invoice.sent
- payment.received (if payments later, keep template reserved)

---

## In-App Notification UI Contract
### Queries
- Get unread notifications for current user (org scoped)
- Mark as read
- Optional: mark all read

### Required fields for UI
- title, bodyPreview, createdAt, deepLink (entity route)
- read/unread state

---

## Outbox Integration (Email Dispatch)
Email dispatch uses P1 outbox jobType=notification_dispatch.

Job payload resolution:
- outbox references eventId and recipient
- worker loads notification record by eventId + recipient + channel=email

Worker behavior:
- render template
- send email via provider
- update notification status sent/failed and outbox status sent/failed

Idempotency:
- use outbox id as provider idempotencyKey header if supported
- always treat outbox doc as single source of truth

---

## Security and Permissions
- notifications: recipient can read their own only
- preferences: user can read/write their own only
- templates: admin can manage
- suppression_list: admin can view/manage, system can write

---

## Acceptance Criteria
- Event triggers create in-app notifications for correct recipients
- Preferences disable channels properly
- Email notifications send through SendGrid adapter
- Suppressed emails never send, status becomes suppressed
- In-app bell shows unread count and list
- Mark read works reliably
- Failures are visible with status and error

---

## Test Plan
- Unit: routing recipient selection per eventType
- Unit: preference evaluation
- Unit: template render variable validation
- Integration: outbox email dispatch success path
- Integration: suppression path
- Integration: forced provider failure, confirm retry and no duplicates
