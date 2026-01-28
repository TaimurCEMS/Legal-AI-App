/**
 * Terminal Test Script for Slice 0 Functions
 * Tests deployed Cloud Functions against real Firebase project.
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."              # Web API key
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"      # optional
 *   $env:FUNCTION_REGION="us-central1"            # optional
 *   npm run build
 *   node lib/__tests__/slice0-terminal-test.js
 *
 * Notes:
 * - Uses Identity Toolkit REST API + deployed callable functions.
 * - Does NOT require Firebase Admin credentials.
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
  console.log('🧪 Slice 0 backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!'; // only used for these test users
  const user1Email = `test-slice0-user1-${runId}@legal-ai-test.com`;
  const user2Email = `test-slice0-user2-${runId}@legal-ai-test.com`;

  const user1 = await signUpUser(user1Email, password);
  ok('Auth - created user1', { email: user1Email, uid: user1.uid });

  const user2 = await signUpUser(user2Email, password);
  ok('Auth - created user2', { email: user2Email, uid: user2.uid });

  // orgCreate: user1 becomes ADMIN
  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Slice 0 (${runId})`, description: 'Automated backend verification for Slice 0' },
    user1.idToken
  );
  if (orgCreate?.success !== true || !orgCreate?.data?.orgId) {
    fail('orgCreate - create org', 'Unexpected response', orgCreate);
    return;
  }
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  // orgJoin: user2 becomes VIEWER
  const join = await callCallableFunction('orgJoin', { orgId }, user2.idToken);
  if (join?.success !== true) {
    fail('orgJoin - user2 joins org', 'Unexpected response', join);
    return;
  }
  ok('orgJoin - user2 joined org', join.data);

  // orgJoin idempotency
  const joinAgain = await callCallableFunction('orgJoin', { orgId }, user2.idToken);
  if (joinAgain?.success === true) {
    ok('orgJoin - idempotent (user2 joins again)', joinAgain.data);
  } else {
    fail('orgJoin - idempotent (user2 joins again)', 'Expected success', joinAgain);
  }

  // memberGetMyMembership
  const mem1 = await callCallableFunction('memberGetMyMembership', { orgId }, user1.idToken);
  if (mem1?.success === true && mem1?.data?.role) {
    ok('memberGetMyMembership - user1', mem1.data);
  } else {
    fail('memberGetMyMembership - user1', 'Unexpected response', mem1);
  }

  const mem2 = await callCallableFunction('memberGetMyMembership', { orgId }, user2.idToken);
  if (mem2?.success === true && mem2?.data?.role) {
    ok('memberGetMyMembership - user2', mem2.data);
  } else {
    fail('memberGetMyMembership - user2', 'Unexpected response', mem2);
  }

  // memberListMyOrgs
  const list1 = await callCallableFunction('memberListMyOrgs', {}, user1.idToken);
  if (list1?.success === true && Array.isArray(list1?.data?.orgs)) {
    ok('memberListMyOrgs - user1', { count: list1.data.orgs.length });
  } else {
    fail('memberListMyOrgs - user1', 'Unexpected response', list1);
  }

  const list2 = await callCallableFunction('memberListMyOrgs', {}, user2.idToken);
  if (list2?.success === true && Array.isArray(list2?.data?.orgs)) {
    ok('memberListMyOrgs - user2', { count: list2.data.orgs.length });
  } else {
    fail('memberListMyOrgs - user2', 'Unexpected response', list2);
  }

  // Summary
  const passed = results.filter((r) => r.passed).length;
  const failed = results.length - passed;
  console.log('');
  console.log('📊 Slice 0 backend test summary');
  console.log(`   Passed: ${passed}`);
  console.log(`   Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('❌ Slice 0 backend test fatal error:', (e as Error).message);
  process.exit(1);
});

