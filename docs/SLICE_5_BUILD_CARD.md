# SLICE 5: Task Hub (Task Management) - Build Card

**⚠️ Important Notes:**
- **Function Names:** Flutter MUST use export names (`taskCreate`, `taskGet`, etc.), NOT callable names (`task.create`, etc.)
- **Firestore Indexes:** Create the base index BEFORE deployment (Section 10)
- **Search Limitations:** Title-only in-memory search (MVP approach, full-text search in future)
- **Assignment Validation:** Verify assignee is org member before assignment
- **Status Transitions:** Enforce valid status transitions (e.g., cannot mark COMPLETED task as PENDING)

## 1) Purpose

Build the Task Hub feature that allows users to create, assign, track, and manage tasks within their organization. Tasks can be associated with cases and assigned to team members. This slice establishes task management as a core collaboration feature that supports case work and team coordination.

## 2) Scope In ✅

### Backend (Cloud Functions):
- `task.create` - Create new tasks
- `task.get` - Get task details by ID
- `task.list` - List tasks for an organization/case/assignee (with filtering, search, pagination)
- `task.update` - Update task information (title, description, status, dueDate, assignee)
- `task.delete` - Soft delete tasks (sets deletedAt timestamp)
- Task-org relationship enforcement
- Task-case relationship management
- Task-assignee relationship (must be org member)
- Entitlement checks (plan + role permissions)
- Status transition validation
- Due date validation
- Audit logging for task operations
- Firestore security rules for task collection

### Frontend (Flutter):
- Task list screen (with search, filtering by status/assignee/case, sorting)
- Task creation form (with case selection, assignee selection, due date picker)
- Task details view (view/edit, status updates, assignee changes)
- Task edit form (all fields editable)
- Integration with existing navigation (AppShell)
- Task display in case details screen (tasks linked to case)
- Loading states and error handling
- Empty states for no tasks
- Optimistic UI updates for instant feedback
- Status badge indicators
- Due date indicators (overdue, due soon, due later)

### Data Model:
- Tasks belong to organizations (orgId required)
- Tasks can be associated with cases (caseId optional)
- Tasks have: title, description, status, dueDate, assigneeId, priority
- Soft delete support (deletedAt timestamp)
- Timestamps (createdAt, updatedAt)
- Creator tracking (createdBy, updatedBy)

## 3) Scope Out ❌

- Task dependencies (task A depends on task B) - Future slice
- Task subtasks - Future slice
- Task templates - Future slice
- Task recurring schedules - Future slice
- Task time tracking - Future slice
- Task comments/notes - Future slice
- Task file attachments - Future slice (use documents)
- Task notifications/reminders - Future slice
- Task bulk operations - Future slice
- Task analytics/reporting - Future slice
- Task Gantt charts - Future slice
- Task kanban boards - Future slice

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, membership, entitlements engine)
- ✅ **Slice 1**: Required (Flutter UI shell, navigation, theme system, reusable widgets)
- ✅ **Slice 2**: Required (tasks can be associated with cases)
- ✅ **Slice 2.5**: Required (task assignment requires member list)

**No Dependencies on:**
- Slice 3 (Clients) - Tasks can exist without clients
- Slice 4 (Documents) - Tasks can exist without documents

---

## 5) Backend Endpoints (Cloud Functions)

### 5.1 `task.create` (Callable Function)

**Function Name (Export):** `taskCreate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `task.create` (for reference only, Flutter uses export name)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `task.create` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Plan Gating:** `TASKS` feature must be enabled
- FREE: ✅ (enabled for MVP, like TEAM_MEMBERS)
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
  "status": "string (required, one of: PENDING, IN_PROGRESS, COMPLETED, CANCELLED)",
  "dueDate": "string (optional, ISO 8601 date, must be future or today)",
  "assigneeId": "string (optional, must be org member uid)",
  "priority": "string (optional, one of: LOW, MEDIUM, HIGH, default: MEDIUM)"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "taskId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "title": "string",
    "description": "string | null",
    "status": "string",
    "dueDate": "string | null (ISO 8601 date)",
    "assigneeId": "string | null",
    "assigneeName": "string | null (display name or email)",
    "priority": "string",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing or invalid title, invalid status, invalid priority, invalid dueDate (past date), invalid assigneeId
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `task.create` permission
- `PLAN_LIMIT` (403): TASKS feature not available in plan
- `NOT_FOUND` (404): Case not found (if caseId provided), or assignee not found in org (if assigneeId provided)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**TaskId Generation:**
- Use Firestore auto-ID: `db.collection('organizations').doc(orgId).collection('tasks').doc()`
- Example: "task_abc123def456"

**Title Validation:**
- Required: 1-200 characters
- Trim whitespace: `title.trim()`
- Sanitize: Remove leading/trailing special characters
- Pattern: Allow alphanumeric, spaces, hyphens, underscores, ampersands, commas, periods, parentheses
- Reject: Empty strings, only whitespace

**Description Validation (Optional):**
- Maximum 2000 characters
- Trim whitespace if provided
- Allow null or empty string

**Status Validation:**
- Required: Must be one of: `PENDING`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`
- Case-sensitive (use enum)
- Default: `PENDING` if not provided

**Priority Validation (Optional):**
- Must be one of: `LOW`, `MEDIUM`, `HIGH`
- Default: `MEDIUM` if not provided
- Case-sensitive (use enum)

**Due Date Validation (Optional):**
- If provided, must be valid ISO 8601 date string (YYYY-MM-DD format)
- Must be today or future date (cannot be past)
- **Timezone Handling:** Normalize to UTC midnight (00:00:00) for date-only comparison
- Store as Firestore Timestamp (date only, time set to 00:00:00 UTC)
- **Comparison Logic:** Compare dates only (ignore time) to avoid timezone bugs
- Reject: Invalid format, past dates
- **Example:** "2026-01-25" → Firestore Timestamp(2026-01-25 00:00:00 UTC)

**Assignee Validation (Optional):**
- If provided, must be valid uid (non-empty string)
- Verify assignee is member of organization
- Use `memberListMembers` or direct Firestore query to verify membership
- Reject: Invalid uid, not a member of org

**Case Association (Optional):**
- If `caseId` provided, verify case exists and belongs to org
- Verify user has permission to view case
- If case is soft-deleted, reject association

**Implementation Flow:**
1. Validate auth token (Firebase handles)
2. Validate orgId (required, non-empty)
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'TASKS', requiredPermission: 'task.create' })`
4. Validate title (trim, sanitize, length check)
5. Validate description (optional, length check if provided)
6. Validate status (required, must be valid enum value)
7. Validate priority (optional, default to MEDIUM if not provided)
8. Validate dueDate (optional, must be valid date, must be today or future)
9. If assigneeId provided: verify assignee is org member
10. If caseId provided: verify case exists and belongs to org, verify user can access case
11. Generate taskId using Firestore auto-ID
12. Create task document in `organizations/{orgId}/tasks/{taskId}`
13. Lookup assignee name if assigneeId provided (batch lookup with memberListMembers or direct query)
14. Create audit event:
    - Action: `task.created`
    - Metadata: { title, status, priority, caseId, assigneeId, dueDate }
15. Return success response with task data

**Files:**
- `functions/src/functions/task.ts` - `taskCreate` function
- `functions/src/constants/permissions.ts` - Add `task.create`, `task.read`, `task.update`, `task.delete` permissions
- `functions/src/constants/entitlements.ts` - Set `TASKS: true` for FREE plan

---

### 5.2 `task.get` (Callable Function)

**Function Name (Export):** `taskGet` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `task.get` (for reference only)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `task.read` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ✅ (all org members can read tasks)

**Note:** We need to ADD `task.read`, `task.update`, and `task.delete` permissions to ROLE_PERMISSIONS (see Section 7.1)

**Plan Gating:** `TASKS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "taskId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "taskId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "title": "string",
    "description": "string | null",
    "status": "string",
    "dueDate": "string | null (ISO 8601 date)",
    "assigneeId": "string | null",
    "assigneeName": "string | null",
    "priority": "string",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing taskId
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Task not found, or task belongs to different org, or task is soft-deleted
- `INTERNAL_ERROR` (500): Database read failure

