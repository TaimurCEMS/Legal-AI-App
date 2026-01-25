/**
 * Cloud Functions Entry Point
 * Slice 0: Foundation (Auth + Org + Entitlements Engine)
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export Slice 0 callable functions
export { orgCreate, orgJoin } from './functions/org';
export { memberGetMyMembership, memberListMyOrgs, memberListMembers, memberUpdateRole } from './functions/member';

// Export Slice 2 - Case Hub callable functions
export { caseCreate, caseGet, caseList, caseUpdate, caseDelete } from './functions/case';
export {
  caseListParticipants,
  caseAddParticipant,
  caseRemoveParticipant,
} from './functions/case-participants';

// Export Slice 3 - Client Hub callable functions
export { clientCreate, clientGet, clientList, clientUpdate, clientDelete } from './functions/client';

// Export Slice 4 - Document Hub callable functions
export { documentCreate, documentGet, documentList, documentUpdate, documentDelete } from './functions/document';

// Export Slice 5 - Task Hub callable functions
export { taskCreate, taskGet, taskList, taskUpdate, taskDelete } from './functions/task';
