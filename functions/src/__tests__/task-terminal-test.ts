/**
 * Terminal Test Script for Slice 5 Task Hub Functions
 * Tests deployed Cloud Functions against real Firebase project.
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."              # Web API key
 *   $env:GCLOUD_PROJECT="legal-ai-app-1203e"      # optional
 *   $env:FUNCTION_REGION="us-central1"            # optional
 *   npm run build
 *   node lib/__tests__/task-terminal-test.js
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

function todayDateOnly(): string {
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

async function run() {
  console.log('🧪 Task Hub backend test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!';
  const adminEmail = `test-task-admin-${runId}@legal-ai-test.com`;
  const viewerEmail = `test-task-viewer-${runId}@legal-ai-test.com`;

  const adminUser = await signUpUser(adminEmail, password);
  ok('Auth - created admin user', { email: adminEmail, uid: adminUser.uid });

  const viewerUser = await signUpUser(viewerEmail, password);
  ok('Auth - created viewer user', { email: viewerEmail, uid: viewerUser.uid });

  // Org create (admin becomes ADMIN)
  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Org Tasks (${runId})`, description: 'Automated backend verification for Tasks' },
    adminUser.idToken
  );
  if (orgCreate?.success !== true || !orgCreate?.data?.orgId) {
    fail('orgCreate - create org', 'Unexpected response', orgCreate);
    return;
  }
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  // Viewer joins org (VIEWER)
  const join = await callCallableFunction('orgJoin', { orgId }, viewerUser.idToken);
  if (join?.success !== true) {
    fail('orgJoin - viewer joins org', 'Unexpected response', join);
    return;
  }
  ok('orgJoin - viewer joined org', join.data);

  // Create client + ORG_WIDE case
  const clientCreate = await callCallableFunction('clientCreate', { orgId, name: 'Task Test Client' }, adminUser.idToken);
  if (clientCreate?.success !== true || !clientCreate?.data?.clientId) {
    fail('clientCreate - create client', 'Unexpected response', clientCreate);
    return;
  }
  const clientId = clientCreate.data.clientId as string;
  ok('clientCreate - created client', { clientId });

  const caseOrgWide = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Task Case (ORG_WIDE)', visibility: 'ORG_WIDE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  if (caseOrgWide?.success !== true || !caseOrgWide?.data?.caseId) {
    fail('caseCreate - create ORG_WIDE case', 'Unexpected response', caseOrgWide);
    return;
  }
  const caseId = caseOrgWide.data.caseId as string;
  ok('caseCreate - created ORG_WIDE case', { caseId });

  // Create PRIVATE case for access test
  const casePrivate = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Task Case (PRIVATE)', visibility: 'PRIVATE', status: 'OPEN', clientId },
    adminUser.idToken
  );
  if (casePrivate?.success !== true || !casePrivate?.data?.caseId) {
    fail('caseCreate - create PRIVATE case', 'Unexpected response', casePrivate);
    return;
  }
  const privateCaseId = casePrivate.data.caseId as string;
  ok('caseCreate - created PRIVATE case', { privateCaseId });

  // Viewer cannot create tasks
  const viewerCreate = await callCallableFunction(
    'taskCreate',
    {
      orgId,
      caseId,
      title: 'Should fail',
      description: 'Viewer cannot create tasks',
      status: 'PENDING',
      priority: 'MEDIUM',
      dueDate: todayDateOnly(),
    },
    viewerUser.idToken
  );
  if (viewerCreate?.success === false && viewerCreate?.error?.code === 'NOT_AUTHORIZED') {
    ok('Permissions - viewer cannot create task', viewerCreate.error);
  } else {
    fail('Permissions - viewer cannot create task', 'Expected NOT_AUTHORIZED', viewerCreate);
  }

  // Admin creates a task on ORG_WIDE case
  const adminTask = await callCallableFunction(
    'taskCreate',
    {
      orgId,
      caseId,
      title: 'Task test - draft letter',
      description: 'Automated task test',
      status: 'PENDING',
      priority: 'MEDIUM',
      dueDate: todayDateOnly(),
    },
    adminUser.idToken
  );
  if (adminTask?.success !== true || !adminTask?.data?.taskId) {
    fail('taskCreate - admin creates task', 'Unexpected response', adminTask);
    return;
  }
  const taskId = adminTask.data.taskId as string;
  ok('taskCreate - admin created task', { taskId });

  // Admin lists tasks and sees it
  const listAdmin = await callCallableFunction('taskList', { orgId, limit: 50, offset: 0, caseId }, adminUser.idToken);
  const adminIds = (listAdmin?.data?.tasks ?? []).map((t: any) => t.taskId);
  if (listAdmin?.success === true && adminIds.includes(taskId)) {
    ok('taskList - admin sees task', { total: listAdmin.data.total, taskIds: adminIds.slice(0, 5) });
  } else {
    fail('taskList - admin sees task', 'Task missing', listAdmin);
  }

  // Viewer lists tasks and sees it (case is ORG_WIDE)
  const listViewer = await callCallableFunction('taskList', { orgId, limit: 50, offset: 0, caseId }, viewerUser.idToken);
  const viewerIds = (listViewer?.data?.tasks ?? []).map((t: any) => t.taskId);
  if (listViewer?.success === true && viewerIds.includes(taskId)) {
    ok('taskList - viewer sees ORG_WIDE case task', { total: listViewer.data.total });
  } else {
    fail('taskList - viewer sees ORG_WIDE case task', 'Expected task in list', listViewer);
  }

  // Get task (viewer)
  const getViewer = await callCallableFunction('taskGet', { orgId, taskId }, viewerUser.idToken);
  if (getViewer?.success === true && getViewer?.data?.taskId === taskId) {
    ok('taskGet - viewer can get task', getViewer.data);
  } else {
    fail('taskGet - viewer can get task', 'Unexpected response', getViewer);
  }

  // Update task (admin)
  const update = await callCallableFunction(
    'taskUpdate',
    { orgId, taskId, title: 'Task test - updated title' },
    adminUser.idToken
  );
  if (update?.success === true && update?.data?.title === 'Task test - updated title') {
    ok('taskUpdate - admin updates title', update.data);
  } else {
    fail('taskUpdate - admin updates title', 'Unexpected response', update);
  }

  // Private case task should be hidden from viewer
  const privateTask = await callCallableFunction(
    'taskCreate',
    {
      orgId,
      caseId: privateCaseId,
      title: 'Private task',
      status: 'PENDING',
      priority: 'MEDIUM',
      dueDate: todayDateOnly(),
    },
    adminUser.idToken
  );
  if (privateTask?.success !== true || !privateTask?.data?.taskId) {
    fail('taskCreate - admin creates PRIVATE case task', 'Unexpected response', privateTask);
    return;
  }
  const privateTaskId = privateTask.data.taskId as string;
  ok('taskCreate - admin created PRIVATE case task', { privateTaskId });

  const viewerPrivateGet = await callCallableFunction('taskGet', { orgId, taskId: privateTaskId }, viewerUser.idToken);
  if (viewerPrivateGet?.success === false && viewerPrivateGet?.error?.code === 'NOT_FOUND') {
    ok('Case access - viewer cannot get PRIVATE case task (NOT_FOUND)', viewerPrivateGet.error);
  } else {
    fail('Case access - viewer cannot get PRIVATE case task (NOT_FOUND)', 'Expected NOT_FOUND', viewerPrivateGet);
  }

  // Delete task (admin) and ensure it is excluded
  const del = await callCallableFunction('taskDelete', { orgId, taskId }, adminUser.idToken);
  if (del?.success === true && del?.data?.taskId === taskId) {
    ok('taskDelete - admin deletes task', del.data);
  } else {
    fail('taskDelete - admin deletes task', 'Unexpected response', del);
  }

  const listAfterDelete = await callCallableFunction('taskList', { orgId, limit: 100, offset: 0, caseId }, adminUser.idToken);
  const afterIds = (listAfterDelete?.data?.tasks ?? []).map((t: any) => t.taskId);
  if (listAfterDelete?.success === true && !afterIds.includes(taskId)) {
    ok('taskList - excludes soft-deleted tasks', { count: afterIds.length });
  } else {
    fail('taskList - excludes soft-deleted tasks', 'Deleted task still present', listAfterDelete);
  }

  // Summary
  const passed = results.filter((r) => r.passed).length;
  const failed = results.length - passed;
  console.log('');
  console.log('📊 Task Hub backend test summary');
  console.log(`   Passed: ${passed}`);
  console.log(`   Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('❌ Task Hub backend test fatal error:', (e as Error).message);
  process.exit(1);
});

