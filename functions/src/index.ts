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

// Export Slice 6a - Document Text Extraction functions
export { documentExtract, documentGetExtractionStatus, extractionProcessJob } from './functions/extraction';

// Export Slice 6b - AI Chat/Research functions
export {
  aiChatCreate,
  aiChatSend,
  aiChatList,
  aiChatGetMessages,
  aiChatDelete,
} from './functions/ai-chat';

// Export Slice 7 - Calendar & Court Dates functions
export {
  eventCreate,
  eventGet,
  eventList,
  eventUpdate,
  eventDelete,
} from './functions/event';

// Export Slice 8 - Notes/Memos functions
export {
  noteCreate,
  noteGet,
  noteList,
  noteUpdate,
  noteDelete,
} from './functions/note';

// Export Slice 9 - AI Document Drafting functions
export {
  draftTemplateList,
  draftCreate,
  draftGenerate,
  draftProcessJob,
  draftGet,
  draftList,
  draftUpdate,
  draftDelete,
  draftExport,
} from './functions/draft';

// Export Slice 10 - Time Tracking functions
export {
  timeEntryCreate,
  timeEntryStartTimer,
  timeEntryStopTimer,
  timeEntryList,
  timeEntryUpdate,
  timeEntryDelete,
} from './functions/time-entry';

// Export Slice 11 - Billing & Invoicing functions
export {
  invoiceCreate,
  invoiceList,
  invoiceGet,
  invoiceUpdate,
  invoiceRecordPayment,
  invoiceExport,
} from './functions/invoice';

// Export Slice 12 - Audit Trail UI functions
export { auditList, auditExport } from './functions/audit';
