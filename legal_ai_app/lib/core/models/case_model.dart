import 'package:cloud_firestore/cloud_firestore.dart';
import 'org_model.dart';

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate(); // Firestore Timestamp
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for CaseModel');
}

enum CaseVisibility {
  orgWide('ORG_WIDE'),
  private('PRIVATE');

  final String value;
  const CaseVisibility(this.value);

  static CaseVisibility fromString(String value) {
    return CaseVisibility.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CaseVisibility.orgWide,
    );
  }
}

enum CaseStatus {
  open('OPEN'),
  closed('CLOSED'),
  archived('ARCHIVED');

  final String value;
  const CaseStatus(this.value);

  static CaseStatus fromString(String value) {
    return CaseStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CaseStatus.open,
    );
  }
}

class CaseModel {
  final String caseId;
  final String orgId;
  final String title;
  final String? description;
  final String? clientId;
  final String? clientName;
  final CaseVisibility visibility;
  final CaseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;

  const CaseModel({
    required this.caseId,
    required this.orgId,
    required this.title,
    this.description,
    this.clientId,
    this.clientName,
    required this.visibility,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      caseId: json['caseId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      clientId: json['clientId'] as String?,
      clientName: json['clientName'] as String?,
      visibility: CaseVisibility.fromString(
        json['visibility'] as String? ?? 'ORG_WIDE',
      ),
      status: CaseStatus.fromString(
        json['status'] as String? ?? 'OPEN',
      ),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      deletedAt:
          json['deletedAt'] != null ? _parseTimestamp(json['deletedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caseId': caseId,
      'orgId': orgId,
      'title': title,
      'description': description,
      'clientId': clientId,
      'clientName': clientName,
      'visibility': visibility.value,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}

