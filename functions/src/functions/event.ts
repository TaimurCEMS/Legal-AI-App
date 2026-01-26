/**
 * Calendar & Court Dates Functions (Slice 7)
 *
 * These functions manage calendar events for legal professionals including:
 * - Court dates, hearings, filing deadlines
 * - Statute of limitations tracking
 * - Meetings and consultations
 * - Reminders via FCM push notifications
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { createAuditEvent } from '../utils/audit';
import { canUserAccessCase } from '../utils/case-access';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

// Event types for legal workflows
type EventType =
  | 'COURT_DATE'
  | 'HEARING'
  | 'FILING_DEADLINE'
  | 'STATUTE_LIMITATION'
  | 'MEETING'
  | 'CONSULTATION'
  | 'DEPOSITION'
  | 'MEDIATION'
  | 'ARBITRATION'
  | 'OTHER';

type EventStatus = 'SCHEDULED' | 'COMPLETED' | 'CANCELLED';
type EventPriority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
type EventVisibility = 'ORG' | 'CASE_ONLY' | 'PRIVATE';

interface Reminder {
  minutesBefore: number;
}

interface Recurrence {
  frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
  interval: number;
  endDate?: FirestoreTimestamp;
  count?: number;
}

interface EventException {
  title?: string;
  description?: string;
  startDateTime?: FirestoreTimestamp;
  endDateTime?: FirestoreTimestamp;
  location?: string;
  status?: EventStatus;
  isCancelled?: boolean;
}

interface EventDocument {
  eventId: string;
  orgId: string;
  caseId: string | null;
  title: string;
  description: string | null;
  eventType: EventType;
  startDateTime: FirestoreTimestamp;
  endDateTime: FirestoreTimestamp | null;
  allDay: boolean;
  location: string | null;
  attendeeUids: string[];
  reminders: Reminder[];
  recurrence: Recurrence | null;
  priority: EventPriority;
  notes: string | null;
  status: EventStatus;
  visibility: EventVisibility;
  exceptions?: { [instanceDateKey: string]: EventException };
  recurringParentId?: string;
  recurringEndedAt?: FirestoreTimestamp;
  deletedAt: FirestoreTimestamp | null;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
}

// Valid event types
const VALID_EVENT_TYPES: EventType[] = [
  'COURT_DATE',
  'HEARING',
  'FILING_DEADLINE',
  'STATUTE_LIMITATION',
  'MEETING',
  'CONSULTATION',
  'DEPOSITION',
  'MEDIATION',
  'ARBITRATION',
  'OTHER',
];

// Valid reminder values (in minutes)
const VALID_REMINDER_MINUTES = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080];

// Default priority based on event type
function getDefaultPriority(eventType: EventType): EventPriority {
  switch (eventType) {
    case 'COURT_DATE':
    case 'FILING_DEADLINE':
    case 'STATUTE_LIMITATION':
      return 'CRITICAL';
    case 'HEARING':
    case 'DEPOSITION':
    case 'MEDIATION':
    case 'ARBITRATION':
      return 'HIGH';
    default:
      return 'MEDIUM';
  }
}

// Status transitions
const ALLOWED_STATUS_TRANSITIONS: Record<EventStatus, EventStatus[]> = {
  SCHEDULED: ['COMPLETED', 'CANCELLED'],
  COMPLETED: ['SCHEDULED', 'CANCELLED'],
  CANCELLED: ['SCHEDULED'],
};

function isValidStatusTransition(from: EventStatus, to: EventStatus): boolean {
  return ALLOWED_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
}

// Parsing and validation helpers
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

function parseLocation(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length > 500) return null;
  return trimmed || null;
}

function parseNotes(raw: unknown): string | null {
  if (raw == null) return null;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length > 1000) return null;
  return trimmed || null;
}

function parseEventType(raw: unknown): EventType | null {
  if (typeof raw !== 'string') return null;
  if (VALID_EVENT_TYPES.includes(raw as EventType)) {
    return raw as EventType;
  }
  return null;
}

function parseStatus(raw: unknown): EventStatus | null {
  if (raw == null) return 'SCHEDULED';
  if (raw === 'SCHEDULED' || raw === 'COMPLETED' || raw === 'CANCELLED') {
    return raw;
  }
  return null;
}

function parsePriority(raw: unknown): EventPriority | null {
  if (raw == null) return null; // Will use default based on event type
  if (raw === 'LOW' || raw === 'MEDIUM' || raw === 'HIGH' || raw === 'CRITICAL') {
    return raw;
  }
  return null;
}

function parseVisibility(raw: unknown): EventVisibility {
  if (raw === 'ORG' || raw === 'CASE_ONLY' || raw === 'PRIVATE') {
    return raw;
  }
  return 'ORG';
}

function parseDateTime(raw: unknown): Date | null {
  if (typeof raw !== 'string') return null;
  try {
    const date = new Date(raw);
    if (isNaN(date.getTime())) return null;
    return date;
  } catch {
    return null;
  }
}

function parseReminders(raw: unknown): Reminder[] | null {
  if (raw == null) return [];
  if (!Array.isArray(raw)) return null;
  if (raw.length > 3) return null; // Max 3 reminders

  const reminders: Reminder[] = [];
  for (const r of raw) {
    if (typeof r !== 'object' || r === null) return null;
    const minutesBefore = (r as any).minutesBefore;
    if (typeof minutesBefore !== 'number') return null;
    if (!VALID_REMINDER_MINUTES.includes(minutesBefore)) return null;
    reminders.push({ minutesBefore });
  }
  return reminders;
}

function parseRecurrence(raw: unknown): Recurrence | null {
  if (raw == null) return null;
  if (typeof raw !== 'object') return null;

  const r = raw as any;
  const validFrequencies = ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'];
  if (!validFrequencies.includes(r.frequency)) return null;

  const interval = typeof r.interval === 'number' ? r.interval : 1;
  if (interval < 1 || interval > 365) return null;

  const recurrence: Recurrence = {
    frequency: r.frequency,
    interval,
  };

  if (r.endDate) {
    const endDate = parseDateTime(r.endDate);
    if (endDate) {
      recurrence.endDate = admin.firestore.Timestamp.fromDate(endDate);
    }
  }

  if (typeof r.count === 'number' && r.count > 0) {
    recurrence.count = Math.min(r.count, 365); // Cap at 365
  }

  return recurrence;
}

function parseAttendeeUids(raw: unknown, creatorUid: string): string[] {
  const attendees = new Set<string>();
  attendees.add(creatorUid); // Creator is always an attendee

  if (Array.isArray(raw)) {
    for (const uid of raw) {
      if (typeof uid === 'string' && uid.trim().length > 0) {
        attendees.add(uid.trim());
      }
    }
  }

  return Array.from(attendees);
}

// Convert Timestamp to ISO string
function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

// Format date key for recurring exceptions: "YYYY-MM-DD"
function formatDateKey(date: Date): string {
  return date.toISOString().split('T')[0];
}

// Get case name and status for response
async function getCaseInfo(
  orgId: string,
  caseId: string | null
): Promise<{ caseName: string | null; caseStatus: string | null }> {
  if (!caseId) return { caseName: null, caseStatus: null };

  try {
    const caseRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('cases')
      .doc(caseId);
    const caseSnap = await caseRef.get();

    if (!caseSnap.exists) return { caseName: null, caseStatus: null };

    const caseData = caseSnap.data() as { title?: string; status?: string };
    return {
      caseName: caseData?.title ?? null,
      caseStatus: caseData?.status ?? null,
    };
  } catch (error) {
    functions.logger.warn('Error getting case info:', error);
    return { caseName: null, caseStatus: null };
  }
}

// Verify attendees are org members
async function verifyAttendeesAreMember(
  orgId: string,
  attendeeUids: string[]
): Promise<{ valid: boolean; invalidUids: string[] }> {
  const invalidUids: string[] = [];

  for (const uid of attendeeUids) {
    const memberRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('members')
      .doc(uid);
    const memberSnap = await memberRef.get();
    if (!memberSnap.exists) {
      invalidUids.push(uid);
    }
  }

  return { valid: invalidUids.length === 0, invalidUids };
}

// Create scheduled reminders for an event
async function createScheduledReminders(
  orgId: string,
  eventId: string,
  event: {
    title: string;
    startDateTime: FirestoreTimestamp;
    location: string | null;
    eventType: EventType;
    attendeeUids: string[];
    reminders: Reminder[];
  }
): Promise<void> {
  if (event.reminders.length === 0 || event.attendeeUids.length === 0) return;

  const batch = db.batch();
  const remindersRef = db
    .collection('organizations')
    .doc(orgId)
    .collection('scheduledReminders');

  for (const reminder of event.reminders) {
    for (const recipientUid of event.attendeeUids) {
      const scheduledFor = new Date(event.startDateTime.toDate());
      scheduledFor.setMinutes(scheduledFor.getMinutes() - reminder.minutesBefore);

      // Don't schedule reminders in the past
      if (scheduledFor <= new Date()) continue;

      const reminderDoc = remindersRef.doc();
      batch.set(reminderDoc, {
        reminderId: reminderDoc.id,
        eventId,
        orgId,
        scheduledFor: admin.firestore.Timestamp.fromDate(scheduledFor),
        sent: false,
        recipientUid,
        eventTitle: event.title,
        eventStartDateTime: event.startDateTime,
        eventLocation: event.location,
        eventType: event.eventType,
      });
    }
  }

  await batch.commit();
}

// Delete scheduled reminders for an event
async function deleteScheduledReminders(orgId: string, eventId: string): Promise<void> {
  const remindersRef = db
    .collection('organizations')
    .doc(orgId)
    .collection('scheduledReminders');

  const snapshot = await remindersRef.where('eventId', '==', eventId).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

// Maximum recurring instances to expand per query
const MAX_RECURRING_INSTANCES = 365;

// Expand recurring events within a date range
function expandRecurringEvent(
  event: EventDocument,
  startDate: Date,
  endDate: Date
): Array<EventDocument & { isRecurringInstance: boolean; instanceDate: string }> {
  if (!event.recurrence) {
    return [
      {
        ...event,
        isRecurringInstance: false,
        instanceDate: formatDateKey(event.startDateTime.toDate()),
      },
    ];
  }

  const instances: Array<
    EventDocument & { isRecurringInstance: boolean; instanceDate: string }
  > = [];

  let current = event.startDateTime.toDate();
  const recurrenceEnd = event.recurrence.endDate
    ? event.recurrence.endDate.toDate()
    : endDate;

  let count = 0;
  while (current <= recurrenceEnd && current <= endDate && count < MAX_RECURRING_INSTANCES) {
    const instanceDateKey = formatDateKey(current);
    const exception = event.exceptions?.[instanceDateKey];

    // Skip cancelled instances
    if (exception?.isCancelled) {
      current = getNextOccurrence(current, event.recurrence);
      continue;
    }

    if (current >= startDate) {
      instances.push({
        ...event,
        // Apply exception overrides if present
        title: exception?.title ?? event.title,
        startDateTime: exception?.startDateTime ?? admin.firestore.Timestamp.fromDate(current),
        location: exception?.location ?? event.location,
        status: exception?.status ?? event.status,
        isRecurringInstance: true,
        instanceDate: instanceDateKey,
      });
    }

    current = getNextOccurrence(current, event.recurrence);
    count++;
  }

  return instances;
}

// Get next occurrence based on recurrence pattern
function getNextOccurrence(current: Date, recurrence: Recurrence): Date {
  const next = new Date(current);

  switch (recurrence.frequency) {
    case 'DAILY':
      next.setDate(next.getDate() + recurrence.interval);
      break;
    case 'WEEKLY':
      next.setDate(next.getDate() + 7 * recurrence.interval);
      break;
    case 'MONTHLY':
      next.setMonth(next.getMonth() + recurrence.interval);
      break;
    case 'YEARLY':
      next.setFullYear(next.getFullYear() + recurrence.interval);
      break;
  }

  return next;
}

// Build cursor for pagination
function buildCursor(event: EventDocument): string {
  return `${toIso(event.startDateTime)}_${event.eventId}`;
}

// Parse cursor for pagination
function parseCursor(cursor: string): { startDateTime: Date; eventId: string } | null {
  const parts = cursor.split('_');
  if (parts.length < 2) return null;

  const eventId = parts.pop()!;
  const dateStr = parts.join('_');

  try {
    const startDateTime = new Date(dateStr);
    if (isNaN(startDateTime.getTime())) return null;
    return { startDateTime, eventId };
  } catch {
    return null;
  }
}

/**
 * Create a new calendar event
 * Function Name (Export): eventCreate
 */
