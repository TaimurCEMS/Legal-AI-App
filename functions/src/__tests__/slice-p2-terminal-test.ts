/**
 * P2 Notification Engine Terminal Test
 * Tests deployed notification callables (list, unread count, preferences, mark read).
 *
 * Run: npm run test:p2
 * Requires: WEB_API_KEY or FIREBASE_API_KEY in env (or .env), test user credentials.
 */
import 'dotenv/config';
import axios from 'axios';

const REGION = 'us-central1';
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'legal-ai-app-1203e';
const FIREBASE_API_KEY = process.env.WEB_API_KEY || process.env.FIREBASE_API_KEY;

if (!FIREBASE_API_KEY) {
  console.error('❌ WEB_API_KEY or FIREBASE_API_KEY required (e.g. in functions/.env)');
  process.exit(1);
}

const TEST_EMAIL = process.env.TEST_EMAIL || 'test@example.com';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'testpassword123';

let idToken: string = '';
let orgId: string = '';

async function signIn(email: string, password: string): Promise<string> {
  const response = await axios.post(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
    { email, password, returnSecureToken: true }
  );
  return response.data.idToken;
}

async function callFunction(functionName: string, data: Record<string, unknown>): Promise<unknown> {
  const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${functionName}`;
  const response = await axios.post(url, { data }, {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
  });
  return response.data.result;
}

async function runTests(): Promise<void> {
  console.log('🚀 P2 Notification Engine Terminal Test\n');

  try {
    console.log('1️⃣  Signing in...');
    idToken = await signIn(TEST_EMAIL, TEST_PASSWORD);
    console.log('✅ Signed in\n');

    console.log('2️⃣  Getting organization...');
    const orgsResult = (await callFunction('memberListMyOrgs', {})) as { orgs?: { orgId: string }[] };
    if (!orgsResult?.orgs?.length) {
      const createResult = (await callFunction('orgCreate', {
        name: 'P2 Test Org',
        description: 'P2 notification test',
      })) as { orgId: string };
      orgId = createResult.orgId;
      console.log(`✅ Created org: ${orgId}\n`);
    } else {
      orgId = orgsResult.orgs[0].orgId;
      console.log(`✅ Using org: ${orgId}\n`);
    }

    // notificationUnreadCount
    console.log('3️⃣  notificationUnreadCount');
    const countResult = (await callFunction('notificationUnreadCount', { orgId })) as { count?: number };
    if (typeof countResult?.count !== 'number') {
      throw new Error('notificationUnreadCount: expected { count: number }');
    }
    console.log(`✅ Unread count: ${countResult.count}\n`);

    // notificationList
    console.log('4️⃣  notificationList');
    const listResult = (await callFunction('notificationList', { orgId, limit: 20 })) as { notifications?: unknown[] };
    if (!Array.isArray(listResult?.notifications)) {
      throw new Error('notificationList: expected { notifications: array }');
    }
    console.log(`✅ Notifications: ${listResult.notifications.length} items\n`);

    // notificationPreferencesGet
    console.log('5️⃣  notificationPreferencesGet');
    const prefsResult = (await callFunction('notificationPreferencesGet', { orgId })) as { preferences?: Record<string, { inApp: boolean; email: boolean }> };
    if (typeof prefsResult?.preferences !== 'object') {
      throw new Error('notificationPreferencesGet: expected { preferences: object }');
    }
    const categories = Object.keys(prefsResult.preferences);
    console.log(`✅ Preferences: ${categories.length} categories (${categories.slice(0, 3).join(', ')}...)\n`);

    // notificationPreferencesUpdate (toggle matter email off then on)
    console.log('6️⃣  notificationPreferencesUpdate');
    const updateResult = (await callFunction('notificationPreferencesUpdate', {
      orgId,
      category: 'matter',
      email: false,
    })) as { preferences?: Record<string, { email: boolean }> };
    if (typeof updateResult?.preferences !== 'object') {
      throw new Error('notificationPreferencesUpdate: expected { preferences: object }');
    }
    const matterPref = updateResult.preferences?.matter;
    if (matterPref && matterPref.email !== false) {
      throw new Error('notificationPreferencesUpdate: expected matter.email === false');
    }
    await callFunction('notificationPreferencesUpdate', { orgId, category: 'matter', email: true });
    console.log('✅ Updated matter email pref, then restored\n');

    // notificationMarkAllRead (idempotent)
    console.log('7️⃣  notificationMarkAllRead');
    const markResult = (await callFunction('notificationMarkAllRead', { orgId })) as { marked?: number };
    if (typeof markResult?.marked !== 'number') {
      throw new Error('notificationMarkAllRead: expected { marked: number }');
    }
    console.log(`✅ Marked ${markResult.marked} as read\n`);

    // notificationUnreadCount again (should be 0 if we had any)
    const countAfter = (await callFunction('notificationUnreadCount', { orgId })) as { count?: number };
    console.log(`8️⃣  Unread count after mark all read: ${countAfter.count}\n`);

    console.log('──────────────────────────────────────────────────');
    console.log('✅ P2 notification tests passed (8 steps)\n');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('\n❌ P2 test failed:', message);
    if (axios.isAxiosError(err) && err.response?.data) {
      console.error('Response:', JSON.stringify(err.response.data, null, 2));
    }
    process.exit(1);
  }
}

runTests();
