# Slice 18 Build Card: Online Payments (Stripe)

**Status:** 🟡 NOT STARTED  
**Priority:** High (product-wise depends on P2 for "invoice created / payment received" notifications)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 10 ✅, Slice 11 ✅, **P2 Notification Engine** (recommended)  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §7, §8

---

## 📋 Overview

Slice 18 adds **online payment collection** for invoices via **Stripe**. Clients can pay invoices through a secure link or portal; payment status updates the invoice and triggers notifications (P2: "payment.received").

**Key Features:**
1. **Stripe integration** – Create payment intents or checkout sessions for an invoice (or invoice line items).
2. **Payment link** – Generate a client-facing link (or embed) to pay an invoice; link is scoped to invoice and optionally time-limited.
3. **Webhook** – Stripe webhook for `payment_intent.succeeded` (or checkout.session.completed); update invoice paid amount, status; emit domain event `payment.received`; P2 sends notification.
4. **Firm settings** – Store Stripe account/link (Connect or direct API key per org); optional Stripe Connect for multi-entity.

**Out of Scope (MVP):**
- Full Stripe Connect onboarding UI (can use Stripe Dashboard for MVP).
- Recurring payments / subscriptions (one-time invoice payment only).
- Refunds via app (manual in Stripe or later slice).

---

## 🎯 Success Criteria

### Backend
- **`paymentCreateLink`** – Create Stripe Checkout Session or PaymentIntent for an invoice; return client URL (or session ID for client-side redirect).
- **`paymentWebhook`** – HTTPS endpoint for Stripe webhooks; verify signature; on success event, update invoice (paid amount, status), emit `payment.received` domain event; idempotent by Stripe event ID.
- **`paymentListByInvoice`** – List payment transactions for an invoice (from Stripe or stored copy) for audit display.
- Entitlement: billing/payment feature flag and permission (e.g. `billing.manage` for creating links; invoice read for client view).

### Frontend
- **Invoice details (firm side):** "Send payment link" button → copy link or open preview; show payment status (paid/partial/unpaid) and last payment date.
- **Client payment page (optional):** Standalone page (or hosted by Stripe Checkout) where client enters card and pays; success/cancel redirect back to firm or thank-you page.
- **Settings:** Stripe API key or Connect account ID configuration (admin only); optional "Test mode" toggle.

### Testing
- Backend: Create link returns valid URL; webhook handler updates invoice and is idempotent.
- E2E: Create invoice → create payment link → complete payment in Stripe test mode → verify invoice updated and notification (if P2) sent.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions)

#### 1. Payment Link Creation
- **`paymentCreateLink`**  
  - **Request:** `{ orgId, invoiceId, successUrl?, cancelUrl?, amountOverride? }` (amountOverride optional for partial payments).  
  - **Flow:** Auth → org membership → `billing.manage` → load invoice → verify not already fully paid → create Stripe Checkout Session (or PaymentIntent) with metadata orgId, invoiceId → return `{ url, sessionId }`.  
  - **Idempotency:** Optional idempotency key per invoice + "create link" to avoid duplicate sessions.

#### 2. Webhook
- **`paymentWebhook`** – HTTPS function; raw body for signature verification.  
  - **Events:** `checkout.session.completed` or `payment_intent.succeeded`.  
  - **Flow:** Verify Stripe-Signature → parse event → if payment success, get metadata (orgId, invoiceId) → load invoice → update paid amount (idempotent by storing processed event IDs) → emit domain event `payment.received` → return 200.  
  - **Security:** Webhook secret in env; reject invalid signature.

#### 3. List Payments
- **`paymentListByInvoice`** – **Request:** `{ orgId, invoiceId }`. **Success:** List of payment records (amount, date, Stripe payment ID, status). Data from Firestore `organizations/{orgId}/invoices/{invoiceId}/payments` or from Stripe API; prefer stored copy for consistency.

### Data Model (extend existing)

- **Invoice:** Already has paid amount and status (Slice 11). Add optional `stripePaymentIntentId` or `stripeSessionId` for link creation tracking.
- **New subcollection or table:** `organizations/{orgId}/invoices/{invoiceId}/payment_transactions/{id}` – store Stripe payment ID, amount, currency, status, createdAt, stripeEventId (for idempotency).

### Stripe Configuration

- **Firm-level:** Store `stripeAccountId` (Connect) or use single Stripe account with metadata orgId. API keys in Cloud Functions env (e.g. STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET).
- **Idempotency:** Store processed webhook event IDs in Firestore to avoid double-applying.

### Frontend (Flutter)

- **Invoice details:** "Create payment link" → call `paymentCreateLink` → show URL + copy button; optional "Open link" for testing.
- **Payment status:** Display "Paid", "Partially paid", "Unpaid" and last payment date; link to list of payment transactions if needed.
- **Settings → Billing:** Stripe connection status; input for webhook URL (for admin reference); test/live mode indicator.

---

## 🔐 Security & Permissions

- Only users with `billing.manage` (and invoice access) can create payment links.
- Webhook must validate Stripe signature; never trust body without verification.
- Client-facing payment link should be signed or single-use so it cannot be reused indefinitely (Stripe Checkout session expiry).

---

## 📝 Backend Endpoints (Summary)

| Function | Request | Success | Errors |
|----------|---------|---------|--------|
| paymentCreateLink | orgId, invoiceId, successUrl?, cancelUrl? | { url, sessionId } | NOT_FOUND, ALREADY_PAID, STRIPE_ERROR |
| paymentWebhook | (raw body + Stripe-Signature header) | 200 | 400 invalid signature |
| paymentListByInvoice | orgId, invoiceId | { payments: [...] } | NOT_FOUND, FORBIDDEN |

---

## 🧪 Testing Strategy

- Unit: Webhook payload parsing and idempotency (replay same event ID).
- Integration: Stripe test mode – create session, complete payment, verify invoice updated.
- P2: After payment, confirm `payment.received` event and notification (if P2 implemented).

---

## 📚 References

- MASTER_SPEC_V2.0.md §2.3 (payment.received event)
- SLICE_11_BUILD_CARD.md (Invoicing)
- Stripe: Checkout Session, PaymentIntent, Webhooks

---

**Last Updated:** 2026-01-30
