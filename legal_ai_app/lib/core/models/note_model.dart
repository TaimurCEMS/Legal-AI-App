/// Note data model for Slice 8 - Notes/Memos on Cases
/// 
/// Notes inherit visibility from their case:
/// - If case is ORG_WIDE: all org members can see notes
/// - If case is PRIVATE: only case creator + participants can see notes

enum NoteCategory {
  clientMeeting('CLIENT_MEETING', 'Client Meeting'),
  research('RESEARCH', 'Research'),
  strategy('STRATEGY', 'Strategy'),
  internal('INTERNAL', 'Internal'),
  other('OTHER', 'Other');

  const NoteCategory(this.value, this.displayLabel);
  final String value;
  final String displayLabel;

  static NoteCategory fromString(String value) {
    return NoteCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NoteCategory.other,
    );
  }
}

class NoteModel {
  final String noteId;
  final String orgId;
  final String caseId;
  final String title;
  final String content;
  final NoteCategory category;
  final bool isPinned;
  final bool isPrivate; // If true, only the creator can see this note
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;

  NoteModel({
    required this.noteId,
    required this.orgId,
    required this.caseId,
    required this.title,
    required this.content,
    required this.category,
    required this.isPinned,
    this.isPrivate = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.updatedBy,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      noteId: json['noteId'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: NoteCategory.fromString(json['category'] as String? ?? 'OTHER'),
      isPinned: json['isPinned'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'orgId': orgId,
      'caseId': caseId,
      'title': title,
      'content': content,
      'category': category.value,
      'isPinned': isPinned,
      'isPrivate': isPrivate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is Map) {
      // Firestore Timestamp format
      final seconds = value['_seconds'] as int?;
      final nanoseconds = value['_nanoseconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds ?? 0) ~/ 1000000,
        );
      }
    }
    return DateTime.now();
  }

  NoteModel copyWith({
    String? noteId,
    String? orgId,
    String? caseId,
    String? title,
    String? content,
    NoteCategory? category,
    bool? isPinned,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return NoteModel(
      noteId: noteId ?? this.noteId,
      orgId: orgId ?? this.orgId,
      caseId: caseId ?? this.caseId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() {
    return 'NoteModel(noteId: $noteId, title: $title, category: ${category.value}, isPinned: $isPinned, isPrivate: $isPrivate)';
  }
}
