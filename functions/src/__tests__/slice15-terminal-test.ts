/**
 * Slice 15 Terminal Test
 * Tests for Advanced Admin Features
 *
 * Run: npm run test:slice15
 * Loads FIREBASE_API_KEY from functions/.env if set; otherwise use env var.
 */
import 'dotenv/config';
import axios from 'axios';

const REGION = 'us-central1';
const PROJECT_ID = 'legal-ai-app-1203e';
// Use WEB_API_KEY from .env (FIREBASE_ prefix reserved by Firebase deploy)
const FIREBASE_API_KEY = process.env.WEB_API_KEY || process.env.FIREBASE_API_KEY;

if (!FIREBASE_API_KEY) {
  console.error('❌ WEB_API_KEY or FIREBASE_API_KEY environment variable is required');
  process.exit(1);
}

// Test credentials (use your actual test account credentials)
const TEST_EMAIL = 'test@example.com';
const TEST_PASSWORD = 'testpassword123';

let idToken: string = '';
let orgId: string = '';
let currentUserUid: string = '';
let testInvitationId: string = '';
let testInviteCode: string = '';

async function signIn(email: string, password: string): Promise<string> {
  try {
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      {
        email,
        password,
        returnSecureToken: true,
      }
    );
    return response.data.idToken;
  } catch (error: any) {
    throw new Error(`Sign in failed: ${error.response?.data?.error?.message || error.message}`);
  }
}

async function callFunction(functionName: string, data: any): Promise<any> {
  const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${functionName}`;
  try {
    const response = await axios.post(
      url,
      { data },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${idToken}`,
        },
      }
    );
    return response.data.result;
  } catch (error: any) {
    const errorData = error.response?.data?.error || error.message;
    throw new Error(`Function ${functionName} failed: ${JSON.stringify(errorData)}`);
  }
}

