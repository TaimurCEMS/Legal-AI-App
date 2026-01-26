/// Event Model for Calendar & Court Dates (Slice 7)
///
/// Represents calendar events including court dates, hearings, filing deadlines,
/// meetings, and other legal practice events.

DateTime _parseTimestamp(dynamic value) {
  if (value == null) {
    return DateTime.now(); // Default to now for missing timestamps
  }
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw FormatException('Invalid timestamp format for EventModel: $value');
}

DateTime? _parseOptionalTimestamp(dynamic value) {
  if (value == null) return null;
  return _parseTimestamp(value);
}

/// Event types for legal workflows
enum EventType {
  courtDate('COURT_DATE'),
  hearing('HEARING'),
  filingDeadline('FILING_DEADLINE'),
  statuteLimitation('STATUTE_LIMITATION'),
  meeting('MEETING'),
  consultation('CONSULTATION'),
  deposition('DEPOSITION'),
  mediation('MEDIATION'),
  arbitration('ARBITRATION'),
  other('OTHER');

  final String value;
  const EventType(this.value);

  static EventType fromString(String value) {
    return EventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventType.other,
    );
  }

  String get displayName {
    switch (this) {
      case EventType.courtDate:
        return 'Court Date';
      case EventType.hearing:
        return 'Hearing';
      case EventType.filingDeadline:
        return 'Filing Deadline';
      case EventType.statuteLimitation:
        return 'Statute of Limitations';
      case EventType.meeting:
        return 'Meeting';
      case EventType.consultation:
        return 'Consultation';
      case EventType.deposition:
        return 'Deposition';
      case EventType.mediation:
        return 'Mediation';
      case EventType.arbitration:
        return 'Arbitration';
      case EventType.other:
        return 'Other';
    }
  }

  /// Returns true if this event type typically has critical priority
  bool get isCriticalType {
    return this == EventType.courtDate ||
        this == EventType.filingDeadline ||
        this == EventType.statuteLimitation;
  }
}

enum EventStatus {
  scheduled('SCHEDULED'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String value;
  const EventStatus(this.value);

  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventStatus.scheduled,
    );
  }

  String get displayName {
    switch (this) {
      case EventStatus.scheduled:
        return 'Scheduled';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum EventPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  final String value;
  const EventPriority(this.value);

  static EventPriority fromString(String value) {
    return EventPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case EventPriority.low:
        return 'Low';
      case EventPriority.medium:
        return 'Medium';
      case EventPriority.high:
        return 'High';
      case EventPriority.critical:
        return 'Critical';
    }
  }
}

enum EventVisibility {
  org('ORG'),
  caseOnly('CASE_ONLY'),
  private_('PRIVATE');

  final String value;
  const EventVisibility(this.value);

  static EventVisibility fromString(String value) {
    return EventVisibility.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventVisibility.org,
    );
  }

  String get displayName {
    switch (this) {
      case EventVisibility.org:
        return 'Organization-wide';
      case EventVisibility.caseOnly:
        return 'Case Team Only';
      case EventVisibility.private_:
        return 'Private';
    }
  }
}

/// Reminder model for event notifications
class ReminderModel {
  final int minutesBefore;

  const ReminderModel({required this.minutesBefore});

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      minutesBefore: json['minutesBefore'] as int,
    );
  }

  Map<String, dynamic> toJson() => {'minutesBefore': minutesBefore};

  String get displayName {
    if (minutesBefore == 0) return 'At time of event';
    if (minutesBefore < 60) return '$minutesBefore minutes before';
    if (minutesBefore == 60) return '1 hour before';
    if (minutesBefore < 1440) return '${minutesBefore ~/ 60} hours before';
    if (minutesBefore == 1440) return '1 day before';
    if (minutesBefore == 2880) return '2 days before';
    if (minutesBefore == 10080) return '1 week before';
    return '${minutesBefore ~/ 1440} days before';
  }
}

/// Recurrence model for recurring events
class RecurrenceModel {
  final String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY
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
      interval: json['interval'] as int? ?? 1,
      endDate: json['endDate'] != null ? _parseTimestamp(json['endDate']) : null,
      count: json['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'interval': interval,
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (count != null) 'count': count,
      };

  String get displayName {
    final intervalText = interval > 1 ? ' $interval' : '';
    switch (frequency) {
      case 'DAILY':
        return interval == 1 ? 'Daily' : 'Every$intervalText days';
      case 'WEEKLY':
        return interval == 1 ? 'Weekly' : 'Every$intervalText weeks';
      case 'MONTHLY':
        return interval == 1 ? 'Monthly' : 'Every$intervalText months';
      case 'YEARLY':
        return interval == 1 ? 'Yearly' : 'Every$intervalText years';
      default:
        return frequency;
    }
  }
}

