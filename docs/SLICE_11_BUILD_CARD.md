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

## 2) Scope In ✅

### Backend (Cloud Functions)
- `invoiceCreate` – Create invoice from unbilled billable time entries (case-scoped; date range or explicit timeEntryIds; rateCents, currency, dueAt, note)
- `invoiceGet` – Get invoice + line items + payments
- `invoiceList` – List invoices (filters: caseId, status); pagination (limit, offset)
- `invoiceUpdate` – Update status (draft/sent/void), dueAt, note
- `invoiceRecordPayment` – Record payment (amountCents, paidAt, note); update paidCents and status (paid when full)
- `invoiceExport` – Export invoice to PDF, upload to Storage, create Document Hub document (category invoice, folderPath)
- Entitlement: BILLING_INVOICING; permission: billing.manage (MVP ADMIN); case access enforced; export requires EXPORTS + document.create

### Frontend (Flutter)
- Billing tab: invoice list; create flow (case, date range, rate, review entries, create); invoice details (status, record payment, export PDF)

### Data Model
- `organizations/{orgId}/invoices/{invoiceId}`, `invoices/{invoiceId}/lineItems/{lineItemId}`, `invoices/{invoiceId}/payments/{paymentId}`; TimeEntry extended with invoiceId, invoicedAt

---

## 3) Scope Out ❌

- Trust/IOLTA accounting, trust ledgers; advanced rate rules (per client/matter/user), discounts, taxes, LEDES; automated invoice numbering; email sending; payment processing integrations

---

## 4) Dependencies

**External Services:** Firebase Auth, Firestore, Cloud Functions, Cloud Storage (Slice 0).

**Dependencies on Other Slices:** Slice 0 (org, entitlements), Slice 1 (Flutter UI), Slice 2 (cases), Slice 3 (clients – optional), Slice 4 (Document Hub for export), Slice 10 (time entries).

**No Dependencies on:** Slice 5 (Tasks), Slice 6–9 (AI, Calendar, Notes, Drafting).

---

## 5) Backend Endpoints (Slice 4 style)

### 5.1 `invoiceCreate` (Callable Function)

**Function Name (Export):** `invoiceCreate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `BILLING_INVOICING`  
**Required Permission:** `billing.manage`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "from": "string (optional, ISO date/time)",
  "to": "string (optional, ISO date/time)",
  "timeEntryIds": "string[] (optional – if provided, use these entries; else use case + date range)",
  "rateCents": "number (required, positive integer)",
  "currency": "string (required, 3-letter e.g. USD)",
  "dueAt": "string (optional, ISO timestamp)",
  "note": "string (optional, max 4000)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "invoiceId": "string",
    "caseId": "string",
    "status": "draft",
    "invoiceNumber": "string",
    "currency": "string",
    "subtotalCents": "number",
    "paidCents": 0,
    "totalCents": "number",
    "lineItemCount": "number",
    "issuedAt": "ISO 8601",
    "dueAt": "ISO 8601 | null",
    "note": "string | null"
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (caseId, rateCents, currency, from/to, dueAt, note; no unbilled entries; too many entries), `NOT_AUTHORIZED`, `PLAN_LIMIT`, `NOT_FOUND` (case), `INTERNAL_ERROR` (index required).

**Implementation Flow:** Validate auth, orgId, caseId, rateCents, currency → entitlement → case access → resolve entries (timeEntryIds or query by case+from/to); filter billable, stopped, unbilled → create invoice doc, line items, update time entries (invoiceId, invoicedAt) in batch → return invoice.

---

### 5.2 `invoiceGet` (Callable Function)

**Function Name (Export):** `invoiceGet`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `billing.manage`

**Request Payload:** `{ "orgId": "string (required)", "invoiceId": "string (required)" }`

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "invoice": { "invoiceId", "orgId", "caseId", "status", "invoiceNumber", "currency", "subtotalCents", "paidCents", "totalCents", "issuedAt", "dueAt", "note", "lineItemCount", "createdAt", "updatedAt", "createdBy", "updatedBy", "lineItems": [ { "lineItemId", "description", "timeEntryId", "startAt", "endAt", "durationSeconds", "rateCents", "amountCents" } ], "payments": [ { "paymentId", "amountCents", "paidAt", "note", "createdAt", "createdBy" } ] }
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invoiceId), `NOT_AUTHORIZED`, `NOT_FOUND` (invoice or case access).

**Implementation Flow:** Validate → entitlement → load invoice → case access → load lineItems and payments subcollections → return invoice + lineItems + payments.

---

### 5.3 `invoiceList` (Callable Function)

**Function Name (Export):** `invoiceList`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `billing.manage`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional)",
  "status": "string (optional, draft | sent | paid | void)",
  "limit": "number (optional, default 50, max 100)",
  "offset": "number (optional, default 0)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "invoices": [ { "invoiceId", "orgId", "caseId", "status", "invoiceNumber", "currency", "subtotalCents", "paidCents", "totalCents", "issuedAt", "dueAt", "lineItemCount" } ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invalid caseId/status), `NOT_AUTHORIZED`, `NOT_FOUND` (case if caseId provided), `INTERNAL_ERROR` (index).

**Implementation Flow:** Validate → entitlement → query invoices (optional caseId filter); filter by case access; filter by status → paginate → return.

---

### 5.4 `invoiceUpdate` (Callable Function)

**Function Name (Export):** `invoiceUpdate`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `billing.manage`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "invoiceId": "string (required)",
  "status": "string (optional, draft | sent | void – paid cannot be changed)",
  "dueAt": "string | null (optional)",
  "note": "string | null (optional)"
}
```

