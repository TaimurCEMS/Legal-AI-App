/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Audit Logging Utilities
 * Creates audit events for critical actions
 */

import * as admin from 'firebase-admin';

const db = admin.firestore();

export interface AuditEventData {
  orgId: string;
  actorUid: string;
  action: string;
  entityType: string;
  entityId: string;
  metadata?: Record<string, any>;
}

/**
 * Create an audit event
 */
export async function createAuditEvent(data: AuditEventData): Promise<void> {
  const auditRef = db
    .collection('organizations')
    .doc(data.orgId)
    .collection('audit_events')
    .doc();

  await auditRef.set({
    id: auditRef.id,
    orgId: data.orgId,
    actorUid: data.actorUid,
    action: data.action,
    entityType: data.entityType,
    entityId: data.entityId,
    timestamp: admin.firestore.Timestamp.now(),
    ...(data.metadata && { metadata: data.metadata }),
  });
}
