import 'chat_thread_model.dart';

DateTime _parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for DraftModel');
}

enum DraftStatus {
  idle('idle', 'Idle'),
  pending('pending', 'Queued'),
  processing('processing', 'Generating'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed');

  const DraftStatus(this.value, this.displayLabel);
  final String value;
  final String displayLabel;

  static DraftStatus fromString(String value) {
    return DraftStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DraftStatus.idle,
    );
  }
}

class DraftModel {
  final String draftId;
  final String orgId;
  final String caseId;
  final String templateId;
  final String templateName;
  final String title;
  final String? prompt;
  final Map<String, String> variables;
  final JurisdictionModel? jurisdiction;
  final String content;
  final DraftStatus status;
  final String? error;
  final String? lastJobId;
  final int versionCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? lastGeneratedAt;

  const DraftModel({
    required this.draftId,
    required this.orgId,
    required this.caseId,
    required this.templateId,
    required this.templateName,
    required this.title,
    this.prompt,
    required this.variables,
    this.jurisdiction,
    required this.content,
    required this.status,
    this.error,
    this.lastJobId,
    required this.versionCount,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.lastGeneratedAt,
  });

  bool get isGenerating => status == DraftStatus.pending || status == DraftStatus.processing;

  factory DraftModel.fromJson(Map<String, dynamic> json) {
    final varsRaw = json['variables'];
    final vars = <String, String>{};
    if (varsRaw is Map) {
      for (final entry in varsRaw.entries) {
        final k = entry.key?.toString();
        final v = entry.value?.toString();
        if (k != null && v != null) {
          vars[k] = v;
        }
      }
    }

    return DraftModel(
      draftId: json['draftId'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String,
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Draft',
      prompt: json['prompt'] as String?,
      variables: vars,
      jurisdiction: json['jurisdiction'] != null
          ? JurisdictionModel.fromJson(
              Map<String, dynamic>.from(json['jurisdiction'] as Map),
            )
          : null,
      content: json['content'] as String? ?? '',
      status: DraftStatus.fromString(json['status'] as String? ?? 'idle'),
      error: json['error'] as String?,
      lastJobId: json['lastJobId'] as String?,
      versionCount: json['versionCount'] as int? ?? 0,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      lastGeneratedAt: json['lastGeneratedAt'] != null
          ? _parseTimestamp(json['lastGeneratedAt'])
          : null,
    );
  }
}

