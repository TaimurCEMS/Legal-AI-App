/**
 * Admin Functions (Slice 15)
 * Organization-level admin operations (export, statistics)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';

const db = admin.firestore();
const storage = admin.storage();

/**
 * Export all organization data to JSON
 * Callable Name: orgExport
 */
export const orgExport = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.data_export',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can export organization data'
      );
    }

    // Get organization details
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Organization does not exist');
    }

    const orgData = orgDoc.data()!;

    functions.logger.info(`Starting data export for organization: ${orgId}`);

    // Export data structure
    const exportData: any = {
      exportedAt: new Date().toISOString(),
      exportedBy: uid,
      organization: {
        orgId,
        name: orgData.name,
        description: orgData.description || null,
        plan: orgData.plan || 'FREE',
        createdAt: orgData.createdAt?.toDate()?.toISOString() || null,
      },
      members: [],
      cases: [],
      clients: [],
      documents: [],
      tasks: [],
      events: [],
      notes: [],
      timeEntries: [],
      invoices: [],
      auditEvents: [],
    };

    // Export members (anonymized sensitive data)
    const membersSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .get();

    for (const memberDoc of membersSnapshot.docs) {
      const memberData = memberDoc.data();
      exportData.members.push({
        uid: memberDoc.id,
        role: memberData.role,
        joinedAt: memberData.joinedAt?.toDate()?.toISOString() || null,
      });
    }

    // Export cases
    const casesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .get();

    for (const caseDoc of casesSnapshot.docs) {
      const caseData = caseDoc.data();
      exportData.cases.push({
        caseId: caseDoc.id,
        title: caseData.title,
        description: caseData.description || null,
        status: caseData.status,
        visibility: caseData.visibility,
        clientId: caseData.clientId || null,
        createdAt: caseData.createdAt?.toDate()?.toISOString() || null,
        createdBy: caseData.createdBy,
        isDeleted: caseData.isDeleted || false,
      });
    }

    // Export clients
    const clientsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('clients')
      .get();

    for (const clientDoc of clientsSnapshot.docs) {
      const clientData = clientDoc.data();
      exportData.clients.push({
        clientId: clientDoc.id,
        name: clientData.name,
        email: clientData.email || null,
        phone: clientData.phone || null,
        address: clientData.address || null,
        createdAt: clientData.createdAt?.toDate()?.toISOString() || null,
        isDeleted: clientData.isDeleted || false,
      });
    }

    // Export documents (metadata only, not file contents)
    const documentsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .get();

    for (const docDoc of documentsSnapshot.docs) {
      const docData = docDoc.data();
      exportData.documents.push({
        documentId: docDoc.id,
        name: docData.name,
        caseId: docData.caseId || null,
        storagePath: docData.storagePath || null,
        fileSize: docData.fileSize || null,
        mimeType: docData.mimeType || null,
        category: docData.category || null,
        uploadedAt: docData.uploadedAt?.toDate()?.toISOString() || null,
        uploadedBy: docData.uploadedBy,
        isDeleted: docData.isDeleted || false,
      });
    }

    // Export tasks
    const tasksSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .get();

    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      exportData.tasks.push({
        taskId: taskDoc.id,
        title: taskData.title,
        description: taskData.description || null,
        status: taskData.status,
        priority: taskData.priority || null,
        caseId: taskData.caseId || null,
        assignedTo: taskData.assignedTo || null,
        dueDate: taskData.dueDate || null,
        createdAt: taskData.createdAt?.toDate()?.toISOString() || null,
        isDeleted: taskData.isDeleted || false,
      });
    }

    // Export events
    const eventsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('events')
      .get();

    for (const eventDoc of eventsSnapshot.docs) {
      const eventData = eventDoc.data();
      exportData.events.push({
        eventId: eventDoc.id,
        title: eventData.title,
        description: eventData.description || null,
        eventType: eventData.eventType,
        status: eventData.status || null,
        caseId: eventData.caseId || null,
        startAt: eventData.startAt?.toDate()?.toISOString() || null,
        endAt: eventData.endAt?.toDate()?.toISOString() || null,
        createdAt: eventData.createdAt?.toDate()?.toISOString() || null,
        isDeleted: eventData.isDeleted || false,
      });
    }

    // Export notes
    const notesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('notes')
      .get();

    for (const noteDoc of notesSnapshot.docs) {
      const noteData = noteDoc.data();
      exportData.notes.push({
        noteId: noteDoc.id,
        title: noteData.title,
        content: noteData.content || null,
        caseId: noteData.caseId || null,
        category: noteData.category || null,
        isPinned: noteData.isPinned || false,
        isPrivate: noteData.isPrivate || false,
        createdAt: noteData.createdAt?.toDate()?.toISOString() || null,
        createdBy: noteData.createdBy,
        isDeleted: noteData.isDeleted || false,
      });
    }

    // Export time entries
    const timeEntriesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('timeEntries')
      .get();

    for (const timeEntryDoc of timeEntriesSnapshot.docs) {
      const timeEntryData = timeEntryDoc.data();
      exportData.timeEntries.push({
        timeEntryId: timeEntryDoc.id,
        caseId: timeEntryData.caseId || null,
        description: timeEntryData.description || null,
        durationMinutes: timeEntryData.durationMinutes,
        isBillable: timeEntryData.isBillable || false,
        createdBy: timeEntryData.createdBy,
        date: timeEntryData.date || null,
        createdAt: timeEntryData.createdAt?.toDate()?.toISOString() || null,
        isDeleted: timeEntryData.isDeleted || false,
      });
    }

    // Export invoices
    const invoicesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('invoices')
      .get();

    for (const invoiceDoc of invoicesSnapshot.docs) {
      const invoiceData = invoiceDoc.data();
      exportData.invoices.push({
        invoiceId: invoiceDoc.id,
        caseId: invoiceData.caseId || null,
        clientId: invoiceData.clientId || null,
        status: invoiceData.status,
        totalAmount: invoiceData.totalAmount || 0,
        paidAmount: invoiceData.paidAmount || 0,
        createdAt: invoiceData.createdAt?.toDate()?.toISOString() || null,
        dueAt: invoiceData.dueAt?.toDate()?.toISOString() || null,
      });
    }

    // Export audit events (last 1000)
    const auditEventsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('audit_events')
      .orderBy('timestamp', 'desc')
      .limit(1000)
      .get();

    for (const auditDoc of auditEventsSnapshot.docs) {
      const auditData = auditDoc.data();
      exportData.auditEvents.push({
        eventId: auditDoc.id,
        action: auditData.action,
        entityType: auditData.entityType,
        entityId: auditData.entityId,
        actorUid: auditData.actorUid,
        timestamp: auditData.timestamp?.toDate()?.toISOString() || null,
        metadata: auditData.metadata || null,
      });
    }

    // Convert to JSON
    const jsonData = JSON.stringify(exportData, null, 2);

    // Upload to Storage
    const bucket = storage.bucket();
    const fileName = `exports/${orgId}/org-export-${Date.now()}.json`;
    const file = bucket.file(fileName);

    await file.save(jsonData, {
      contentType: 'application/json',
      metadata: {
        metadata: {
          exportedBy: uid,
          exportedAt: new Date().toISOString(),
          orgId,
        },
      },
    });

    // Generate signed URL (valid for 1 hour)
    let signedUrl: string;
    try {
      const [url] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 60 * 60 * 1000, // 1 hour
      });
      signedUrl = url;
    } catch (signError: any) {
      const signMsg = signError?.message ?? String(signError);
      functions.logger.error('orgExport getSignedUrl failed:', signError);
      if (
        signMsg.includes('permission') ||
        signMsg.includes('sign') ||
        signMsg.includes('credentials') ||
        signMsg.includes('Sign')
      ) {
        return errorResponse(
          ErrorCode.INTERNAL_ERROR,
          'Export file was created but the download link could not be generated. ' +
            'Enable IAM Service Account Credentials API and grant the Cloud Functions service account the "Service Account Token Creator" role in Google Cloud Console.'
        );
      }
      throw signError;
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'org.data.exported',
      entityType: 'organization',
      entityId: orgId,
      metadata: {
        fileName,
        membersCount: exportData.members.length,
        casesCount: exportData.cases.length,
        documentsCount: exportData.documents.length,
      },
    });

    functions.logger.info(`Data export completed for organization: ${orgId}`);

    return successResponse({
      downloadUrl: signedUrl,
      fileName,
      exportedAt: exportData.exportedAt,
      counts: {
        members: exportData.members.length,
        cases: exportData.cases.length,
        clients: exportData.clients.length,
        documents: exportData.documents.length,
        tasks: exportData.tasks.length,
        events: exportData.events.length,
        notes: exportData.notes.length,
        timeEntries: exportData.timeEntries.length,
        invoices: exportData.invoices.length,
        auditEvents: exportData.auditEvents.length,
      },
    });
  } catch (error: any) {
    const msg = error?.message ?? String(error);
    functions.logger.error('Error exporting organization data:', error);
    if (msg.includes('permission') || msg.includes('sign') || msg.includes('credentials')) {
      return errorResponse(
        ErrorCode.INTERNAL_ERROR,
        'Export failed: storage signing not configured. Grant the Cloud Functions service account "Service Account Token Creator" and ensure IAM Service Account Credentials API is enabled.'
      );
    }
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to export organization data. Check Cloud Functions logs for details.'
    );
  }
});

