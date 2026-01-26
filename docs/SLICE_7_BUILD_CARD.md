# SLICE 7: Calendar & Court Dates - Build Card

**Last Updated:** January 26, 2026  
**Version:** 1.1 (Post-Review)  
**Status:** 📋 READY TO START  
**Owner:** Taimur (CEMS)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅

---

## Review Notes (v1.1)

**Reviewed by:** ChatGPT & Gemini (January 26, 2026)

**Critical Fixes Applied:**
1. ✅ Added `attendeeUids` field - reminders notify all attendees, not just creator
2. ✅ Replaced offset pagination with cursor-based pagination
3. ✅ Clarified timestamp contract (Firestore Timestamp → ISO string in API)
4. ✅ Defined recurrence exception key format: `YYYY-MM-DD` (UTC)
5. ✅ Defined `THIS_AND_FUTURE` behavior: split recurring parent at cutover
6. ✅ MVP uses FCM push only (removed local notifications complexity)

**Medium-Priority Additions:**
- Added `visibility` field (future-safe for enterprise)
- Search includes title + location
- Recurring instance expansion capped at 365
- Case status warning when linking to non-OPEN case

---

## 1) Purpose

Build the Calendar & Court Dates feature that allows legal professionals to manage critical deadlines, court appearances, and case-related events. **This is a high-priority feature** because:

1. **Lawyers live by deadlines** - Missing court dates = malpractice liability
2. **Table stakes** - All competitors (Clio, CaseTrak) have calendar features
3. **Daily use feature** - Used multiple times daily by every lawyer
4. **Risk mitigation** - Statute of limitations tracking prevents career-ending mistakes

---

## 2) Scope In ✅

### Backend (Cloud Functions):
- `eventCreate` - Create new calendar events
- `eventGet` - Get event details by ID
- `eventList` - List events with filtering, search, pagination
- `eventUpdate` - Update event information
- `eventDelete` - Soft delete events
- Case-event relationship management
- Entitlement checks (plan + role permissions)
- Reminder scheduling (Firebase Cloud Messaging)
- Recurring event support
- Audit logging for all event operations
- Firestore security rules for events collection

### Frontend (Flutter):
- Calendar view screen (month, week, day views)
- Event list screen (agenda view)
- Event creation form (with case linking, reminders, recurrence)
- Event details view (view/edit mode)
- Case details integration (events linked to case)
- Notification handling
- Loading states and error handling
- Empty states for no events
- Overdue/upcoming event indicators

### Data Model:
- Events belong to organizations (orgId required)
- Events can be linked to cases (caseId optional)
- Events have: title, description, eventType, startDateTime, endDateTime, location, reminders, recurrence
- Soft delete support (deletedAt timestamp)
- Timestamps (createdAt, updatedAt)
- Creator tracking (createdBy, updatedBy)

---

## 3) Scope Out ❌

- External calendar sync (Google Calendar, Outlook) - Future slice
- Meeting scheduling with clients - Future slice
- Automated conflict detection - Future slice
- Court deadline calculators (jurisdiction-specific rules) - Future slice
- Email notifications - Future slice (in-app only for MVP)
- Team availability view - Future slice
- Drag-and-drop calendar editing - Future slice
- Multi-day event display optimization - Future slice
- Calendar sharing with external parties - Future slice

---

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0
- Firebase Cloud Messaging (required for reminders) - NEW

**NPM Packages:**
- No new backend packages required

**Flutter Packages:**
- `table_calendar: ^3.0.9` - Calendar UI widget
- `timezone: ^0.9.2` - Timezone handling
- (Note: Local notifications removed for MVP - using FCM push only)

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org, membership, entitlements engine)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme)
- ✅ **Slice 2**: Required (events can be linked to cases)

**No Dependencies on:**
- Slice 3 (Clients) - Events don't directly link to clients (via cases)
- Slice 4 (Documents) - Events don't link to documents
- Slice 5 (Tasks) - Events are separate from tasks (different purpose)

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `event.create` (Callable Function)

**Function Name (Export):** `eventCreate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `event.create` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `CALENDAR` feature must be enabled
- FREE: ✅ (enabled for MVP testing)
- BASIC: ✅
- PRO: ✅
- ENTERPRISE: ✅

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (optional, null if not associated with case)",
  "title": "string (required, 1-200 chars)",
  "description": "string (optional, max 2000 chars)",
  "eventType": "string (required, one of: COURT_DATE, HEARING, FILING_DEADLINE, STATUTE_LIMITATION, MEETING, CONSULTATION, DEPOSITION, MEDIATION, ARBITRATION, OTHER)",
  "startDateTime": "string (required, ISO 8601 datetime UTC)",
  "endDateTime": "string (optional, ISO 8601 datetime UTC, must be after startDateTime)",
  "allDay": "boolean (optional, default: false)",
  "location": "string (optional, max 500 chars)",
  "attendeeUids": "[string] (optional, org member UIDs to notify, creator auto-included)",
  "reminders": "[{ minutesBefore: number }] (optional, max 3, FCM push notifications)",
  "recurrence": "{ frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY', interval: number, endDate?: string (ISO date) } (optional)",
  "priority": "string (optional, one of: LOW, MEDIUM, HIGH, CRITICAL, default: MEDIUM)",
  "notes": "string (optional, internal notes, max 1000 chars)",
  "visibility": "string (optional, one of: ORG, CASE_ONLY, PRIVATE, default: ORG)"
}
```

**⚠️ Timestamp Contract:**
- **Input:** ISO 8601 string in UTC (e.g., `"2026-02-15T09:00:00Z"`)
- **Storage:** Firestore Timestamp (UTC)
- **Output:** ISO 8601 string in UTC
- **All-day events:** Store as UTC midnight, display in local timezone

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "eventId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "caseName": "string | null",
    "caseStatus": "string | null (OPEN, CLOSED, etc.)",
    "title": "string",
    "description": "string | null",
    "eventType": "string",
    "startDateTime": "ISO 8601 UTC",
    "endDateTime": "ISO 8601 UTC | null",
    "allDay": "boolean",
    "location": "string | null",
    "attendeeUids": "[string]",
    "reminders": "[{ minutesBefore }]",
    "recurrence": "{ frequency, interval, endDate } | null",
    "priority": "string",
    "notes": "string | null",
    "status": "string (SCHEDULED, COMPLETED, CANCELLED)",
    "visibility": "string (ORG, CASE_ONLY, PRIVATE)",
    "createdAt": "ISO 8601 UTC",
    "updatedAt": "ISO 8601 UTC",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  },
  "warnings": "[string] (optional, e.g., 'Linked case is CLOSED')"
}
```

**⚠️ Case Status Warning:**
If `caseId` is provided and the case status is not `OPEN`, include a warning in the response (but still allow creation). This helps lawyers catch mistakes.

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing or invalid fields
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have permission
- `PLAN_LIMIT` (403): CALENDAR feature not available in plan
- `NOT_FOUND` (404): Case not found (if caseId provided)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**EventId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc(orgId).collection('events').doc()`

