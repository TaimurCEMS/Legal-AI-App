/**
 * Task Management Functions (Slice 5 - Task Hub)
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

type TaskStatus = 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
type TaskPriority = 'LOW' | 'MEDIUM' | 'HIGH';

interface TaskDocument {
  id: string;
  orgId: string;
  caseId?: string | null;
  title: string;
  description?: string | null;
  status: TaskStatus;
  dueDate?: FirestoreTimestamp | null;
  assigneeId?: string | null;
  priority: TaskPriority;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
  deletedAt?: FirestoreTimestamp | null;
}

// Status transition matrix
const ALLOWED_TRANSITIONS: Record<TaskStatus, TaskStatus[]> = {
  PENDING: ['IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'CANCELLED', 'PENDING'],
  COMPLETED: ['CANCELLED'],
  CANCELLED: ['PENDING'],
};

function isValidStatusTransition(from: TaskStatus, to: TaskStatus): boolean {
  return ALLOWED_TRANSITIONS[from]?.includes(to) ?? false;
}

function parseTitle(rawTitle: unknown): string | null {
  if (typeof rawTitle !== 'string') return null;
  const trimmed = rawTitle.trim();
  if (!trimmed || trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function parseDescription(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length > 2000) return null;
  return trimmed || null;
}

function parseStatus(raw: unknown): TaskStatus | null {
  if (raw == null) return null;
  if (raw === 'PENDING' || raw === 'IN_PROGRESS' || raw === 'COMPLETED' || raw === 'CANCELLED') {
    return raw;
  }
  return null;
}

function parsePriority(raw: unknown): TaskPriority | null {
  if (raw == null) return 'MEDIUM';
  if (raw === 'LOW' || raw === 'MEDIUM' || raw === 'HIGH') return raw;
  return null;
}

function parseDateOnly(dateString: string | null | undefined): Date | null {
  if (!dateString || typeof dateString !== 'string') return null;
  // Parse YYYY-MM-DD format
  const parts = dateString.split('-');
  if (parts.length !== 3) return null;
  const year = parseInt(parts[0], 10);
  const month = parseInt(parts[1], 10);
  const day = parseInt(parts[2], 10);
  if (isNaN(year) || isNaN(month) || isNaN(day)) return null;
  // Create UTC date at midnight
  return new Date(Date.UTC(year, month - 1, day));
}

function validateDueDate(dueDate: Date | null, allowPast: boolean = false): { valid: boolean; error?: string } {
  if (!dueDate) return { valid: true };
  
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  dueDate.setUTCHours(0, 0, 0, 0);
  
  if (!allowPast && dueDate < today) {
    return { valid: false, error: 'Due date must be today or in the future' };
  }
  
  return { valid: true };
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

function toIsoDateOnly(ts: FirestoreTimestamp | null | undefined): string | null {
  if (!ts) return null;
  const date = ts.toDate();
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function getAssigneeName(orgId: string, assigneeId?: string | null): Promise<string | null> {
  if (!assigneeId) return null;
  
  try {
    // Check if assignee is org member
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(assigneeId);
    
    const memberDoc = await memberRef.get();
    if (!memberDoc.exists) {
      return null; // Not a member
    }
    
    // Get user info from Auth
    const userRecord = await admin.auth().getUser(assigneeId);
    return userRecord.displayName || userRecord.email || null;
  } catch (error) {
    functions.logger.warn('Error getting assignee name:', error);
    return null;
  }
}

async function verifyAssigneeIsMember(orgId: string, assigneeId: string): Promise<boolean> {
  try {
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(assigneeId);
    
    const memberDoc = await memberRef.get();
    return memberDoc.exists;
  } catch (error) {
    functions.logger.error('Error verifying assignee membership:', error);
    return false;
  }
}

async function verifyCaseExists(orgId: string, caseId: string, uid: string): Promise<{ exists: boolean; accessible: boolean }> {
  try {
    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);
    
    const caseDoc = await caseRef.get();
    if (!caseDoc.exists) {
      return { exists: false, accessible: false };
    }
    
    const caseData = caseDoc.data() as { visibility?: string; createdBy?: string; deletedAt?: FirestoreTimestamp };
    
    if (caseData.deletedAt) {
      return { exists: false, accessible: false };
    }
    
    // Check visibility
    if (caseData.visibility === 'PRIVATE' && caseData.createdBy !== uid) {
      return { exists: true, accessible: false };
    }
    
    return { exists: true, accessible: true };
  } catch (error) {
    functions.logger.error('Error verifying case:', error);
    return { exists: false, accessible: false };
  }
}

/**
 * Create a new task
 * Function Name (Export): taskCreate
 * Callable Name (Internal): task.create
 */
