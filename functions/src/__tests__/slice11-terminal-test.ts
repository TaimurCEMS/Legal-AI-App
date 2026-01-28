/**
 * Terminal Test Script for Slice 11 Billing & Invoicing Functions
 * Tests deployed Cloud Functions against real Firebase project
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."              # Web API key
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"      # optional
 *   $env:FUNCTION_REGION="us-central1"            # optional
 *   npm run build
 *   node lib/__tests__/slice11-terminal-test.js
 */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as https from 'https';

const apiKey = process.env.FIREBASE_API_KEY;
if (!apiKey) {
  console.error('❌ ERROR: FIREBASE_API_KEY env var is required.');
  process.exit(1);
}

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'legal-ai-app-1203e';
const region = process.env.FUNCTION_REGION || 'us-central1';

type TestResult = { name: string; passed: boolean; error?: string; data?: any };
const results: TestResult[] = [];

function ok(name: string, data?: any) {
  results.push({ name, passed: true, data });
  console.log(`✅ ${name}`);
}

function fail(name: string, error: string, data?: any) {
  results.push({ name, passed: false, error, data });
  console.log(`❌ ${name}: ${error}`);
}

function httpsJsonRequest<T>(options: https.RequestOptions, body: any): Promise<T> {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(body ?? {});
    const req = https.request(
      {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
          ...(options.headers ?? {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            if ((res.statusCode ?? 0) >= 200 && (res.statusCode ?? 0) < 300) {
              resolve(parsed as T);
            } else {
              reject(new Error(`HTTP ${res.statusCode}: ${data}`));
            }
          } catch {
            reject(new Error(`Failed to parse JSON: HTTP ${res.statusCode} - ${data}`));
          }
        });
      }
    );
    req.on('error', (e) => reject(e));
    req.write(postData);
    req.end();
  });
}