**DateTime Validation:**
- startDateTime is required, must be valid ISO 8601 with timezone
- endDateTime is optional, but if provided must be after startDateTime
- For allDay events, normalize times to 00:00:00 - 23:59:59 of the date(s)
- Store as Firestore Timestamps (UTC)

**Event Type Validation:**
- Required: Must be one of the defined event types
- Different types may have different default priorities:
  - COURT_DATE, FILING_DEADLINE, STATUTE_LIMITATION → default CRITICAL
  - HEARING, DEPOSITION, MEDIATION, ARBITRATION → default HIGH
  - MEETING, CONSULTATION, OTHER → default MEDIUM

**Reminder Scheduling:**
- Store reminder config in event document
- Schedule reminders via Cloud Function trigger or scheduled function
- Max 3 reminders per event
- Valid minutesBefore values: 0, 5, 10, 15, 30, 60, 120, 1440 (1 day), 2880 (2 days), 10080 (1 week)

**Recurrence Handling (MVP):**
- Store recurrence pattern in event document
- For MVP: Generate recurring instances at query time (not stored individually)
- Future: Pre-generate recurring instances for better performance

**Implementation Flow:**
1. Validate auth token
2. Validate orgId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'CALENDAR', requiredPermission: 'event.create' })`
4. Validate title (trim, length check)
5. Validate description (optional, length check)
6. Validate eventType (required, must be valid enum)
7. Validate startDateTime (required, valid ISO 8601)
8. Validate endDateTime (optional, must be after start)
9. Validate location (optional, length check)
10. Validate reminders (optional, max 3, valid minutesBefore values)
11. Validate recurrence (optional, valid frequency and interval)
12. If caseId provided: verify case exists and user can access
13. Generate eventId
14. Create event document
15. If reminders: schedule reminder notifications
16. Create audit event: `event.created`
17. Return success response

---

### 5.2 `event.get` (Callable Function)

**Function Name (Export):** `eventGet` ⚠️ **Flutter MUST use this name**

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `event.read` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ✅ (all org members can read events)

**Plan Gating:** `CALENDAR` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "eventId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "eventId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "caseName": "string | null",
    "title": "string",
    "description": "string | null",
    "eventType": "string",
    "startDateTime": "ISO 8601 timestamp",
    "endDateTime": "ISO 8601 timestamp | null",
    "allDay": "boolean",
    "location": "string | null",
    "reminders": "[...]",
    "recurrence": "{ ... } | null",
    "priority": "string",
    "notes": "string | null",
    "status": "string",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string",
    "updatedBy": "string"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing eventId
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Event not found or soft-deleted
- `INTERNAL_ERROR` (500): Database read failure

---

### 5.3 `event.list` (Callable Function)

**Function Name (Export):** `eventList` ⚠️ **Flutter MUST use this name**

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `event.read`

**Plan Gating:** `CALENDAR` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "pageSize": "number (optional, 1-100, default: 50)",
  "cursor": "string (optional, from previous response nextCursor)",
  "search": "string (optional, search in title + location)",
  "caseId": "string (optional, filter by case)",
  "eventType": "string (optional, filter by event type)",
  "status": "string (optional, filter by status: SCHEDULED, COMPLETED, CANCELLED)",
  "priority": "string (optional, filter by priority)",
  "startDate": "string (optional, ISO 8601 date, events on or after this date)",
  "endDate": "string (optional, ISO 8601 date, events on or before this date)",
  "includeRecurring": "boolean (optional, default: true, expand recurring events)"
}
```

**⚠️ Cursor-Based Pagination (Required for Firestore Performance):**
- **Why:** Firestore offset is slow and expensive - it reads and discards skipped documents
- **Cursor format:** `{startDateTime}_{eventId}` (e.g., `"2026-02-15T09:00:00Z_evt123"`)
- **First page:** Omit `cursor` parameter
- **Next page:** Use `nextCursor` from previous response

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "eventId": "string",
        "orgId": "string",
        "caseId": "string | null",
        "caseName": "string | null",
        "title": "string",
        "eventType": "string",
        "startDateTime": "ISO 8601 UTC",
        "endDateTime": "ISO 8601 UTC | null",
        "allDay": "boolean",
        "location": "string | null",
        "attendeeUids": "[string]",
        "priority": "string",
        "status": "string",
        "visibility": "string",
        "isRecurringInstance": "boolean",
        "recurringParentId": "string | null",
        "instanceDate": "string (YYYY-MM-DD, for recurring instances)",
        "createdAt": "ISO 8601 UTC"
      }
    ],
    "nextCursor": "string | null (null if no more pages)",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid parameters
- `NOT_AUTHORIZED` (403): User not a member of org
- `INTERNAL_ERROR` (500): Database query failure

**Implementation Details:**

**Query Strategy:**
- **Base Query:** Firestore query with `deletedAt == null` and `orderBy startDateTime ASC`
- **Date Range:** Primary filter - Firestore handles startDate/endDate + caseId
- **In-Memory Filters:** eventType, status, priority, search (title + location)
- **Recurring Events:** Expand recurring patterns within the date range

**⚠️ Recurring Event Expansion (with Safety Cap):**
```typescript
const MAX_RECURRING_INSTANCES = 365; // Prevent timeout bombs

function expandRecurringEvents(
  event: EventDocument,
  startDate: Date,
  endDate: Date
): EventInstance[] {
  if (!event.recurrence) return [toInstance(event)];
  
  const instances: EventInstance[] = [];
  let current = new Date(event.startDateTime.toDate());
  const recurrenceEnd = event.recurrence.endDate 
    ? event.recurrence.endDate.toDate()
    : endDate;
  
  let count = 0;
  while (current <= recurrenceEnd && current <= endDate && count < MAX_RECURRING_INSTANCES) {
    // Check for exception on this date
    const instanceDateKey = formatDateKey(current); // "YYYY-MM-DD"
    const exception = event.exceptions?.[instanceDateKey];
    
    if (exception?.isCancelled) {
      // Skip cancelled instances
      current = getNextOccurrence(current, event.recurrence);
      continue;
    }
    
    if (current >= startDate) {
      instances.push({
        ...event,
        // Apply exception overrides if present
        title: exception?.title ?? event.title,
        startDateTime: exception?.startDateTime ?? current,
        location: exception?.location ?? event.location,
        status: exception?.status ?? event.status,
        isRecurringInstance: true,
        recurringParentId: event.eventId,
        instanceDate: instanceDateKey,
      });
    }
    
    current = getNextOccurrence(current, event.recurrence);
    count++;
  }
  
  return instances;
}

// Exception key format: "YYYY-MM-DD" in UTC
function formatDateKey(date: Date): string {
  return date.toISOString().split('T')[0];
}
```

**⚠️ Instance Cap Rationale:**
- Prevents timeout if user creates "Daily for 50 years"
- 365 instances covers 1 year of daily events
- User can paginate/filter by date range for more

---

### 5.4 `event.update` (Callable Function)