export const taskCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, title, description, status, dueDate, assigneeId, priority, caseId } = data || {};

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  // Validate title
  const sanitizedTitle = parseTitle(title);
  if (!sanitizedTitle) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Task title must be 1-200 characters'
    );
  }

  // Validate description
  const sanitizedDescription = parseDescription(description);
  if (description && sanitizedDescription === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Task description must be 2000 characters or less'
    );
  }

  // Validate status
  const parsedStatus = parseStatus(status);
  if (!parsedStatus) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Status must be PENDING, IN_PROGRESS, COMPLETED, or CANCELLED'
    );
  }

  // Validate priority
  const parsedPriority = parsePriority(priority);
  if (!parsedPriority) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Priority must be LOW, MEDIUM, or HIGH'
    );
  }

  // Validate dueDate
  const parsedDueDate = parseDateOnly(dueDate);
  const dueDateValidation = validateDueDate(parsedDueDate, false);
  if (!dueDateValidation.valid) {
    return errorResponse(
      ErrorCode.INVALID_DUE_DATE,
      dueDateValidation.error || 'Invalid due date'
    );
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TASKS',
      requiredPermission: 'task.create',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          "You don't have permission to create tasks"
        );
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(
          ErrorCode.PLAN_LIMIT,
          'TASKS feature not available in current plan'
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to create tasks'
      );
    }

    // Validate assignee if provided
    if (assigneeId && typeof assigneeId === 'string' && assigneeId.trim().length > 0) {
      const isValidAssignee = await verifyAssigneeIsMember(orgId, assigneeId.trim());
      if (!isValidAssignee) {
        return errorResponse(
          ErrorCode.ASSIGNEE_NOT_MEMBER,
          'Assignee must be a member of the organization'
        );
      }
    }

    // Validate case if provided
    if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
      const caseCheck = await verifyCaseExists(orgId, caseId.trim(), uid);
      if (!caseCheck.exists) {
        return errorResponse(
          ErrorCode.NOT_FOUND,
          'Case not found'
        );
      }
      if (!caseCheck.accessible) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You do not have access to this case'
        );
      }
    }

    // Create task document
    const now = admin.firestore.Timestamp.now();
    const taskRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .doc();
    
    const taskId = taskRef.id;
    
    const taskData: Omit<TaskDocument, 'id'> = {
      orgId,
      caseId: caseId && typeof caseId === 'string' && caseId.trim().length > 0 ? caseId.trim() : null,
      title: sanitizedTitle,
      description: sanitizedDescription ?? null,
      status: parsedStatus,
      dueDate: parsedDueDate ? admin.firestore.Timestamp.fromDate(parsedDueDate) : null,
      assigneeId: assigneeId && typeof assigneeId === 'string' && assigneeId.trim().length > 0 ? assigneeId.trim() : null,
      priority: parsedPriority,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      updatedBy: uid,
      deletedAt: null,
    };

    await taskRef.set({
      ...taskData,
      id: taskId,
    });

    // Get assignee name if assigned
    const assigneeName = await getAssigneeName(orgId, taskData.assigneeId);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'task.created',
      entityType: 'task',
      entityId: taskId,
      metadata: {
        title: sanitizedTitle,
        status: parsedStatus,
        priority: parsedPriority,
        caseId: taskData.caseId,
        assigneeId: taskData.assigneeId,
        dueDate: dueDate || null,
      },
    });

    return successResponse({
      taskId,
      orgId,
      caseId: taskData.caseId,
      title: sanitizedTitle,
      description: sanitizedDescription ?? null,
      status: parsedStatus,
      dueDate: toIsoDateOnly(taskData.dueDate),
      assigneeId: taskData.assigneeId,
      assigneeName,
      priority: parsedPriority,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      updatedBy: uid,
    });
  } catch (error) {
    functions.logger.error('Error creating task:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to create task'
    );
  }
});

