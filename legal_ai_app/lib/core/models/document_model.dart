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
  // Text extraction fields (Slice 6a)
  final String? extractedText;
  final String extractionStatus; // 'none', 'pending', 'processing', 'completed', 'failed'
  final String? extractionError;
  final DateTime? extractedAt;
  final int? pageCount;
  final int? wordCount;

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
    // Text extraction fields
    this.extractedText,
    this.extractionStatus = 'none',
    this.extractionError,
    this.extractedAt,
    this.pageCount,
    this.wordCount,
  });

  bool get isDeleted => deletedAt != null;

  /// Whether the document has extracted text
  bool get hasExtractedText =>
      extractedText != null && extractedText!.isNotEmpty;

  /// Whether extraction can be started (not in progress and not already completed, or failed)
  bool get canExtract =>
      extractionStatus == 'none' || extractionStatus == 'failed';

  /// Whether extraction is currently in progress
  bool get isExtracting =>
      extractionStatus == 'pending' || extractionStatus == 'processing';

  /// Whether extraction completed successfully
  bool get extractionCompleted => extractionStatus == 'completed';

  /// Whether extraction failed
  bool get extractionFailed => extractionStatus == 'failed';

  /// Check if file type supports text extraction
  bool get isExtractable {
    final type = fileType.toLowerCase();
    return type == 'pdf' || type == 'docx' || type == 'txt' || type == 'rtf';
  }

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
      // Text extraction fields
      extractedText: json['extractedText'] as String?,
      extractionStatus: json['extractionStatus'] as String? ?? 'none',
      extractionError: json['extractionError'] as String?,
      extractedAt: json['extractedAt'] != null
          ? _parseTimestamp(json['extractedAt'])
          : null,
      pageCount: json['pageCount'] as int?,
      wordCount: json['wordCount'] as int?,
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
      // Text extraction fields
      'extractedText': extractedText,
      'extractionStatus': extractionStatus,
      'extractionError': extractionError,
      'extractedAt': extractedAt?.toIso8601String(),
      'pageCount': pageCount,
      'wordCount': wordCount,
    };
  }

  /// Create a copy with updated extraction status
  DocumentModel copyWithExtractionStatus({
    String? extractionStatus,
    String? extractionError,
    String? extractedText,
    DateTime? extractedAt,
    int? pageCount,
    int? wordCount,
  }) {
    return DocumentModel(
      documentId: documentId,
      orgId: orgId,
      caseId: caseId,
      name: name,
      description: description,
      fileType: fileType,
      fileSize: fileSize,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      deletedAt: deletedAt,
      extractedText: extractedText ?? this.extractedText,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      extractionError: extractionError ?? this.extractionError,
      extractedAt: extractedAt ?? this.extractedAt,
      pageCount: pageCount ?? this.pageCount,
      wordCount: wordCount ?? this.wordCount,
    );
  }
}
