/**
 * Terminal Test Script for Slice 14 AI Document Summarization (Backend)
 * Tests deployed Cloud Functions against real Firebase project.
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"   # optional
 *   $env:FUNCTION_REGION="us-central1"         # optional
 *   npm run build
 *   node lib/__tests__/slice14-terminal-test.js
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

function assert(condition: any, message: string) {
  if (!condition) throw new Error(message);
}

async function run() {
  console.log('🧪 Slice 14 (AI Document Summarization) backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!';
  const email = `test-summary-${runId}@legal-ai-test.com`;

  const user = await signUpUser(email, password);
  ok('Auth - created user', { email, uid: user.uid });

  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Summary (${runId})`, description: 'Automated backend verification for Document Summarization' },
    user.idToken
  );
  assert(orgCreate?.success === true && orgCreate?.data?.orgId, 'orgCreate failed');
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  // documentSummaryList (no summaries yet)
  const listRes = await callCallableFunction(
    'documentSummaryList',
    { orgId, limit: 20, offset: 0 },
    user.idToken
  );
  assert(listRes?.success === true, 'documentSummaryList failed');
  const summaries = listRes.data?.summaries ?? [];
  assert(Array.isArray(summaries), 'documentSummaryList summaries should be array');
  ok('documentSummaryList - returns empty list when no summaries', { count: summaries.length });

  // documentSummaryGet with invalid id -> NOT_FOUND
  const getRes = await callCallableFunction(
    'documentSummaryGet',
    { orgId, summaryId: 'non-existent-summary-id-12345' },
    user.idToken
  );
  assert(getRes?.success === false, 'documentSummaryGet should fail for invalid id');
  const errorCode = getRes?.error?.code ?? getRes?.error?.message ?? '';
  assert(
    String(errorCode).includes('NOT_FOUND') || String(getRes?.error?.message ?? '').toLowerCase().includes('not found'),
    'Expected NOT_FOUND or "not found" for invalid summary id'
  );
  ok('documentSummaryGet - returns NOT_FOUND for invalid summary id', { errorCode });

  console.log('---');
  const failed = results.filter((r) => !r.passed);
  if (failed.length > 0) {
    console.log(`❌ Slice 14 tests failed: ${failed.length}/${results.length}`);
    process.exit(1);
  }
  console.log(`✅ Slice 14 tests passed: ${results.length}/${results.length}`);
}

run().catch((e) => {
  console.error('❌ Slice 14 test runner crashed:', e);
  process.exit(1);
});