**Function Name (Export):** `eventUpdate` ⚠️ **Flutter MUST use this name**

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `event.update` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `CALENDAR` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "eventId": "string (required)",
  "title": "string (optional)",
  "description": "string (optional, null to clear)",
  "eventType": "string (optional)",
  "startDateTime": "string (optional)",
  "endDateTime": "string (optional, null to clear)",
  "allDay": "boolean (optional)",
  "location": "string (optional, null to clear)",
  "reminders": "[...] (optional, empty array to clear all)",
  "recurrence": "{ ... } | null (optional, null to remove recurrence)",
  "priority": "string (optional)",
  "notes": "string (optional, null to clear)",
  "status": "string (optional, SCHEDULED, COMPLETED, CANCELLED)",
  "caseId": "string (optional, link to case, null to unlink)",
  "updateScope": "string (optional, for recurring: THIS_ONLY, THIS_AND_FUTURE, ALL)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "eventId": "string",
    "orgId": "string",
    "... (full event object)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing eventId, invalid field values
- `NOT_AUTHORIZED` (403): User not authorized
- `NOT_FOUND` (404): Event not found
- `INTERNAL_ERROR` (500): Database write failure

**Recurring Event Update Handling (v1.1 - Clarified):**

For recurring events, `updateScope` determines how the update applies:

**`THIS_ONLY`:**
- Add an entry to `exceptions` map with key `"YYYY-MM-DD"` (instance date)
- Exception contains only the overridden fields
- Base event unchanged

**`THIS_AND_FUTURE` (Split Pattern):**
1. Update original event: set `recurringEndedAt` to day before the instance date
2. Create NEW recurring event starting from the instance date with:
   - New `eventId`
   - `recurringParentId` pointing to original event
   - Applied changes (time, title, etc.)
   - Same recurrence pattern

```typescript
// Example: Change weekly meeting time starting March 1st
// Original: Weekly at 9am, started Jan 1st
// After THIS_AND_FUTURE at March 1st to 10am:

// Original event (updated):
{
  eventId: "evt-001",
  startDateTime: "2026-01-01T09:00:00Z",
  recurrence: { frequency: "WEEKLY", interval: 1 },
  recurringEndedAt: "2026-02-28" // Ends day before split
}

// New event (created):
{
  eventId: "evt-002",
  startDateTime: "2026-03-01T10:00:00Z", // New time
  recurrence: { frequency: "WEEKLY", interval: 1 },
  recurringParentId: "evt-001" // Links to original
}
```

**`ALL`:**
- Update the base recurring event directly
- Clear `exceptions` map if changes invalidate previous exceptions
- All past and future instances affected

**Status Transitions:**
```
SCHEDULED → COMPLETED ✅
SCHEDULED → CANCELLED ✅
COMPLETED → SCHEDULED ✅ (reopen)
COMPLETED → CANCELLED ✅
CANCELLED → SCHEDULED ✅ (reopen)
CANCELLED → COMPLETED ❌ (must go through SCHEDULED first)
```

**Implementation Flow:**
1. Validate auth and entitlements
2. Fetch existing event
3. Validate all provided fields
4. Handle recurring event scope if applicable
5. Update event document
6. Reschedule reminders if changed
7. Create audit event: `event.updated`
8. Return updated event

---

### 5.5 `event.delete` (Callable Function)

**Function Name (Export):** `eventDelete` ⚠️ **Flutter MUST use this name**

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `event.delete` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `CALENDAR` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "eventId": "string (required)",
  "deleteScope": "string (optional, for recurring: THIS_ONLY, THIS_AND_FUTURE, ALL)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "eventId": "string",
    "deleted": true,
    "message": "Event deleted successfully"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing eventId
- `NOT_AUTHORIZED` (403): User not authorized
- `NOT_FOUND` (404): Event not found or already deleted
- `INTERNAL_ERROR` (500): Database write failure

**Soft Delete Implementation:**
- Set `deletedAt` to current timestamp
- Cancel any scheduled reminders
- For recurring events, handle based on `deleteScope`

---

## 6) Data Model

### 6.1 Event Document

**Path:** `organizations/{orgId}/events/{eventId}`

```typescript
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
  
  // ✅ Attendees (v1.1 - for multi-user reminders)
  attendeeUids: string[]; // Org member UIDs, creator auto-included
  
  reminders: Reminder[];
  recurrence: Recurrence | null;
  priority: EventPriority;
  notes: string | null;
  status: EventStatus;
  
  // ✅ Visibility (v1.1 - future-safe for enterprise)
  visibility: 'ORG' | 'CASE_ONLY' | 'PRIVATE';
  
  // Recurring event exceptions (for THIS_ONLY edits)
  // ✅ Key format: "YYYY-MM-DD" in UTC (e.g., "2026-02-15")
  exceptions?: { [instanceDateKey: string]: EventException };
  
  // For split recurring events (THIS_AND_FUTURE creates new parent)
  recurringParentId?: string; // Links to original parent if this is a split
  recurringEndedAt?: FirestoreTimestamp; // Original end date before split
  
  // Soft delete
  deletedAt: FirestoreTimestamp | null;
  
  // Timestamps
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  updatedBy: string;
}

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

interface Reminder {
  minutesBefore: number;
  // ✅ v1.1: Removed 'type' - MVP uses FCM push only
  // Recipients determined by attendeeUids (all attendees get notified)
}

interface Recurrence {
  frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
  interval: number; // e.g., every 2 weeks
  endDate?: FirestoreTimestamp;
  count?: number; // Alternative to endDate: repeat N times
  daysOfWeek?: number[]; // For WEEKLY: 0=Sun, 1=Mon, etc.
  dayOfMonth?: number; // For MONTHLY: 1-31
  monthOfYear?: number; // For YEARLY: 1-12
}

interface EventException {
  // Override fields for this specific instance
  title?: string;
  description?: string;
  startDateTime?: FirestoreTimestamp;
  endDateTime?: FirestoreTimestamp;
  location?: string;
  status?: EventStatus;
  isCancelled?: boolean;
}
```

### 6.2 Scheduled Reminder Document

**Path:** `organizations/{orgId}/scheduledReminders/{reminderId}`

**⚠️ v1.1 Change:** One reminder document per recipient per reminder time (not per event)

```typescript
interface ScheduledReminder {
  reminderId: string;
  eventId: string;
  orgId: string;
  scheduledFor: FirestoreTimestamp;
  sent: boolean;
  sentAt?: FirestoreTimestamp;
  
  // ✅ v1.1: Reminder per recipient (not just creator)
  recipientUid: string; // Each attendee gets their own reminder doc
  
  // Event info for notification content
  eventTitle: string;
  eventStartDateTime: FirestoreTimestamp;
  eventLocation?: string;
  eventType: string;
}
```