async function signUpUser(email: string, password: string): Promise<{ idToken: string; uid: string }> {
  const res = await httpsJsonRequest<{ idToken: string; localId: string }>(
    {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signUp?key=${apiKey}`,
      method: 'POST',
    },
    { email, password, returnSecureToken: true }
  );
  return { idToken: res.idToken, uid: res.localId };
}

async function callCallableFunction(functionName: string, data: any, idToken: string): Promise<any> {
  const hostname = `${region}-${projectId}.cloudfunctions.net`;
  const path = `/${functionName}`;
  return await httpsJsonRequest<any>(
    {
      hostname,
      path,
      method: 'POST',
      headers: {
        Authorization: `Bearer ${idToken}`,
      },
    },
    { data }
  ).then((raw) => raw.result ?? raw);
}

async function run() {
  console.log('🧪 Slice 11 backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!'; // only used for this test user
  const adminEmail = `test-slice11-admin-${runId}@legal-ai-test.com`;
  const userEmail = `test-slice11-user-${runId}@legal-ai-test.com`;

  // Create two users (admin will create org, user will join)
  const adminUser = await signUpUser(adminEmail, password);
  ok('Auth - created admin user', { email: adminEmail, uid: adminUser.uid });

  const user = await signUpUser(userEmail, password);
  ok('Auth - created user', { email: userEmail, uid: user.uid });

  // Org create (admin becomes ADMIN)
  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Slice 11 (${runId})`, description: 'Automated backend verification for Slice 11' },
    adminUser.idToken
  );
  if (orgCreate?.success !== true || !orgCreate?.data?.orgId) {
    fail('orgCreate - create org', 'Unexpected response', orgCreate);
    return;
  }
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  // User joins org (VIEWER)
  const join = await callCallableFunction('orgJoin', { orgId }, user.idToken);
  if (join?.success !== true) {
    fail('orgJoin - user joins org', 'Unexpected response', join);
    return;
  }
  ok('orgJoin - user joined org', join.data);

  // Create client
  const clientCreate = await callCallableFunction('clientCreate', { orgId, name: 'Test Client (Slice 11)' }, adminUser.idToken);
  if (clientCreate?.success !== true || !clientCreate?.data?.clientId) {
    fail('clientCreate - create client', 'Unexpected response', clientCreate);
    return;
  }
  const clientId = clientCreate.data.clientId as string;
  ok('clientCreate - created client', { clientId });

  // Create ORG_WIDE case
  const caseOrgWide = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Billing Case (ORG_WIDE)', visibility: 'ORG_WIDE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  if (caseOrgWide?.success !== true || !caseOrgWide?.data?.caseId) {
    fail('caseCreate - create ORG_WIDE case', 'Unexpected response', caseOrgWide);
    return;
  }
  const caseId = caseOrgWide.data.caseId as string;
  ok('caseCreate - created ORG_WIDE case', { caseId });

  // Create PRIVATE case (only accessible to creator)
  const casePrivate = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Billing Case (PRIVATE)', visibility: 'PRIVATE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  if (casePrivate?.success !== true || !casePrivate?.data?.caseId) {
    fail('caseCreate - create PRIVATE case', 'Unexpected response', casePrivate);
    return;
  }
  const privateCaseId = casePrivate.data.caseId as string;
  ok('caseCreate - created PRIVATE case', { privateCaseId });

  // Create a couple of billable stopped time entries (manual)
  const endAt1 = new Date();
  const startAt1 = new Date(endAt1.getTime() - 30 * 60 * 1000);
  const entry1 = await callCallableFunction(
    'timeEntryCreate',
    {
      orgId,
      caseId,
      clientId,
      description: 'Billing test - research',
      billable: true,
      startAt: startAt1.toISOString(),
      endAt: endAt1.toISOString(),
    },
    adminUser.idToken
  );
  if (entry1?.success !== true || !entry1?.data?.timeEntry?.timeEntryId) {
    fail('timeEntryCreate - create entry 1', 'Unexpected response', entry1);
    return;
  }
  const timeEntryId1 = entry1.data.timeEntry.timeEntryId as string;
  ok('timeEntryCreate - created entry 1', { timeEntryId1 });

  const endAt2 = new Date();
  const startAt2 = new Date(endAt2.getTime() - 45 * 60 * 1000);
  const entry2 = await callCallableFunction(
    'timeEntryCreate',
    {
      orgId,
      caseId,
      clientId,
      description: 'Billing test - drafting',
      billable: true,
      startAt: startAt2.toISOString(),
      endAt: endAt2.toISOString(),
    },
    adminUser.idToken
  );
  if (entry2?.success !== true || !entry2?.data?.timeEntry?.timeEntryId) {
    fail('timeEntryCreate - create entry 2', 'Unexpected response', entry2);
    return;
  }
  const timeEntryId2 = entry2.data.timeEntry.timeEntryId as string;
  ok('timeEntryCreate - created entry 2', { timeEntryId2 });

  // Permissions: VIEWER should be blocked from billing.manage
  const viewerList = await callCallableFunction('invoiceList', { orgId, limit: 10, offset: 0 }, user.idToken);
  if (viewerList?.success === false && viewerList?.error?.code === 'NOT_AUTHORIZED') {
    ok('Permissions - viewer cannot list invoices', viewerList.error);
  } else {
    fail('Permissions - viewer cannot list invoices', 'Expected NOT_AUTHORIZED', viewerList);
  }

  // Create invoice (admin)
  const rangeFrom = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const rangeTo = new Date(Date.now() + 1 * 24 * 60 * 60 * 1000);
  const createInvoice = await callCallableFunction(
    'invoiceCreate',
    {
      orgId,
      caseId,
      from: rangeFrom.toISOString(),
      to: rangeTo.toISOString(),
      rateCents: 25000, // $250/hr
      currency: 'USD',
      note: 'Automated test invoice',
    },
    adminUser.idToken
  );
  if (createInvoice?.success !== true || !createInvoice?.data?.invoice?.invoiceId) {
    fail('invoiceCreate - creates invoice', 'Unexpected response', createInvoice);
    return;
  }
  const invoiceId = createInvoice.data.invoice.invoiceId as string;
  const totalCents = createInvoice.data.invoice.totalCents as number;
  ok('invoiceCreate - created invoice', { invoiceId, totalCents });

  // Creating invoice again with same range should find nothing unbilled
  const createInvoiceAgain = await callCallableFunction(
    'invoiceCreate',
    {
      orgId,
      caseId,
      from: rangeFrom.toISOString(),
      to: rangeTo.toISOString(),
      rateCents: 25000,
      currency: 'USD',
    },
    adminUser.idToken
  );
  if (createInvoiceAgain?.success === false && createInvoiceAgain?.error?.code === 'VALIDATION_ERROR') {
    ok('invoiceCreate - prevents rebilling already invoiced entries', createInvoiceAgain.error);
  } else {
    fail('invoiceCreate - prevents rebilling already invoiced entries', 'Expected VALIDATION_ERROR', createInvoiceAgain);
  }

  // List invoices (admin)
  const listInvoices = await callCallableFunction('invoiceList', { orgId, limit: 50, offset: 0 }, adminUser.idToken);
  const ids = (listInvoices?.data?.invoices ?? []).map((i: any) => i.invoiceId);
  if (listInvoices?.success === true && ids.includes(invoiceId)) {
    ok('invoiceList - returns created invoice', { total: listInvoices.data.total, invoiceIds: ids.slice(0, 5) });
  } else {
    fail('invoiceList - returns created invoice', 'Invoice missing from list', listInvoices);
  }

  // Get invoice details
  const getInvoice = await callCallableFunction('invoiceGet', { orgId, invoiceId }, adminUser.idToken);
  if (
    getInvoice?.success === true &&
    getInvoice?.data?.invoice?.invoiceId === invoiceId &&
    Array.isArray(getInvoice?.data?.invoice?.lineItems) &&
    getInvoice.data.invoice.lineItems.length >= 1
  ) {
    ok('invoiceGet - returns invoice details + line items', {
      lineItemCount: getInvoice.data.invoice.lineItems.length,
    });
  } else {
    fail('invoiceGet - returns invoice details + line items', 'Unexpected response', getInvoice);
  }

  // Record partial payment
  const part = Math.max(1, Math.floor(totalCents / 2));
  const pay1 = await callCallableFunction(
    'invoiceRecordPayment',
    { orgId, invoiceId, amountCents: part, note: 'Partial payment (test)' },
    adminUser.idToken
  );
  if (pay1?.success === true && pay1?.data?.invoice?.paidCents >= part) {
    ok('invoiceRecordPayment - records partial payment', pay1.data.invoice);
  } else {
    fail('invoiceRecordPayment - records partial payment', 'Unexpected response', pay1);
  }

  // Record remaining payment (should become paid)
  const remaining = Math.max(1, totalCents - part);
  const pay2 = await callCallableFunction(
    'invoiceRecordPayment',
    { orgId, invoiceId, amountCents: remaining, note: 'Final payment (test)' },
    adminUser.idToken
  );
  if (pay2?.success === true && pay2?.data?.invoice?.status === 'paid') {
    ok('invoiceRecordPayment - records final payment and marks paid', pay2.data.invoice);
  } else {
    fail('invoiceRecordPayment - records final payment and marks paid', 'Expected status=paid', pay2);
  }

  // Export invoice to PDF (creates Document Hub record)
  const exp = await callCallableFunction('invoiceExport', { orgId, invoiceId }, adminUser.idToken);
  if (exp?.success === true && exp?.data?.documentId && exp?.data?.storagePath) {
    const sp = exp.data.storagePath as string;
    const expectedPrefix = `organizations/${orgId}/documents/invoices/`;
    if (typeof sp === 'string' && sp.startsWith(expectedPrefix) && sp.includes(`__${caseId}/`)) {
      ok('invoiceExport - creates Document Hub PDF', exp.data);
    } else {
      fail('invoiceExport - creates Document Hub PDF', `Unexpected storagePath (expected under ${expectedPrefix}.../${caseId})`, exp.data);
    }
  } else {
    fail('invoiceExport - creates Document Hub PDF', 'Unexpected response', exp);
  }

  // Promote user to ADMIN, then try to invoice PRIVATE case -> should still be NOT_FOUND (case hidden)
  const promote = await callCallableFunction(
    'memberUpdateRole',
    { orgId, memberUid: user.uid, role: 'ADMIN' },
    adminUser.idToken
  );
  if (promote?.success !== true) {
    fail('memberUpdateRole - promote user to ADMIN', 'Unexpected response', promote);
    return;
  }
  ok('memberUpdateRole - user promoted to ADMIN', promote.data);

  const userInvoicePrivate = await callCallableFunction(
    'invoiceCreate',
    {
      orgId,
      caseId: privateCaseId,
      from: rangeFrom.toISOString(),
      to: rangeTo.toISOString(),
      rateCents: 25000,
      currency: 'USD',
    },
    user.idToken
  );
  if (userInvoicePrivate?.success === false && userInvoicePrivate?.error?.code === 'NOT_FOUND') {
    ok('Case access - PRIVATE case hidden for invoiceCreate (NOT_FOUND)', userInvoicePrivate.error);
  } else {
    fail('Case access - PRIVATE case hidden for invoiceCreate (NOT_FOUND)', 'Expected NOT_FOUND', userInvoicePrivate);
  }

  // Summary
  const passed = results.filter((r) => r.passed).length;
  const failed = results.length - passed;
  console.log('');
  console.log('📊 Slice 11 backend test summary');
  console.log(`   Passed: ${passed}`);
  console.log(`   Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('❌ Slice 11 backend test fatal error:', (e as Error).message);
  process.exit(1);
});

