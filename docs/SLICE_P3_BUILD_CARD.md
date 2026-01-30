# SLICE_P3_BUILD_CARD.md
## Slice: P3 Deliverability & Compliance Hardening (SPF/DKIM/DMARC + Bounces + Complaints + Suppression + Unsubscribe)

### Objective
Harden email operations so you:
- stay out of spam
- protect sender reputation
- comply with unsubscribe and complaint handling expectations
- automate suppression updates from provider signals

### Depends On
- P2 Notification Engine

---

## In Scope
1) Domain setup guidance and checklist:
   - SPF
   - DKIM
   - DMARC policy recommendation (start p=none, then tighten)
2) SendGrid event webhook ingestion (or SES later):
   - bounces
   - spam complaints
   - invalid email
3) Automatic suppression list updates
4) Unsubscribe architecture:
   - basic tokenized unsubscribe endpoint for non-critical notification categories
   - category-based unsubscribe (do not allow unsubscribe from strictly transactional if required)
5) Monitoring:
   - dashboard queries for bounce rate and complaint rate
   - alert thresholds (manual initially)

## Out of Scope
- Full marketing email compliance suite
- Advanced deliverability analytics

---

## Webhook Processing
### Endpoint
- Cloud Function HTTPS endpoint: /email/events

### Security
- Validate provider signature if available
- Rate limit basic protections
- Store raw event batch in `email_provider_events_raw` for audit/debug

### Normalized processing
For each event:
- identify orgId if encoded in custom args
- update suppression_list if bounce or complaint
- update corresponding notification record status if applicable

---

## Suppression Rules
- Bounce => suppress immediately
- Complaint => suppress immediately
- Manual admin suppress remains supported
- Provide admin unsuppress workflow (optional)

---

## Unsubscribe Rules (v1 hardening)
- Only applies to non-critical categories (configurable)
- Store per-user unsubscribe preferences linked to notification_preferences
- Always respect unsubscribe for email channel

---

## Acceptance Criteria
- SPF/DKIM/DMARC checklist documented and applied for sending domain
- Bounce events result in suppression_list entries automatically
- Complaint events result in suppression_list entries automatically
- Subsequent sends to suppressed emails are blocked by P2 logic
- Unsubscribe endpoint updates preferences and prevents further emails in allowed categories
- Raw webhook events are persisted for debugging

---

## Test Plan
- Integration: send simulated bounce webhook, confirm suppression
- Integration: subsequent notification attempts mark suppressed and do not send
- Integration: unsubscribe flow updates preferences