**Reminder Creation Logic:**
When an event is created with reminders:
```typescript
// For each reminder time × each attendee = one reminder doc
for (const reminder of event.reminders) {
  for (const attendeeUid of event.attendeeUids) {
    const scheduledFor = new Date(event.startDateTime);
    scheduledFor.setMinutes(scheduledFor.getMinutes() - reminder.minutesBefore);
    
    await db.collection('organizations').doc(orgId)
      .collection('scheduledReminders').add({
        eventId: event.eventId,
        orgId,
        scheduledFor: admin.firestore.Timestamp.fromDate(scheduledFor),
        sent: false,
        recipientUid: attendeeUid,
        eventTitle: event.title,
        eventStartDateTime: event.startDateTime,
        eventLocation: event.location,
        eventType: event.eventType,
      });
  }
}
```

---

## 7) Frontend Implementation (Flutter)

### 7.1 Data Models

**EventModel** (`legal_ai_app/lib/core/models/event_model.dart`):

```dart
enum EventType {
  courtDate('COURT_DATE', 'Court Date'),
  hearing('HEARING', 'Hearing'),
  filingDeadline('FILING_DEADLINE', 'Filing Deadline'),
  statuteLimitation('STATUTE_LIMITATION', 'Statute of Limitations'),
  meeting('MEETING', 'Meeting'),
  consultation('CONSULTATION', 'Consultation'),
  deposition('DEPOSITION', 'Deposition'),
  mediation('MEDIATION', 'Mediation'),
  arbitration('ARBITRATION', 'Arbitration'),
  other('OTHER', 'Other');

  final String value;
  final String displayName;
  const EventType(this.value, this.displayName);
  
  static EventType fromString(String value) {
    return EventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventType.other,
    );
  }
  
  // Icon for each event type
  IconData get icon {
    switch (this) {
      case EventType.courtDate:
        return Icons.gavel;
      case EventType.hearing:
        return Icons.record_voice_over;
      case EventType.filingDeadline:
        return Icons.upload_file;
      case EventType.statuteLimitation:
        return Icons.timer_off;
      case EventType.meeting:
        return Icons.groups;
      case EventType.consultation:
        return Icons.person;
      case EventType.deposition:
        return Icons.question_answer;
      case EventType.mediation:
        return Icons.handshake;
      case EventType.arbitration:
        return Icons.balance;
      case EventType.other:
        return Icons.event;
    }
  }
  
  // Default priority for event type
  EventPriority get defaultPriority {
    switch (this) {
      case EventType.courtDate:
      case EventType.filingDeadline:
      case EventType.statuteLimitation:
        return EventPriority.critical;
      case EventType.hearing:
      case EventType.deposition:
      case EventType.mediation:
      case EventType.arbitration:
        return EventPriority.high;
      default:
        return EventPriority.medium;
    }
  }
}

enum EventStatus {
  scheduled('SCHEDULED', 'Scheduled'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  final String value;
  final String displayName;
  const EventStatus(this.value, this.displayName);
  
  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventStatus.scheduled,
    );
  }
  
  Color get color {
    switch (this) {
      case EventStatus.scheduled:
        return Colors.blue;
      case EventStatus.completed:
        return Colors.green;
      case EventStatus.cancelled:
        return Colors.grey;
    }
  }
}

enum EventPriority {
  low('LOW', 'Low'),
  medium('MEDIUM', 'Medium'),
  high('HIGH', 'High'),
  critical('CRITICAL', 'Critical');

  final String value;
  final String displayName;
  const EventPriority(this.value, this.displayName);
  
  static EventPriority fromString(String value) {
    return EventPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventPriority.medium,
    );
  }
  
  Color get color {
    switch (this) {
      case EventPriority.low:
        return Colors.grey;
      case EventPriority.medium:
        return Colors.blue;
      case EventPriority.high:
        return Colors.orange;
      case EventPriority.critical:
        return Colors.red;
    }
  }
}

// ✅ v1.1: Added visibility enum
enum EventVisibility {
  org('ORG', 'Organization'),
  caseOnly('CASE_ONLY', 'Case Members'),
  private_('PRIVATE', 'Private');

  final String value;
  final String displayName;
  const EventVisibility(this.value, this.displayName);
  
  static EventVisibility fromString(String value) {
    return EventVisibility.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventVisibility.org,
    );
  }
}

class ReminderModel {
  final int minutesBefore;
  // ✅ v1.1: Removed 'type' - MVP uses FCM push only
  
  const ReminderModel({
    required this.minutesBefore,
  });
  
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      minutesBefore: json['minutesBefore'] as int,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'minutesBefore': minutesBefore,
  };
  
  String get displayText {
    if (minutesBefore == 0) return 'At time of event';
    if (minutesBefore < 60) return '$minutesBefore minutes before';
    if (minutesBefore < 1440) return '${minutesBefore ~/ 60} hours before';
    return '${minutesBefore ~/ 1440} days before';
  }
  
  // Preset options for UI dropdown
  static const List<int> presetMinutes = [
    0,      // At time of event
    5,      // 5 minutes before
    15,     // 15 minutes before
    30,     // 30 minutes before
    60,     // 1 hour before
    120,    // 2 hours before
    1440,   // 1 day before
    2880,   // 2 days before
    10080,  // 1 week before
  ];
}

class RecurrenceModel {
  final String frequency;
  final int interval;
  final DateTime? endDate;
  final int? count;
  
  const RecurrenceModel({
    required this.frequency,
    required this.interval,
    this.endDate,
    this.count,
  });
  
  factory RecurrenceModel.fromJson(Map<String, dynamic> json) {
    return RecurrenceModel(
      frequency: json['frequency'] as String,
      interval: json['interval'] as int,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      count: json['count'] as int?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'interval': interval,
    if (endDate != null) 'endDate': endDate!.toIso8601String().split('T')[0],
    if (count != null) 'count': count,
  };
  
  String get displayText {
    final freq = frequency.toLowerCase();
    if (interval == 1) return 'Every $freq';
    return 'Every $interval ${freq}s';
  }
}

class EventModel {
  final String eventId;
  final String orgId;
  final String? caseId;
  final String? caseName;
  final String? caseStatus; // ✅ v1.1: For warning display
  final String title;
  final String? description;
  final EventType eventType;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final bool allDay;
  final String? location;
  final List<String> attendeeUids; // ✅ v1.1: Multi-user support
  final List<ReminderModel> reminders;
  final RecurrenceModel? recurrence;
  final EventPriority priority;
  final String? notes;
  final EventStatus status;
  final EventVisibility visibility; // ✅ v1.1: Access control
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  
  // For recurring instances
  final bool isRecurringInstance;
  final String? recurringParentId;
  final String? instanceDate; // ✅ v1.1: "YYYY-MM-DD" for recurring
  
  const EventModel({
    required this.eventId,
    required this.orgId,
    this.caseId,
    this.caseName,
    this.caseStatus,
    required this.title,
    this.description,
    required this.eventType,
    required this.startDateTime,
    this.endDateTime,
    required this.allDay,
    this.location,
    required this.attendeeUids,
    required this.reminders,
    this.recurrence,
    required this.priority,
    this.notes,
    required this.status,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.isRecurringInstance = false,
    this.recurringParentId,
    this.instanceDate,
  });
  
  // ✅ v1.1: Check if linked case is not OPEN
  bool get hasCaseWarning => caseId != null && caseStatus != null && caseStatus != 'OPEN';
  
  // Computed properties
  bool get isOverdue {
    if (status != EventStatus.scheduled) return false;
    return startDateTime.isBefore(DateTime.now());
  }
  
  bool get isToday {
    final now = DateTime.now();
    return startDateTime.year == now.year &&
           startDateTime.month == now.month &&
           startDateTime.day == now.day;
  }
  
  bool get isUpcoming {
    if (status != EventStatus.scheduled) return false;
    final now = DateTime.now();
    final threeDaysFromNow = now.add(const Duration(days: 3));
    return startDateTime.isAfter(now) && startDateTime.isBefore(threeDaysFromNow);
  }
  
  bool get isCritical {
    return priority == EventPriority.critical ||
           eventType == EventType.statuteLimitation ||
           eventType == EventType.filingDeadline;
  }
  
  Duration? get duration {
    if (endDateTime == null) return null;
    return endDateTime!.difference(startDateTime);
  }
  
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      eventId: json['eventId'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      caseName: json['caseName'] as String?,
      caseStatus: json['caseStatus'] as String?, // ✅ v1.1
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: EventType.fromString(json['eventType'] as String),
      startDateTime: DateTime.parse(json['startDateTime'] as String),
      endDateTime: json['endDateTime'] != null 
          ? DateTime.parse(json['endDateTime'] as String) 
          : null,
      allDay: json['allDay'] as bool? ?? false,
      location: json['location'] as String?,
      attendeeUids: (json['attendeeUids'] as List<dynamic>?)
          ?.map((e) => e as String).toList() ?? [], // ✅ v1.1
      reminders: (json['reminders'] as List<dynamic>?)
          ?.map((e) => ReminderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList() ?? [],
      recurrence: json['recurrence'] != null 
          ? RecurrenceModel.fromJson(Map<String, dynamic>.from(json['recurrence']))
          : null,
      priority: EventPriority.fromString(json['priority'] as String? ?? 'MEDIUM'),
      notes: json['notes'] as String?,
      status: EventStatus.fromString(json['status'] as String? ?? 'SCHEDULED'),
      visibility: EventVisibility.fromString(json['visibility'] as String? ?? 'ORG'), // ✅ v1.1
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String,
      updatedBy: json['updatedBy'] as String,
      isRecurringInstance: json['isRecurringInstance'] as bool? ?? false,
      recurringParentId: json['recurringParentId'] as String?,
      instanceDate: json['instanceDate'] as String?, // ✅ v1.1
    );
  }
  
  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'orgId': orgId,
    'caseId': caseId,
    'caseName': caseName,
    'title': title,
    'description': description,
    'eventType': eventType.value,
    'startDateTime': startDateTime.toIso8601String(),
    'endDateTime': endDateTime?.toIso8601String(),
    'allDay': allDay,
    'location': location,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'recurrence': recurrence?.toJson(),
    'priority': priority.value,
    'notes': notes,
    'status': status.value,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };
}
```

