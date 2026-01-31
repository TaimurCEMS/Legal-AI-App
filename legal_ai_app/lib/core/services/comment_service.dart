import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/comment_model.dart';

/// Service for comment CRUD (Slice 16)
class CommentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<CommentModel> create({
    required String orgId,
    required String matterId,
    String? taskId,
    String? documentId,
    required String body,
  }) async {
    final result = await _functions.httpsCallable('commentCreate').call<Map<String, dynamic>>({
      'orgId': orgId,
      'matterId': matterId,
      if (taskId != null && taskId.isNotEmpty) 'taskId': taskId,
      if (documentId != null && documentId.isNotEmpty) 'documentId': documentId,
      'body': body,
    });
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to create comment');
    }
    return CommentModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<CommentModel> get({required String orgId, required String commentId}) async {
    final result = await _functions.httpsCallable('commentGet').call<Map<String, dynamic>>({
      'orgId': orgId,
      'commentId': commentId,
    });
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to get comment');
    }
    return CommentModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<CommentListResult> list({
    required String orgId,
    String? matterId,
    String? taskId,
    String? documentId,
    int limit = 50,
    int offset = 0,
  }) async {
    // Backend requires exactly one of matterId, taskId, or documentId
    final params = <String, dynamic>{
      'orgId': orgId,
      'limit': limit,
      'offset': offset,
    };
    if (taskId != null && taskId.isNotEmpty) {
      params['taskId'] = taskId;
    } else if (documentId != null && documentId.isNotEmpty) {
      params['documentId'] = documentId;
    } else if (matterId != null && matterId.isNotEmpty) {
      params['matterId'] = matterId;
    }

    final result = await _functions.httpsCallable('commentList').call<Map<String, dynamic>>(params);
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to list comments');
    }
    final responseData = data['data'] as Map<String, dynamic>;
    final list = (responseData['comments'] as List<dynamic>)
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return CommentListResult(
      comments: list,
      total: responseData['total'] as int? ?? list.length,
      hasMore: responseData['hasMore'] as bool? ?? false,
    );
  }

  Future<CommentModel> update({
    required String orgId,
    required String commentId,
    required String body,
  }) async {
    final result = await _functions.httpsCallable('commentUpdate').call<Map<String, dynamic>>({
      'orgId': orgId,
      'commentId': commentId,
      'body': body,
    });
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to update comment');
    }
    return CommentModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> delete({required String orgId, required String commentId}) async {
    final result = await _functions.httpsCallable('commentDelete').call<Map<String, dynamic>>({
      'orgId': orgId,
      'commentId': commentId,
    });
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to delete comment');
    }
  }
}

class CommentListResult {
  final List<CommentModel> comments;
  final int total;
  final bool hasMore;
  CommentListResult({required this.comments, required this.total, required this.hasMore});
}
