/**
 * Full Integration Test for Slice 13 AI Contract Analysis
 * Tests the complete contract analysis flow:
 * 1. Sign up user, create org, case, client
 * 2. Create document (with mock extracted text)
 * 3. Call contractAnalyze
 * 4. Verify analysis results (clauses, risks)
 *
 * Usage (PowerShell):
 *   cd functions
 *   $env:FIREBASE_API_KEY="AIza...."
 *   $env:FIREBASE_ADMIN_KEY="<service account JSON file path>"
 *   npm run build
 *   node lib/__tests__/slice13-full-integration-test.js
 */
/* eslint-disable @typescript-eslint/no-explicit-any */

import * as https from 'https';
import * as admin from 'firebase-admin';

const apiKey = process.env.FIREBASE_API_KEY;
if (!apiKey) {
  console.error('❌ ERROR: FIREBASE_API_KEY env var is required.');
  process.exit(1);
}

// Initialize Firebase Admin (for Firestore writes to set extractedText)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'legal-ai-app-1203e';
const region = process.env.FUNCTION_REGION || 'us-central1';

type TestResult = { name: string; passed: boolean; error?: string; data?: any };
const results: TestResult[] = [];

function ok(name: string, data?: any) {
  results.push({ name, passed: true, data });
  console.log(`✅ ${name}`);
}