/**
 * Get organization statistics
 * Callable Name: orgGetStats
 */
export const orgGetStats = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;
  const { orgId } = data;

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  try {
    // Check entitlement: ADMIN only
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredPermission: 'admin.view_stats',
    });

    if (!entitlement.allowed) {
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Only administrators can view organization statistics'
      );
    }

    // Get organization details
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();

    if (!orgDoc.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Organization does not exist');
    }

    const orgData = orgDoc.data()!;

    functions.logger.info(`Fetching statistics for organization: ${orgId}`);

    // Get counts for all entities
    const [
      membersCount,
      casesCount,
      clientsCount,
      documentsCount,
      tasksCount,
      eventsCount,
      notesCount,
      timeEntriesCount,
      invoicesCount,
    ] = await Promise.all([
      db.collection('organizations').doc(orgId).collection('members').count().get(),
      db.collection('organizations').doc(orgId).collection('cases').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('clients').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('documents').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('tasks').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('events').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('notes').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('timeEntries').where('isDeleted', '==', false).count().get(),
      db.collection('organizations').doc(orgId).collection('invoices').count().get(),
    ]);

    // Get activity metrics (last 30 days)
    const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 24 * 60 * 60 * 1000
    );

    const [
      recentCasesCount,
      recentDocumentsCount,
      recentTasksCount,
      recentEventsCount,
    ] = await Promise.all([
      db.collection('organizations').doc(orgId).collection('cases')
        .where('createdAt', '>=', thirtyDaysAgo)
        .count()
        .get(),
      db.collection('organizations').doc(orgId).collection('documents')
        .where('uploadedAt', '>=', thirtyDaysAgo)
        .count()
        .get(),
      db.collection('organizations').doc(orgId).collection('tasks')
        .where('createdAt', '>=', thirtyDaysAgo)
        .count()
        .get(),
      db.collection('organizations').doc(orgId).collection('events')
        .where('createdAt', '>=', thirtyDaysAgo)
        .count()
        .get(),
    ]);

    // Calculate storage usage (sum of all document file sizes)
    const documentsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('documents')
      .where('isDeleted', '==', false)
      .select('fileSize')
      .get();

    let totalStorageBytes = 0;
    documentsSnapshot.forEach((doc) => {
      const fileSize = doc.data().fileSize || 0;
      totalStorageBytes += fileSize;
    });

    // Convert bytes to MB
    const totalStorageMB = Math.round((totalStorageBytes / (1024 * 1024)) * 100) / 100;

    return successResponse({
      orgId,
      orgName: orgData.name,
      plan: orgData.plan || 'FREE',
      counts: {
        members: membersCount.data().count,
        cases: casesCount.data().count,
        clients: clientsCount.data().count,
        documents: documentsCount.data().count,
        tasks: tasksCount.data().count,
        events: eventsCount.data().count,
        notes: notesCount.data().count,
        timeEntries: timeEntriesCount.data().count,
        invoices: invoicesCount.data().count,
      },
      recentActivity: {
        last30Days: {
          casesCreated: recentCasesCount.data().count,
          documentsUploaded: recentDocumentsCount.data().count,
          tasksCreated: recentTasksCount.data().count,
          eventsCreated: recentEventsCount.data().count,
        },
      },
      storage: {
        totalMB: totalStorageMB,
        totalBytes: totalStorageBytes,
      },
    });
  } catch (error: any) {
    functions.logger.error('Error getting organization statistics:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to get organization statistics');
  }
});