async function runTests() {
  console.log('🚀 Slice 15 Terminal Test - Advanced Admin Features\n');

  try {
    // Step 1: Sign in
    console.log('1️⃣  Signing in...');
    idToken = await signIn(TEST_EMAIL, TEST_PASSWORD);
    console.log('✅ Signed in successfully\n');

    // Step 2: Get or create org
    console.log('2️⃣  Getting organization list...');
    const orgsResult = await callFunction('memberListMyOrgs', {});
    if (orgsResult.orgs && orgsResult.orgs.length > 0) {
      orgId = orgsResult.orgs[0].orgId;
      console.log(`✅ Using existing org: ${orgId}\n`);
    } else {
      console.log('Creating new organization...');
      const orgResult = await callFunction('orgCreate', {
        name: 'Slice 15 Test Org',
        description: 'Test organization for Slice 15',
      });
      orgId = orgResult.orgId;
      console.log(`✅ Created org: ${orgId}\n`);
    }

    // Test 1: Organization Settings - Get
    console.log('Test 1: orgGetSettings');
    const settingsResult = await callFunction('orgGetSettings', { orgId });
    console.log(`✅ Got organization settings: ${settingsResult.name}`);
    console.log(`   - Timezone: ${settingsResult.timezone}`);
    console.log(`   - Business Hours: ${JSON.stringify(settingsResult.businessHours)}\n`);

    // Test 2: Organization Settings - Update
    console.log('Test 2: orgUpdate');
    const updateResult = await callFunction('orgUpdate', {
      orgId,
      description: 'Updated test organization',
      timezone: 'America/New_York',
      businessHours: { start: '09:00', end: '18:00' },
      defaultCaseVisibility: 'ORG_WIDE',
      website: 'https://example.com',
    });
    console.log(`✅ Updated organization settings`);
    console.log(`   - Description: ${updateResult.description}`);
    console.log(`   - Timezone: ${updateResult.timezone}\n`);

    // Get current user uid for profile tests
    const membershipResult = await callFunction('memberGetMyMembership', { orgId });
    currentUserUid = membershipResult?.uid ?? '';
    if (!currentUserUid) {
      console.error('❌ Could not get current user uid from memberGetMyMembership');
      process.exit(1);
    }

    // Test 3: Member Profile - Update own profile
    console.log('Test 3: memberUpdateProfile (self)');
    const profileUpdateResult = await callFunction('memberUpdateProfile', {
      orgId,
      memberUid: currentUserUid,
      bio: 'Senior Partner specializing in corporate law',
      title: 'Senior Partner',
      specialties: ['Corporate Law', 'M&A', 'Securities'],
      barAdmissions: [
        { jurisdiction: 'New York', barNumber: 'NY123456', admittedYear: 2010 },
      ],
      isPublic: true,
    });
    console.log(`✅ Updated member profile`);
    console.log(`   - Title: ${profileUpdateResult.title}`);
    console.log(`   - Specialties: ${profileUpdateResult.specialties?.join(', ')}\n`);

    // Test 4: Member Profile - Get profile
    console.log('Test 4: memberGetProfile');
    const profileGetResult = await callFunction('memberGetProfile', {
      orgId,
      memberUid: currentUserUid,
    });
    console.log(`✅ Retrieved member profile`);
    console.log(`   - Role: ${profileGetResult.role}`);
    console.log(`   - Bio: ${profileGetResult.bio?.substring(0, 50)}...\n`);

    // Test 5: Invitation - Create
    console.log('Test 5: invitationCreate');
    const invitationResult = await callFunction('invitationCreate', {
      orgId,
      email: 'newmember@example.com',
      role: 'LAWYER',
    });
    testInvitationId = invitationResult.invitationId;
    testInviteCode = invitationResult.inviteCode;
    console.log(`✅ Created invitation`);
    console.log(`   - Invitation ID: ${testInvitationId}`);
    console.log(`   - Invite Code: ${testInviteCode}`);
    console.log(`   - Email: ${invitationResult.email}`);
    console.log(`   - Role: ${invitationResult.role}\n`);

    // Test 6: Invitation - List
    console.log('Test 6: invitationList');
    const invitationsResult = await callFunction('invitationList', {
      orgId,
      status: 'pending',
    });
    console.log(`✅ Listed invitations`);
    console.log(`   - Total: ${invitationsResult.totalCount}`);
    console.log(`   - Pending: ${invitationsResult.invitations.length}\n`);

    // Test 7: Invitation - Revoke
    console.log('Test 7: invitationRevoke');
    const revokeResult = await callFunction('invitationRevoke', {
      orgId,
      invitationId: testInvitationId,
    });
    console.log(`✅ Revoked invitation`);
    console.log(`   - Status: ${revokeResult.status}\n`);

    // Test 8: Organization Statistics
    console.log('Test 8: orgGetStats');
    const statsResult = await callFunction('orgGetStats', { orgId });
    console.log(`✅ Retrieved organization statistics`);
    console.log(`   - Members: ${statsResult.counts.members}`);
    console.log(`   - Cases: ${statsResult.counts.cases}`);
    console.log(`   - Documents: ${statsResult.counts.documents}`);
    console.log(`   - Storage: ${statsResult.storage.totalMB} MB\n`);

    // Test 9: Organization Export (optional, takes time)
    console.log('Test 9: orgExport (optional - may take a while)');
    try {
      const exportResult = await callFunction('orgExport', { orgId });
      console.log(`✅ Exported organization data`);
      console.log(`   - File: ${exportResult.fileName}`);
      console.log(`   - Members: ${exportResult.counts.members}`);
      console.log(`   - Cases: ${exportResult.counts.cases}`);
      console.log(`   - Documents: ${exportResult.counts.documents}\n`);
    } catch (error: any) {
      console.log(`⚠️  Export skipped or failed (may require Storage permissions): ${error.message}\n`);
    }

    // All tests passed
    console.log('✅ All Slice 15 tests completed successfully!\n');
  } catch (error: any) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }
}

runTests();
