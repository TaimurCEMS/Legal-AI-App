import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

/// Service for note CRUD operations.
/// 
/// Notes inherit visibility from their case:
/// - If case is ORG_WIDE: all org members can see notes
/// - If case is PRIVATE: only case creator + participants can see notes
class NoteService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Create a new note
  Future<NoteModel> createNote({
    required String orgId,
    required String caseId,
    required String title,
    required String content,
    NoteCategory? category,
    bool isPinned = false,
    bool isPrivate = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('noteCreate');
      final result = await callable.call<Map<String, dynamic>>({
        'orgId': orgId,
        'caseId': caseId,
        'title': title,
        'content': content,
        if (category != null) 'category': category.value,
        'isPinned': isPinned,
        'isPrivate': isPrivate,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error']?['message'] ?? 'Failed to create note');
      }

      return NoteModel.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('NoteService.createNote error: $e');
      rethrow;
    }
  }

  /// Get a single note by ID
  Future<NoteModel> getNote({
    required String orgId,
    required String noteId,
  }) async {
    try {
      final callable = _functions.httpsCallable('noteGet');
      final result = await callable.call<Map<String, dynamic>>({
        'orgId': orgId,
        'noteId': noteId,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error']?['message'] ?? 'Failed to get note');
      }

      return NoteModel.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('NoteService.getNote error: $e');
      rethrow;
    }
  }

  /// List notes with optional filters
  Future<NoteListResult> listNotes({
    required String orgId,
    String? caseId,
    NoteCategory? category,
    bool? pinnedOnly,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final callable = _functions.httpsCallable('noteList');
      final result = await callable.call<Map<String, dynamic>>({
        'orgId': orgId,
        if (caseId != null) 'caseId': caseId,
        if (category != null) 'category': category.value,
        if (pinnedOnly != null) 'pinnedOnly': pinnedOnly,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error']?['message'] ?? 'Failed to list notes');
      }

      final responseData = data['data'] as Map<String, dynamic>;
      final notesJson = responseData['notes'] as List<dynamic>;
      final notes = notesJson
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return NoteListResult(
        notes: notes,
        total: responseData['total'] as int,
        hasMore: responseData['hasMore'] as bool,
      );
    } catch (e) {
      debugPrint('NoteService.listNotes error: $e');
      rethrow;
    }
  }

  /// Update a note
  Future<NoteModel> updateNote({
    required String orgId,
    required String noteId,
    String? caseId,
    String? title,
    String? content,
    NoteCategory? category,
    bool? isPinned,
    bool? isPrivate,
  }) async {
    try {
      final callable = _functions.httpsCallable('noteUpdate');
      final result = await callable.call<Map<String, dynamic>>({
        'orgId': orgId,
        'noteId': noteId,
        if (caseId != null) 'caseId': caseId,
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (category != null) 'category': category.value,
        if (isPinned != null) 'isPinned': isPinned,
        if (isPrivate != null) 'isPrivate': isPrivate,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error']?['message'] ?? 'Failed to update note');
      }

      return NoteModel.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('NoteService.updateNote error: $e');
      rethrow;
    }
  }

  /// Delete a note (soft delete)
  Future<void> deleteNote({
    required String orgId,
    required String noteId,
  }) async {
    try {
      final callable = _functions.httpsCallable('noteDelete');
      final result = await callable.call<Map<String, dynamic>>({
        'orgId': orgId,
        'noteId': noteId,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error']?['message'] ?? 'Failed to delete note');
      }
    } catch (e) {
      debugPrint('NoteService.deleteNote error: $e');
      rethrow;
    }
  }
}

/// Result class for note list operations
class NoteListResult {
  final List<NoteModel> notes;
  final int total;
  final bool hasMore;

  NoteListResult({
    required this.notes,
    required this.total,
    required this.hasMore,
  });
}
