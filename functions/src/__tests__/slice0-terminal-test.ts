/**
 * Terminal Test Script for Slice 0 Functions
 * Tests deployed Cloud Functions against real Firebase project
 * 
 * Usage: npm run test:slice0
 * 
 * Requirements:
 * - GCLOUD_PROJECT environment variable set (or GCP_PROJECT)
 * - Firebase Admin SDK initialized (uses default credentials)
 * - Deployed functions accessible via HTTPS
 */

import * as admin from 'firebase-admin';
import * as https from 'https';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    // Try to initialize with service account if available
    const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (serviceAccountPath) {
      // Read service account JSON file
      const serviceAccountJson = fs.readFileSync(serviceAccountPath, 'utf8');
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else {
      // Try default initialization (works in GCP environments or with gcloud auth)
      admin.initializeApp();
    }
  } catch (error: any) {
    console.error('❌ ERROR: Firebase Admin initialization failed');
    console.error('   This usually means credentials are not configured.');
    console.error('');
    console.error('   Solutions:');
    console.error('   1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable:');
    console.error('      $env:GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"');
    console.error('');
    console.error('   2. Or use gcloud auth:');
    console.error('      gcloud auth application-default login');
    console.error('');
    console.error('   3. Or download service account key from Firebase Console:');
    console.error('      Project Settings → Service Accounts → Generate New Private Key');
    console.error('');
    throw error;
  }
}

// Get Firebase project configuration
const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || admin.app().options.projectId;
if (!projectId) {
  console.error('❌ ERROR: Project ID not found. Set GCLOUD_PROJECT or GCP_PROJECT environment variable.');
  console.error('   Alternatively, ensure Firebase Admin is initialized with project credentials.');
  process.exit(1);
}

// Function region (can be overridden via FUNCTION_REGION env var)
const region = process.env.FUNCTION_REGION || 'us-central1';

// Test user UID (will be created if doesn't exist)
const testUserId = 'test-user-slice0';

interface TestResult {
  name: string;
  passed: boolean;
  data?: any;
  error?: string;
}

/**
 * Get or create a test user and return ID token
 * Uses Firebase Admin SDK to create a custom token, then exchanges it for ID token
 */
async function getTestUserToken(): Promise<string> {
  try {
    // Try to get existing user
    try {
      await admin.auth().getUser(testUserId);
    } catch (error: any) {
      // User doesn't exist, create it
      if (error.code === 'auth/user-not-found') {
        await admin.auth().createUser({
          uid: testUserId,
          email: `test-${Date.now()}@legal-ai-test.com`,
          displayName: 'Test User (Slice 0)',
        });
      } else {
        throw error;
      }
    }

    // Create custom token
    const customToken = await admin.auth().createCustomToken(testUserId);

    // Get API key from Firebase config or use environment variable
    const apiKey = process.env.FIREBASE_API_KEY;
    if (!apiKey) {
      throw new Error('FIREBASE_API_KEY environment variable required. Get it from Firebase Console > Project Settings > General > Web API Key');
    }
    
    // Validate API key format (should start with AIza)
    if (!apiKey.startsWith('AIza')) {
      console.warn('⚠️  WARNING: API key format looks incorrect. Should start with "AIza"');
    }

    // Exchange custom token for ID token via REST API
    const idToken = await exchangeCustomTokenForIdToken(customToken, apiKey);

    return idToken;
  } catch (error: any) {
    console.error('❌ Failed to get test user token:', error.message);
    throw error;
  }
}

/**
 * Exchange custom token for ID token using Firebase REST API
 */
