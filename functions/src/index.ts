/**
 * Cloud Functions Entry Point
 * Slice 0: Foundation (Auth + Org + Entitlements Engine)
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export Slice 0 callable functions
export { orgCreate, orgJoin } from './functions/org';
export { memberGetMyMembership } from './functions/member';