**Success Response (200):** `data.invoice` (updated invoice fields).

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invoiceId, invalid status, paid→other status), `NOT_AUTHORIZED`, `NOT_FOUND`.

**Implementation Flow:** Validate → load invoice → case access → apply updates (status draft/sent/void only; paid immutable) → audit invoice.updated → return updated invoice.

---

### 5.5 `invoiceRecordPayment` (Callable Function)

**Function Name (Export):** `invoiceRecordPayment`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `billing.manage`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "invoiceId": "string (required)",
  "amountCents": "number (required, positive integer)",
  "paidAt": "string (optional, ISO timestamp)",
  "note": "string (optional)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "payment": { "paymentId", "amountCents" },
    "invoice": { "invoiceId", "status", "paidCents", "totalCents" }
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invoiceId, amountCents, paidAt, note; void invoice), `NOT_AUTHORIZED`, `NOT_FOUND`.

**Implementation Flow:** Validate → load invoice → case access; if status void return VALIDATION_ERROR → transaction: create payment doc, update invoice paidCents (min(totalCents, paidCents+amount)), status (paid if full) → audit invoice.payment_recorded → return payment + invoice summary.

---

### 5.6 `invoiceExport` (Callable Function)

**Function Name (Export):** `invoiceExport`  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `BILLING_INVOICING` + `EXPORTS`  
**Required Permission:** `billing.manage` + `document.create`

**Request Payload:** `{ "orgId": "string (required)", "invoiceId": "string (required)" }`

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "documentId": "string",
    "name": "string",
    "storagePath": "string",
    "fileType": "application/pdf"
  }
}
```

**Error Responses:** `ORG_REQUIRED`, `VALIDATION_ERROR` (invoiceId), `NOT_AUTHORIZED`, `NOT_FOUND` (invoice or case access), `PLAN_LIMIT` (EXPORTS).

**Implementation Flow:** Validate → load invoice → case access → check EXPORTS + document.create → generate PDF (invoice + line items + payments) → upload to Storage `organizations/{orgId}/documents/invoices/{CaseName}__{caseId}/{documentId}/{filename}` → create Document Hub document (category invoice, folderPath Invoices/<Case Name>) → return document info.

---

## 6) Data Model

### 6.1 Firestore Collections
```
organizations/{orgId}/invoices/{invoiceId}
organizations/{orgId}/invoices/{invoiceId}/lineItems/{lineItemId}
organizations/{orgId}/invoices/{invoiceId}/payments/{paymentId}
```

### 6.2 Invoice (MVP)
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

### 6.3 InvoiceLineItem (MVP)
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

### 6.4 TimeEntry (Slice 10 extension fields)
```typescript
interface TimeEntryDocument {
  // ... existing Slice 10 fields ...
  invoiceId?: string | null;     // null/unset => unbilled
  invoicedAt?: Timestamp | null; // set when linked to invoice
}
```

---

## 7) Backend Summary (see 5) for Slice 4 style)

### 7.1 Functions (MVP)
- `invoiceCreate` – create invoice for a case from unbilled time entries (creates line items + links time entries)
- `invoiceGet` – get invoice + line items + payment summary
- `invoiceList` – list invoices (filters: caseId, status)
- `invoiceUpdate` – update invoice status (draft/sent/void), dueAt, note (MVP)
- `invoiceRecordPayment` – record payment + update paid/paid status
- `invoiceExport` – export invoice as PDF and save as Document Hub document

### 7.2 Security & Access Control
- All calls require `orgId`
- All invoice operations require:
  - Plan feature: `BILLING_INVOICING` (ADMIN bypass currently applies per `checkEntitlement`)
  - Permission: `billing.manage` (MVP: ADMIN-only)
- Invoices are **case-linked**; access requires `canUserAccessCase(orgId, caseId, uid)`
- Exports require **EXPORTS** + `document.create` (same pattern as Slice 9 draft export)

---

## 8) Frontend (Flutter)

### 8.1 Models
- `InvoiceModel`, `InvoiceLineItemModel`, `InvoicePaymentModel`

### 8.2 Service
- `InvoiceService` (Cloud Functions wrapper)

### 8.3 Provider
- `InvoiceProvider` (list/get/create/export/payment)

### 8.4 UI (MVP)
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

## 9) Testing Checklist (Manual)

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