---

### 7.2 Service Layer

**EventService** (`legal_ai_app/lib/core/services/event_service.dart`):

```dart
class EventService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<EventModel> createEvent({
    required OrgModel org,
    required String title,
    String? description,
    required EventType eventType,
    required DateTime startDateTime,
    DateTime? endDateTime,
    bool allDay = false,
    String? location,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    String? caseId,
  }) async {
    final response = await _functionsService.callFunction('eventCreate', {
      'orgId': org.orgId,
      'title': title.trim(),
      if (description != null) 'description': description.trim(),
      'eventType': eventType.value,
      'startDateTime': startDateTime.toUtc().toIso8601String(),
      if (endDateTime != null) 'endDateTime': endDateTime.toUtc().toIso8601String(),
      'allDay': allDay,
      if (location != null) 'location': location.trim(),
      if (reminders != null && reminders.isNotEmpty)
        'reminders': reminders.map((r) => r.toJson()).toList(),
      if (recurrence != null) 'recurrence': recurrence.toJson(),
      if (priority != null) 'priority': priority.value,
      if (notes != null) 'notes': notes.trim(),
      if (caseId != null) 'caseId': caseId,
    });

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data']));
    }

    throw response['error']?['message'] ?? 'Failed to create event';
  }

  Future<EventModel> getEvent({
    required OrgModel org,
    required String eventId,
  }) async {
    final response = await _functionsService.callFunction('eventGet', {
      'orgId': org.orgId,
      'eventId': eventId,
    });

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data']));
    }

    throw response['error']?['message'] ?? 'Failed to load event';
  }

  // ✅ v1.1: Changed to cursor-based pagination
  Future<({List<EventModel> events, String? nextCursor, bool hasMore})> listEvents({
    required OrgModel org,
    int pageSize = 50,
    String? cursor, // ✅ v1.1: Cursor instead of offset
    String? search,
    String? caseId,
    EventType? eventType,
    EventStatus? status,
    EventPriority? priority,
    DateTime? startDate,
    DateTime? endDate,
    bool includeRecurring = true,
  }) async {
    final response = await _functionsService.callFunction('eventList', {
      'orgId': org.orgId,
      'pageSize': pageSize,
      if (cursor != null) 'cursor': cursor, // ✅ v1.1
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (caseId != null) 'caseId': caseId,
      if (eventType != null) 'eventType': eventType.value,
      if (status != null) 'status': status.value,
      if (priority != null) 'priority': priority.value,
      if (startDate != null) 'startDate': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
      'includeRecurring': includeRecurring,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data']);
      final events = (data['events'] as List<dynamic>)
          .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (
        events: events,
        nextCursor: data['nextCursor'] as String?, // ✅ v1.1
        hasMore: data['hasMore'] as bool? ?? false,
      );
    }

    throw response['error']?['message'] ?? 'Failed to load events';
  }

  Future<EventModel> updateEvent({
    required OrgModel org,
    required String eventId,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? allDay,
    String? location,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    EventStatus? status,
    String? caseId,
    bool clearDescription = false,
    bool clearEndDateTime = false,
    bool clearLocation = false,
    bool clearNotes = false,
    bool clearRecurrence = false,
    bool unlinkCase = false,
    String? updateScope, // THIS_ONLY, THIS_AND_FUTURE, ALL
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'eventId': eventId,
    };

    if (title != null) payload['title'] = title.trim();
    if (clearDescription) {
      payload['description'] = null;
    } else if (description != null) {
      payload['description'] = description.trim();
    }
    if (eventType != null) payload['eventType'] = eventType.value;
    if (startDateTime != null) payload['startDateTime'] = startDateTime.toUtc().toIso8601String();
    if (clearEndDateTime) {
      payload['endDateTime'] = null;
    } else if (endDateTime != null) {
      payload['endDateTime'] = endDateTime.toUtc().toIso8601String();
    }
    if (allDay != null) payload['allDay'] = allDay;
    if (clearLocation) {
      payload['location'] = null;
    } else if (location != null) {
      payload['location'] = location.trim();
    }
    if (reminders != null) payload['reminders'] = reminders.map((r) => r.toJson()).toList();
    if (clearRecurrence) {
      payload['recurrence'] = null;
    } else if (recurrence != null) {
      payload['recurrence'] = recurrence.toJson();
    }
    if (priority != null) payload['priority'] = priority.value;
    if (clearNotes) {
      payload['notes'] = null;
    } else if (notes != null) {
      payload['notes'] = notes.trim();
    }
    if (status != null) payload['status'] = status.value;
    if (unlinkCase) {
      payload['caseId'] = null;
    } else if (caseId != null) {
      payload['caseId'] = caseId;
    }
    if (updateScope != null) payload['updateScope'] = updateScope;

    final response = await _functionsService.callFunction('eventUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data']));
    }

    throw response['error']?['message'] ?? 'Failed to update event';
  }

  Future<void> deleteEvent({
    required OrgModel org,
    required String eventId,
    String? deleteScope, // THIS_ONLY, THIS_AND_FUTURE, ALL
  }) async {
    final response = await _functionsService.callFunction('eventDelete', {
      'orgId': org.orgId,
      'eventId': eventId,
      if (deleteScope != null) 'deleteScope': deleteScope,
    });

    if (response['success'] != true) {
      throw response['error']?['message'] ?? 'Failed to delete event';
    }
  }
}
```

