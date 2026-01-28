# Slice 11: Billing & Invoicing - Build Card

**Status:** ✅ COMPLETE (MVP)  
**Priority:** 🟡 HIGH  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 3 ✅, Slice 4 ✅, Slice 10 ✅

---

## 1) Overview

### 1.1 Purpose
Convert captured time (Slice 10) into client-ready invoices with an auditable workflow and durable exported artifacts (PDF saved into Document Hub).

### 1.2 MVP Scope (this slice)
- Create invoice for a case from **unbilled, billable, stopped** time entries (with date range + selection support).
- Persist invoice + line items in Firestore (org-scoped, case-linked).
- Mark included time entries as billed (link `invoiceId`).
- Invoice list + details (status: DRAFT/SENT/PAID/VOID).
- Record payments (partial/full) and compute balance.
- Export invoice to **PDF** and save to Document Hub (server-side export pattern).

### 1.3 Shipping Notes / Implementation Details
- **Invoice export storage structure (Storage):**
  - Invoice PDFs are stored under a dedicated prefix (grouped by case):
    - `organizations/{orgId}/documents/invoices/{CaseName}__{caseId}/{documentId}/{filename}`
- **Document Hub metadata (for future folder UI):**
  - Exported invoice documents include:
    - `category: "invoice"`
    - `folderPath: "Invoices/<Case Name>"`
  - UI folder rendering is intentionally deferred; Documents page remains a flat list for now.

### 1.4 Explicit Non-Goals (defer)
- Trust/IOLTA accounting and trust ledgers
- Advanced rate rules (per client/matter/user), discounts, taxes, LEDES
- Automated invoice numbering schemes across org (beyond basic)
- Email sending / payment processing integrations

---

## 2) Data Model

### 2.1 Firestore Collections
```
organizations/{orgId}/invoices/{invoiceId}
organizations/{orgId}/invoices/{invoiceId}/lineItems/{lineItemId}
organizations/{orgId}/invoices/{invoiceId}/payments/{paymentId}
```

### 2.2 Invoice (MVP)
```typescript
type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'void';

interface InvoiceDocument {
  invoiceId: string;
  orgId: string;
  caseId: string;
  clientId?: string | null; // optional (derived from case if available)

  status: InvoiceStatus;
  invoiceNumber?: string | null; // optional MVP (can be manually set later)

  currency: string; // e.g. "USD"
  subtotalCents: number;
  paidCents: number;
  totalCents: number; // subtotal for MVP (no tax/discount yet)

  issuedAt: Timestamp;
  dueAt?: Timestamp | null;
  note?: string | null;

  lineItemCount: number;

  createdAt: Timestamp;
  updatedAt: Timestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: Timestamp | null;
}
```

### 2.3 InvoiceLineItem (MVP)
```typescript
interface InvoiceLineItemDocument {
  lineItemId: string;
  orgId: string;
  invoiceId: string;

  description: string;
  timeEntryId?: string | null; // linkage to Slice 10
  startAt?: Timestamp | null;
  endAt?: Timestamp | null;
  durationSeconds?: number | null;

  rateCents: number;   // MVP: provided/defaulted per invoice creation
  amountCents: number; // computed: round(durationSeconds/3600 * rateCents)

  createdAt: Timestamp;
  createdBy: string;
}
```

### 2.4 TimeEntry (Slice 10 extension fields)
```typescript
interface TimeEntryDocument {
  // ... existing Slice 10 fields ...
  invoiceId?: string | null;     // null/unset => unbilled
  invoicedAt?: Timestamp | null; // set when linked to invoice
}
```

---

## 3) Backend (Cloud Functions)

### 3.1 Functions (MVP)
- `invoiceCreate` – create invoice for a case from unbilled time entries (creates line items + links time entries)
- `invoiceGet` – get invoice + line items + payment summary
- `invoiceList` – list invoices (filters: caseId, status)
- `invoiceUpdate` – update invoice status (draft/sent/void), dueAt, note (MVP)
- `invoiceRecordPayment` – record payment + update paid/paid status
- `invoiceExport` – export invoice as PDF and save as Document Hub document

### 3.2 Security & Access Control
- All calls require `orgId`
- All invoice operations require:
  - Plan feature: `BILLING_INVOICING` (ADMIN bypass currently applies per `checkEntitlement`)
  - Permission: `billing.manage` (MVP: ADMIN-only)
- Invoices are **case-linked**; access requires `canUserAccessCase(orgId, caseId, uid)`
- Exports require **EXPORTS** + `document.create` (same pattern as Slice 9 draft export)

---

## 4) Frontend (Flutter)

### 4.1 Models
- `InvoiceModel`, `InvoiceLineItemModel`, `InvoicePaymentModel`

### 4.2 Service
- `InvoiceService` (Cloud Functions wrapper)

### 4.3 Provider
- `InvoiceProvider` (list/get/create/export/payment)

### 4.4 UI (MVP)
- Add **Billing** tab (Invoice list)
- Create invoice flow:
  - Select case
  - Select date range
  - Default rate + currency (MVP)
  - Review entries/line items
  - Create invoice
- Invoice details:
  - Status + totals
  - Record payment
  - Export PDF

---

## 5) Testing Checklist (Manual)

### Backend
- [ ] Create invoice from case time entries (unbilled only)
- [ ] Creating invoice marks time entries with `invoiceId`
- [ ] Viewer cannot create invoices (permission denied)
- [ ] Case access enforced: cannot invoice a case you can’t access
- [ ] Record payment updates `paidCents` and status
- [ ] Export creates a Document Hub record + uploads PDF

**Terminal test (recommended):**
```bash
cd functions
$env:FIREBASE_API_KEY="AIza...."
$env:GCLOUD_PROJECT="legal-ai-app-1203e"
$env:FUNCTION_REGION="us-central1"
npm run test:slice11
```

### Frontend
- [ ] Billing tab loads invoices
- [ ] Create invoice flow works end-to-end
- [ ] Invoice export returns a saved Document that appears in Document Hub

---

**Created:** 2026-01-28  
**Last Updated:** 2026-01-28  

