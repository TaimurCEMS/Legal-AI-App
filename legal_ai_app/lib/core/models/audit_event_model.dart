import 'dart:convert';

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.parse(value).toLocal();
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  }
  throw const FormatException('Invalid timestamp format for AuditEventModel');
}

class AuditEventModel {
  final String auditEventId;
  final String orgId;
  final String actorUid;
  final String? actorEmail;
  final String? actorDisplayName;
  final String action;
  final String entityType;
  final String entityId;
  final String? caseId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const AuditEventModel({
    required this.auditEventId,
    required this.orgId,
    required this.actorUid,
    required this.actorEmail,
    required this.actorDisplayName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.caseId,
    required this.timestamp,
    required this.metadata,
  });

  factory AuditEventModel.fromJson(Map<String, dynamic> json) {
    return AuditEventModel(
      auditEventId: json['auditEventId'] as String? ?? json['id'] as String? ?? '',
      orgId: json['orgId'] as String? ?? '',
      actorUid: json['actorUid'] as String? ?? '',
      actorEmail: json['actorEmail'] as String?,
      actorDisplayName: json['actorDisplayName'] as String?,
      action: json['action'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      caseId: json['caseId'] as String?,
      timestamp: _parseTimestamp(json['timestamp']),
      metadata: (json['metadata'] is Map)
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  String prettyMetadata() {
    if (metadata == null) return '';
    return const JsonEncoder.withIndent('  ').convert(metadata);
  }

  /// Human-readable label for entity type (e.g. "task" -> "Task", "timeEntry" -> "Time Entry").
  String get entityTypeDisplayLabel {
    const labels = <String, String>{
      'case': 'Case',
      'client': 'Client',
      'document': 'Document',
      'task': 'Task',
      'timeEntry': 'Time Entry',
      'invoice': 'Invoice',
      'note': 'Note',
      'event': 'Event',
      'draft': 'Draft',
      'membership': 'Membership',
      'org': 'Organization',
    };
    return labels[entityType] ?? _titleCase(entityType);
  }

  /// Human-readable label for action (e.g. "document.created" -> "Document Created").
  String get actionDisplayLabel {
    if (action.isEmpty) return action;
    // Common pattern: "entity.action" -> "Entity Action"
    final parts = action.split('.');
    return parts.map(_titleCase).join(' • ');
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.length > 1 ? lower.substring(1) : ''}';
  }
}

