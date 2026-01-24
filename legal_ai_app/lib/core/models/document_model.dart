import 'package:flutter/material.dart';

DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for DocumentModel');
}

class DocumentModel {
  final String documentId;
  final String orgId;
  final String? caseId;
  final String name;
  final String? description;
  final String fileType;
  final int fileSize;
  final String storagePath;
  final String? downloadUrl; // Signed URL, may expire
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;

  const DocumentModel({
    required this.documentId,
    required this.orgId,
    this.caseId,
    required this.name,
    this.description,
    required this.fileType,
    required this.fileSize,
    required this.storagePath,
    this.downloadUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Format file size as human-readable string (e.g., "2.3 MB")
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get icon based on file type
  IconData get fileTypeIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.description; // Material icon for PDF
      case 'doc':
      case 'docx':
        return Icons.description; // Material icon for Word
      case 'txt':
        return Icons.text_snippet; // Material icon for text
      case 'rtf':
        return Icons.description; // Material icon for RTF
      default:
        return Icons.insert_drive_file; // Default file icon
    }
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      documentId: json['documentId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      fileType: json['fileType'] as String,
      fileSize: json['fileSize'] as int,
      storagePath: json['storagePath'] as String,
      downloadUrl: json['downloadUrl'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      deletedAt: json['deletedAt'] != null
          ? _parseTimestamp(json['deletedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'orgId': orgId,
      'caseId': caseId,
      'name': name,
      'description': description,
      'fileType': fileType,
      'fileSize': fileSize,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}