/// Main Event model
class EventModel {
  final String eventId;
  final String orgId;
  final String? caseId;
  final String? caseName;
  final String? caseStatus;
  final String title;
  final String? description;
  final EventType eventType;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final bool allDay;
  final String? location;
  final List<String> attendeeUids;
  final List<ReminderModel> reminders;
  final RecurrenceModel? recurrence;
  final EventPriority priority;
  final String? notes;
  final EventStatus status;
  final EventVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  // For recurring instances
  final bool isRecurringInstance;
  final String? recurringParentId;
  final String? instanceDate;

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

  /// Check if linked case is not OPEN (for warning display)
  bool get hasCaseWarning =>
      caseId != null && caseStatus != null && caseStatus != 'OPEN';

  /// Check if event is in the past
  bool get isPast {
    if (status == EventStatus.completed || status == EventStatus.cancelled) {
      return false;
    }
    return startDateTime.isBefore(DateTime.now());
  }

  /// Check if event is today
  bool get isToday {
    final now = DateTime.now();
    return startDateTime.year == now.year &&
        startDateTime.month == now.month &&
        startDateTime.day == now.day;
  }

  /// Check if event is upcoming within 7 days
  bool get isUpcoming {
    if (status != EventStatus.scheduled) return false;
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return startDateTime.isAfter(now) && startDateTime.isBefore(weekFromNow);
  }

  /// Duration of the event
  Duration? get duration {
    if (endDateTime == null) return null;
    return endDateTime!.difference(startDateTime);
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Parse createdAt first - it's usually present
    final createdAt = _parseTimestamp(json['createdAt']);
    
    return EventModel(
      eventId: json['eventId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      caseName: json['caseName'] as String?,
      caseStatus: json['caseStatus'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: EventType.fromString(json['eventType'] as String? ?? 'OTHER'),
      startDateTime: _parseTimestamp(json['startDateTime']),
      endDateTime: _parseOptionalTimestamp(json['endDateTime']),
      allDay: json['allDay'] as bool? ?? false,
      location: json['location'] as String?,
      attendeeUids: (json['attendeeUids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) =>
                  ReminderModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      recurrence: json['recurrence'] != null
          ? RecurrenceModel.fromJson(
              Map<String, dynamic>.from(json['recurrence'] as Map))
          : null,
      priority:
          EventPriority.fromString(json['priority'] as String? ?? 'MEDIUM'),
      notes: json['notes'] as String?,
      status:
          EventStatus.fromString(json['status'] as String? ?? 'SCHEDULED'),
      visibility:
          EventVisibility.fromString(json['visibility'] as String? ?? 'ORG'),
      createdAt: createdAt,
      // updatedAt may not be in list responses, default to createdAt
      updatedAt: json['updatedAt'] != null 
          ? _parseTimestamp(json['updatedAt']) 
          : createdAt,
      // createdBy/updatedBy may not be in list responses
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      isRecurringInstance: json['isRecurringInstance'] as bool? ?? false,
      recurringParentId: json['recurringParentId'] as String?,
      instanceDate: json['instanceDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'orgId': orgId,
        'caseId': caseId,
        'caseName': caseName,
        'caseStatus': caseStatus,
        'title': title,
        'description': description,
        'eventType': eventType.value,
        'startDateTime': startDateTime.toIso8601String(),
        'endDateTime': endDateTime?.toIso8601String(),
        'allDay': allDay,
        'location': location,
        'attendeeUids': attendeeUids,
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'recurrence': recurrence?.toJson(),
        'priority': priority.value,
        'notes': notes,
        'status': status.value,
        'visibility': visibility.value,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'isRecurringInstance': isRecurringInstance,
        'recurringParentId': recurringParentId,
        'instanceDate': instanceDate,
      };

  /// Create a copy with updated fields
  EventModel copyWith({
    String? eventId,
    String? orgId,
    String? caseId,
    String? caseName,
    String? caseStatus,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? allDay,
    String? location,
    List<String>? attendeeUids,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    EventStatus? status,
    EventVisibility? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool? isRecurringInstance,
    String? recurringParentId,
    String? instanceDate,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      orgId: orgId ?? this.orgId,
      caseId: caseId ?? this.caseId,
      caseName: caseName ?? this.caseName,
      caseStatus: caseStatus ?? this.caseStatus,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      attendeeUids: attendeeUids ?? this.attendeeUids,
      reminders: reminders ?? this.reminders,
      recurrence: recurrence ?? this.recurrence,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      isRecurringInstance: isRecurringInstance ?? this.isRecurringInstance,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      instanceDate: instanceDate ?? this.instanceDate,
    );
  }
}