export const eventCreate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    caseId,
    title,
    description,
    eventType,
    startDateTime,
    endDateTime,
    allDay,
    location,
    attendeeUids,
    reminders,
    recurrence,
    priority,
    notes,
    visibility,
  } = data || {};

  // Validate orgId
  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  // Validate title
  const sanitizedTitle = parseTitle(title);
  if (!sanitizedTitle) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Event title must be 1-200 characters');
  }

  // Validate description
  const sanitizedDescription = parseDescription(description);
  if (description && sanitizedDescription === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Event description must be 2000 characters or less'
    );
  }

  // Validate event type
  const parsedEventType = parseEventType(eventType);
  if (!parsedEventType) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `Event type must be one of: ${VALID_EVENT_TYPES.join(', ')}`
    );
  }

  // Validate startDateTime
  const parsedStartDateTime = parseDateTime(startDateTime);
  if (!parsedStartDateTime) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      'Start date/time is required and must be a valid ISO 8601 date'
    );
  }

  // Validate endDateTime (optional, must be after start)
  let parsedEndDateTime: Date | null = null;
  if (endDateTime !== undefined && endDateTime !== null) {
    parsedEndDateTime = parseDateTime(endDateTime);
    if (!parsedEndDateTime) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'End date/time must be a valid ISO 8601 date');
    }
    if (parsedEndDateTime <= parsedStartDateTime) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'End date/time must be after start date/time');
    }
  }

  // Validate location
  const sanitizedLocation = parseLocation(location);
  if (location && sanitizedLocation === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Location must be 500 characters or less');
  }

  // Validate notes
  const sanitizedNotes = parseNotes(notes);
  if (notes && sanitizedNotes === null) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Notes must be 1000 characters or less');
  }

  // Validate reminders
  const parsedReminders = parseReminders(reminders);
  if (parsedReminders === null) {
    return errorResponse(
      ErrorCode.VALIDATION_ERROR,
      `Reminders must be an array of max 3 items with valid minutesBefore values: ${VALID_REMINDER_MINUTES.join(', ')}`
    );
  }

  // Validate recurrence
  const parsedRecurrence = parseRecurrence(recurrence);

  // Parse priority (use default if not provided)
  let parsedPriority = parsePriority(priority);
  if (parsedPriority === null) {
    parsedPriority = getDefaultPriority(parsedEventType);
  }

  // Parse visibility
  const parsedVisibility = parseVisibility(visibility);

  // Parse allDay flag
  const isAllDay = allDay === true;

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CALENDAR',
      requiredPermission: 'event.create',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, "You don't have permission to create events");
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'Calendar feature not available in current plan');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to create events');
    }

    // Parse and validate attendees
    const parsedAttendeeUids = parseAttendeeUids(attendeeUids, uid);

    // Verify all attendees are org members
    const attendeeCheck = await verifyAttendeesAreMember(orgId, parsedAttendeeUids);
    if (!attendeeCheck.valid) {
      return errorResponse(
        ErrorCode.ASSIGNEE_NOT_MEMBER,
        `The following attendees are not members of the organization: ${attendeeCheck.invalidUids.join(', ')}`
      );
    }

    // Validate case if provided
    let validatedCaseId: string | null = null;
    let caseStatus: string | null = null;
    const warnings: string[] = [];

    if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
      const caseCheck = await canUserAccessCase(orgId, caseId.trim(), uid);
      if (!caseCheck.allowed) {
        if (caseCheck.reason === 'Case not found') {
          return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
        }
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
      }
      validatedCaseId = caseId.trim();

      // Get case status for warning
      const caseInfo = await getCaseInfo(orgId, validatedCaseId);
      caseStatus = caseInfo.caseStatus;

      // Add warning if case is not OPEN
      if (caseStatus && caseStatus !== 'OPEN') {
        warnings.push(`Linked case is ${caseStatus}`);
      }
    }

    // Create event document
    const now = admin.firestore.Timestamp.now();
    const eventRef = db.collection('organizations').doc(orgId).collection('events').doc();
    const eventId = eventRef.id;

    const eventData: EventDocument = {
      eventId,
      orgId,
      caseId: validatedCaseId,
      title: sanitizedTitle,
      description: sanitizedDescription,
      eventType: parsedEventType,
      startDateTime: admin.firestore.Timestamp.fromDate(parsedStartDateTime),
      endDateTime: parsedEndDateTime
        ? admin.firestore.Timestamp.fromDate(parsedEndDateTime)
        : null,
      allDay: isAllDay,
      location: sanitizedLocation,
      attendeeUids: parsedAttendeeUids,
      reminders: parsedReminders,
      recurrence: parsedRecurrence,
      priority: parsedPriority,
      notes: sanitizedNotes,
      status: 'SCHEDULED',
      visibility: parsedVisibility,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      updatedBy: uid,
    };

    await eventRef.set(eventData);

    // Create scheduled reminders
    await createScheduledReminders(orgId, eventId, {
      title: sanitizedTitle,
      startDateTime: eventData.startDateTime,
      location: sanitizedLocation,
      eventType: parsedEventType,
      attendeeUids: parsedAttendeeUids,
      reminders: parsedReminders,
    });

    // Get case info for response
    const caseInfo = await getCaseInfo(orgId, validatedCaseId);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'event.created',
      entityType: 'event',
      entityId: eventId,
      metadata: {
        title: sanitizedTitle,
        eventType: parsedEventType,
        startDateTime: toIso(eventData.startDateTime),
        caseId: validatedCaseId,
        attendeeCount: parsedAttendeeUids.length,
      },
    });

    const response: any = {
      eventId,
      orgId,
      caseId: validatedCaseId,
      caseName: caseInfo.caseName,
      caseStatus: caseInfo.caseStatus,
      title: sanitizedTitle,
      description: sanitizedDescription,
      eventType: parsedEventType,
      startDateTime: toIso(eventData.startDateTime),
      endDateTime: eventData.endDateTime ? toIso(eventData.endDateTime) : null,
      allDay: isAllDay,
      location: sanitizedLocation,
      attendeeUids: parsedAttendeeUids,
      reminders: parsedReminders,
      recurrence: parsedRecurrence
        ? {
            frequency: parsedRecurrence.frequency,
            interval: parsedRecurrence.interval,
            endDate: parsedRecurrence.endDate ? toIso(parsedRecurrence.endDate) : null,
            count: parsedRecurrence.count ?? null,
          }
        : null,
      priority: parsedPriority,
      notes: sanitizedNotes,
      status: 'SCHEDULED',
      visibility: parsedVisibility,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      updatedBy: uid,
    };

    if (warnings.length > 0) {
      response.warnings = warnings;
    }

    return successResponse(response);
  } catch (error) {
    functions.logger.error('Error creating event:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to create event');
  }
});