---

### 7.3 State Management

**EventProvider** (`legal_ai_app/lib/features/calendar/providers/event_provider.dart`):

Key features:
- Optimistic UI updates for create/update/delete
- Events grouped by date for calendar view
- Upcoming events list (next 7 days)
- Filter by case, type, status
- Search with 300ms debounce
- Prevents duplicate loads

```dart
class EventProvider with ChangeNotifier {
  final EventService _eventService = EventService();

  final List<EventModel> _events = [];
  EventModel? _selectedEvent;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  
  // Calendar view state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  
  // Filters
  String? _lastLoadedOrgId;
  String? _lastLoadedCaseId;
  DateTime? _lastLoadedStartDate;
  DateTime? _lastLoadedEndDate;
  
  List<EventModel> get events => List.unmodifiable(_events);
  EventModel? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  DateTime get focusedMonth => _focusedMonth;
  DateTime? get selectedDate => _selectedDate;
  
  // Get events for a specific date (for calendar day markers)
  List<EventModel> eventsForDate(DateTime date) {
    return _events.where((e) {
      final eventDate = DateTime(e.startDateTime.year, e.startDateTime.month, e.startDateTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return eventDate == targetDate;
    }).toList();
  }
  
  // Get upcoming events (next 7 days)
  List<EventModel> get upcomingEvents {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _events.where((e) {
      return e.status == EventStatus.scheduled &&
             e.startDateTime.isAfter(now) &&
             e.startDateTime.isBefore(weekFromNow);
    }).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }
  
  // Get overdue events
  List<EventModel> get overdueEvents {
    final now = DateTime.now();
    return _events.where((e) {
      return e.status == EventStatus.scheduled &&
             e.startDateTime.isBefore(now);
    }).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }
  
  // Get critical events (statute limitations, filing deadlines)
  List<EventModel> get criticalEvents {
    return _events.where((e) => e.isCritical && e.status == EventStatus.scheduled).toList();
  }

  Future<void> loadEvents({
    required OrgModel org,
    DateTime? startDate,
    DateTime? endDate,
    String? caseId,
    EventType? eventType,
    EventStatus? status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastLoadedOrgId = org.orgId;
    _lastLoadedCaseId = caseId;
    _lastLoadedStartDate = startDate;
    _lastLoadedEndDate = endDate;
    notifyListeners();

    try {
      final result = await _eventService.listEvents(
        org: org,
        startDate: startDate,
        endDate: endDate,
        caseId: caseId,
        eventType: eventType,
        status: status,
      );
      
      _events.clear();
      _events.addAll(result.events);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load events for calendar month view
  Future<void> loadEventsForMonth(OrgModel org, DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0); // Last day of month
    
    _focusedMonth = month;
    await loadEvents(org: org, startDate: startDate, endDate: endDate);
  }
  
  void setSelectedDate(DateTime? date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<bool> createEvent({
    required OrgModel org,
    required String title,
    String? description,
    required EventType eventType,
    required DateTime startDateTime,
    DateTime? endDateTime,
    bool allDay = false,
    String? location,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final createdEvent = await _eventService.createEvent(
        org: org,
        title: title,
        description: description,
        eventType: eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: allDay,
        location: location,
        reminders: reminders,
        recurrence: recurrence,
        priority: priority,
        notes: notes,
        caseId: caseId,
      );
      
      _events.add(createdEvent);
      _events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateEvent({
    required OrgModel org,
    required String eventId,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? allDay,
    String? location,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    EventStatus? status,
    String? caseId,
    bool clearDescription = false,
    bool clearEndDateTime = false,
    bool clearLocation = false,
    bool clearNotes = false,
    bool clearRecurrence = false,
    bool unlinkCase = false,
    String? updateScope,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedEvent = await _eventService.updateEvent(
        org: org,
        eventId: eventId,
        title: title,
        description: description,
        eventType: eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: allDay,
        location: location,
        reminders: reminders,
        recurrence: recurrence,
        priority: priority,
        notes: notes,
        status: status,
        caseId: caseId,
        clearDescription: clearDescription,
        clearEndDateTime: clearEndDateTime,
        clearLocation: clearLocation,
        clearNotes: clearNotes,
        clearRecurrence: clearRecurrence,
        unlinkCase: unlinkCase,
        updateScope: updateScope,
      );
      
      final index = _events.indexWhere((e) => e.eventId == eventId);
      if (index != -1) {
        _events[index] = updatedEvent;
      }
      if (_selectedEvent?.eventId == eventId) {
        _selectedEvent = updatedEvent;
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEvent({
    required OrgModel org,
    required String eventId,
    String? deleteScope,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    
    // Optimistic removal
    final index = _events.indexWhere((e) => e.eventId == eventId);
    EventModel? removedEvent;
    if (index != -1) {
      removedEvent = _events.removeAt(index);
    }
    if (_selectedEvent?.eventId == eventId) {
      _selectedEvent = null;
    }
    notifyListeners();

    try {
      await _eventService.deleteEvent(
        org: org,
        eventId: eventId,
        deleteScope: deleteScope,
      );
      return true;
    } catch (e) {
      // Rollback on error
      if (removedEvent != null && index != -1) {
        _events.insert(index, removedEvent);
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearEvents() {
    _events.clear();
    _selectedEvent = null;
    _errorMessage = null;
    _lastLoadedOrgId = null;
    notifyListeners();
  }
}
```

---

### 7.4 UI Screens

**CalendarScreen** (`legal_ai_app/lib/features/calendar/screens/calendar_screen.dart`):