/**
 * Get task details
 * Function Name (Export): taskGet
 * Callable Name (Internal): task.get
 */
export const taskGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, taskId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!taskId || typeof taskId !== 'string' || taskId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Task ID is required'
    );
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TASKS',
      requiredPermission: 'task.read',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to view tasks'
      );
    }

    const taskRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .doc(taskId);

    const taskSnap = await taskRef.get();
    if (!taskSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task not found'
      );
    }

    const taskData = taskSnap.data() as TaskDocument;

    if (taskData.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task not found'
      );
    }

    // Get assignee name if assigned
    const assigneeName = await getAssigneeName(orgId, taskData.assigneeId);

    return successResponse({
      taskId: taskData.id,
      orgId: taskData.orgId,
      caseId: taskData.caseId ?? null,
      title: taskData.title,
      description: taskData.description ?? null,
      status: taskData.status,
      dueDate: toIsoDateOnly(taskData.dueDate),
      assigneeId: taskData.assigneeId ?? null,
      assigneeName,
      priority: taskData.priority,
      createdAt: toIso(taskData.createdAt),
      updatedAt: toIso(taskData.updatedAt),
      createdBy: taskData.createdBy,
      updatedBy: taskData.updatedBy,
    });
  } catch (error) {
    functions.logger.error('Error getting task:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to get task'
    );
  }
});

/**
 * List tasks for an organization with filtering and pagination
 * Function Name (Export): taskList
 * Callable Name (Internal): task.list
 */
export const taskList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, limit, offset, search, status, caseId, assigneeId, priority } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const pageSize = typeof limit === 'number' ? limit : 50;
  if (pageSize < 1 || pageSize > 100) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Limit must be between 1 and 100'
    );
  }

  const pageOffset = typeof offset === 'number' ? offset : 0;
  if (pageOffset < 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Offset must be >= 0'
    );
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TASKS',
      requiredPermission: 'task.read',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to view tasks'
      );
    }

    // Build base query
    let query: admin.firestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .where('deletedAt', '==', null)
      .orderBy('updatedAt', 'desc');

    // Apply Firestore filters
    if (status && typeof status === 'string' && ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'].includes(status)) {
      query = query.where('status', '==', status);
    }
    if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
      // Verify case access
      const caseCheck = await verifyCaseExists(orgId, caseId.trim(), uid);
      if (!caseCheck.accessible) {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You do not have access to this case'
        );
      }
      query = query.where('caseId', '==', caseId.trim());
    }
    if (assigneeId && typeof assigneeId === 'string' && assigneeId.trim().length > 0) {
      query = query.where('assigneeId', '==', assigneeId.trim());
    }
    if (priority && typeof priority === 'string' && ['LOW', 'MEDIUM', 'HIGH'].includes(priority)) {
      query = query.where('priority', '==', priority);
    }

    // Fetch tasks (limit to 1000 for MVP)
    let snapshot;
    try {
      snapshot = await query.limit(1000).get();
    } catch (queryError: any) {
      // Handle Firestore index errors gracefully
      if (queryError.code === 9 || queryError.message?.includes('index') || queryError.message?.includes('FAILED_PRECONDITION')) {
        functions.logger.error('TaskList: Index required. Query:', JSON.stringify({ orgId, status, caseId, assigneeId, priority }));
        return errorResponse(
          ErrorCode.INTERNAL_ERROR,
          'Firestore index required. Please check Firebase Console for index creation link, or contact support.'
        );
      }
      throw queryError;
    }

    if (snapshot.empty) {
      return successResponse({
        tasks: [],
        total: 0,
        hasMore: false,
      });
    }

    // Convert to array and apply in-memory filters
    let tasks = snapshot.docs.map((doc) => {
      const data = doc.data() as TaskDocument;
      return {
        doc,
        data,
      };
    });

    // Apply search filter (in-memory, case-insensitive)
    if (search && typeof search === 'string' && search.trim().length > 0) {
      const searchLower = search.trim().toLowerCase();
      tasks = tasks.filter((t) => t.data.title.toLowerCase().includes(searchLower));
    }

    // Hard cap check
    if (tasks.length > 1000) {
      return errorResponse(
        ErrorCode.VALIDATION_ERROR,
        'Too many tasks. Please use filters to narrow your search.'
      );
    }

    // Apply pagination
    const total = tasks.length;
    const paginatedTasks = tasks.slice(pageOffset, pageOffset + pageSize);
    const hasMore = pageOffset + pageSize < total;

    // Batch lookup assignee names
    const assigneeIds = new Set<string>();
    paginatedTasks.forEach((t) => {
      if (t.data.assigneeId) {
        assigneeIds.add(t.data.assigneeId);
      }
    });

    const assigneeNameMap = new Map<string, string | null>();
    if (assigneeIds.size > 0) {
      try {
        const getUsersResult = await admin.auth().getUsers(
          Array.from(assigneeIds).map((id) => ({ uid: id }))
        );
        getUsersResult.users.forEach((user) => {
          assigneeNameMap.set(user.uid, user.displayName || user.email || null);
        });
      } catch (authError) {
        functions.logger.warn('Error fetching assignee names:', authError);
      }
    }

    // Build response
    const taskList = paginatedTasks.map((t) => {
      const taskData = t.data;
      return {
        taskId: taskData.id,
        orgId: taskData.orgId,
        caseId: taskData.caseId ?? null,
        title: taskData.title,
        description: taskData.description ?? null,
        status: taskData.status,
        dueDate: toIsoDateOnly(taskData.dueDate),
        assigneeId: taskData.assigneeId ?? null,
        assigneeName: taskData.assigneeId ? assigneeNameMap.get(taskData.assigneeId) ?? null : null,
        priority: taskData.priority,
        createdAt: toIso(taskData.createdAt),
        updatedAt: toIso(taskData.updatedAt),
        createdBy: taskData.createdBy,
        updatedBy: taskData.updatedBy,
      };
    });

    return successResponse({
      tasks: taskList,
      total,
      hasMore,
    });
  } catch (error) {
    functions.logger.error('Error listing tasks:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to list tasks'
    );
  }
});

