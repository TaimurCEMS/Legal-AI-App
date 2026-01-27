import 'package:flutter/foundation.dart';
import '../../../core/models/note_model.dart';
import '../../../core/services/note_service.dart';

/// Provider for note state management.
/// 
/// Notes inherit visibility from their case:
/// - If case is ORG_WIDE: all org members can see notes
/// - If case is PRIVATE: only case creator + participants can see notes
class NoteProvider extends ChangeNotifier {
  final NoteService _noteService = NoteService();

  List<NoteModel> _notes = [];
  NoteModel? _selectedNote;
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  bool _hasMore = false;

  // Getters
  List<NoteModel> get notes => _notes;
  NoteModel? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  bool get hasMore => _hasMore;

  /// Load notes with optional filters
  Future<void> loadNotes({
    required String orgId,
    String? caseId,
    NoteCategory? category,
    bool? pinnedOnly,
    String? search,
    bool refresh = false,
  }) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _notes = [];
      }
      notifyListeners();

      debugPrint('NoteProvider.loadNotes: Loading notes for org=$orgId, caseId=$caseId');
      
      final result = await _noteService.listNotes(
        orgId: orgId,
        caseId: caseId,
        category: category,
        pinnedOnly: pinnedOnly,
        search: search,
        limit: 50,
        offset: refresh ? 0 : _notes.length,
      );

      debugPrint('NoteProvider.loadNotes: Received ${result.notes.length} notes, total=${result.total}');
      
      if (refresh) {
        _notes = result.notes;
      } else {
        _notes = [..._notes, ...result.notes];
      }
      _total = result.total;
      _hasMore = result.hasMore;
    } catch (e, stackTrace) {
      _error = e.toString();
      debugPrint('NoteProvider.loadNotes error: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load a single note by ID
  Future<void> loadNoteDetails({
    required String orgId,
    required String noteId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _selectedNote = await _noteService.getNote(orgId: orgId, noteId: noteId);
    } catch (e) {
      _error = e.toString();
      debugPrint('NoteProvider.loadNoteDetails error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new note
  Future<NoteModel?> createNote({
    required String orgId,
    required String caseId,
    required String title,
    required String content,
    NoteCategory? category,
    bool isPinned = false,
    bool isPrivate = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final note = await _noteService.createNote(
        orgId: orgId,
        caseId: caseId,
        title: title,
        content: content,
        category: category,
        isPinned: isPinned,
        isPrivate: isPrivate,
      );

      // Add to the beginning of the list (newest first)
      // If pinned, ensure it's sorted correctly
      if (note.isPinned) {
        _notes.insert(0, note);
      } else {
        // Find the first non-pinned note and insert before it
        final firstNonPinnedIndex = _notes.indexWhere((n) => !n.isPinned);
        if (firstNonPinnedIndex == -1) {
          _notes.add(note);
        } else {
          _notes.insert(firstNonPinnedIndex, note);
        }
      }
      _total++;
      notifyListeners();

      return note;
    } catch (e) {
      _error = e.toString();
      debugPrint('NoteProvider.createNote error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a note
  Future<NoteModel?> updateNote({
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
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedNote = await _noteService.updateNote(
        orgId: orgId,
        noteId: noteId,
        caseId: caseId,
        title: title,
        content: content,
        category: category,
        isPinned: isPinned,
        isPrivate: isPrivate,
      );

      // Update in list
      final index = _notes.indexWhere((n) => n.noteId == noteId);
      if (index != -1) {
        _notes[index] = updatedNote;
        
        // Re-sort if pin status changed
        if (isPinned != null) {
          _notes.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
        }
      }

      // Update selected note if it's the same
      if (_selectedNote?.noteId == noteId) {
        _selectedNote = updatedNote;
      }

      notifyListeners();
      return updatedNote;
    } catch (e) {
      _error = e.toString();
      debugPrint('NoteProvider.updateNote error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle pin status
  Future<void> togglePin({
    required String orgId,
    required String noteId,
  }) async {
    final note = _notes.firstWhere(
      (n) => n.noteId == noteId,
      orElse: () => throw Exception('Note not found'),
    );
    await updateNote(orgId: orgId, noteId: noteId, isPinned: !note.isPinned);
  }

  /// Delete a note
  Future<bool> deleteNote({
    required String orgId,
    required String noteId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _noteService.deleteNote(orgId: orgId, noteId: noteId);

      // Remove from list
      _notes.removeWhere((n) => n.noteId == noteId);
      _total--;

      // Clear selected note if it was deleted
      if (_selectedNote?.noteId == noteId) {
        _selectedNote = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('NoteProvider.deleteNote error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear notes list
  void clearNotes() {
    _notes = [];
    _total = 0;
    _hasMore = false;
    _error = null;
    notifyListeners();
  }

  /// Clear selected note
  void clearSelectedNote() {
    _selectedNote = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
