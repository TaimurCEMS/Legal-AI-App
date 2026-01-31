import 'package:cloud_firestore/cloud_firestore.dart';
import 'org_model.dart';

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate(); // Firestore Timestamp
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for TaskModel');
}

// Helper method to parse date-only value (String YYYY-MM-DD or Firestore Timestamp) as UTC
DateTime _parseDateOnly(dynamic value) {
  if (value is Timestamp) {
    final dt = value.toDate();
    return DateTime.utc(dt.year, dt.month, dt.day);
  }
  if (value is DateTime) {
    return DateTime.utc(value.year, value.month, value.day);
  }
  if (value is String) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date format: $value');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return DateTime.utc(year, month, day);
  }
  throw FormatException('Invalid date format: $value');
}

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
  
  String get statusDisplayName {
    switch (this) {
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
  
  String get priorityDisplayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
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
   /// Task-level visibility flag (Slice 5.5 extension).
   /// When true for PRIVATE cases, the task is only visible to:
   /// - Admins
   /// - The assignee
   /// - The creator while unassigned
   final bool restrictedToAssignee;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  
  const TaskModel({
    required this.taskId,
    required this.orgId,
    this.caseId,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.assigneeId,
    this.assigneeName,
    required this.priority,
    this.restrictedToAssignee = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });
  
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
  
  
  // Factory constructor from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      taskId: json['taskId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'PENDING'),
      dueDate: json['dueDate'] != null 
          ? _parseDateOnly(json['dueDate']) // Parse date (String or Timestamp) safely (UTC)
          : null,
      assigneeId: json['assigneeId'] as String?,
      assigneeName: json['assigneeName'] as String?,
      priority: TaskPriority.fromString(json['priority'] as String? ?? 'MEDIUM'),
      restrictedToAssignee: json['restrictedToAssignee'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String,
      updatedBy: json['updatedBy'] as String,
    );
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
      'restrictedToAssignee': restrictedToAssignee,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }
}
