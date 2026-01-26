/// Chat Message Model (Slice 6b - AI Chat/Research)

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for ChatMessageModel');
}

/// Citation linking to a source document
class CitationModel {
  final String documentId;
  final String documentName;
  final String excerpt;
  final int? pageNumber;

  const CitationModel({
    required this.documentId,
    required this.documentName,
    required this.excerpt,
    this.pageNumber,
  });

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      documentId: json['documentId'] as String,
      documentName: json['documentName'] as String,
      excerpt: json['excerpt'] as String? ?? '',
      pageNumber: json['pageNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'documentName': documentName,
      'excerpt': excerpt,
      if (pageNumber != null) 'pageNumber': pageNumber,
    };
  }
}

/// Metadata about the AI response
class ChatMetadataModel {
  final String model;
  final int? tokensUsed;
  final int? processingTimeMs;

  const ChatMetadataModel({
    required this.model,
    this.tokensUsed,
    this.processingTimeMs,
  });

  factory ChatMetadataModel.fromJson(Map<String, dynamic> json) {
    return ChatMetadataModel(
      model: json['model'] as String? ?? 'unknown',
      tokensUsed: json['tokensUsed'] as int?,
      processingTimeMs: json['processingTimeMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      if (tokensUsed != null) 'tokensUsed': tokensUsed,
      if (processingTimeMs != null) 'processingTimeMs': processingTimeMs,
    };
  }
}

/// A single chat message (user or assistant)
class ChatMessageModel {
  final String messageId;
  final String threadId;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final List<CitationModel>? citations;
  final ChatMetadataModel? metadata;
  final DateTime createdAt;
  final String createdBy;

  const ChatMessageModel({
    required this.messageId,
    required this.threadId,
    required this.role,
    required this.content,
    this.citations,
    this.metadata,
    required this.createdAt,
    required this.createdBy,
  });

  /// Whether this is a user message
  bool get isUser => role == 'user';

  /// Whether this is an AI assistant message
  bool get isAssistant => role == 'assistant';

  /// Whether this message has citations
  bool get hasCitations => citations != null && citations!.isNotEmpty;

  /// Get time display string
  String get timeDisplay {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $amPm';
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      messageId: json['messageId'] as String,
      threadId: json['threadId'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      citations: (json['citations'] as List<dynamic>?)
          ?.map((c) => CitationModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      metadata: json['metadata'] != null
          ? ChatMetadataModel.fromJson(Map<String, dynamic>.from(json['metadata'] as Map))
          : null,
      createdAt: _parseTimestamp(json['createdAt']),
      createdBy: json['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'threadId': threadId,
      'role': role,
      'content': content,
      if (citations != null) 'citations': citations!.map((c) => c.toJson()).toList(),
      if (metadata != null) 'metadata': metadata!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}
