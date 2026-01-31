/// Activity feed item model for Slice 16 - from domain_events
class ActivityFeedItem {
  final String eventId;
  final String eventType;
  final String entityType;
  final String entityId;
  final String? matterId;
  final String actorUid;
  final String? actorDisplayName;
  final DateTime timestamp;
  final String summary;
  final String deepLink;

  ActivityFeedItem({
    required this.eventId,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    this.matterId,
    required this.actorUid,
    this.actorDisplayName,
    required this.timestamp,
    required this.summary,
    required this.deepLink,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      eventId: json['eventId'] as String,
      eventType: json['eventType'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      matterId: json['matterId'] as String?,
      actorUid: json['actorUid'] as String? ?? '',
      actorDisplayName: json['actorDisplayName'] as String?,
      timestamp: _parseTimestamp(json['timestamp']),
      summary: json['summary'] as String? ?? 'Activity',
      deepLink: json['deepLink'] as String? ?? '/home',
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