Key features:
- Month view calendar with event markers
- Switch between month/week/agenda views
- Tap date to see events for that day
- FAB to create new event
- Pull-to-refresh
- Event type color coding
- Critical event indicators

**EventCreateScreen** (`legal_ai_app/lib/features/calendar/screens/event_create_screen.dart`):

Key features:
- Title field (required)
- Event type dropdown (with icons)
- Date/time pickers (start and end)
- All-day toggle
- Location field
- Description field
- Case linking dropdown
- Priority dropdown
- Reminder configuration
- Recurrence options

**EventDetailsScreen** (`legal_ai_app/lib/features/calendar/screens/event_details_screen.dart`):

Key features:
- View/edit mode toggle
- All event details display
- Status update (mark complete, cancel)
- Case link navigation
- Edit/delete actions
- Recurring event scope picker (if recurring)

---

## 8) Security & Permissions

### 8.1 Role Permissions

**Add to `functions/src/constants/permissions.ts`:**

```typescript
export const ROLE_PERMISSIONS = {
  ADMIN: {
    // ... existing permissions
    'event.create': true,
    'event.read': true,
    'event.update': true,
    'event.delete': true,
  },
  LAWYER: {
    // ... existing permissions
    'event.create': true,
    'event.read': true,
    'event.update': true,
    'event.delete': true,
  },
  PARALEGAL: {
    // ... existing permissions
    'event.create': true,
    'event.read': true,
    'event.update': true,
    'event.delete': true,
  },
  VIEWER: {
    // ... existing permissions
    'event.create': false,
    'event.read': true, // Can view events
    'event.update': false,
    'event.delete': false,
  },
};
```

### 8.2 Plan Features

**Update `functions/src/constants/entitlements.ts`:**

```typescript
export const PLAN_FEATURES = {
  FREE: {
    // ... existing features
    CALENDAR: true, // Enable for MVP testing
  },
  BASIC: {
    // ... existing features
    CALENDAR: true,
  },
  PRO: {
    // ... existing features
    CALENDAR: true,
  },
  ENTERPRISE: {
    // ... existing features
    CALENDAR: true,
  },
};
```

### 8.3 Firestore Security Rules

**Add to `firestore.rules`:**

```javascript
// Slice 7: Events under organizations collection
match /organizations/{orgId}/events/{eventId} {
  // Read: org members can read non-deleted events
  allow read: if isOrgMember(orgId) &&
    (!('deletedAt' in resource.data) || resource.data.deletedAt == null);

  // All writes are via Admin SDK (Cloud Functions); deny direct client writes
  allow create, update, delete: if false;
}

// Scheduled reminders (if using separate collection)
match /organizations/{orgId}/scheduledReminders/{reminderId} {
  allow read: if isOrgMember(orgId);
  allow create, update, delete: if false;
}
```

---

## 9) Firestore Indexes

**Required Index (add to `firestore.indexes.json`):**

```json
{
  "indexes": [
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "deletedAt", "order": "ASCENDING" },
        { "fieldPath": "startDateTime", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "deletedAt", "order": "ASCENDING" },
        { "fieldPath": "caseId", "order": "ASCENDING" },
        { "fieldPath": "startDateTime", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## 10) Notifications & Reminders

### 10.1 Reminder Scheduling Strategy

**Option A (MVP): Scheduled Cloud Function**
- Run a Cloud Function every 5 minutes
- Query for reminders due in the next 5 minutes
- Send notifications via FCM
- Mark reminders as sent

**Option B (Future): Firebase Cloud Tasks**
- Schedule individual tasks for each reminder
- More precise timing but more complex

### 10.2 Reminder Implementation (MVP)

```typescript
// Scheduled function: runs every 5 minutes
export const processReminders = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const fiveMinutesFromNow = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 5 * 60 * 1000
    );
    
    // Query all scheduled reminders due in the next 5 minutes
    const remindersSnapshot = await db
      .collectionGroup('scheduledReminders')
      .where('sent', '==', false)
      .where('scheduledFor', '<=', fiveMinutesFromNow)
      .get();
    
    const batch = db.batch();
    const notifications: Promise<void>[] = [];
    
    for (const doc of remindersSnapshot.docs) {
      const reminder = doc.data();
      
      // Send notification
      notifications.push(
        sendPushNotification(reminder.recipientUid, {
          title: `Reminder: ${reminder.eventTitle}`,
          body: `Event starting at ${formatDateTime(reminder.eventStartDateTime)}`,
          data: { eventId: reminder.eventId, orgId: reminder.orgId },
        })
      );
      
      // Mark as sent
      batch.update(doc.ref, {
        sent: true,
        sentAt: now,
      });
    }
    
    await Promise.all(notifications);
    await batch.commit();
  });