/**
 * Update a task
 * Function Name (Export): taskUpdate
 * Callable Name (Internal): task.update
 */
export const taskUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, taskId, title, description, status, dueDate, assigneeId, priority, caseId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!taskId || typeof taskId !== 'string' || taskId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Task ID is required'
    );
  }

  try {
    // Check entitlement (basic update permission)
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TASKS',
      requiredPermission: 'task.update',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          "You don't have permission to update tasks"
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to update tasks'
      );
    }

    // Get existing task
    const taskRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .doc(taskId);

    const taskSnap = await taskRef.get();
    if (!taskSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task not found'
      );
    }

    const existingTask = taskSnap.data() as TaskDocument;
    if (existingTask.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task not found'
      );
    }

    // Track changes for audit
    const changes: Record<string, any> = {};
    const updateData: Partial<TaskDocument> = {};

    // Validate and apply title
    if (title !== undefined) {
      const sanitizedTitle = parseTitle(title);
      if (!sanitizedTitle) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Task title must be 1-200 characters'
        );
      }
      if (sanitizedTitle !== existingTask.title) {
        updateData.title = sanitizedTitle;
        changes.title = sanitizedTitle;
      }
    }

    // Validate and apply description
    if (description !== undefined) {
      const sanitizedDescription = description === null ? null : parseDescription(description);
      if (description !== null && sanitizedDescription === null) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Task description must be 2000 characters or less'
        );
      }
      if (sanitizedDescription !== existingTask.description) {
        updateData.description = sanitizedDescription;
        changes.description = sanitizedDescription;
      }
    }

    // Validate and apply status (with transition validation)
    if (status !== undefined) {
      const parsedStatus = parseStatus(status);
      if (!parsedStatus) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Status must be PENDING, IN_PROGRESS, COMPLETED, or CANCELLED'
        );
      }
      if (parsedStatus !== existingTask.status) {
        // Validate status transition
        if (!isValidStatusTransition(existingTask.status, parsedStatus)) {
          return errorResponse(
            ErrorCode.INVALID_STATUS_TRANSITION,
            `Invalid status transition from ${existingTask.status} to ${parsedStatus}`
          );
        }

        // Check task.complete permission if transitioning to COMPLETED
        if (parsedStatus === 'COMPLETED') {
          const completeEntitlement = await checkEntitlement({
            uid,
            orgId,
            requiredFeature: 'TASKS',
            requiredPermission: 'task.complete',
          });
          if (!completeEntitlement.allowed) {
            return errorResponse(
              ErrorCode.NOT_AUTHORIZED,
              "You don't have permission to complete tasks"
            );
          }
        }

        updateData.status = parsedStatus;
        changes.status = { from: existingTask.status, to: parsedStatus };
      }
    }

    // Validate and apply priority
    if (priority !== undefined) {
      const parsedPriority = parsePriority(priority);
      if (!parsedPriority) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Priority must be LOW, MEDIUM, or HIGH'
        );
      }
      if (parsedPriority !== existingTask.priority) {
        updateData.priority = parsedPriority;
        changes.priority = parsedPriority;
      }
    }

    // Validate and apply dueDate
    if (dueDate !== undefined) {
      const parsedDueDate = dueDate === null ? null : parseDateOnly(dueDate);
      if (dueDate !== null && !parsedDueDate) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Invalid due date format. Use YYYY-MM-DD'
        );
      }
      const dueDateValidation = validateDueDate(parsedDueDate, false);
      if (!dueDateValidation.valid) {
        return errorResponse(
          ErrorCode.INVALID_DUE_DATE,
          dueDateValidation.error || 'Invalid due date'
        );
      }
      const newDueDate = parsedDueDate ? admin.firestore.Timestamp.fromDate(parsedDueDate) : null;
      if (newDueDate?.toMillis() !== existingTask.dueDate?.toMillis()) {
        updateData.dueDate = newDueDate;
        changes.dueDate = dueDate;
      }
    }

    // Validate and apply assigneeId
    if (assigneeId !== undefined) {
      const newAssigneeId = assigneeId === null || assigneeId === '' ? null : assigneeId.trim();
      
      if (newAssigneeId !== existingTask.assigneeId) {
        // Check task.assign permission if assignee is changing
        if (newAssigneeId !== null || existingTask.assigneeId !== null) {
          const assignEntitlement = await checkEntitlement({
            uid,
            orgId,
            requiredFeature: 'TASKS',
            requiredPermission: 'task.assign',
          });
          if (!assignEntitlement.allowed) {
            return errorResponse(
              ErrorCode.NOT_AUTHORIZED,
              "You don't have permission to assign tasks"
            );
          }
        }

        // Validate assignee is member if provided
        if (newAssigneeId) {
          const isValidAssignee = await verifyAssigneeIsMember(orgId, newAssigneeId);
          if (!isValidAssignee) {
            return errorResponse(
              ErrorCode.ASSIGNEE_NOT_MEMBER,
              'Assignee must be a member of the organization'
            );
          }
        }

        updateData.assigneeId = newAssigneeId;
        changes.assigneeId = { from: existingTask.assigneeId, to: newAssigneeId };
      }
    }

    // Validate and apply caseId
    if (caseId !== undefined) {
      const newCaseId = caseId === null || caseId === '' ? null : caseId.trim();
      
      if (newCaseId !== existingTask.caseId) {
        // Validate case if provided
        if (newCaseId) {
          const caseCheck = await verifyCaseExists(orgId, newCaseId, uid);
          if (!caseCheck.exists) {
            return errorResponse(
              ErrorCode.NOT_FOUND,
              'Case not found'
            );
          }
          if (!caseCheck.accessible) {
            return errorResponse(
              ErrorCode.NOT_AUTHORIZED,
              'You do not have access to this case'
            );
          }
        }

        updateData.caseId = newCaseId;
        changes.caseId = { from: existingTask.caseId, to: newCaseId };
      }
    }

    // If no changes, return existing task
    if (Object.keys(updateData).length === 0) {
      const assigneeName = await getAssigneeName(orgId, existingTask.assigneeId);
      return successResponse({
        taskId: existingTask.id,
        orgId: existingTask.orgId,
        caseId: existingTask.caseId ?? null,
        title: existingTask.title,
        description: existingTask.description ?? null,
        status: existingTask.status,
        dueDate: toIsoDateOnly(existingTask.dueDate),
        assigneeId: existingTask.assigneeId ?? null,
        assigneeName,
        priority: existingTask.priority,
        createdAt: toIso(existingTask.createdAt),
        updatedAt: toIso(existingTask.updatedAt),
        createdBy: existingTask.createdBy,
        updatedBy: existingTask.updatedBy,
      });
    }

    // Update task
    const now = admin.firestore.Timestamp.now();
    updateData.updatedAt = now;
    updateData.updatedBy = uid;

    await taskRef.update(updateData);

    // Get updated task
    const updatedSnap = await taskRef.get();
    const updatedTask = updatedSnap.data() as TaskDocument;

    // Get assignee name
    const assigneeName = await getAssigneeName(orgId, updatedTask.assigneeId);

    // Determine audit event type
    let auditAction = 'task.updated';
    const auditMetadata: any = { taskId, changedFields: changes };

    if (changes.status?.to === 'COMPLETED') {
      auditAction = 'task.completed';
      auditMetadata.previousStatus = changes.status.from;
      auditMetadata.newStatus = changes.status.to;
      auditMetadata.completedBy = uid;
    } else if (changes.assigneeId) {
      auditAction = changes.assigneeId.from ? 'task.reassigned' : 'task.assigned';
      auditMetadata.previousAssigneeId = changes.assigneeId.from;
      auditMetadata.newAssigneeId = changes.assigneeId.to;
    } else if (changes.caseId) {
      auditAction = changes.caseId.to ? 'task.case_linked' : 'task.case_unlinked';
      auditMetadata.caseId = changes.caseId.to;
      auditMetadata.previousCaseId = changes.caseId.from;
    }

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: auditAction,
      entityType: 'task',
      entityId: taskId,
      metadata: auditMetadata,
    });

    return successResponse({
      taskId: updatedTask.id,
      orgId: updatedTask.orgId,
      caseId: updatedTask.caseId ?? null,
      title: updatedTask.title,
      description: updatedTask.description ?? null,
      status: updatedTask.status,
      dueDate: toIsoDateOnly(updatedTask.dueDate),
      assigneeId: updatedTask.assigneeId ?? null,
      assigneeName,
      priority: updatedTask.priority,
      createdAt: toIso(updatedTask.createdAt),
      updatedAt: toIso(updatedTask.updatedAt),
      createdBy: updatedTask.createdBy,
      updatedBy: updatedTask.updatedBy,
    });
  } catch (error) {
    functions.logger.error('Error updating task:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to update task'
    );
  }
});

