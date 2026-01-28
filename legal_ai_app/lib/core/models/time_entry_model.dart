DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.parse(value).toLocal();
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for TimeEntryModel');
}

enum TimeEntryStatus {
  running('running'),
  stopped('stopped');

  final String value;
  const TimeEntryStatus(this.value);

  static TimeEntryStatus fromString(String value) {
    return TimeEntryStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TimeEntryStatus.stopped,
    );
  }
}

class TimeEntryModel {
  final String timeEntryId;
  final String orgId;
  final String? caseId;
  final String? clientId;
  final String description;
  final bool billable;
  final TimeEntryStatus status;
  final DateTime startAt;
  final DateTime? endAt;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const TimeEntryModel({
    required this.timeEntryId,
    required this.orgId,
    this.caseId,
    this.clientId,
    required this.description,
    required this.billable,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  bool get isRunning => status == TimeEntryStatus.running;

  int elapsedSeconds(DateTime now) {
    if (!isRunning) return durationSeconds;
    final secs = now.difference(startAt).inSeconds;
    return secs < 0 ? 0 : secs;
  }

  static String formatDuration(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final remSeconds = s % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${remSeconds}s';
    }
    return '${remSeconds}s';
  }

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryModel(
      timeEntryId: json['timeEntryId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      clientId: json['clientId'] as String?,
      description: json['description'] as String? ?? '',
      billable: json['billable'] as bool? ?? true,
      status: TimeEntryStatus.fromString(json['status'] as String? ?? 'stopped'),
      startAt: _parseTimestamp(json['startAt']),
      endAt: json['endAt'] != null ? _parseTimestamp(json['endAt']) : null,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeEntryId': timeEntryId,
      'orgId': orgId,
      'caseId': caseId,
      'clientId': clientId,
      'description': description,
      'billable': billable,
      'status': status.value,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }
}