/**
 * Get event details by ID
 * Function Name (Export): eventGet
 */
export const eventGet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, eventId } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!eventId || typeof eventId !== 'string' || eventId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Event ID is required');
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CALENDAR',
      requiredPermission: 'event.read',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view events');
    }

    const eventRef = db.collection('organizations').doc(orgId).collection('events').doc(eventId);
    const eventSnap = await eventRef.get();

    if (!eventSnap.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
    }

    const eventData = eventSnap.data() as EventDocument;

    if (eventData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
    }

    // ========================================
    // VISIBILITY CHECK (Privacy Enforcement)
    // ========================================
    
    // PRIVATE events: only visible to creator
    if (eventData.visibility === 'PRIVATE') {
      if (eventData.createdBy !== uid) {
        return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
      }
    }
    
    // CASE_ONLY events: only visible to users with case access
    if (eventData.visibility === 'CASE_ONLY') {
      if (eventData.caseId) {
        const caseCheck = await canUserAccessCase(orgId, eventData.caseId, uid);
        if (!caseCheck.allowed) {
          return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
        }
      } else {
        // CASE_ONLY without a caseId - only creator can see
        if (eventData.createdBy !== uid) {
          return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
        }
      }
    }
    
    // ORG visibility: accessible to all org members (already verified above)
    // ========================================

    // Get case info
    const caseInfo = await getCaseInfo(orgId, eventData.caseId);

    return successResponse({
      eventId: eventData.eventId,
      orgId: eventData.orgId,
      caseId: eventData.caseId,
      caseName: caseInfo.caseName,
      caseStatus: caseInfo.caseStatus,
      title: eventData.title,
      description: eventData.description,
      eventType: eventData.eventType,
      startDateTime: toIso(eventData.startDateTime),
      endDateTime: eventData.endDateTime ? toIso(eventData.endDateTime) : null,
      allDay: eventData.allDay,
      location: eventData.location,
      attendeeUids: eventData.attendeeUids,
      reminders: eventData.reminders,
      recurrence: eventData.recurrence
        ? {
            frequency: eventData.recurrence.frequency,
            interval: eventData.recurrence.interval,
            endDate: eventData.recurrence.endDate ? toIso(eventData.recurrence.endDate) : null,
            count: eventData.recurrence.count ?? null,
          }
        : null,
      priority: eventData.priority,
      notes: eventData.notes,
      status: eventData.status,
      visibility: eventData.visibility,
      createdAt: toIso(eventData.createdAt),
      updatedAt: toIso(eventData.updatedAt),
      createdBy: eventData.createdBy,
      updatedBy: eventData.updatedBy,
    });
  } catch (error) {
    functions.logger.error('Error getting event:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to get event');
  }
});