/**
 * Delete a task (soft delete)
 * Function Name (Export): taskDelete
 * Callable Name (Internal): task.delete
 */
export const taskDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, taskId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!taskId || typeof taskId !== 'string' || taskId.trim().length === 0) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Task ID is required'
    );
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'TASKS',
      requiredPermission: 'task.delete',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          'You are not a member of this organization'
        );
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(
          ErrorCode.NOT_AUTHORIZED,
          "You don't have permission to delete tasks"
        );
      }
      return errorResponse(
        ErrorCode.NOT_AUTHORIZED,
        'Not authorized to delete tasks'
      );
    }

    const taskRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('tasks')
      .doc(taskId);

    const taskSnap = await taskRef.get();
    if (!taskSnap.exists) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task not found'
      );
    }

    const taskData = taskSnap.data() as TaskDocument;

    if (taskData.deletedAt) {
      return errorResponse(
        ErrorCode.NOT_FOUND,
        'Task already deleted'
      );
    }

    // Soft delete
    const now = admin.firestore.Timestamp.now();
    await taskRef.update({
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
    });

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'task.deleted',
      entityType: 'task',
      entityId: taskId,
      metadata: {
        title: taskData.title,
        status: taskData.status,
        caseId: taskData.caseId,
        assigneeId: taskData.assigneeId,
      },
    });

    return successResponse({
      taskId,
      message: 'Task deleted successfully',
    });
  } catch (error) {
    functions.logger.error('Error deleting task:', error);
    return errorResponse(
      ErrorCode.INTERNAL_ERROR,
      'Failed to delete task'
    );
  }
});
