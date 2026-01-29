/**
 * Terminal Test Script for Slice 12 Audit Trail UI (Backend)
 * Tests deployed Cloud Functions against real Firebase project.
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."              # Web API key
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"      # optional
 *   $env:FUNCTION_REGION="us-central1"            # optional
 *   npm run build
 *   node lib/__tests__/slice12-terminal-test.js
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
  console.log('🧪 Slice 12 (Audit Trail UI) backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!';
  const adminEmail = `test-audit-admin-${runId}@legal-ai-test.com`;
  const admin2Email = `test-audit-admin2-${runId}@legal-ai-test.com`;

  const adminUser = await signUpUser(adminEmail, password);
  ok('Auth - created admin user', { email: adminEmail, uid: adminUser.uid });

  const admin2User = await signUpUser(admin2Email, password);
  ok('Auth - created second user', { email: admin2Email, uid: admin2User.uid });

  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Audit (${runId})`, description: 'Automated backend verification for Audit Trail UI' },
    adminUser.idToken
  );
  assert(orgCreate?.success === true && orgCreate?.data?.orgId, 'orgCreate failed');
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  const join = await callCallableFunction('orgJoin', { orgId }, admin2User.idToken);
  assert(join?.success === true, 'orgJoin failed');
  ok('orgJoin - second user joined org', join.data);

  // Promote second user to ADMIN so they have audit.view, but NOT private case access
  const promote = await callCallableFunction(
    'memberUpdateRole',
    { orgId, memberUid: admin2User.uid, role: 'ADMIN' },
    adminUser.idToken
  );
  assert(promote?.success === true, 'memberUpdateRole (promote) failed');
  ok('memberUpdateRole - promoted second user to ADMIN', { uid: admin2User.uid });

  // Create a client
  const clientCreate = await callCallableFunction('clientCreate', { orgId, name: 'Audit Test Client' }, adminUser.idToken);
  assert(clientCreate?.success === true && clientCreate?.data?.clientId, 'clientCreate failed');
  const clientId = clientCreate.data.clientId as string;
  ok('clientCreate - created client', { clientId });

  // Create ORG_WIDE + PRIVATE cases (generates audit events)
  const caseOrgWide = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Audit Case (ORG_WIDE)', visibility: 'ORG_WIDE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  assert(caseOrgWide?.success === true && caseOrgWide?.data?.caseId, 'caseCreate ORG_WIDE failed');
  const orgWideCaseId = caseOrgWide.data.caseId as string;
  ok('caseCreate - created ORG_WIDE case', { orgWideCaseId });

  const casePrivate = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Audit Case (PRIVATE)', visibility: 'PRIVATE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  assert(casePrivate?.success === true && casePrivate?.data?.caseId, 'caseCreate PRIVATE failed');
  const privateCaseId = casePrivate.data.caseId as string;
  ok('caseCreate - created PRIVATE case', { privateCaseId });

  // Create tasks to generate additional audit events with metadata.caseId
  const taskOrgWide = await callCallableFunction(
    'taskCreate',
    { orgId, caseId: orgWideCaseId, title: 'Audit Task (ORG_WIDE)', status: 'PENDING', priority: 'MEDIUM' },
    adminUser.idToken
  );
  assert(taskOrgWide?.success === true && taskOrgWide?.data?.taskId, 'taskCreate ORG_WIDE failed');
  ok('taskCreate - created ORG_WIDE task', { taskId: taskOrgWide.data.taskId });

  const taskPrivate = await callCallableFunction(
    'taskCreate',
    { orgId, caseId: privateCaseId, title: 'Audit Task (PRIVATE)', status: 'PENDING', priority: 'MEDIUM' },
    adminUser.idToken
  );
  assert(taskPrivate?.success === true && taskPrivate?.data?.taskId, 'taskCreate PRIVATE failed');
  ok('taskCreate - created PRIVATE task', { taskId: taskPrivate.data.taskId });

  // Admin should see private-case audit events when filtering by that caseId
  const adminPrivateAudit = await callCallableFunction(
    'auditList',
    { orgId, caseId: privateCaseId, limit: 50, offset: 0, includeMetadata: true },
    adminUser.idToken
  );
  assert(adminPrivateAudit?.success === true, 'auditList (admin/private) failed');
  const adminPrivateEvents = adminPrivateAudit.data?.events ?? [];
  assert(Array.isArray(adminPrivateEvents), 'auditList events should be an array');
  assert(adminPrivateEvents.length > 0, 'Expected admin to see at least 1 private-case audit event');
  ok('auditList - admin can see PRIVATE case events', { count: adminPrivateEvents.length });

  // Second ADMIN should NOT see private-case audit events when filtering by that caseId (no existence leakage)
  const admin2PrivateAudit = await callCallableFunction(
    'auditList',
    { orgId, caseId: privateCaseId, limit: 50, offset: 0, includeMetadata: true },
    admin2User.idToken
  );
  assert(admin2PrivateAudit?.success === true, 'auditList (admin2/private) failed');
  const admin2PrivateEvents = admin2PrivateAudit.data?.events ?? [];
  assert(Array.isArray(admin2PrivateEvents), 'auditList events should be an array');
  assert(admin2PrivateEvents.length === 0, 'Expected second ADMIN to see 0 private-case audit events');
  ok('auditList - second ADMIN cannot see PRIVATE case events', { count: admin2PrivateEvents.length });

  // Second ADMIN org-wide audit list should not contain any event tied to the private case
  const admin2All = await callCallableFunction(
    'auditList',
    { orgId, limit: 100, offset: 0, includeMetadata: true },
    admin2User.idToken
  );
  assert(admin2All?.success === true, 'auditList (admin2/all) failed');
  const admin2Events = admin2All.data?.events ?? [];
  assert(Array.isArray(admin2Events), 'auditList events should be an array');
  const leaked = admin2Events.filter((e: any) => e?.caseId === privateCaseId || e?.entityId === privateCaseId);
  assert(leaked.length === 0, 'Expected no private-case-related audit events to leak to second ADMIN');
  ok('auditList - second ADMIN sees no leaked private-case events', { total: admin2Events.length });

  console.log('---');
  const failed = results.filter((r) => !r.passed);
  if (failed.length > 0) {
    console.log(`❌ Slice 12 tests failed: ${failed.length}/${results.length}`);
    process.exit(1);
  }
  console.log(`✅ Slice 12 tests passed: ${results.length}/${results.length}`);
}

run().catch((e) => {
  console.error('❌ Slice 12 test runner crashed:', e);
  process.exit(1);
});