/**
 * List events with filtering and cursor-based pagination
 * Function Name (Export): eventList
 */
export const eventList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    pageSize,
    cursor,
    search,
    caseId,
    eventType,
    status,
    priority,
    startDate,
    endDate,
    includeRecurring,
  } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  const limit = typeof pageSize === 'number' ? Math.min(Math.max(pageSize, 1), 100) : 50;

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CALENDAR',
      requiredPermission: 'event.read',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to view events');
    }

    // Parse date range
    let filterStartDate: Date | null = null;
    let filterEndDate: Date | null = null;

    if (startDate && typeof startDate === 'string') {
      filterStartDate = parseDateTime(startDate + 'T00:00:00Z');
    }
    if (endDate && typeof endDate === 'string') {
      filterEndDate = parseDateTime(endDate + 'T23:59:59Z');
    }

    // Default to next 30 days if no date range specified
    if (!filterStartDate && !filterEndDate) {
      filterStartDate = new Date();
      filterEndDate = new Date();
      filterEndDate.setDate(filterEndDate.getDate() + 30);
    } else if (!filterStartDate) {
      filterStartDate = new Date();
      filterStartDate.setFullYear(filterStartDate.getFullYear() - 1); // 1 year back
    } else if (!filterEndDate) {
      filterEndDate = new Date();
      filterEndDate.setFullYear(filterEndDate.getFullYear() + 1); // 1 year forward
    }

    // Build base query
    let query: admin.firestore.Query = db
      .collection('organizations')
      .doc(orgId)
      .collection('events')
      .where('deletedAt', '==', null)
      .orderBy('startDateTime', 'asc');

    // Apply cursor for pagination
    if (cursor && typeof cursor === 'string') {
      const parsedCursor = parseCursor(cursor);
      if (parsedCursor) {
        query = query.startAfter(
          admin.firestore.Timestamp.fromDate(parsedCursor.startDateTime),
          parsedCursor.eventId
        );
      }
    }

    // Apply case filter in Firestore
    if (caseId && typeof caseId === 'string' && caseId.trim().length > 0) {
      // Verify case access
      const caseCheck = await canUserAccessCase(orgId, caseId.trim(), uid);
      if (!caseCheck.allowed) {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
      }
      query = query.where('caseId', '==', caseId.trim());
    }

    // Fetch events
    let snapshot;
    try {
      snapshot = await query.limit(500).get(); // Fetch more for filtering
    } catch (queryError: any) {
      if (
        queryError.code === 9 ||
        queryError.message?.includes('index') ||
        queryError.message?.includes('FAILED_PRECONDITION')
      ) {
        functions.logger.error('EventList: Index required');
        return errorResponse(
          ErrorCode.INTERNAL_ERROR,
          'Firestore index required. Please check Firebase Console.'
        );
      }
      throw queryError;
    }

    if (snapshot.empty) {
      return successResponse({
        events: [],
        nextCursor: null,
        hasMore: false,
      });
    }

    // Convert to array
    let events = snapshot.docs.map((doc) => doc.data() as EventDocument);

    // ========================================
    // VISIBILITY FILTERING (Privacy Enforcement)
    // ========================================
    // Filter out events the user doesn't have permission to see
    // - PRIVATE: Only creator can see
    // - CASE_ONLY: Only users with case access can see
    // - ORG: Everyone in org can see (already filtered by org membership above)
    
    const visibilityFilteredEvents: EventDocument[] = [];
    const caseAccessCache = new Map<string, boolean>(); // Cache case access checks
    
    for (const event of events) {
      // PRIVATE events: only visible to creator
      if (event.visibility === 'PRIVATE') {
        if (event.createdBy === uid) {
          visibilityFilteredEvents.push(event);
        }
        // Skip if not the creator
        continue;
      }
      
      // CASE_ONLY events: only visible to users with case access
      if (event.visibility === 'CASE_ONLY') {
        if (event.caseId) {
          // Check cache first
          let hasAccess = caseAccessCache.get(event.caseId);
          
          if (hasAccess === undefined) {
            // Not in cache, check access
            const caseCheck = await canUserAccessCase(orgId, event.caseId, uid);
            hasAccess = caseCheck.allowed;
            caseAccessCache.set(event.caseId, hasAccess);
          }
          
          if (hasAccess) {
            visibilityFilteredEvents.push(event);
          }
          // Skip if no case access
        }
        // Skip CASE_ONLY events without a caseId (shouldn't happen, but defensive)
        continue;
      }
      
      // ORG visibility: visible to all org members (already verified above)
      visibilityFilteredEvents.push(event);
    }
    
    events = visibilityFilteredEvents;
    // ========================================

    // Apply in-memory filters
    if (eventType && typeof eventType === 'string' && VALID_EVENT_TYPES.includes(eventType as EventType)) {
      events = events.filter((e) => e.eventType === eventType);
    }

    if (status && typeof status === 'string' && ['SCHEDULED', 'COMPLETED', 'CANCELLED'].includes(status)) {
      events = events.filter((e) => e.status === status);
    }

    if (priority && typeof priority === 'string' && ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(priority)) {
      events = events.filter((e) => e.priority === priority);
    }

    // Apply search filter (title + location)
    if (search && typeof search === 'string' && search.trim().length > 0) {
      const searchLower = search.trim().toLowerCase();
      events = events.filter(
        (e) =>
          e.title.toLowerCase().includes(searchLower) ||
          (e.location && e.location.toLowerCase().includes(searchLower))
      );
    }

    // Expand recurring events if requested
    const shouldExpandRecurring = includeRecurring !== false;
    let expandedEvents: Array<EventDocument & { isRecurringInstance: boolean; instanceDate: string }> = [];

    if (shouldExpandRecurring && filterStartDate && filterEndDate) {
      for (const event of events) {
        const expanded = expandRecurringEvent(event, filterStartDate, filterEndDate);
        expandedEvents.push(...expanded);
      }
    } else {
      expandedEvents = events.map((e) => ({
        ...e,
        isRecurringInstance: false,
        instanceDate: formatDateKey(e.startDateTime.toDate()),
      }));
    }

    // Filter by date range
    if (filterStartDate || filterEndDate) {
      expandedEvents = expandedEvents.filter((e) => {
        const eventDate = e.startDateTime.toDate();
        if (filterStartDate && eventDate < filterStartDate) return false;
        if (filterEndDate && eventDate > filterEndDate) return false;
        return true;
      });
    }

    // Sort by startDateTime
    expandedEvents.sort((a, b) => a.startDateTime.toMillis() - b.startDateTime.toMillis());

    // Apply pagination
    const paginatedEvents = expandedEvents.slice(0, limit);
    const hasMore = expandedEvents.length > limit;

    // Build next cursor from last event
    let nextCursor: string | null = null;
    if (paginatedEvents.length > 0 && hasMore) {
      const lastEvent = paginatedEvents[paginatedEvents.length - 1];
      nextCursor = buildCursor(lastEvent);
    }

    // Get case info for each event
    const caseIds = new Set(paginatedEvents.map((e) => e.caseId).filter(Boolean) as string[]);
    const caseInfoMap = new Map<string, { caseName: string | null; caseStatus: string | null }>();

    for (const id of caseIds) {
      const info = await getCaseInfo(orgId, id);
      caseInfoMap.set(id, info);
    }

    // Build response
    const eventList = paginatedEvents.map((e) => {
      const caseInfo = e.caseId ? caseInfoMap.get(e.caseId) : null;
      return {
        eventId: e.eventId,
        orgId: e.orgId,
        caseId: e.caseId,
        caseName: caseInfo?.caseName ?? null,
        title: e.title,
        eventType: e.eventType,
        startDateTime: toIso(e.startDateTime),
        endDateTime: e.endDateTime ? toIso(e.endDateTime) : null,
        allDay: e.allDay,
        location: e.location,
        attendeeUids: e.attendeeUids,
        priority: e.priority,
        status: e.status,
        visibility: e.visibility,
        isRecurringInstance: e.isRecurringInstance,
        recurringParentId: e.recurrence ? e.eventId : null,
        instanceDate: e.instanceDate,
        createdAt: toIso(e.createdAt),
      };
    });

    return successResponse({
      events: eventList,
      nextCursor,
      hasMore,
    });
  } catch (error) {
    functions.logger.error('Error listing events:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to list events');
  }
});

