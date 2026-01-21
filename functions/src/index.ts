/**
 * Cloud Functions Entry Point
 * Slice 0: Foundation (Auth + Org + Entitlements Engine)
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export Slice 0 callable functions
export { orgCreate, orgJoin } from './functions/org';
export { memberGetMyMembership, memberListMyOrgs } from './functions/member';

// Export Slice 2 - Case Hub callable functions
export { caseCreate, caseGet, caseList, caseUpdate, caseDelete } from './functions/case';

// Export Slice 3 - Client Hub callable functions
export { clientCreate, clientGet, clientList, clientUpdate, clientDelete } from './functions/client';
