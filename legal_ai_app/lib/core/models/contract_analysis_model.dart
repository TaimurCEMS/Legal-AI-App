import 'package:flutter/material.dart';

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for ContractAnalysisModel');
}

/// Clause identified in contract analysis
class Clause {
  final String id;
  final String type; // e.g., "termination", "payment", "liability"
  final String title;
  final String content;
  final int? pageNumber;
  final int? startChar;
  final int? endChar;

  const Clause({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.pageNumber,
    this.startChar,
    this.endChar,
  });

  factory Clause.fromJson(Map<String, dynamic> json) {
    return Clause(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      pageNumber: json['pageNumber'] as int?,
      startChar: json['startChar'] as int?,
      endChar: json['endChar'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      if (pageNumber != null) 'pageNumber': pageNumber,
      if (startChar != null) 'startChar': startChar,
      if (endChar != null) 'endChar': endChar,
    };
  }

  /// Display label for clause type
  String get typeDisplayLabel {
    switch (type.toLowerCase()) {
      case 'termination':
        return 'Termination';
      case 'payment':
        return 'Payment';
      case 'liability':
        return 'Liability';
      case 'confidentiality':
        return 'Confidentiality';
      case 'indemnification':
        return 'Indemnification';
      case 'warranty':
        return 'Warranty';
      case 'intellectual_property':
        return 'Intellectual Property';
      case 'governing_law':
        return 'Governing Law';
      case 'dispute_resolution':
        return 'Dispute Resolution';
      default:
        return type;
    }
  }
}

/// Risk identified in contract analysis
class Risk {
  final String id;
  final String severity; // 'high', 'medium', 'low'
  final String category;
  final String title;
  final String description;
  final List<String>? clauseIds;
  final String? recommendation;

  const Risk({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.clauseIds,
    this.recommendation,
  });

  factory Risk.fromJson(Map<String, dynamic> json) {
    return Risk(
      id: json['id'] as String,
      severity: json['severity'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      clauseIds: json['clauseIds'] != null
          ? List<String>.from(json['clauseIds'] as List)
          : null,
      recommendation: json['recommendation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity,
      'category': category,
      'title': title,
      'description': description,
      if (clauseIds != null) 'clauseIds': clauseIds,
      if (recommendation != null) 'recommendation': recommendation,
    };
  }

  /// Display label for severity
  String get severityDisplayLabel {
    switch (severity.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return severity;
    }
  }

  /// Color for severity badge
  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  /// Display label for category
  String get categoryDisplayLabel {
    switch (category.toLowerCase()) {
      case 'liability':
        return 'Liability';
      case 'termination':
        return 'Termination';
      case 'payment':
        return 'Payment';
      case 'confidentiality':
        return 'Confidentiality';
      case 'indemnification':
        return 'Indemnification';
      default:
        return category;
    }
  }
}

/// Contract analysis result
class ContractAnalysisModel {
  final String analysisId;
  final String documentId;
  final String? caseId;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final String? error;
  final String? summary;
  final List<Clause> clauses;
  final List<Risk> risks;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String createdBy;
  final String model;
  final int? tokensUsed;
  final int? processingTimeMs;

  const ContractAnalysisModel({
    required this.analysisId,
    required this.documentId,
    this.caseId,
    required this.status,
    this.error,
    this.summary,
    required this.clauses,
    required this.risks,
    required this.createdAt,
    this.completedAt,
    required this.createdBy,
    required this.model,
    this.tokensUsed,
    this.processingTimeMs,
  });

  factory ContractAnalysisModel.fromJson(Map<String, dynamic> json) {
    // Flatten metadata if present (backend contractAnalyze used to return model inside metadata)
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final model = json['model'] as String? ?? metadata?['model'] as String? ?? 'gpt-4o-mini';
    final tokensUsed = json['tokensUsed'] as int? ?? metadata?['tokensUsed'] as int?;
    final processingTimeMs = json['processingTimeMs'] as int? ?? metadata?['processingTimeMs'] as int?;

    return ContractAnalysisModel(
      analysisId: json['analysisId'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      caseId: json['caseId'] as String?,
      status: json['status'] as String? ?? 'completed',
      error: json['error'] as String?,
      summary: json['summary'] as String?,
      clauses: (json['clauses'] as List<dynamic>? ?? [])
          .map((c) => Clause.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      risks: (json['risks'] as List<dynamic>? ?? [])
          .map((r) => Risk.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      createdAt: json['createdAt'] != null ? _parseTimestamp(json['createdAt']) : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? _parseTimestamp(json['completedAt'])
          : null,
      createdBy: json['createdBy'] as String? ?? '',
      model: model,
      tokensUsed: tokensUsed,
      processingTimeMs: processingTimeMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysisId': analysisId,
      'documentId': documentId,
      if (caseId != null) 'caseId': caseId,
      'status': status,
      if (error != null) 'error': error,
      if (summary != null) 'summary': summary,
      'clauses': clauses.map((c) => c.toJson()).toList(),
      'risks': risks.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'createdBy': createdBy,
      'model': model,
      if (tokensUsed != null) 'tokensUsed': tokensUsed,
      if (processingTimeMs != null) 'processingTimeMs': processingTimeMs,
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'pending';
  bool get hasResults => isCompleted && (summary != null || clauses.isNotEmpty || risks.isNotEmpty);

  /// Group clauses by type
  Map<String, List<Clause>> get clausesByType {
    final grouped = <String, List<Clause>>{};
    for (final clause in clauses) {
      grouped.putIfAbsent(clause.type, () => []).add(clause);
    }
    return grouped;
  }

  /// Group risks by severity
  Map<String, List<Risk>> get risksBySeverity {
    final grouped = <String, List<Risk>>{
      'high': [],
      'medium': [],
      'low': [],
    };
    for (final risk in risks) {
      final severity = risk.severity.toLowerCase();
      if (grouped.containsKey(severity)) {
        grouped[severity]!.add(risk);
      } else {
        grouped['low']!.add(risk);
      }
    }
    return grouped;
  }
}
