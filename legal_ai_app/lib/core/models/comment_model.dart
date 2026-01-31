import 'package:cloud_firestore/cloud_firestore.dart';

/// Comment model for Slice 16 - Comments on matters, tasks, documents
class CommentModel {
  final String commentId;
  final String orgId;
  final String matterId;
  final String? taskId;
  final String? documentId;
  final String authorUid;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommentModel({
    required this.commentId,
    required this.orgId,
    required this.matterId,
    this.taskId,
    this.documentId,
    required this.authorUid,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: json['commentId'] as String,
      orgId: json['orgId'] as String,
      matterId: json['matterId'] as String,
      taskId: json['taskId'] as String?,
      documentId: json['documentId'] as String?,
      authorUid: json['authorUid'] as String,
      body: json['body'] as String,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate(); // Firestore Timestamp
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is Map && value['_seconds'] != null) {
      final seconds = value['_seconds'] as int;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.now();
  }

  bool get isMatterOnly => taskId == null && documentId == null;
  bool get isOnTask => taskId != null;
  bool get isOnDocument => documentId != null;
}