function fail(name: string, error: string) {
  results.push({ name, passed: false, error });
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

function assert(condition: any, message: string) {
  if (!condition) throw new Error(message);
}

// Sample contract text for testing
const SAMPLE_CONTRACT = `SERVICE AGREEMENT

This Service Agreement ("Agreement") is entered into as of January 1, 2024 ("Effective Date") by and between ABC Corp ("Client") and XYZ Services LLC ("Provider").

1. SERVICES
Provider shall provide consulting services as described in Exhibit A.

2. PAYMENT TERMS
Client shall pay Provider $10,000 per month, due within 30 days of invoice date. Late payments will incur a 5% monthly penalty.

3. TERM AND TERMINATION
This Agreement shall continue for an initial term of 12 months and will automatically renew for successive 12-month terms unless either party provides 90 days written notice of termination. Provider may terminate immediately for non-payment exceeding 60 days.

4. LIABILITY
PROVIDER'S TOTAL LIABILITY UNDER THIS AGREEMENT SHALL NOT EXCEED THE FEES PAID BY CLIENT IN THE 12 MONTHS PRECEDING THE CLAIM. PROVIDER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES.

5. CONFIDENTIALITY
Each party agrees to maintain the confidentiality of the other party's Confidential Information for a period of 5 years following termination of this Agreement.

6. INDEMNIFICATION
Client shall indemnify, defend, and hold harmless Provider from any claims arising from Client's use of the Services, except where such claims result from Provider's gross negligence or willful misconduct.

7. GOVERNING LAW
This Agreement shall be governed by the laws of the State of California, without regard to its conflict of law provisions.

8. DISPUTE RESOLUTION
Any disputes arising under this Agreement shall be resolved through binding arbitration in San Francisco, California, under the rules of the American Arbitration Association.

IN WITNESS WHEREOF, the parties have executed this Agreement as of the Effective Date.`;

async function run() {
  console.log('🧪 Slice 13 (Full Contract Analysis Integration) test starting...');
  console.log(`   Project: ${projectId}`);
  console.log(`   Region:  ${region}`);

  const runId = Date.now();
  const password = 'TestPass123!';
  const email = `test-contract-full-${runId}@legal-ai-test.com`;

  // 1. Setup: Create user, org, case, client
  const user = await signUpUser(email, password);
  ok('Auth - created user', { email, uid: user.uid });

  const orgCreate = await callCallableFunction(
    'orgCreate',
    { name: `Test Contract Org (${runId})`, description: 'Full contract analysis integration test' },
    user.idToken
  );
  assert(orgCreate?.success === true && orgCreate?.data?.orgId, 'orgCreate failed');
  const orgId = orgCreate.data.orgId as string;
  ok('orgCreate - created org', { orgId });

  const clientCreate = await callCallableFunction(
    'clientCreate',
    { orgId, name: 'Test Client', email: 'client@test.com' },
    user.idToken
  );
  assert(clientCreate?.success === true && clientCreate?.data?.clientId, 'clientCreate failed');
  const clientId = clientCreate.data.clientId as string;
  ok('clientCreate - created client', { clientId });

  const caseCreate = await callCallableFunction(
    'caseCreate',
    { orgId, title: 'Contract Analysis Test Case', visibility: 'ORG_WIDE', status: 'OPEN', clientId },
    user.idToken
  );
  assert(caseCreate?.success === true && caseCreate?.data?.caseId, 'caseCreate failed');
  const caseId = caseCreate.data.caseId as string;
  ok('caseCreate - created case', { caseId });

  // 2. Create document with mock extracted text (using Firestore Admin SDK)
  const docRef = db.collection('organizations').doc(orgId).collection('documents').doc();
  const documentId = docRef.id;
  const now = admin.firestore.Timestamp.now();
  
  await docRef.set({
    id: documentId,
    orgId,
    caseId,
    name: 'Test Service Agreement.pdf',
    description: 'Sample contract for AI analysis testing',
    fileType: 'pdf',
    fileSize: 50000,
    storagePath: `organizations/${orgId}/documents/${documentId}/test.pdf`,
    createdAt: now,
    updatedAt: now,
    createdBy: user.uid,
    updatedBy: user.uid,
    extractedText: SAMPLE_CONTRACT,
    extractionStatus: 'completed',
    extractedAt: now,
    pageCount: 2,
    wordCount: SAMPLE_CONTRACT.split(/\s+/).length,
  });
  ok('Document - created with extracted text', { documentId, wordCount: SAMPLE_CONTRACT.split(/\s+/).length });

  // 3. Analyze the contract
  console.log('\n📝 Analyzing contract with AI (this may take 10-30 seconds)...');
  const analyzeRes = await callCallableFunction(
    'contractAnalyze',
    { orgId, documentId },
    user.idToken
  );
  
  if (analyzeRes?.success !== true) {
    fail('contractAnalyze - should analyze document', analyzeRes?.error?.message || 'Unknown error');
    console.log('---');
    console.log(`❌ Slice 13 full integration test failed: 1 failure`);
    process.exit(1);
  }
  
  const analysisId = analyzeRes.data?.analysisId;
  const summary = analyzeRes.data?.summary;
  const clauses = analyzeRes.data?.clauses ?? [];
  const risks = analyzeRes.data?.risks ?? [];
  
  assert(analysisId, 'contractAnalyze should return analysisId');
  assert(summary, 'contractAnalyze should return summary');
  assert(Array.isArray(clauses), 'contractAnalyze should return clauses array');
  assert(Array.isArray(risks), 'contractAnalyze should return risks array');
  
  ok('contractAnalyze - analyzed contract', {
    analysisId,
    summaryLength: summary.length,
    clausesCount: clauses.length,
    risksCount: risks.length,
  });

  // 4. Verify analysis results
  assert(clauses.length > 0, 'Analysis should identify at least one clause');
  ok(`contractAnalyze - identified ${clauses.length} clauses`);

  assert(risks.length > 0, 'Analysis should flag at least one risk');
  ok(`contractAnalyze - flagged ${risks.length} risks`);

  // Verify clause structure
  const firstClause = clauses[0];
  assert(firstClause.id, 'Clause should have id');
  assert(firstClause.type, 'Clause should have type');
  assert(firstClause.title, 'Clause should have title');
  assert(firstClause.content, 'Clause should have content');
  ok('contractAnalyze - clauses have correct structure', { sample: firstClause.type });

  // Verify risk structure
  const firstRisk = risks[0];
  assert(firstRisk.id, 'Risk should have id');
  assert(firstRisk.severity, 'Risk should have severity');
  assert(['high', 'medium', 'low'].includes(firstRisk.severity), 'Risk severity should be valid');
  assert(firstRisk.category, 'Risk should have category');
  assert(firstRisk.title, 'Risk should have title');
  assert(firstRisk.description, 'Risk should have description');
  ok('contractAnalyze - risks have correct structure', { sample: firstRisk.severity });

  // 5. Verify contractAnalysisGet returns the same analysis
  const getRes = await callCallableFunction(
    'contractAnalysisGet',
    { orgId, analysisId },
    user.idToken
  );
  assert(getRes?.success === true, 'contractAnalysisGet failed');
  assert(getRes.data?.analysisId === analysisId, 'contractAnalysisGet should return same analysisId');
  assert(getRes.data?.summary === summary, 'contractAnalysisGet should return same summary');
  ok('contractAnalysisGet - retrieved analysis', { analysisId });

  // 6. Verify contractAnalysisList includes the new analysis
  const listRes = await callCallableFunction(
    'contractAnalysisList',
    { orgId, documentId, limit: 10, offset: 0 },
    user.idToken
  );
  assert(listRes?.success === true, 'contractAnalysisList failed');
  const analyses = listRes.data?.analyses ?? [];
  assert(analyses.length > 0, 'contractAnalysisList should return at least one analysis');
  const found = analyses.find((a: any) => a.analysisId === analysisId);
  assert(found, 'contractAnalysisList should include the created analysis');
  ok('contractAnalysisList - includes created analysis', { count: analyses.length });

  console.log('\n📊 Analysis Results Summary:');
  console.log(`   Summary: ${summary.substring(0, 100)}${summary.length > 100 ? '...' : ''}`);
  console.log(`   Clauses identified: ${clauses.length}`);
  clauses.slice(0, 3).forEach((c: any) => {
    console.log(`      - ${c.type}: ${c.title}`);
  });
  if (clauses.length > 3) console.log(`      ... and ${clauses.length - 3} more`);
  console.log(`   Risks flagged: ${risks.length}`);
  risks.slice(0, 3).forEach((r: any) => {
    console.log(`      - [${r.severity.toUpperCase()}] ${r.title}`);
  });
  if (risks.length > 3) console.log(`      ... and ${risks.length - 3} more`);

  console.log('\n---');
  const failed = results.filter((r) => !r.passed);
  if (failed.length > 0) {
    console.log(`❌ Slice 13 full integration test failed: ${failed.length}/${results.length}`);
    process.exit(1);
  }
  console.log(`✅ Slice 13 full integration test passed: ${results.length}/${results.length}`);
  console.log('   All contract analysis functions verified end-to-end.');
}

run().catch((e) => {
  console.error('❌ Slice 13 full integration test crashed:', e);
  process.exit(1);
});
