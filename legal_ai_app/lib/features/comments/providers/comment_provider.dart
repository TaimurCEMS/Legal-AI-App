import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/comment_service.dart';

/// Provider for comments (Slice 16) - scoped by matter, task, or document
/// Uses real-time Firestore listeners with automatic fallback to Cloud Functions
class CommentProvider extends ChangeNotifier {
  final CommentService _service = CommentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CommentModel> _comments = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = false;
  String? _scopeKey;
  String? _currentOrgId;
  String? _currentMatterId;
  String? _currentTaskId;
  String? _currentDocumentId;
  StreamSubscription<QuerySnapshot>? _commentsSubscription;

  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get isRealtimeActive => _commentsSubscription != null;

  Future<void> loadComments({
    required String orgId,
    String? matterId,
    String? taskId,
    String? documentId,
    bool refresh = true,
  }) async {
    final key = '${orgId}_${matterId ?? ''}_${taskId ?? ''}_${documentId ?? ''}';
    
    // Skip if same query already active and not forcing refresh
    if (!refresh && _commentsSubscription != null && key == _scopeKey && _comments.isNotEmpty) {
      return;
    }

    // Cancel existing subscription if scope changed
    if (_scopeKey != key) {
      await _commentsSubscription?.cancel();
      _commentsSubscription = null;
    }

    _scopeKey = key;
    _currentOrgId = orgId;
    _currentMatterId = matterId;
    _currentTaskId = taskId;
    _currentDocumentId = documentId;
    _error = null;
    _isLoading = _comments.isEmpty;
    notifyListeners();

    try {
      debugPrint('CommentProvider.loadComments: Setting up real-time listener for scope=$key');
      
      // Build Firestore query for real-time updates
      Query<Map<String, dynamic>> query = _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('comments')
          .where('deletedAt', isNull: true);

      // Filter by entity (prefer taskId > documentId > matterId)
      if (taskId != null && taskId.isNotEmpty) {
        query = query.where('taskId', isEqualTo: taskId);
      } else if (documentId != null && documentId.isNotEmpty) {
        query = query.where('documentId', isEqualTo: documentId);
      } else if (matterId != null && matterId.isNotEmpty) {
        query = query.where('matterId', isEqualTo: matterId);
      }

      query = query.orderBy('createdAt', descending: true).limit(100);

      // Set up real-time listener
      _commentsSubscription = query.snapshots().listen(
        (snapshot) {
          _comments = snapshot.docs
              .map((doc) {
                try {
                  return CommentModel.fromJson({
                    ...doc.data(),
                    'commentId': doc.id,
                  });
                } catch (e) {
                  debugPrint('CommentProvider: Error parsing comment ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<CommentModel>()
              .toList();
          _isLoading = false;
          _hasMore = false; // Real-time mode doesn't use pagination
          _error = null;
          debugPrint('CommentProvider: Real-time update - ${_comments.length} comments');
          notifyListeners();
        },
        onError: (error) {
          debugPrint('CommentProvider: Real-time listener error: $error');
          // Fallback to Cloud Functions on permission errors
          _fallbackToCloudFunctions();
        },
      );
    } catch (e) {
      debugPrint('CommentProvider.loadComments error: $e');
      _fallbackToCloudFunctions();
    }
  }

  Future<void> _fallbackToCloudFunctions() async {
    debugPrint('CommentProvider: Falling back to Cloud Functions');
    _commentsSubscription?.cancel();
    _commentsSubscription = null;
    
    if (_currentOrgId == null) {
      _isLoading = false;
      _error = 'No org ID set';
      notifyListeners();
      return;
    }
    
    try {
      final result = await _service.list(
        orgId: _currentOrgId!,
        matterId: _currentMatterId,
        taskId: _currentTaskId,
        documentId: _currentDocumentId,
        limit: 100,
        offset: 0,
      );

      _comments = result.comments;
      _hasMore = result.hasMore;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    super.dispose();
  }

  Future<CommentModel?> addComment({
    required String orgId,
    required String matterId,
    String? taskId,
    String? documentId,
    required String body,
  }) async {
    try {
      final comment = await _service.create(
        orgId: orgId,
        matterId: matterId,
        taskId: taskId,
        documentId: documentId,
        body: body,
      );
      
      // Only add locally if real-time isn't active
      if (!isRealtimeActive && comment != null) {
        _comments.insert(0, comment);
        notifyListeners();
      }
      return comment;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateComment({
    required String orgId,
    required String commentId,
    required String body,
  }) async {
    try {
      await _service.update(orgId: orgId, commentId: commentId, body: body);
      
      // Only update locally if real-time isn't active
      if (!isRealtimeActive) {
        final index = _comments.indexWhere((c) => c.commentId == commentId);
        if (index != -1) {
          _comments[index] = CommentModel(
            commentId: _comments[index].commentId,
            orgId: _comments[index].orgId,
            matterId: _comments[index].matterId,
            taskId: _comments[index].taskId,
            documentId: _comments[index].documentId,
            body: body,
            authorUid: _comments[index].authorUid,
            createdAt: _comments[index].createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment({required String orgId, required String commentId}) async {
    try {
      await _service.delete(orgId: orgId, commentId: commentId);
      
      // Only remove locally if real-time isn't active
      if (!isRealtimeActive) {
        _comments.removeWhere((c) => c.commentId == commentId);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearComments() {
    _commentsSubscription?.cancel();
    _commentsSubscription = null;
    _comments = [];
    _error = null;
    _isLoading = false;
    _hasMore = false;
    _scopeKey = null;
    _currentOrgId = null;
    _currentMatterId = null;
    _currentTaskId = null;
    _currentDocumentId = null;
    notifyListeners();
  }
}