**Implementation Details:**
1. Validate auth token
2. Validate orgId and taskId
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'TASKS', requiredPermission: 'task.read' })`
4. Fetch task document from `organizations/{orgId}/tasks/{taskId}`
5. Verify task exists and is not soft-deleted
6. Lookup assignee name if assigneeId exists (batch lookup or direct query)
7. Return task data

---

### 5.3 `task.list` (Callable Function)

**Function Name (Export):** `taskList` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `task.list` (for reference only)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `task.read` (from ROLE_PERMISSIONS - all org members can read tasks)

**Plan Gating:** `TASKS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "limit": "number (optional, 1-100, default: 50)",
  "offset": "number (optional, >= 0, default: 0)",
  "search": "string (optional, search in title)",
  "status": "string (optional, filter by status: PENDING, IN_PROGRESS, COMPLETED, CANCELLED)",
  "caseId": "string (optional, filter by case)",
  "assigneeId": "string (optional, filter by assignee)",
  "priority": "string (optional, filter by priority: LOW, MEDIUM, HIGH)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "tasks": [
      {
        "taskId": "string",
        "orgId": "string",
        "caseId": "string | null",
        "title": "string",
        "description": "string | null",
        "status": "string",
        "dueDate": "string | null",
        "assigneeId": "string | null",
        "assigneeName": "string | null",
        "priority": "string",
        "createdAt": "ISO 8601 timestamp",
        "updatedAt": "ISO 8601 timestamp",
        "createdBy": "string (uid)",
        "updatedBy": "string (uid)"
      }
    ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Invalid limit (must be 1-100), invalid offset (must be >= 0), invalid status/priority enum
- `NOT_AUTHORIZED` (403): User not a member of org
- `NOT_FOUND` (404): Case not found (if caseId provided and invalid)
- `INTERNAL_ERROR` (500): Database query failure

**Implementation Details:**

**Query Strategy (MVP - Hybrid Approach):**
- **Base Query:** Use Firestore query with `deletedAt == null` and `orderBy updatedAt DESC` (requires base index)
- **Firestore Filters (if provided):** Apply at query level for:
  - Status filter (if provided) - use Firestore where clause
  - Case filter (if provided) - use Firestore where clause
  - Assignee filter (if provided) - use Firestore where clause
  - Priority filter (if provided) - use Firestore where clause
- **In-Memory Filtering:** Apply only for:
  - Search filter (case-insensitive contains on title) - not supported by Firestore
  - **Search Edge Cases:**
    - Empty string (`""`) vs null: Treat empty string as no search (same as null)
    - Special characters: Escape or sanitize for safety (e.g., `%`, `_` if using regex)
    - Multiple terms: Current MVP uses simple contains - no AND/OR logic (future enhancement)
- **Pagination:** 
  - **MVP Approach:** Use Firestore `.offset(offset).limit(limit)` (simple but slower at scale)
  - **Future:** Use cursor-based pagination internally for better performance
  - **Hard Cap:** If result set > 1000 tasks, return error or force cursor pagination
- Batch lookup assignee names for all tasks in result set

**Case Access Validation:**
- If caseId filter provided, verify user can access case
- Filter out tasks linked to cases user cannot access

**Performance Notes:**
- MVP approach: Firestore queries for status/case/assignee/priority filters, in-memory for search
- Base index required: `deletedAt ASC, updatedAt DESC`
- Hard cap: Reject queries that would return > 1000 tasks (force cursor pagination)
- Future: Full-text search (Algolia/Elasticsearch) for better search performance

**Files:**
- `functions/src/functions/task.ts` - `taskList` function

---

### 5.4 `task.update` (Callable Function)

**Function Name (Export):** `taskUpdate` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `task.update` (for reference only)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `task.update` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Additional Permission Checks:**
- If assigneeId is being changed: Also check `task.assign` permission
- If status is being changed to COMPLETED: Also check `task.complete` permission

**Note:** We need to ADD `task.update` permission to ROLE_PERMISSIONS (see Section 7.1)

**Plan Gating:** `TASKS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "taskId": "string (required)",
  "title": "string (optional, 1-200 chars)",
  "description": "string (optional, max 2000 chars, null to clear)",
  "status": "string (optional, valid status enum)",
  "dueDate": "string (optional, ISO 8601 date, null to clear)",
  "assigneeId": "string (optional, must be org member uid, null to unassign)",
  "priority": "string (optional, valid priority enum)",
  "caseId": "string (optional, link to case, null to unlink)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "taskId": "string",
    "orgId": "string",
    "caseId": "string | null",
    "title": "string",
    "description": "string | null",
    "status": "string",
    "dueDate": "string | null",
    "assigneeId": "string | null",
    "assigneeName": "string | null",
    "priority": "string",
    "createdAt": "ISO 8601 timestamp",
    "updatedAt": "ISO 8601 timestamp",
    "createdBy": "string (uid)",
    "updatedBy": "string (uid)"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing taskId, invalid field values, invalid status transition
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `task.update` permission, or missing `task.assign` (if assignee changed), or missing `task.complete` (if status changed to COMPLETED)
- `NOT_FOUND` (404): Task not found, or assignee not found (if assigneeId provided)
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Status Transition Validation (Explicit Matrix):**

**Allowed Transitions:**
```
PENDING → IN_PROGRESS ✅
PENDING → COMPLETED ✅
PENDING → CANCELLED ✅

IN_PROGRESS → COMPLETED ✅
IN_PROGRESS → CANCELLED ✅
IN_PROGRESS → PENDING ✅ (reopen)

COMPLETED → CANCELLED ✅ (reopen - requires CANCELLED intermediate step)

CANCELLED → PENDING ✅ (reopen)
```

**Rejected Transitions:**
```
COMPLETED → IN_PROGRESS ❌ (must go through CANCELLED → PENDING first)
COMPLETED → PENDING ❌ (must go through CANCELLED first)
CANCELLED → IN_PROGRESS ❌ (must go through PENDING first)
CANCELLED → COMPLETED ❌ (must go through PENDING → IN_PROGRESS first)
```

**Product Rule - Anti-Accidental Reopen Design:**
- **Intentional Design:** COMPLETED tasks cannot be directly reopened to PENDING or IN_PROGRESS
- **Reopen Process:** Must go through CANCELLED first (COMPLETED → CANCELLED → PENDING → IN_PROGRESS)
- **Rationale:** Prevents accidental reopening of completed work, requires explicit cancellation step
- **UI Impact:** Status dropdown should disable PENDING and IN_PROGRESS options for COMPLETED tasks, only show CANCELLED
- **Future Consideration:** If user feedback indicates this is too restrictive, consider allowing COMPLETED → PENDING directly in a future version

**Implementation:**
```typescript
const ALLOWED_TRANSITIONS: Record<TaskStatus, TaskStatus[]> = {
  PENDING: ['IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'CANCELLED', 'PENDING'],
  COMPLETED: ['CANCELLED'],
  CANCELLED: ['PENDING'],
};

function isValidStatusTransition(from: TaskStatus, to: TaskStatus): boolean {
  return ALLOWED_TRANSITIONS[from]?.includes(to) ?? false;
}
```

**Assignee Update:**
- If assigneeId provided, verify assignee is org member
- If assigneeId is null, unassign task (clear assignee)
- Lookup assignee name after update

**Due Date Update:**
- If dueDate provided, must be valid date (today or future)
- If dueDate is null, clear due date
- Reject: Past dates

**Permission Checks (Granular):**
- General updates (title, description, priority, dueDate, status): Check `task.update` permission
- Assignee changes: Check `task.update` AND `task.assign` permissions
- Status change to COMPLETED: Check `task.update` AND `task.complete` permissions
- Other status changes: Check `task.update` permission only

**Implementation Flow:**
1. Validate auth token
2. Validate orgId and taskId
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'TASKS', requiredPermission: 'task.update' })`
4. Fetch existing task document
5. Verify task exists and is not soft-deleted
6. Validate all provided fields (title, description, status, dueDate, assigneeId, priority)
7. **Permission checks based on what's being updated:**
   - If any field changed: Check `task.update` permission
   - If assigneeId changed: Also check `task.assign` permission
   - If status changed to COMPLETED: Also check `task.complete` permission
8. Validate status transition (if status changed)
9. If assigneeId provided/changed: verify assignee is org member
10. Update task document (only provided fields)
11. Update `updatedAt` and `updatedBy`
12. Lookup assignee name if assigneeId exists
13. Create audit event with specific action type:
    - If status changed to COMPLETED: `task.completed` (metadata: { previousStatus, newStatus, completedBy: uid })
    - If assignee changed: `task.assigned` or `task.reassigned` (metadata: { previousAssigneeId, newAssigneeId, previousAssigneeName, newAssigneeName })
    - If case linked/unlinked: `task.case_linked` or `task.case_unlinked` (metadata: { caseId, previousCaseId })
    - Otherwise: `task.updated` (metadata: { changedFields: { title?, description?, status?, dueDate?, priority? } })
14. Return updated task data

**Files:**
- `functions/src/functions/task.ts` - `taskUpdate` function

---

### 5.5 `task.delete` (Callable Function)

**Function Name (Export):** `taskDelete` ⚠️ **Flutter MUST use this name**  
**Type:** Firebase Callable Function  
**Callable Name (Internal):** `task.delete` (for reference only)

**Auth Requirement:** Valid Firebase Auth token

**Required Permission:** `task.delete` (from ROLE_PERMISSIONS)
- ADMIN: ✅
- LAWYER: ✅
- PARALEGAL: ✅
- VIEWER: ❌

**Note:** We need to ADD `task.delete` permission to ROLE_PERMISSIONS (see Section 7.1)

**Plan Gating:** `TASKS` feature must be enabled

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "taskId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "taskId": "string",
    "message": "Task deleted successfully"
  }
}
```

**Error Responses:**
- `ORG_REQUIRED` (400): Missing orgId
- `VALIDATION_ERROR` (400): Missing taskId
- `NOT_AUTHORIZED` (403): User not a member of org, or role doesn't have `task.delete` permission
- `NOT_FOUND` (404): Task not found, or task belongs to different org, or task already deleted
- `INTERNAL_ERROR` (500): Database write failure

**Implementation Details:**

**Soft Delete:**
- Set `deletedAt` to current timestamp
- Update `updatedAt` and `updatedBy`
- Do NOT remove document from Firestore
- Task will be filtered out of list queries (where deletedAt == null)

**Implementation Flow:**
1. Validate auth token
2. Validate orgId and taskId
3. Check entitlement: `checkEntitlement({ uid, orgId, requiredFeature: 'TASKS', requiredPermission: 'task.delete' })`
4. Fetch task document
5. Verify task exists and is not already soft-deleted
6. Update task document: set `deletedAt` to current timestamp, update `updatedAt` and `updatedBy`
7. Create audit event:
    - Action: `task.deleted`
    - Metadata: { taskId, title, status, caseId, assigneeId }
8. Return success response

**Files:**
- `functions/src/functions/task.ts` - `taskDelete` function

---

## 6) Frontend Implementation (Flutter)

### 6.1 Data Models

**TaskModel** (`legal_ai_app/lib/core/models/task_model.dart`):

```dart
enum TaskStatus {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String value;
  const TaskStatus(this.value);
  
  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskStatus.pending,
    );
  }
}