/**
 * Update an event
 * Function Name (Export): eventUpdate
 */
export const eventUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const {
    orgId,
    eventId,
    title,
    description,
    eventType,
    startDateTime,
    endDateTime,
    allDay,
    location,
    attendeeUids,
    reminders,
    recurrence,
    priority,
    notes,
    status,
    visibility,
    caseId,
    updateScope: _updateScope, // Reserved for future recurring event scope handling
  } = data || {};

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!eventId || typeof eventId !== 'string' || eventId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Event ID is required');
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CALENDAR',
      requiredPermission: 'event.update',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, "You don't have permission to update events");
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to update events');
    }

    // Get existing event
    const eventRef = db.collection('organizations').doc(orgId).collection('events').doc(eventId);
    const eventSnap = await eventRef.get();

    if (!eventSnap.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
    }

    const existingEvent = eventSnap.data() as EventDocument;

    if (existingEvent.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Event not found');
    }

    // Track changes
    const changes: Record<string, any> = {};
    const updateData: Partial<EventDocument> = {};
    let remindersChanged = false;

    // Validate and apply title
    if (title !== undefined) {
      const sanitizedTitle = parseTitle(title);
      if (!sanitizedTitle) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Event title must be 1-200 characters');
      }
      if (sanitizedTitle !== existingEvent.title) {
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
          'Event description must be 2000 characters or less'
        );
      }
      if (sanitizedDescription !== existingEvent.description) {
        updateData.description = sanitizedDescription;
        changes.description = sanitizedDescription;
      }
    }

    // Validate and apply eventType
    if (eventType !== undefined) {
      const parsedEventType = parseEventType(eventType);
      if (!parsedEventType) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          `Event type must be one of: ${VALID_EVENT_TYPES.join(', ')}`
        );
      }
      if (parsedEventType !== existingEvent.eventType) {
        updateData.eventType = parsedEventType;
        changes.eventType = parsedEventType;
      }
    }

    // Validate and apply startDateTime
    if (startDateTime !== undefined) {
      const parsedStartDateTime = parseDateTime(startDateTime);
      if (!parsedStartDateTime) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Start date/time must be a valid ISO 8601 date'
        );
      }
      updateData.startDateTime = admin.firestore.Timestamp.fromDate(parsedStartDateTime);
      changes.startDateTime = startDateTime;
      remindersChanged = true;
    }

    // Validate and apply endDateTime
    if (endDateTime !== undefined) {
      if (endDateTime === null) {
        updateData.endDateTime = null;
        changes.endDateTime = null;
      } else {
        const parsedEndDateTime = parseDateTime(endDateTime);
        if (!parsedEndDateTime) {
          return errorResponse(
            ErrorCode.VALIDATION_ERROR,
            'End date/time must be a valid ISO 8601 date'
          );
        }
        const effectiveStartDateTime = updateData.startDateTime ?? existingEvent.startDateTime;
        if (parsedEndDateTime <= effectiveStartDateTime.toDate()) {
          return errorResponse(
            ErrorCode.VALIDATION_ERROR,
            'End date/time must be after start date/time'
          );
        }
        updateData.endDateTime = admin.firestore.Timestamp.fromDate(parsedEndDateTime);
        changes.endDateTime = endDateTime;
      }
    }

    // Validate and apply allDay
    if (allDay !== undefined) {
      if (typeof allDay !== 'boolean') {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'allDay must be a boolean');
      }
      if (allDay !== existingEvent.allDay) {
        updateData.allDay = allDay;
        changes.allDay = allDay;
      }
    }

    // Validate and apply location
    if (location !== undefined) {
      const sanitizedLocation = location === null ? null : parseLocation(location);
      if (location !== null && sanitizedLocation === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Location must be 500 characters or less');
      }
      if (sanitizedLocation !== existingEvent.location) {
        updateData.location = sanitizedLocation;
        changes.location = sanitizedLocation;
      }
    }

    // Validate and apply notes
    if (notes !== undefined) {
      const sanitizedNotes = notes === null ? null : parseNotes(notes);
      if (notes !== null && sanitizedNotes === null) {
        return errorResponse(ErrorCode.VALIDATION_ERROR, 'Notes must be 1000 characters or less');
      }
      if (sanitizedNotes !== existingEvent.notes) {
        updateData.notes = sanitizedNotes;
        changes.notes = sanitizedNotes;
      }
    }

    // Validate and apply priority
    if (priority !== undefined) {
      const parsedPriority = parsePriority(priority);
      if (!parsedPriority) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Priority must be LOW, MEDIUM, HIGH, or CRITICAL'
        );
      }
      if (parsedPriority !== existingEvent.priority) {
        updateData.priority = parsedPriority;
        changes.priority = parsedPriority;
      }
    }

    // Validate and apply status
    if (status !== undefined) {
      const parsedStatus = parseStatus(status);
      if (!parsedStatus) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          'Status must be SCHEDULED, COMPLETED, or CANCELLED'
        );
      }
      if (parsedStatus !== existingEvent.status) {
        if (!isValidStatusTransition(existingEvent.status, parsedStatus)) {
          return errorResponse(
            ErrorCode.INVALID_STATUS_TRANSITION,
            `Invalid status transition from ${existingEvent.status} to ${parsedStatus}`
          );
        }
        updateData.status = parsedStatus;
        changes.status = { from: existingEvent.status, to: parsedStatus };
      }
    }

    // Validate and apply visibility
    if (visibility !== undefined) {
      const parsedVisibility = parseVisibility(visibility);
      if (parsedVisibility !== existingEvent.visibility) {
        updateData.visibility = parsedVisibility;
        changes.visibility = parsedVisibility;
      }
    }

    // Validate and apply attendees
    if (attendeeUids !== undefined) {
      const parsedAttendeeUids = parseAttendeeUids(attendeeUids, existingEvent.createdBy);
      const attendeeCheck = await verifyAttendeesAreMember(orgId, parsedAttendeeUids);
      if (!attendeeCheck.valid) {
        return errorResponse(
          ErrorCode.ASSIGNEE_NOT_MEMBER,
          `The following attendees are not members of the organization: ${attendeeCheck.invalidUids.join(', ')}`
        );
      }
      updateData.attendeeUids = parsedAttendeeUids;
      changes.attendeeUids = parsedAttendeeUids;
      remindersChanged = true;
    }

    // Validate and apply reminders
    if (reminders !== undefined) {
      const parsedReminders = parseReminders(reminders);
      if (parsedReminders === null) {
        return errorResponse(
          ErrorCode.VALIDATION_ERROR,
          `Reminders must be an array of max 3 items with valid minutesBefore values`
        );
      }
      updateData.reminders = parsedReminders;
      changes.reminders = parsedReminders;
      remindersChanged = true;
    }

    // Validate and apply recurrence
    if (recurrence !== undefined) {
      if (recurrence === null) {
        updateData.recurrence = null;
        changes.recurrence = null;
      } else {
        const parsedRecurrence = parseRecurrence(recurrence);
        if (!parsedRecurrence) {
          return errorResponse(ErrorCode.VALIDATION_ERROR, 'Invalid recurrence configuration');
        }
        updateData.recurrence = parsedRecurrence;
        changes.recurrence = recurrence;
      }
    }

    // Validate and apply caseId
    if (caseId !== undefined) {
      if (caseId === null || caseId === '') {
        updateData.caseId = null;
        changes.caseId = { from: existingEvent.caseId, to: null };
      } else if (typeof caseId === 'string') {
        const caseCheck = await canUserAccessCase(orgId, caseId.trim(), uid);
        if (!caseCheck.allowed) {
          if (caseCheck.reason === 'Case not found') {
            return errorResponse(ErrorCode.NOT_FOUND, 'Case not found');
          }
          return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
        }
        updateData.caseId = caseId.trim();
        changes.caseId = { from: existingEvent.caseId, to: caseId.trim() };
      }
    }

    // If no changes, return existing event
    if (Object.keys(updateData).length === 0) {
      const caseInfo = await getCaseInfo(orgId, existingEvent.caseId);
      return successResponse({
        eventId: existingEvent.eventId,
        orgId: existingEvent.orgId,
        caseId: existingEvent.caseId,
        caseName: caseInfo.caseName,
        caseStatus: caseInfo.caseStatus,
        title: existingEvent.title,
        description: existingEvent.description,
        eventType: existingEvent.eventType,
        startDateTime: toIso(existingEvent.startDateTime),
        endDateTime: existingEvent.endDateTime ? toIso(existingEvent.endDateTime) : null,
        allDay: existingEvent.allDay,
        location: existingEvent.location,
        attendeeUids: existingEvent.attendeeUids,
        reminders: existingEvent.reminders,
        recurrence: existingEvent.recurrence,
        priority: existingEvent.priority,
        notes: existingEvent.notes,
        status: existingEvent.status,
        visibility: existingEvent.visibility,
        createdAt: toIso(existingEvent.createdAt),
        updatedAt: toIso(existingEvent.updatedAt),
        createdBy: existingEvent.createdBy,
        updatedBy: existingEvent.updatedBy,
      });
    }

    // Update event
    const now = admin.firestore.Timestamp.now();
    updateData.updatedAt = now;
    updateData.updatedBy = uid;

    await eventRef.update(updateData);

    // Update reminders if needed
    if (remindersChanged) {
      await deleteScheduledReminders(orgId, eventId);
      const updatedEvent = { ...existingEvent, ...updateData };
      await createScheduledReminders(orgId, eventId, {
        title: updatedEvent.title,
        startDateTime: updatedEvent.startDateTime,
        location: updatedEvent.location,
        eventType: updatedEvent.eventType,
        attendeeUids: updatedEvent.attendeeUids,
        reminders: updatedEvent.reminders,
      });
    }

    // Get updated event
    const updatedSnap = await eventRef.get();
    const updatedEvent = updatedSnap.data() as EventDocument;

    // Get case info
    const caseInfo = await getCaseInfo(orgId, updatedEvent.caseId);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'event.updated',
      entityType: 'event',
      entityId: eventId,
      metadata: {
        changedFields: changes,
      },
    });

    return successResponse({
      eventId: updatedEvent.eventId,
      orgId: updatedEvent.orgId,
      caseId: updatedEvent.caseId,
      caseName: caseInfo.caseName,
      caseStatus: caseInfo.caseStatus,
      title: updatedEvent.title,
      description: updatedEvent.description,
      eventType: updatedEvent.eventType,
      startDateTime: toIso(updatedEvent.startDateTime),
      endDateTime: updatedEvent.endDateTime ? toIso(updatedEvent.endDateTime) : null,
      allDay: updatedEvent.allDay,
      location: updatedEvent.location,
      attendeeUids: updatedEvent.attendeeUids,
      reminders: updatedEvent.reminders,
      recurrence: updatedEvent.recurrence
        ? {
            frequency: updatedEvent.recurrence.frequency,
            interval: updatedEvent.recurrence.interval,
            endDate: updatedEvent.recurrence.endDate ? toIso(updatedEvent.recurrence.endDate) : null,
            count: updatedEvent.recurrence.count ?? null,
          }
        : null,
      priority: updatedEvent.priority,
      notes: updatedEvent.notes,
      status: updatedEvent.status,
      visibility: updatedEvent.visibility,
      createdAt: toIso(updatedEvent.createdAt),
      updatedAt: toIso(updatedEvent.updatedAt),
      createdBy: updatedEvent.createdBy,
      updatedBy: updatedEvent.updatedBy,
    });
  } catch (error) {
    functions.logger.error('Error updating event:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to update event');
  }
});