```

### 10.3 FCM Token Management

- Store FCM tokens in user profile or separate collection
- Update token on app launch
- Handle token refresh
- Support multiple devices per user

---

## 11) Testing Requirements

### 11.1 Backend Testing

**Basic CRUD:**
- [ ] Create event with all fields
- [ ] Create event with minimal fields
- [ ] Create event with case association
- [ ] Create event with case association - verify warning if case is CLOSED
- [ ] Create all-day event
- [ ] Create event with multiple attendees
- [ ] Create event with reminders (verify reminder docs created per attendee)
- [ ] Reject: Create event with end before start
- [ ] Reject: Create event without title
- [ ] Get event by ID
- [ ] List events - first page (no cursor)
- [ ] List events - second page (with cursor from first)
- [ ] List events filtered by date range
- [ ] List events filtered by case
- [ ] List events filtered by type
- [ ] List events with search (title + location)
- [ ] Update event title
- [ ] Update event attendees (verify reminder docs updated)
- [ ] Update event status
- [ ] Delete event (soft delete)
- [ ] Permission checks (VIEWER cannot create/update/delete)

**Recurring Events (Critical):**
- [ ] Create recurring event (daily, weekly, monthly)
- [ ] List events with recurring expansion (verify instances generated)
- [ ] Verify 365 instance cap prevents timeout
- [ ] THIS_ONLY update - verify exception created in exceptions map
- [ ] THIS_ONLY update - verify base event unchanged
- [ ] THIS_AND_FUTURE update - verify original event gets recurringEndedAt
- [ ] THIS_AND_FUTURE update - verify new event created with recurringParentId
- [ ] ALL update - verify base event updated
- [ ] ALL update - verify exceptions cleared if invalidated
- [ ] Delete recurring event THIS_ONLY - verify exception with isCancelled
- [ ] Delete recurring event ALL - verify soft delete

**Reminders:**
- [ ] Reminder docs created for each attendee × each reminder time
- [ ] Scheduled function processes due reminders
- [ ] Reminders marked as sent after processing
- [ ] Reminder cancelled when event deleted

### 11.2 Frontend Testing

- [ ] Calendar view loads and displays events
- [ ] Month navigation works
- [ ] Day selection shows events
- [ ] Event creation form works
- [ ] Date/time pickers work correctly
- [ ] Case linking works
- [ ] Recurrence options work
- [ ] Event details view works
- [ ] Edit mode works
- [ ] Status update works
- [ ] Delete works (with confirmation)
- [ ] Recurring event edit shows scope picker
- [ ] Empty states display correctly
- [ ] Loading states display correctly
- [ ] Error handling works

---

## 12) Implementation Order

### Phase 1: Backend Foundation
1. Update `entitlements.ts` - Add CALENDAR feature
2. Update `permissions.ts` - Add event permissions
3. Create `functions/src/functions/event.ts` - All 5 functions
4. Update `functions/src/index.ts` - Export event functions
5. Update `firestore.rules` - Add event rules
6. Add Firestore indexes
7. Test backend manually
8. Deploy functions

### Phase 2: Frontend Models & Services
1. Create `EventModel` with enums
2. Create `EventService`
3. Test service methods

### Phase 3: State Management
1. Create `EventProvider`
2. Register provider in app.dart
3. Test provider

### Phase 4: UI Screens
1. Create `CalendarScreen` (month view)
2. Create `EventCreateScreen`
3. Create `EventDetailsScreen`
4. Add routes
5. Add "Calendar" tab to AppShell

### Phase 5: Case Integration
1. Add events section to CaseDetailsScreen
2. Test case-event linking

### Phase 6: Notifications (Optional MVP)
1. Create scheduled reminder function
2. Implement FCM notification sending
3. Handle tokens on frontend
4. Test end-to-end

---

## 13) Files to Create/Modify

### Backend:
- `functions/src/functions/event.ts` - All 5 event functions
- `functions/src/index.ts` - Export event functions
- `functions/src/constants/permissions.ts` - Add event permissions
- `functions/src/constants/entitlements.ts` - Add CALENDAR feature
- `firestore.rules` - Add event security rules
- `firestore.indexes.json` - Add event indexes

### Frontend:
- `legal_ai_app/lib/core/models/event_model.dart` - EventModel with enums
- `legal_ai_app/lib/core/services/event_service.dart` - EventService
- `legal_ai_app/lib/features/calendar/providers/event_provider.dart` - EventProvider
- `legal_ai_app/lib/features/calendar/screens/calendar_screen.dart` - CalendarScreen
- `legal_ai_app/lib/features/calendar/screens/event_create_screen.dart` - EventCreateScreen
- `legal_ai_app/lib/features/calendar/screens/event_details_screen.dart` - EventDetailsScreen
- `legal_ai_app/lib/core/routing/route_names.dart` - Add event routes
- `legal_ai_app/lib/core/routing/app_router.dart` - Add event routes
- `legal_ai_app/lib/features/home/widgets/app_shell.dart` - Add calendar tab
- `legal_ai_app/lib/app.dart` - Register EventProvider
- `legal_ai_app/lib/features/cases/screens/case_details_screen.dart` - Add events section
- `legal_ai_app/pubspec.yaml` - Add calendar/notification packages

---

## 14) Success Criteria

### Backend:
- [ ] All 5 functions implemented and deployed
- [ ] All functions pass manual testing
- [ ] Security rules configured
- [ ] Audit logging working
- [ ] Recurring events work correctly

### Frontend:
- [ ] Calendar view works with month navigation
- [ ] Event creation works
- [ ] Event editing works
- [ ] Event deletion works
- [ ] Case integration works
- [ ] Empty/loading/error states work

### Integration:
- [ ] Events appear in case details
- [ ] Calendar tab accessible from main nav
- [ ] Reminders scheduled (optional MVP)

---

## 15) Quick Reference

### Function Names (Flutter):
- `eventCreate` (NOT `event.create`)
- `eventGet` (NOT `event.get`)
- `eventList` (NOT `event.list`)
- `eventUpdate` (NOT `event.update`)
- `eventDelete` (NOT `event.delete`)

### Event Types:
- `COURT_DATE`, `HEARING`, `FILING_DEADLINE`, `STATUTE_LIMITATION`
- `MEETING`, `CONSULTATION`, `DEPOSITION`, `MEDIATION`, `ARBITRATION`, `OTHER`

### Event Status:
- `SCHEDULED`, `COMPLETED`, `CANCELLED`

### Event Priority:
- `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`

### Firestore Path:
- `organizations/{orgId}/events/{eventId}`

### Flutter Packages:
- `table_calendar: ^3.0.9`
- `timezone: ^0.9.2`
- (Local notifications removed for MVP - FCM push only)

### Pagination:
- **Type:** Cursor-based (NOT offset)
- **Cursor format:** `{startDateTime}_{eventId}`
- **First page:** Omit cursor
- **Next page:** Use `nextCursor` from response

### Exception Key Format (Recurring):
- **Format:** `"YYYY-MM-DD"` in UTC
- **Example:** `"2026-02-15"`

### Timestamp Contract:
- **Input/Output:** ISO 8601 UTC string
- **Storage:** Firestore Timestamp

---

**Build Card Created:** January 26, 2026  
**Status:** 📋 **READY TO START**  
**Dependencies:** All met (Slice 0 ✅, Slice 1 ✅, Slice 2 ✅)

**Priority:** 🔴 HIGH - Critical for lawyer adoption (deadline management = malpractice prevention)

---

**Last Updated:** January 26, 2026  
**Next Review:** After implementation begins

---

## Appendix: v1.1 Changes Summary

### Critical Fixes (ChatGPT Review)

| Issue | Fix Applied |
|-------|-------------|
| Reminders only notify creator | Added `attendeeUids` field - all attendees receive reminders |
| Offset pagination (slow at scale) | Changed to cursor-based pagination with `nextCursor` |
| Timestamp contract unclear | Documented: Firestore Timestamp storage → ISO 8601 UTC response |
| Recurrence exception key undefined | Defined: `"YYYY-MM-DD"` in UTC |
| THIS_AND_FUTURE behavior undefined | Defined: Split pattern - end original, create new parent |
| Mixed notification strategy | MVP uses FCM push only (removed local notifications) |

### Technical Recommendations (Gemini Review)

| Issue | Fix Applied |
|-------|-------------|
| Recurring instance timeout risk | Added 365 instance cap per expansion |
| Case status not checked | Added `caseStatus` field + warning when linking to non-OPEN case |
| Timezone leakage for allDay | Documented: UTC storage, local display for allDay |

### New Fields Added

**EventDocument:**
- `attendeeUids: string[]` - Org members to notify
- `visibility: 'ORG' | 'CASE_ONLY' | 'PRIVATE'` - Access control (future-safe)
- `recurringParentId?: string` - For split recurring events
- `recurringEndedAt?: FirestoreTimestamp` - Original end date before split

**API Response:**
- `caseStatus` - For warning display
- `nextCursor` - For cursor pagination
- `instanceDate` - For recurring instances
- `warnings` - Optional array (e.g., "Linked case is CLOSED")

### Removed

- `flutter_local_notifications` package (using FCM push only)
- `type` field from reminders (MVP uses push only)
- `offset` parameter from list API (replaced with cursor)