enum TaskPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  final String value;
  const TaskPriority(this.value);
  
  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

class TaskModel {
  final String taskId;
  final String orgId;
  final String? caseId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? assigneeId;
  final String? assigneeName;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  
  // Computed properties
  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == TaskStatus.completed) return false;
    // Normalize to date-only for comparison (avoid timezone issues)
    final today = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final due = DateTime.utc(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }
  
  bool get isDueSoon {
    if (dueDate == null) return false;
    if (status == TaskStatus.completed) return false;
    // Normalize to date-only for comparison (avoid timezone issues)
    final today = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final due = DateTime.utc(dueDate!.year, dueDate!.month, dueDate!.day);
    final daysUntilDue = due.difference(today).inDays;
    return daysUntilDue >= 0 && daysUntilDue <= 3;
  }
  
  String get statusDisplayName {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  String get priorityDisplayName {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
  
  // Factory constructor from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      taskId: json['taskId'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'PENDING'),
      dueDate: json['dueDate'] != null 
          ? _parseDateOnly(json['dueDate'] as String) // Parse date-only string safely (UTC)
          : null,
      assigneeId: json['assigneeId'] as String?,
      assigneeName: json['assigneeName'] as String?,
      priority: TaskPriority.fromString(json['priority'] as String? ?? 'MEDIUM'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String,
      updatedBy: json['updatedBy'] as String,
    );
  }
  
  // Helper method to parse date-only string (YYYY-MM-DD) as UTC
  static DateTime _parseDateOnly(String dateString) {
    final parts = dateString.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date format: $dateString');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return DateTime.utc(year, month, day); // Parse as UTC to avoid timezone issues
  }
  
  // toJson method
  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'orgId': orgId,
      'caseId': caseId,
      'title': title,
      'description': description,
      'status': status.value,
      'dueDate': dueDate?.toIso8601String().split('T')[0], // Date only (YYYY-MM-DD)
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'priority': priority.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }
}
```

---

### 6.2 Service Layer

**TaskService** (`legal_ai_app/lib/core/services/task_service.dart`):

```dart
import 'package:flutter/foundation.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/cloud_functions_service.dart';

