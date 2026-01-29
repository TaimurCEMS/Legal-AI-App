/// Model for a document summary (Slice 14 - AI Summarization)
class DocumentSummaryModel {
  final String summaryId;
  final String documentId;
  final String? caseId;
  final String summary;
  final DateTime createdAt;
  final String createdBy;
  final String model;
  final int? tokensUsed;
  final int? processingTimeMs;

  const DocumentSummaryModel({
    required this.summaryId,
    required this.documentId,
    this.caseId,
    required this.summary,
    required this.createdAt,
    required this.createdBy,
    required this.model,
    this.tokensUsed,
    this.processingTimeMs,
  });

  factory DocumentSummaryModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return DocumentSummaryModel(
      summaryId: json['summaryId'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      caseId: json['caseId'] as String?,
      summary: json['summary'] as String? ?? '',
      createdAt: createdAt != null
          ? (createdAt is String
              ? DateTime.tryParse(createdAt) ?? DateTime.now()
              : DateTime.now())
          : DateTime.now(),
      createdBy: json['createdBy'] as String? ?? '',
      model: json['model'] as String? ?? 'gpt-4o-mini',
      tokensUsed: json['tokensUsed'] as int?,
      processingTimeMs: json['processingTimeMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summaryId': summaryId,
      'documentId': documentId,
      if (caseId != null) 'caseId': caseId,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'model': model,
      if (tokensUsed != null) 'tokensUsed': tokensUsed,
      if (processingTimeMs != null) 'processingTimeMs': processingTimeMs,
    };
  }
}
