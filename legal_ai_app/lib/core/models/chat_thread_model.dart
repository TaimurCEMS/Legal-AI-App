/// Chat Thread Model (Slice 6b - AI Chat/Research)

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for ChatThreadModel');
}

/// Jurisdiction context for legal analysis
class JurisdictionModel {
  final String? country;
  final String? state;
  final String? region;

  const JurisdictionModel({
    this.country,
    this.state,
    this.region,
  });

  factory JurisdictionModel.fromJson(Map<String, dynamic> json) {
    return JurisdictionModel(
      country: json['country'] as String?,
      state: json['state'] as String?,
      region: json['region'] as String?,
    );
  }

  Map<String, String> toJson() {
    return {
      if (country != null) 'country': country!,
      if (state != null) 'state': state!,
      if (region != null) 'region': region!,
    };
  }

  /// Display label for UI
  String get displayLabel {
    final parts = <String>[];
    if (state != null) parts.add(state!);
    if (region != null && state == null) parts.add(region!);
    if (country != null) parts.add(country!);
    return parts.join(', ');
  }

  bool get isEmpty => country == null && state == null && region == null;
  bool get isNotEmpty => !isEmpty;
}

class ChatThreadModel {
  final String threadId;
  final String caseId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final int messageCount;
  final DateTime lastMessageAt;
  final String status;
  final JurisdictionModel? jurisdiction;

  const ChatThreadModel({
    required this.threadId,
    required this.caseId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.messageCount,
    required this.lastMessageAt,
    required this.status,
    this.jurisdiction,
  });

  /// Whether this thread is active
  bool get isActive => status == 'active';

  /// Time since last message (for display)
  String get lastMessageAgo {
    final diff = DateTime.now().difference(lastMessageAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastMessageAt.month}/${lastMessageAt.day}/${lastMessageAt.year}';
  }

  /// Whether this thread has a jurisdiction set
  bool get hasJurisdiction => jurisdiction != null && jurisdiction!.isNotEmpty;

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      threadId: json['threadId'] as String,
      caseId: json['caseId'] as String,
      title: json['title'] as String? ?? 'Untitled Chat',
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String,
      messageCount: json['messageCount'] as int? ?? 0,
      lastMessageAt: _parseTimestamp(json['lastMessageAt']),
      status: json['status'] as String? ?? 'active',
      jurisdiction: json['jurisdiction'] != null
          ? JurisdictionModel.fromJson(Map<String, dynamic>.from(json['jurisdiction'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'threadId': threadId,
      'caseId': caseId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'messageCount': messageCount,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'status': status,
      if (jurisdiction != null) 'jurisdiction': jurisdiction!.toJson(),
    };
  }

  /// Create a copy with updated jurisdiction
  ChatThreadModel copyWithJurisdiction(JurisdictionModel? newJurisdiction) {
    return ChatThreadModel(
      threadId: threadId,
      caseId: caseId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      messageCount: messageCount,
      lastMessageAt: lastMessageAt,
      status: status,
      jurisdiction: newJurisdiction,
    );
  }
}