/**
 * Delete an event (soft delete)
 * Function Name (Export): eventDelete
 */
export const eventDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, eventId, deleteScope: _deleteScope } = data || {}; // deleteScope reserved for recurring

  if (!orgId || typeof orgId !== 'string' || orgId.trim().length === 0) {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!eventId || typeof eventId !== 'string' || eventId.trim().length === 0) {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Event ID is required');
  }

  try {
    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'CALENDAR',
      requiredPermission: 'event.delete',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'ROLE_BLOCKED') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, "You don't have permission to delete events");
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized to delete events');
    }

    const eventRef = db.collection('organizations').doc(orgId).collection('events').doc(eventId);
    const eventSnap = await eventRef.get();

    if (!eventSnap.exists) {
      // Idempotent delete
      return successResponse({
        eventId,
        deleted: true,
        message: 'Event already deleted',
      });
    }

    const eventData = eventSnap.data() as EventDocument;

    if (eventData.deletedAt) {
      // Idempotent delete
      return successResponse({
        eventId,
        deleted: true,
        message: 'Event already deleted',
      });
    }

    // Soft delete
    const now = admin.firestore.Timestamp.now();
    await eventRef.update({
      deletedAt: now,
      updatedAt: now,
      updatedBy: uid,
    });

    // Delete scheduled reminders
    await deleteScheduledReminders(orgId, eventId);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'event.deleted',
      entityType: 'event',
      entityId: eventId,
      metadata: {
        title: eventData.title,
        eventType: eventData.eventType,
        startDateTime: toIso(eventData.startDateTime),
        caseId: eventData.caseId,
      },
    });

    return successResponse({
      eventId,
      deleted: true,
      message: 'Event deleted successfully',
    });
  } catch (error) {
    functions.logger.error('Error deleting event:', error);
    return errorResponse(ErrorCode.INTERNAL_ERROR, 'Failed to delete event');
  }
});