async function exchangeCustomTokenForIdToken(customToken: string, apiKey: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      token: customToken,
      returnSecureToken: true,
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithCustomToken?key=${apiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          if (res.statusCode === 200 && response.idToken) {
            resolve(response.idToken);
          } else {
            reject(new Error(`Failed to exchange token: ${res.statusCode} - ${data}`));
          }
        } catch {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

/**
 * Call a deployed callable function
 * Callable functions use a specific protocol with data wrapped in { data: ... }
 */
async function callCallableFunction(
  functionName: string,
  data: any,
  idToken: string
): Promise<any> {
  return new Promise((resolve, reject) => {
    // Callable functions URL format: https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME
    const hostname = `${region}-${projectId}.cloudfunctions.net`;
    const path = `/${functionName}`;
    
    // Callable functions expect: { data: { ... } }
    const requestBody = { data };
    const postData = JSON.stringify(requestBody);

    const options = {
      hostname,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Authorization': `Bearer ${idToken}`,
      },
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          if (res.statusCode !== 200) {
            // Try to parse error response
            let errorMessage = responseData;
            try {
              const errorJson = JSON.parse(responseData);
              errorMessage = errorJson.error?.message || errorJson.message || responseData;
            } catch {
              // Keep raw response
            }
            reject(new Error(`Function returned ${res.statusCode}: ${errorMessage}`));
            return;
          }

          const result = JSON.parse(responseData);
          // Callable functions return: { result: { success: true, data: ... } }
          if (result.result) {
            resolve(result.result);
          } else {
            // Sometimes the response is directly the result
            resolve(result);
          }
        } catch {
          reject(new Error(`Failed to parse response: ${responseData}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Request failed: ${error.message}`));
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Test orgCreate function
 */
async function testOrgCreate(idToken: string): Promise<TestResult> {
  try {
    const testData = {
      name: 'Smith & Associates Law Firm',
      description: 'Test organization for Slice 0',
    };

    const response = await callCallableFunction('orgCreate', testData, idToken);

    if (response.success && response.data && response.data.orgId) {
      return {
        name: 'orgCreate',
        passed: true,
        data: response.data,
      };
    } else {
      return {
        name: 'orgCreate',
        passed: false,
        error: `Unexpected response format: ${JSON.stringify(response)}`,
      };
    }
  } catch (error: any) {
    return {
      name: 'orgCreate',
      passed: false,
      error: error.message,
    };
  }
}

/**
 * Test orgJoin function
 */
async function testOrgJoin(orgId: string, idToken: string): Promise<TestResult> {
  try {
    const testData = { orgId };

    const response = await callCallableFunction('orgJoin', testData, idToken);

    if (response.success) {
      return {
        name: 'orgJoin',
        passed: true,
        data: response.data || { message: 'Already a member' },
      };
    } else {
      return {
        name: 'orgJoin',
        passed: false,
        error: `Function returned error: ${JSON.stringify(response)}`,
      };
    }
  } catch (error: any) {
    return {
      name: 'orgJoin',
      passed: false,
      error: error.message,
    };
  }
}

/**
 * Test memberGetMyMembership function
 */
async function testMemberGetMyMembership(orgId: string, idToken: string): Promise<TestResult> {
  try {
    const testData = { orgId };

    const response = await callCallableFunction('memberGetMyMembership', testData, idToken);

    if (response.success && response.data) {
      return {
        name: 'memberGetMyMembership',
        passed: true,
        data: response.data,
      };
    } else {
      return {
        name: 'memberGetMyMembership',
        passed: false,
        error: `Unexpected response: ${JSON.stringify(response)}`,
      };
    }
  } catch (error: any) {
    return {
      name: 'memberGetMyMembership',
      passed: false,
      error: error.message,
    };
  }
}

/**
 * Print test result
 */
function printResult(result: TestResult): void {
  const icon = result.passed ? '✅' : '❌';
  const status = result.passed ? 'PASS' : 'FAIL';
  
  console.log(`${icon} ${result.name}: ${status}`);
  
  if (result.passed && result.data) {
    if (result.data.orgId) {
      console.log(`   orgId: ${result.data.orgId}`);
    }
    if (result.data.name) {
      console.log(`   name: ${result.data.name}`);
    }
    if (result.data.orgName) {
      console.log(`   orgName: ${result.data.orgName}`);
    }
    if (result.data.plan) {
      console.log(`   plan: ${result.data.plan}`);
    }
    if (result.data.role) {
      console.log(`   role: ${result.data.role}`);
    }
    if (result.data.message) {
      console.log(`   message: ${result.data.message}`);
    }
  } else if (!result.passed) {
    console.log(`   ERROR: ${result.error}`);
  }
  console.log('');
}

/**
 * Main test runner
 */
async function runTests(): Promise<void> {
  console.log('🧪 Testing Slice 0 Functions (Deployed)\n');
  console.log(`📋 Project: ${projectId}`);
  console.log(`🌍 Region: ${region}`);
  console.log(`🔗 Functions URL: https://${region}-${projectId}.cloudfunctions.net/\n`);

  try {
    // Get test user token
    console.log('🔐 Authenticating test user...');
    const idToken = await getTestUserToken();
    console.log('✅ Authentication successful\n');

    const results: TestResult[] = [];
    let orgId: string | null = null;

    // Test 1: orgCreate
    console.log('📝 Testing orgCreate...');
    const orgCreateResult = await testOrgCreate(idToken);
    results.push(orgCreateResult);
    printResult(orgCreateResult);
    
    if (orgCreateResult.passed && orgCreateResult.data?.orgId) {
      orgId = orgCreateResult.data.orgId;
    } else {
      console.error('❌ Cannot continue tests without orgId from orgCreate');
      process.exit(1);
    }

    // At this point, orgId is guaranteed to be a string (not null)
    // We've already checked and would have exited if it was null
    const finalOrgId = orgId!;

    // Test 2: orgJoin
    console.log('👥 Testing orgJoin...');
    const orgJoinResult = await testOrgJoin(finalOrgId, idToken);
    results.push(orgJoinResult);
    printResult(orgJoinResult);

    // Test 3: memberGetMyMembership
    console.log('🔍 Testing memberGetMyMembership...');
    const membershipResult = await testMemberGetMyMembership(finalOrgId, idToken);
    results.push(membershipResult);
    printResult(membershipResult);

    // Summary
    const allPassed = results.every((r) => r.passed);
    const passedCount = results.filter((r) => r.passed).length;

    console.log('─'.repeat(50));
    if (allPassed) {
      console.log(`✅ All tests passed! (${passedCount}/${results.length})\n`);
    } else {
      console.log(`❌ Some tests failed (${passedCount}/${results.length} passed)\n`);
    }

    // Save results to file
    const resultsFile = path.join(__dirname, 'slice0-test-results.json');
    const resultsData = {
      timestamp: new Date().toISOString(),
      projectId,
      region,
      summary: {
        total: results.length,
        passed: passedCount,
        failed: results.length - passedCount,
        allPassed,
      },
      results: results.map((r) => ({
        name: r.name,
        passed: r.passed,
        data: r.data,
        error: r.error,
      })),
    };

    try {
      fs.writeFileSync(resultsFile, JSON.stringify(resultsData, null, 2));
      console.log(`📄 Test results saved to: ${resultsFile}\n`);
    } catch (error) {
      console.warn('⚠️  Could not save test results to file:', error);
    }

    process.exit(allPassed ? 0 : 1);
  } catch (error: any) {
    console.error('❌ Test suite failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

// Run tests
runTests().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
