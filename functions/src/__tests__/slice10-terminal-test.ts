/**
 * Terminal Test Script for Slice 10 Time Tracking Functions
 * Tests deployed Cloud Functions against real Firebase project
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."   # Web API key
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"  # optional
 *   npm run build
 *   node lib/__tests__/slice10-terminal-test.js
 *
 * Notes:
 * - Does NOT require Firebase Admin credentials.
 * - Creates test users via Identity Toolkit REST API, then calls deployed callable functions via HTTPS.
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
  console.log('🧪 Slice 10 backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!'; // only used for this test user
  const user1Email = `test-slice10-admin-${runId}@legal-ai-test.com`;
  const user2Email = `test-slice10-user-${runId}@legal-ai-test.com`;

  // Create two users (user1 will create org, user2 will join)
  const user1 = await signUpUser(user1Email, password);
  ok('Auth - created user1 (admin)', { email: user1Email, uid: user1.uid });

  const user2 = await signUpUser(user2Email, password);
  ok('Auth - created user2', { email: user2Email, uid: user2.uid });

  // Org create (user1 becomes ADMIN)
  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Slice 10 (${runId})`, description: 'Automated backend verification for Slice 10' },
    user1.idToken
  );
  if (orgCreate?.success !== true || !orgCreate?.data?.orgId) {
    fail('orgCreate - create org', 'Unexpected response', orgCreate);
    return;
  }
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  // User2 joins org (VIEWER)
  const join = await callCallableFunction('orgJoin', { orgId }, user2.idToken);
  if (join?.success !== true) {
    fail('orgJoin - user2 joins org', 'Unexpected response', join);
    return;
  }
  ok('orgJoin - user2 joined org', join.data);

  // Promote user2 to ADMIN so they bypass TIME_TRACKING plan gate on FREE,
  // but should still be blocked from PRIVATE cases they can't access.
  const promote = await callCallableFunction(
    'memberUpdateRole',
    { orgId, memberUid: user2.uid, role: 'ADMIN' },
    user1.idToken
  );
  if (promote?.success !== true) {
    fail('memberUpdateRole - promote user2 to ADMIN', 'Unexpected response', promote);
    return;
  }
  ok('memberUpdateRole - user2 promoted to ADMIN', promote.data);

  // Create client
  const clientCreate = await callCallableFunction(
    'clientCreate',
    { orgId, name: 'Test Client (Slice 10)' },
    user1.idToken
  );
  if (clientCreate?.success !== true || !clientCreate?.data?.clientId) {
    fail('clientCreate - create client', 'Unexpected response', clientCreate);
    return;
  }
  const clientId = clientCreate.data.clientId as string;
  ok('clientCreate - created client', { clientId });

  // Create ORG_WIDE case (accessible to both users)
  const caseOrgWide = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Time Tracking Case (ORG_WIDE)', visibility: 'ORG_WIDE', status: 'OPEN', clientId },
    user1.idToken
  );
  if (caseOrgWide?.success !== true || !caseOrgWide?.data?.caseId) {
    fail('caseCreate - create ORG_WIDE case', 'Unexpected response', caseOrgWide);
    return;
  }
  const caseId = caseOrgWide.data.caseId as string;
  ok('caseCreate - created ORG_WIDE case', { caseId });

  // Create PRIVATE case (only accessible to creator user1)
  const casePrivate = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Time Tracking Case (PRIVATE)', visibility: 'PRIVATE', status: 'OPEN', clientId },
    user1.idToken
  );
  if (casePrivate?.success !== true || !casePrivate?.data?.caseId) {
    fail('caseCreate - create PRIVATE case', 'Unexpected response', casePrivate);
    return;
  }
  const privateCaseId = casePrivate.data.caseId as string;
  ok('caseCreate - created PRIVATE case', { privateCaseId });

  // 1) Start timer as user1 (success)
  const start1 = await callCallableFunction(
    'timeEntryStartTimer',
    { orgId, caseId, clientId, description: 'Timer test - drafting', billable: true },
    user1.idToken
  );
  if (start1?.success === true && start1?.data?.timeEntry?.timeEntryId && start1?.data?.timeEntry?.status === 'running') {
    ok('timeEntryStartTimer - starts running timer (user1)', start1.data.timeEntry);
  } else {
    fail('timeEntryStartTimer - starts running timer (user1)', 'Unexpected response', start1);
    return;
  }
  const runningId = start1.data.timeEntry.timeEntryId as string;

  // 2) Start timer again as user1 (blocked)
  const start2 = await callCallableFunction(
    'timeEntryStartTimer',
    { orgId, caseId, description: 'Should fail - second timer', billable: true },
    user1.idToken
  );
  if (start2?.success === false && start2?.error?.code === 'VALIDATION_ERROR') {
    ok('timeEntryStartTimer - blocks second running timer (user1)', start2.error);
  } else {
    fail('timeEntryStartTimer - blocks second running timer (user1)', 'Expected VALIDATION_ERROR', start2);
  }

  // 3) List running timers for user1
  const listRunning = await callCallableFunction(
    'timeEntryList',
    { orgId, userId: user1.uid, status: 'running', limit: 10, offset: 0 },
    user1.idToken
  );
  const runningIds = (listRunning?.data?.timeEntries ?? []).map((e: any) => e.timeEntryId);
  if (listRunning?.success === true && runningIds.includes(runningId)) {
    ok('timeEntryList - returns running timer for user1', { total: listRunning.data.total, runningIds });
  } else {
    fail('timeEntryList - returns running timer for user1', 'Running entry missing', listRunning);
  }

  // 4) Stop timer as user1
  const stop1 = await callCallableFunction('timeEntryStopTimer', { orgId }, user1.idToken);
  if (stop1?.success === true && stop1?.data?.timeEntry?.status === 'stopped' && typeof stop1?.data?.timeEntry?.durationSeconds === 'number') {
    ok('timeEntryStopTimer - stops timer and computes duration (user1)', stop1.data.timeEntry);
  } else {
    fail('timeEntryStopTimer - stops timer and computes duration (user1)', 'Unexpected response', stop1);
  }

  // 5) Start timer again after stop (lock released)
  const start3 = await callCallableFunction(
    'timeEntryStartTimer',
    { orgId, caseId, description: 'Timer test - second run', billable: false },
    user1.idToken
  );
  if (start3?.success === true && start3?.data?.timeEntry?.status === 'running') {
    ok('timeEntryStartTimer - succeeds after stop (lock released)', start3.data.timeEntry);
  } else {
    fail('timeEntryStartTimer - succeeds after stop (lock released)', 'Unexpected response', start3);
  }
  await callCallableFunction('timeEntryStopTimer', { orgId }, user1.idToken);

  // 6) Manual entry (user1)
  const endAt = new Date();
  const startAt = new Date(endAt.getTime() - 15 * 60 * 1000);
  const manual = await callCallableFunction(
    'timeEntryCreate',
    {
      orgId,
      caseId,
      clientId,
      description: 'Manual test - client call',
      billable: true,
      startAt: startAt.toISOString(),
      endAt: endAt.toISOString(),
    },
    user1.idToken
  );
  if (manual?.success === true && manual?.data?.timeEntry?.timeEntryId && manual?.data?.timeEntry?.status === 'stopped') {
    ok('timeEntryCreate - creates manual entry (user1)', manual.data.timeEntry);
  } else {
    fail('timeEntryCreate - creates manual entry (user1)', 'Unexpected response', manual);
  }
  const manualId = manual?.data?.timeEntry?.timeEntryId as string;

  // 7) Filters (caseId + billable)
  const listFiltered = await callCallableFunction(
    'timeEntryList',
    { orgId, caseId, billable: true, limit: 50, offset: 0 },
    user1.idToken
  );
  const filteredIds = (listFiltered?.data?.timeEntries ?? []).map((e: any) => e.timeEntryId);
  if (listFiltered?.success === true && filteredIds.includes(manualId)) {
    ok('timeEntryList - supports caseId + billable filters', { total: listFiltered.data.total, filteredIds });
  } else {
    fail('timeEntryList - supports caseId + billable filters', 'Expected manual entry in filtered list', listFiltered);
  }

  // 8) Update manual entry
  const updated = await callCallableFunction(
    'timeEntryUpdate',
    { orgId, timeEntryId: manualId, description: 'Updated manual description', billable: false },
    user1.idToken
  );
  if (updated?.success === true && updated?.data?.timeEntry?.description === 'Updated manual description' && updated?.data?.timeEntry?.billable === false) {
    ok('timeEntryUpdate - updates description/billable', updated.data.timeEntry);
  } else {
    fail('timeEntryUpdate - updates description/billable', 'Unexpected response', updated);
  }

  // 9) Case access: user2 tries to start timer on PRIVATE case (should be NOT_FOUND)
  const user2Private = await callCallableFunction(
    'timeEntryStartTimer',
    { orgId, caseId: privateCaseId, description: 'Should not see private case', billable: true },
    user2.idToken
  );
  if (user2Private?.success === false && user2Private?.error?.code === 'NOT_FOUND') {
    ok('Case access - PRIVATE case hidden from user2 (NOT_FOUND)', user2Private.error);
  } else {
    fail('Case access - PRIVATE case hidden from user2 (NOT_FOUND)', 'Expected NOT_FOUND', user2Private);
  }

  // 10) Delete manual entry and ensure excluded from list
  const del = await callCallableFunction('timeEntryDelete', { orgId, timeEntryId: manualId }, user1.idToken);
  if (del?.success === true && del?.data?.deleted === true) {
    ok('timeEntryDelete - soft deletes entry', del.data);
  } else {
    fail('timeEntryDelete - soft deletes entry', 'Unexpected response', del);
  }

  const listAfterDelete = await callCallableFunction(
    'timeEntryList',
    { orgId, caseId, limit: 100, offset: 0 },
    user1.idToken
  );
  const afterIds = (listAfterDelete?.data?.timeEntries ?? []).map((e: any) => e.timeEntryId);
  if (listAfterDelete?.success === true && !afterIds.includes(manualId)) {
    ok('timeEntryList - excludes soft-deleted entries', { count: afterIds.length });
  } else {
    fail('timeEntryList - excludes soft-deleted entries', 'Deleted entry still present in list', listAfterDelete);
  }

  // Summary
  const passed = results.filter((r) => r.passed).length;
  const failed = results.length - passed;
  console.log('');
  console.log('📊 Slice 10 backend test summary');
  console.log(`   Passed: ${passed}`);
  console.log(`   Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('❌ Slice 10 backend test fatal error:', (e as Error).message);
  process.exit(1);
});