class TaskService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<TaskModel> createTask({
    required OrgModel org,
    required String title,
    String? description,
    required TaskStatus status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    String? caseId,
  }) async {
    final response = await _functionsService.callFunction('taskCreate', {
      'orgId': org.orgId,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'status': status.value,
      if (dueDate != null) {
        // Normalize to date-only (UTC midnight) to avoid timezone issues
        final dateOnly = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
        'dueDate': dateOnly.toIso8601String().split('T')[0],
      }
      if (assigneeId != null && assigneeId.trim().isNotEmpty) 'assigneeId': assigneeId.trim(),
      'priority': priority.value,
    });

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.createTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to create task. Please try again.';
    throw message;
  }

  Future<TaskModel> getTask({
    required OrgModel org,
    required String taskId,
  }) async {
    final response = await _functionsService.callFunction('taskGet', {
      'orgId': org.orgId,
      'taskId': taskId,
    });

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.getTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to load task. Please try again.';
    throw message;
  }

  Future<({List<TaskModel> tasks, int total, bool hasMore})> listTasks({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    final response = await _functionsService.callFunction('taskList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status.value,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (assigneeId != null && assigneeId.trim().isNotEmpty) 'assigneeId': assigneeId.trim(),
      if (priority != null) 'priority': priority.value,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (tasks: list, total: total, hasMore: hasMore);
    }

    debugPrint('TaskService.listTasks error: $response');
    final message = response['error']?['message'] ??
        'Failed to load tasks. Please try again.';
    throw message;
  }

  Future<TaskModel> updateTask({
    required OrgModel org,
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority? priority,
    String? caseId, // Support case linking/unlinking
    // Explicit flags for clearing fields (fixes "null vs not passed" issue)
    bool clearDueDate = false,
    bool unassign = false,
    bool unlinkCase = false,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'taskId': taskId,
    };

    if (title != null) payload['title'] = title.trim();
    if (description != null) {
      payload['description'] = description.trim().isEmpty ? null : description.trim();
    }
    if (status != null) payload['status'] = status.value;
    
    // Handle dueDate: explicit clear flag vs new date
    if (clearDueDate) {
      payload['dueDate'] = null; // Explicitly clear
    } else if (dueDate != null) {
      // Normalize to date-only (UTC midnight) to avoid timezone issues
      final dateOnly = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
      payload['dueDate'] = dateOnly.toIso8601String().split('T')[0];
    }
    
    // Handle assigneeId: explicit unassign flag vs new assignee
    if (unassign) {
      payload['assigneeId'] = null; // Explicitly unassign
    } else if (assigneeId != null && assigneeId.trim().isNotEmpty) {
      payload['assigneeId'] = assigneeId.trim();
    }
    
    // Handle caseId: explicit unlink flag vs new case link
    if (unlinkCase) {
      payload['caseId'] = null; // Explicitly unlink
    } else if (caseId != null && caseId.trim().isNotEmpty) {
      payload['caseId'] = caseId.trim();
    }
    
    if (priority != null) payload['priority'] = priority.value;

    final response = await _functionsService.callFunction('taskUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.updateTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to update task. Please try again.';
    throw message;
  }

  Future<void> deleteTask({
    required OrgModel org,
    required String taskId,
  }) async {
    final response = await _functionsService.callFunction('taskDelete', {
      'orgId': org.orgId,
      'taskId': taskId,
    });

    if (response['success'] != true) {
      debugPrint('TaskService.deleteTask error: $response');
      final message = response['error']?['message'] ??
          'Failed to delete task. Please try again.';
      throw message;
    }
  }
}
```

---

### 6.3 State Management

**TaskProvider** (`legal_ai_app/lib/features/tasks/providers/task_provider.dart`):

```dart
import 'package:flutter/foundation.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/task_service.dart';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();

  final List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  String? _lastLoadedCaseId; // Track last loaded caseId for auto-refresh
  String? _lastLoadedOrgId; // Track last loaded orgId
  String? _lastQuerySignature; // Track query signature to prevent duplicate loads

  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  TaskModel? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String? get lastLoadedCaseId => _lastLoadedCaseId;

  Future<void> loadTasks({
    required OrgModel org,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    // Create query signature to prevent duplicate loads (includes all filters)
    final querySignature = '${org.orgId}_${caseId ?? 'null'}_${search ?? 'null'}_${status?.value ?? 'null'}_${assigneeId ?? 'null'}_${priority?.value ?? 'null'}';
    
    // Prevent duplicate loads - only block if exact same query is already loading
    if (_isLoading && _lastQuerySignature == querySignature) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _tasks.clear(); // Clear existing tasks to show loading state immediately
    _lastLoadedCaseId = caseId;
    _lastLoadedOrgId = org.orgId;
    _lastQuerySignature = querySignature;
    notifyListeners();

    try {
      final result = await _taskService.listTasks(
        org: org,
        search: search,
        status: status,
        caseId: caseId,
        assigneeId: assigneeId,
        priority: priority,
      );
      
      _tasks.clear();
      // Use a Set to ensure no duplicates by taskId
      final existingIds = <String>{};
      for (final task in result.tasks) {
        if (!existingIds.contains(task.taskId)) {
          _tasks.add(task);
          existingIds.add(task.taskId);
        }
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('TaskProvider.loadTasks error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTaskDetails({
    required OrgModel org,
    required String taskId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final task = await _taskService.getTask(org: org, taskId: taskId);
      _selectedTask = task;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _selectedTask = null;
      debugPrint('TaskProvider.loadTaskDetails error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask({
    required OrgModel org,
    required String title,
    String? description,
    required TaskStatus status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    
    // Optimistic UI update: Add task to list immediately
    final optimisticTaskId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticTask = TaskModel(
      taskId: optimisticTaskId,
      orgId: org.orgId,
      caseId: caseId,
      title: title,
      description: description,
      status: status,
      dueDate: dueDate,
      assigneeId: assigneeId,
      assigneeName: null, // Will be set after backend confirms
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: '',
      updatedBy: '',
    );
    
    // Only add optimistically if we're viewing tasks for this case/org
    if ((caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) ||
        (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId)) {
      _tasks.add(optimisticTask);
    }
    
    notifyListeners();

    try {
      final createdTask = await _taskService.createTask(
        org: org,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        assigneeId: assigneeId,
        priority: priority,
        caseId: caseId,
      );
      
      // Remove ONLY the specific optimistic task (ID-specific removal)
      _tasks.removeWhere((t) => t.taskId == optimisticTaskId);
      _tasks.add(createdTask);
      
      // Reload tasks to ensure we have latest data (assignee names, etc.)
      if (caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) {
        loadTasks(org: org, caseId: caseId).catchError((e) {
          debugPrint('Error reloading tasks after create: $e');
        });
      } else if (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId) {
        loadTasks(org: org).catchError((e) {
          debugPrint('Error reloading tasks after create: $e');
        });
      } else {
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      // Remove ONLY the specific optimistic task on error (ID-specific removal)
      _tasks.removeWhere((t) => t.taskId == optimisticTaskId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTask({
    required OrgModel org,
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority? priority,
    String? caseId,
    // Explicit flags for clearing fields (fixes "null vs not passed" issue)
    bool clearDueDate = false,
    bool unassign = false,
    bool unlinkCase = false,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    
    // Optimistic UI update: Update task in list immediately
    final taskIndex = _tasks.indexWhere((t) => t.taskId == taskId);
    TaskModel? previousTask;
    if (taskIndex != -1) {
      previousTask = _tasks[taskIndex];
      _tasks[taskIndex] = TaskModel(
        taskId: previousTask.taskId,
        orgId: previousTask.orgId,
        caseId: unlinkCase ? null : (caseId ?? previousTask.caseId),
        title: title ?? previousTask.title,
        description: description ?? previousTask.description,
        status: status ?? previousTask.status,
        dueDate: clearDueDate ? null : (dueDate ?? previousTask.dueDate),
        assigneeId: unassign ? null : (assigneeId ?? previousTask.assigneeId),
        assigneeName: previousTask.assigneeName, // Will be updated after backend confirms
        priority: priority ?? previousTask.priority,
        createdAt: previousTask.createdAt,
        updatedAt: DateTime.now(),
        createdBy: previousTask.createdBy,
        updatedBy: previousTask.updatedBy,
      );
    }
    
    // Update selected task if it's the one being updated
    if (_selectedTask?.taskId == taskId && previousTask != null) {
      _selectedTask = _tasks[taskIndex];
    }
    
    notifyListeners();

    try {
      final updatedTask = await _taskService.updateTask(
        org: org,
        taskId: taskId,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        assigneeId: assigneeId,
        priority: priority,
        caseId: caseId,
        clearDueDate: clearDueDate,
        unassign: unassign,
        unlinkCase: unlinkCase,
      );
      
      // Replace optimistic update with real data
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
      }
      if (_selectedTask?.taskId == taskId) {
        _selectedTask = updatedTask;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      if (taskIndex != -1 && previousTask != null) {
        _tasks[taskIndex] = previousTask;
      }
      if (_selectedTask?.taskId == taskId && previousTask != null) {
        _selectedTask = previousTask;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTask({
    required OrgModel org,
    required String taskId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    
    // Optimistic UI update: Remove task from list immediately
    final taskIndex = _tasks.indexWhere((t) => t.taskId == taskId);
    TaskModel? removedTask;
    if (taskIndex != -1) {
      removedTask = _tasks.removeAt(taskIndex);
    }
    if (_selectedTask?.taskId == taskId) {
      _selectedTask = null;
    }
    notifyListeners();

    try {
      await _taskService.deleteTask(org: org, taskId: taskId);
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      if (removedTask != null && taskIndex != -1) {
        _tasks.insert(taskIndex, removedTask);
      }
      if (removedTask != null && _selectedTask == null && removedTask.taskId == taskId) {
        _selectedTask = removedTask;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all tasks (used when switching organizations)
  void clearTasks() {
    _tasks.clear();
    _selectedTask = null;
    _errorMessage = null;
    _isLoading = false;
    _isUpdating = false;
    _lastLoadedCaseId = null;
    _lastLoadedOrgId = null;
    _lastQuerySignature = null;
    notifyListeners();
  }
}
```

---

### 6.4 UI Screens

**TaskListScreen** (`legal_ai_app/lib/features/tasks/screens/task_list_screen.dart`):

**Key Features:**
- Search bar (300ms debounce - Learning 33)
- Filter by status (dropdown)
- Filter by priority (dropdown)
- Filter by assignee (dropdown with member list)
- Filter by case (dropdown with case list)
- Sort options (due date, priority, updated date)
- Pull-to-refresh
- Empty states
- Loading states
- Error handling
- Optimistic UI updates (Learning 32)
- Task cards with:
  - Status badge (color-coded)
  - Priority indicator
  - Due date (with overdue/due soon indicators)
  - Assignee name/avatar
  - Case link (if associated)
  - Quick actions (mark complete, edit, delete)

**TaskCreateScreen** (`legal_ai_app/lib/features/tasks/screens/task_create_screen.dart`):

**Key Features:**
- Title field (required, 1-200 chars)
- Description field (optional, max 2000 chars)
- Status dropdown (default: PENDING)
- Priority dropdown (default: MEDIUM)
- Due date picker (optional, date only, must be today or future)
- Case selection dropdown (optional, shows cases user can access)
- Assignee selection dropdown (optional, shows org members)
- Form validation
- Error handling
- Loading states
- Optimistic UI update on create (Learning 32)

**TaskDetailsScreen** (`legal_ai_app/lib/features/tasks/screens/task_details_screen.dart`):

**Key Features:**
- View mode (read-only)
- Edit mode (all fields editable)
- Status update (with transition validation)
- Assignee change (dropdown with member list)
- Due date update (date picker)
- Priority update (dropdown)
- Case linking/unlinking
- Delete button (with confirmation)
- Loading states
- Error handling
- Optimistic UI updates (Learning 32)
- Related case link (if task linked to case)

---

## 7) Security & Permissions

### 7.1 Role Permissions

**Update `functions/src/constants/permissions.ts`:**

**Current permissions already have:**
- `task.create`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌
- `task.assign`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌
- `task.complete`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌

**ADD these new permissions (world-class approach):**
- `task.read`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ✅ (all can read)
- `task.update`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌
- `task.delete`: ADMIN ✅, LAWYER ✅, PARALEGAL ✅, VIEWER ❌

**Updated ROLE_PERMISSIONS structure:**
```typescript
export const ROLE_PERMISSIONS = {
  ADMIN: {
    // ... existing permissions
    'task.create': true,
    'task.read': true,
    'task.update': true,
    'task.delete': true,
    'task.assign': true,
    'task.complete': true,
    // ... other permissions
  },
  LAWYER: {
    // ... existing permissions
    'task.create': true,
    'task.read': true,
    'task.update': true,
    'task.delete': true,
    'task.assign': true,
    'task.complete': true,
    // ... other permissions
  },
  PARALEGAL: {
    // ... existing permissions
    'task.create': true,
    'task.read': true,
    'task.update': true,
    'task.delete': true,
    'task.assign': true,
    'task.complete': true,
    // ... other permissions
  },
  VIEWER: {
    // ... existing permissions
    'task.create': false,
    'task.read': true, // Can view tasks
    'task.update': false,
    'task.delete': false,
    'task.assign': false,
    'task.complete': false,
    // ... other permissions
  },
};
```

**Permission Usage:**
- `task.create`: For creating tasks
- `task.read`: For reading tasks (all org members)
- `task.update`: For general updates (title, description, priority, dueDate, status)
- `task.delete`: For deleting tasks
- `task.assign`: For changing assignee (additional check in `taskUpdate`)
- `task.complete`: For status changes to COMPLETED (additional check in `taskUpdate`)

### 7.2 Plan Features

**Update `functions/src/constants/entitlements.ts`:**

**Current state:** `TASKS: false` for FREE plan

**Change required:** Set `TASKS: true` for FREE plan (like we did with TEAM_MEMBERS for Slice 2.5)

```typescript
export const PLAN_FEATURES = {
  FREE: {
    // ... existing features
    TASKS: true, // Enable for MVP (like TEAM_MEMBERS)
    // ... other features
  },
  // ... other plans already have TASKS: true
};
```

**Rationale:** Enable TASKS for FREE plan to allow multi-user testing and collaboration features.

### 7.3 Firestore Security Rules

**Add to `firestore.rules`:**

```javascript
// Slice 5: Tasks under organizations collection
match /organizations/{orgId}/tasks/{taskId} {
  // Read: org members can read non-deleted tasks
  allow read: if isOrgMember(orgId) &&
    (!('deletedAt' in resource.data) || resource.data.deletedAt == null);

  // All writes are via Admin SDK (Cloud Functions); deny direct client writes
  allow create, update, delete: if false;
}
```

---

## 8) Testing Requirements

### 8.0 Testing Philosophy (Critical - Apply All Learnings)

**Key Principles:**
- ✅ **Test edge cases EARLY** (Learning 27) - Don't wait until after multiple fixes
- ✅ **Test with real data** - Use actual org members, cases, assignees
- ✅ **Test permission boundaries** - VIEWER cannot create/update/delete
- ✅ **Test status transitions** - Invalid transitions should be rejected
- ✅ **Test optimistic updates** - Verify rollback on error
- ✅ **Test debounce timing** - Verify 300ms, not 500ms or 800ms
- ✅ **Test async guards** - Verify no race conditions
- ✅ **Test state persistence** - Verify tasks persist on org switch, browser refresh

**Common Mistakes to Avoid:**
- ❌ Using callable names instead of export names (Learning 1)
- ❌ Hiding soft delete in update function (Learning 17)
- ❌ Not testing edge cases early (Learning 27)
- ❌ Using 500ms+ debounce times (Learning 33)
- ❌ Not using optimistic UI updates (Learning 32)
- ❌ Missing async guards causing race conditions (Learning 34)
- ❌ Not updating related data immediately (Learning 31)
- ❌ Using context after dispose() (Learning 30)
- ❌ Duplicate heroTags for FABs (Learning 29)

### 8.1 Backend Testing

**Manual Testing Checklist:**
- [ ] Create task with all fields
- [ ] Create task with minimal fields (title, status only)
- [ ] Create task with case association
- [ ] Create task with assignee
- [ ] Create task with due date (today)
- [ ] Create task with due date (future)
- [ ] Reject: Create task with past due date
- [ ] Reject: Create task with invalid assignee (not org member)
- [ ] Reject: Create task with invalid case (doesn't exist)
- [ ] Get task by ID
- [ ] Reject: Get non-existent task
- [ ] List tasks (all)
- [ ] List tasks filtered by status
- [ ] List tasks filtered by case
- [ ] List tasks filtered by assignee
- [ ] List tasks filtered by priority
- [ ] List tasks with search (title)
- [ ] List tasks with pagination
- [ ] Update task title
- [ ] Update task status (valid transitions)
- [ ] Reject: Update task status (invalid transition)
- [ ] Update task assignee
- [ ] Update task due date
- [ ] Reject: Update task with past due date
- [ ] Unassign task (set assigneeId to null)
- [ ] Clear task due date (set to null)
- [ ] Delete task (soft delete)
- [ ] Reject: Delete already deleted task
- [ ] Permission checks (VIEWER cannot create/update/delete)
- [ ] Case access validation (cannot see tasks for inaccessible cases)

### 8.2 Frontend Testing

**Manual Testing Checklist:**
- [ ] Task list loads and displays tasks
- [ ] Search works (300ms debounce)
- [ ] Status filter works
- [ ] Priority filter works
- [ ] Assignee filter works
- [ ] Case filter works
- [ ] Pull-to-refresh works
- [ ] Create task form validates inputs
- [ ] Create task shows optimistic update
- [ ] Create task appears in list immediately
- [ ] Edit task updates immediately (optimistic)
- [ ] Delete task removes immediately (optimistic)
- [ ] Status update works with valid transitions
- [ ] Status update rejects invalid transitions (UI validation)
- [ ] Due date picker only allows today or future
- [ ] Assignee dropdown shows org members
- [ ] Case dropdown shows accessible cases
- [ ] Task details screen loads correctly
- [ ] Task details screen edit mode works
- [ ] Error messages display correctly
- [ ] Loading states show during operations
- [ ] Empty states show when no tasks
- [ ] Organization switching clears task list
- [ ] Browser refresh maintains state

### 8.3 Integration Testing

**End-to-End Flows:**
- [ ] Create task → appears in list immediately (optimistic) → backend confirms → real data replaces optimistic
- [ ] Create task with case → appears in case details → appears in task list filtered by case
- [ ] Assign task to member → appears in their filtered list → assignee name displays correctly
- [ ] Mark task complete → status updates immediately (optimistic) → backend confirms
- [ ] Update task → changes appear immediately (optimistic) → backend confirms
- [ ] Delete task → removed immediately (optimistic) → backend confirms → cannot be retrieved
- [ ] Switch organization → tasks cleared → load new org tasks
- [ ] Browser refresh → tasks persist → state maintained
- [ ] Invalid status transition → rejected with clear error message
- [ ] Past due date → rejected with clear error message
- [ ] Invalid assignee → rejected with clear error message

### 8.4 Performance Testing

**Load Testing:**
- [ ] Test with 50 tasks (should be fast)
- [ ] Test with 200 tasks (should be acceptable)
- [ ] Test with 500 tasks (should work, may be slower)
- [ ] Test search with 200 tasks (should be responsive, 300ms debounce)
- [ ] Test filtering with multiple filters (status + assignee + case)

**Optimization Verification:**
- [ ] Verify 300ms debounce (not 500ms or 800ms)
- [ ] Verify optimistic updates appear instantly
- [ ] Verify no unnecessary rebuilds
- [ ] Verify state guards prevent race conditions

---

## 9) Learnings Applied

### ✅ Learning 1: Firebase Callable Function Names
- **Applied:** All functions use export names (`taskCreate`, not `task.create`)
- **Documentation:** Clear warnings in build card

### ✅ Learning 17: Explicit Soft Delete Endpoints
- **Applied:** Dedicated `taskDelete` function (not hidden in update)
- **Implementation:** Sets `deletedAt` timestamp, creates audit event

### ✅ Learning 18: Firestore OR Logic via Two-Query Merge
- **Not Needed:** Task list doesn't require OR logic (simpler queries)

### ✅ Learning 19: Cursor-Based vs Offset Pagination
- **Applied:** Offset pagination for MVP (documented for future cursor-based)
- **Note:** Works for < 1000 tasks, optimize later if needed

### ✅ Learning 20: Being Honest About Search Scope
- **Applied:** In-memory search on title only (documented limitation)
- **Future:** Full-text search in Slice 6+ (AI features)

### ✅ Learning 21: Security Rules Must Be Concrete
- **Applied:** Concrete Firestore rules (read for members, no direct writes)
- **Implementation:** All writes via Cloud Functions

### ✅ Learning 22: State Persistence is First-Class
- **Applied:** Task list persists on org switch, browser refresh
- **Implementation:** Proper state management in TaskProvider

### ✅ Learning 32: Optimistic UI Updates
- **Applied:** All create/update/delete operations use optimistic updates
- **Implementation:** Instant feedback, rollback on error

### ✅ Learning 33: Debounce Times Affect Performance
- **Applied:** Search debounce set to 300ms (not 500ms)
- **Implementation:** Fast, responsive search

### ✅ Learning 34: Async State Management Guards
- **Applied:** Guards in TaskProvider to prevent concurrent operations
- **Implementation:** `_isLoading`, `_isUpdating` flags

### ✅ Learning 31: Immediate UI Updates for Related Data
- **Applied:** Update task list when task is created/updated/deleted
- **Implementation:** Notify listeners, reload if needed

### ✅ Learning 30: Store Provider References Before dispose()
- **Applied:** Proper dispose handling in all screens
- **Implementation:** Store references early, use after disposal

### ✅ Learning 29: Unique heroTag for FABs
- **Applied:** Unique heroTag for task list FAB
- **Implementation:** `heroTag: 'task_fab'`

---

## 10) Firestore Indexes

**⚠️ CRITICAL: Create the base index BEFORE deployment or queries will fail**

**Required Index (add to `firestore.indexes.json`):**

### 10.1 Tasks Collection Index

**Base Index (REQUIRED): Tasks by org, deletedAt, updatedAt**
```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "deletedAt", "order": "ASCENDING" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
}
```

**Deployment:**
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Wait for indexes to build (check Firebase Console)
# Indexes typically build in 1-5 minutes
```

**Note:** 
- **MVP Approach:** Use Firestore queries for status/case/assignee/priority filters (requires base index only)
- **Search:** In-memory filtering on title (not supported by Firestore)
- **Hard Cap:** Reject queries that would return > 1000 tasks
- **Future:** Add composite indexes for multi-filter queries if needed (e.g., status + assignee). These are optional and can be added later when performance requires them.

---

## 11) Edge Cases & Failure States

### 11.1 Assignee Leaves Organization

**Scenario:** Task is assigned to a member who leaves the organization.

**Handling:**
- **Option A (Recommended):** Keep task assigned to that uid, but show "Member no longer in organization" in UI
- **Option B:** Auto-reassign to task creator when member leaves
- **Option C:** Mark as unassigned when member leaves

**Implementation:** 
- In `taskUpdate`, verify assignee is still org member before assignment
- In `taskList`, filter out tasks with invalid assignees OR show them with warning
- **For MVP:** Keep assigned, show warning in UI if assignee not found in member list

### 11.2 Case Deleted

**Scenario:** Task is linked to a case that gets soft-deleted.

**Handling:**
- Keep task linked to caseId
- Show "Case Deleted" warning in UI
- Allow task to be unlinked from case
- Task remains functional

**Implementation:**
- In `taskList`, verify case exists if caseId provided
- In UI, show warning if case is soft-deleted
- Allow user to unlink task from deleted case

### 11.3 Past Due Dates

**Scenario:** User tries to set due date in the past.

**Handling:**
- **Reject in backend:** Return `VALIDATION_ERROR: "Due date must be today or in the future"`
- **UI validation:** Date picker should not allow past dates
- **Existing tasks:** Allow tasks with past due dates to exist (they're already overdue)

### 11.4 Invalid Status Transitions

**Scenario:** User tries invalid status transition (e.g., COMPLETED → IN_PROGRESS).

**Handling:**
- **Backend validation:** Reject with `VALIDATION_ERROR: "Invalid status transition"`
- **UI validation:** Disable invalid status options in dropdown
- **Error message:** Show clear message explaining valid transitions

### 11.5 Duplicate Assignments

**Scenario:** Multiple tasks assigned to same person (not really an error, but consider limits).

**Handling:**
- **No limit for MVP:** Allow unlimited tasks per assignee
- **Future:** Consider task limits per assignee for better workload management

### 11.6 Task with Deleted Case

**Scenario:** Task linked to case, case gets deleted.

**Handling:**
- Task remains linked to caseId
- Show "Case Deleted" indicator in task list/details
- Allow unlinking from deleted case
- Task remains functional

---

## 12) Error Handling

### 12.1 Backend Error Codes

**Add to `functions/src/constants/errors.ts`:**

```typescript
export enum ErrorCode {
  // ... existing error codes
  INVALID_STATUS_TRANSITION = 'INVALID_STATUS_TRANSITION',
  INVALID_DUE_DATE = 'INVALID_DUE_DATE',
  ASSIGNEE_NOT_MEMBER = 'ASSIGNEE_NOT_MEMBER',
}

export const ERROR_MESSAGES: Record<ErrorCode, string> = {
  // ... existing messages
  [ErrorCode.INVALID_STATUS_TRANSITION]: 'Invalid status transition',
  [ErrorCode.INVALID_DUE_DATE]: 'Due date must be today or in the future',
  [ErrorCode.ASSIGNEE_NOT_MEMBER]: 'Assignee must be a member of the organization',
};
```

### 12.2 Frontend Error Handling

- Display user-friendly error messages
- Show specific errors for validation failures
- Handle network errors gracefully
- Provide retry mechanisms
- Log errors for debugging

### 12.3 Concurrent Operation Handling

**Scenario:** Two users edit the same task simultaneously.

**Handling:**
- **Last-Write-Wins Strategy (MVP):** The last update wins, overwrites previous changes
- **Implementation:** Firestore automatically handles this with timestamp-based `updatedAt` field
- **User Experience:** 
  - If user A updates title while user B updates status, user B's update will overwrite user A's title change
  - **Future Enhancement:** Consider optimistic locking with version numbers or conflict resolution UI
- **Audit Trail:** Both operations are logged in audit events, so changes can be traced
- **Recommendation:** For MVP, accept last-write-wins. Add conflict resolution UI in future if needed.

**Race Condition Prevention:**
- Backend uses Firestore transactions for critical operations (e.g., status transitions)
- Frontend uses async guards (`_isUpdating`, `_isLoading`) to prevent concurrent calls
- Optimistic updates are ID-specific to prevent cross-operation interference

---

## 13) Performance Considerations

### 13.1 MVP Approach (Current)
- In-memory filtering (works for < 1000 tasks)
- Offset pagination (works for < 1000 tasks)
- Batch assignee name lookup
- 300ms debounce for search

### 13.2 Future Optimizations
- Cursor-based pagination (when > 500 tasks)
- Firestore composite indexes for efficient querying
- Full-text search (Algolia/Elasticsearch)
- Caching frequently accessed tasks

---

## 14) Integration Points

### 14.1 Case Details Screen Integration
- Display tasks linked to case
- "Add Task" button in case details
- Filter task list by case
- Navigate to task from case details

### 14.2 Member List Integration
- Use `memberListMembers` for assignee dropdown
- Display assignee names in task list
- Filter tasks by assignee

### 14.3 Navigation Integration
- Add "Tasks" tab to AppShell
- Routes: `/tasks`, `/tasks/create`, `/tasks/details/:id`
- Breadcrumb navigation

---

## 15) Success Criteria

### Backend:
- [ ] All 5 functions implemented and deployed
- [ ] All functions pass manual testing
- [ ] Security rules configured
- [ ] Audit logging working
- [ ] Error handling comprehensive
- [ ] Validation working correctly

### Frontend:
- [ ] All 3 screens implemented
- [ ] Task list working with filters
- [ ] Task create working
- [ ] Task update working
- [ ] Task delete working
- [ ] Optimistic UI updates working
- [ ] Search working (300ms debounce)
- [ ] Integration with cases working
- [ ] Integration with members working
- [ ] All edge cases handled

### Integration:
- [ ] Tasks appear in case details
- [ ] Task assignment working
- [ ] State management working
- [ ] Organization switching working
- [ ] Browser refresh working

---

## 16) Deployment Checklist

### Before Deployment:
- [ ] All functions implemented
- [ ] All functions tested manually
- [ ] Firestore indexes created (REQUIRED - see Section 10)
- [ ] Security rules updated
- [ ] Error codes added
- [ ] Permissions added to ROLE_PERMISSIONS
- [ ] TASKS feature added to PLAN_FEATURES
- [ ] Functions exported in `index.ts`

### Deployment:
- [ ] Deploy functions: `firebase deploy --only functions`
- [ ] Deploy security rules: `firebase deploy --only firestore:rules`
- [ ] Verify functions deployed correctly
- [ ] Test functions from Flutter app

### After Deployment:
- [ ] Verify all functions working
- [ ] Test end-to-end flows
- [ ] Verify security rules working
- [ ] Check error handling
- [ ] Monitor for errors

---

## 17) Implementation Order (Recommended)

### Phase 1: Backend Foundation (Do First)
1. ✅ Update `entitlements.ts` - Set `TASKS: true` for FREE plan
2. ✅ Create `functions/src/functions/task.ts` - Implement all 5 functions
3. ✅ Update `functions/src/index.ts` - Export task functions
4. ✅ Update `firestore.rules` - Add task security rules
5. ✅ Test backend functions manually (use Firebase Console or Postman)
6. ✅ Deploy functions: `firebase deploy --only functions`
7. ✅ Deploy rules: `firebase deploy --only firestore:rules`

### Phase 2: Frontend Models & Services (Do Second)
1. ✅ Create `TaskModel` with enums (TaskStatus, TaskPriority)
2. ✅ Create `TaskService` with all CRUD methods
3. ✅ Test service methods (verify function names match exports)

### Phase 3: State Management (Do Third)
1. ✅ Create `TaskProvider` with optimistic updates
2. ✅ Register `TaskProvider` in `app.dart`
3. ✅ Test provider methods (create, update, delete with optimistic updates)

### Phase 4: UI Screens (Do Fourth)
1. ✅ Create `TaskListScreen` (search, filters, optimistic updates)
2. ✅ Create `TaskCreateScreen` (form, validation, optimistic create)
3. ✅ Create `TaskDetailsScreen` (view/edit, optimistic updates)
4. ✅ Add routes to `app_router.dart`
5. ✅ Add "Tasks" tab to `AppShell`

### Phase 5: Integration (Do Fifth)
1. ✅ Add tasks section to `CaseDetailsScreen`
2. ✅ Test case-task linking
3. ✅ Test assignee selection (use member list)
4. ✅ Test end-to-end flows

### Phase 6: Testing & Polish (Do Last)
1. ✅ Run all manual tests (Section 8)
2. ✅ Test edge cases
3. ✅ Verify optimistic updates work correctly
4. ✅ Verify debounce timing (300ms)
5. ✅ Verify state persistence
6. ✅ Code cleanup and documentation

**Critical Path:**
- Backend must be deployed before frontend can work
- Models must be created before services
- Services must be created before providers
- Providers must be created before screens
- Integration can happen in parallel with screens

---

## 18) Files to Create/Modify

### Backend:
- `functions/src/functions/task.ts` - All 5 task functions
- `functions/src/index.ts` - Export task functions
- `functions/src/constants/permissions.ts` - Add task permissions
- `functions/src/constants/entitlements.ts` - Add TASKS feature
- `functions/src/constants/errors.ts` - Add task error codes
- `firestore.rules` - Add task security rules
- `firestore.indexes.json` - Add task indexes (optional for MVP)

### Frontend:
- `legal_ai_app/lib/core/models/task_model.dart` - TaskModel with enums
- `legal_ai_app/lib/core/services/task_service.dart` - TaskService
- `legal_ai_app/lib/features/tasks/providers/task_provider.dart` - TaskProvider
- `legal_ai_app/lib/features/tasks/screens/task_list_screen.dart` - TaskListScreen
- `legal_ai_app/lib/features/tasks/screens/task_create_screen.dart` - TaskCreateScreen
- `legal_ai_app/lib/features/tasks/screens/task_details_screen.dart` - TaskDetailsScreen
- `legal_ai_app/lib/core/routing/route_names.dart` - Add task routes
- `legal_ai_app/lib/core/routing/app_router.dart` - Add task routes
- `legal_ai_app/lib/features/home/widgets/app_shell.dart` - Add tasks tab
- `legal_ai_app/lib/app.dart` - Register TaskProvider
- `legal_ai_app/lib/features/cases/screens/case_details_screen.dart` - Add tasks section

---

## 19) Notes

### 19.1 MVP Limitations
- In-memory search (title only, first 1000 tasks)
- Offset pagination (not cursor-based)
- No task dependencies
- No subtasks
- No recurring tasks
- No task templates

### 19.2 Future Enhancements
- Task dependencies (task A depends on task B)
- Task subtasks
- Task templates
- Task recurring schedules
- Task time tracking
- Task comments/notes
- Task notifications/reminders
- Task bulk operations
- Task analytics/reporting

### 19.3 Testing Strategy
- **Early Testing:** Test edge cases during development, not after
- **Manual Testing:** Comprehensive manual testing checklist
- **Integration Testing:** End-to-end flow testing
- **Performance Testing:** Test with 100+ tasks to verify in-memory filtering works

---

**Build Card Created:** January 23, 2026  
**Status:** 🔄 **READY TO START**  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 2.5 ✅

**Priority:** High (enables team collaboration and case task tracking)

---

## 20) Quick Reference

### Function Names (Flutter):
- `taskCreate` (NOT `task.create`)
- `taskGet` (NOT `task.get`)
- `taskList` (NOT `task.list`)
- `taskUpdate` (NOT `task.update`)
- `taskDelete` (NOT `task.delete`)

### Task Status Values:
- `PENDING`
- `IN_PROGRESS`
- `COMPLETED`
- `CANCELLED`

### Task Priority Values:
- `LOW`
- `MEDIUM`
- `HIGH`

### Firestore Path:
- `organizations/{orgId}/tasks/{taskId}`

### Search Debounce:
- 300ms (not 500ms or 800ms)

### Pagination:
- Offset-based for MVP (limit: 1-100, default: 50)
- Future: Cursor-based when > 500 tasks

---

**Last Updated:** January 23, 2026  
**Next Review:** After implementation begins

---

## 21) Implementation Status (as of 2026‑01‑23)

### Backend

- **Implemented & Deployed:**
  - All 5 callable functions: `taskCreate`, `taskGet`, `taskList`, `taskUpdate`, `taskDelete`.
  - Entitlements and granular permissions (`task.create`, `task.read`, `task.update`, `task.delete`, `task.assign`, `task.complete`) enforced via `checkEntitlement`.
  - Status transition matrix, due‑date validation (today or future), assignee membership checks, and case access checks (including private cases) implemented in `functions/src/functions/task.ts`.
  - Task security rules under `organizations/{orgId}/tasks/{taskId}` added to `firestore.rules`.
  - Base and composite Firestore indexes for tasks added to `firestore.indexes.json` and deployed.

### Frontend

- **Implemented:**
  - `TaskModel` with `TaskStatus` / `TaskPriority` enums and helpers.
  - `TaskService` calling the 5 backend functions with correct export names.
  - `TaskProvider` with optimistic create/update/delete and error handling.
  - `TaskListScreen` with search, status/priority filters, debounce, and pull‑to‑refresh.
  - `TaskCreateScreen` with validation, case linking, assignee selection, and optimistic create.
  - `TaskDetailsScreen` with view/edit, status transitions, case linking/unlinking, assignment, and soft delete.
  - Routing and navigation: tasks tab in `AppShell`, routes for list/create/details.
  - Case details: tasks section showing tasks linked to the case, with “Add Task” entry point.

### Known Non‑Blocking UX Issues (for a future polish slice)

- **Case details → Documents:**
  - On first navigation to a case after login, the documents section may occasionally require a manual refresh or re‑entering the screen before documents appear, due to timing around org initialization and provider loads.
- **Case details → Tasks & Documents:**
  - Lists are not realtime; they refresh on navigation and explicit actions (create/update/delete/refresh), not via Firestore snapshot listeners. This is acceptable for MVP and can be upgraded later.

These issues do **not** block Slice 5; they are candidates for a small “QA / polish” slice after later features.

---

## 22) Implementation Summary

### What Needs to Be Built

**Backend (5 functions):**
1. `taskCreate` - Create tasks with validation
2. `taskGet` - Get task details
3. `taskList` - List tasks with filters/search
4. `taskUpdate` - Update tasks with status transition validation
5. `taskDelete` - Soft delete tasks

**Frontend (3 screens + models/services):**
1. `TaskModel` - Data model with enums
2. `TaskService` - Service layer
3. `TaskProvider` - State management with optimistic updates
4. `TaskListScreen` - List with search/filters
5. `TaskCreateScreen` - Create form
6. `TaskDetailsScreen` - View/edit screen

**Integration:**
- Tasks section in `CaseDetailsScreen`
- Tasks tab in `AppShell`
- Routes configuration

### Critical Requirements

✅ **Must Have:**
- Optimistic UI updates (Learning 32)
- 300ms debounce for search (Learning 33)
- Async guards to prevent race conditions (Learning 34)
- Use export names, not callable names (Learning 1)
- Explicit soft delete endpoint (Learning 17)
- Enable TASKS for FREE plan (like TEAM_MEMBERS)
- Status transition validation
- Assignee validation (must be org member)
- Due date validation (today or future only)

✅ **Testing:**
- Test edge cases early (Learning 27)
- Comprehensive manual testing checklist
- Integration testing
- Performance testing with 100+ tasks

### Estimated Effort

**Backend:** 2-3 days
- Function implementation: 1 day
- Testing and debugging: 1 day
- Deployment and verification: 0.5 day

**Frontend:** 3-4 days
- Models and services: 0.5 day
- Provider with optimistic updates: 1 day
- Screens (3 screens): 1.5 days
- Integration: 0.5 day
- Testing and polish: 0.5 day

**Total:** 5-7 days for complete implementation

### Success Metrics

- ✅ All 5 backend functions deployed and working
- ✅ All 3 frontend screens implemented and working
- ✅ Optimistic UI updates working correctly
- ✅ Search debounce at 300ms
- ✅ All edge cases tested and handled
- ✅ Integration with cases working
- ✅ Task assignment working
- ✅ Status transitions validated
- ✅ No race conditions
- ✅ State persistence working

---

**Ready to Start:** ✅  
**All Dependencies Met:** ✅  
**Build Card Complete:** ✅

### ✅ Critical Issues Fixed (Based on ChatGPT/DeepSeek Review)

1. **✅ Permission Contradictions Fixed**
   - Added explicit `task.read`, `task.update`, `task.delete` permissions
   - Removed contradiction between "task.read required" and "no task.read needed"
   - All permission checks now consistent throughout build card

2. **✅ Permission Model World-Class**
   - No longer using `task.create` as "god permission"
   - Separate permissions: `task.create`, `task.read`, `task.update`, `task.delete`
   - Field-level gates: `task.assign`, `task.complete` for specific operations

3. **✅ Update API Supports Clear/Unassign**
   - Added `clearDueDate: bool` and `unassign: bool` flags to `updateTask()`
   - Fixes "null vs not passed" issue in Dart optional parameters
   - Backend handles explicit null values correctly

4. **✅ TaskService Imports Fixed**
   - Changed from `import '../models/task_model.dart'` (wrong)
   - To `import '../../../core/models/task_model.dart'` (correct)
   - All imports now use correct relative paths

5. **✅ Date Handling Timezone Issues Fixed**
   - Normalize to UTC midnight for date-only comparison
   - Backend stores dates as UTC 00:00:00
   - Frontend compares dates using UTC normalization
   - `isOverdue` and `isDueSoon` use date-only logic

6. **✅ Firestore Indexes Explicitly Specified**
   - Added complete Section 10 with 6 required indexes
   - JSON format for `firestore.indexes.json`
   - Deployment instructions included
   - Warning: Create BEFORE deployment

7. **✅ Status Transition Matrix Defined**
   - Explicit allowed/rejected transitions in Section 5.4
   - TypeScript implementation example provided
   - Backend validation function specified

8. **✅ Audit Events More Specific**
   - `task.created` - general creation
   - `task.completed` - status change to COMPLETED
   - `task.assigned` / `task.reassigned` - assignee changes
   - `task.case_linked` / `task.case_unlinked` - case linking
   - `task.updated` - general updates
   - `task.deleted` - deletion

9. **✅ Edge Cases Documented**
   - Section 11: Edge Cases & Failure States
   - Assignee leaves org handling
   - Case deleted handling
   - Past due dates
   - Invalid status transitions
   - Duplicate assignments

### ✅ Additional Critical Fixes (Second Review Pass)

10. **✅ Provider Reload Guard Fixed**
    - Now tracks query signature (orgId + caseId + search + status + assignee + priority)
    - Prevents stale data when filters change
    - Only blocks exact duplicate queries

11. **✅ Optimistic Create Rollback Fixed**
    - Uses ID-specific removal (`t.taskId == optimisticTaskId`)
    - No longer uses unsafe `startsWith('temp_')` pattern
    - Prevents removing wrong optimistic tasks

12. **✅ Date Parsing UTC-Safe**
    - Added `_parseDateOnly()` helper method
    - Manually parses YYYY-MM-DD as UTC
    - Prevents timezone bugs in date comparisons

13. **✅ Indexes Contradiction Resolved**
    - Changed to hybrid approach: Firestore queries for filters, in-memory for search
    - Reduced to 1 base index (deletedAt + updatedAt)
    - Added hard cap: reject queries > 1000 tasks

14. **✅ Case Link/Unlink Support**
    - Added `caseId` parameter to `updateTask()`
    - Added `unlinkCase` flag for explicit unlinking
    - Backend payload supports case linking/unlinking

15. **✅ Status Transition Matrix Clarified**
    - Added note about CANCELLED intermediate step requirement
    - Documented intentional design decision
    - Suggested future flexibility option

### ✅ Additional Improvements

- **Testing Philosophy Section:** Added Section 8.0 with testing principles
- **Performance Testing:** Added Section 8.4 with load testing guidelines
- **Implementation Order:** Added Section 17 with 6-phase plan
- **Quick Reference:** Added Section 19 for easy lookup

---

### ✅ Final Fixes (Third Review Pass)

16. **✅ TaskService.updateTask() Signature Fixed**
    - Added missing `caseId` parameter
    - Added missing `unlinkCase` flag
    - Function signature now matches code implementation

17. **✅ Status Transition Matrix Product Rule Documented**
    - Added explicit "Anti-Accidental Reopen Design" product rule
    - Documented rationale and UI impact
    - Noted future consideration for flexibility

18. **✅ Index Section Wording Fixed**
    - Changed "Create ALL indexes" to "Create the base index"
    - Clarified that composite indexes are optional/future
    - Removed confusion about multiple required indexes

### ✅ Final Fixes (Fourth Review Pass - Build Approval)

19. **✅ Critical Dart Syntax Bug Fixed**
    - Fixed semicolon to comma in `TaskService.createTask()` map literal (line 804)
    - Changed `'dueDate': ...;` to `'dueDate': ...,` (valid Dart syntax)
    - Code will now compile correctly

20. **✅ Section Numbering Fixed**
    - Fixed Section 13 subsections (12.1 → 13.1, 12.2 → 13.2)
    - Fixed Section 14 subsections (13.1 → 14.1, 13.2 → 14.2, 13.3 → 14.3)
    - Fixed Section 19 subsections (17.1 → 19.1, 17.2 → 19.2, 17.3 → 19.3)

21. **✅ Search Implementation Clarified**
    - Added explicit edge case handling for empty string vs null
    - Documented special character handling
    - Clarified multiple terms behavior (simple contains, no AND/OR logic)

22. **✅ Concurrent Operation Handling Documented**
    - Added Section 12.3: Concurrent Operation Handling
    - Documented last-write-wins strategy for MVP
    - Explained race condition prevention mechanisms
    - Noted future enhancement for conflict resolution

23. **✅ Pagination Strategy Clarified**
    - Explicitly documented Firestore `.offset().limit()` approach for MVP
    - Noted future cursor-based pagination option
    - Maintained hard cap enforcement (>1000 tasks)

---

**Build Card Status:** ✅ **APPROVED TO BUILD - ALL ISSUES RESOLVED**  
**All Critical Issues Fixed (4 Review Passes):** ✅  
**Compilation Issues Fixed:** ✅  
**Ready for Implementation:** ✅
