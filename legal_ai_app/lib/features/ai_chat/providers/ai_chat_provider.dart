import 'package:flutter/foundation.dart';

import '../../../core/models/chat_thread_model.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/ai_chat_service.dart';

/// Provider for AI Chat state management (Slice 6b)
class AIChatProvider extends ChangeNotifier {
  final AIChatService _chatService = AIChatService();

  // State
  List<ChatThreadModel> _threads = [];
  List<ChatMessageModel> _messages = [];
  ChatThreadModel? _currentThread;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  int _totalThreads = 0;
  bool _hasMoreThreads = false;

  // Getters
  List<ChatThreadModel> get threads => _threads;
  List<ChatMessageModel> get messages => _messages;
  ChatThreadModel? get currentThread => _currentThread;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get totalThreads => _totalThreads;
  bool get hasMoreThreads => _hasMoreThreads;

  /// Load chat threads for a case
  Future<void> loadThreads({
    required OrgModel org,
    required String caseId,
    bool refresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    if (refresh) {
      _threads = [];
    }
    notifyListeners();

    try {
      final result = await _chatService.listThreads(
        org: org,
        caseId: caseId,
        limit: 20,
        offset: refresh ? 0 : _threads.length,
      );

      if (refresh) {
        _threads = result.threads;
      } else {
        _threads = [..._threads, ...result.threads];
      }
      _totalThreads = result.total;
      _hasMoreThreads = result.hasMore;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AIChatProvider.loadThreads error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new chat thread
  Future<ChatThreadModel?> createThread({
    required OrgModel org,
    required String caseId,
    String? title,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final thread = await _chatService.createThread(
        org: org,
        caseId: caseId,
        title: title,
      );

      // Add to beginning of list
      _threads = [thread, ..._threads];
      _totalThreads++;
      _currentThread = thread;
      _messages = [];
      notifyListeners();

      return thread;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AIChatProvider.createThread error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Load messages for a thread
  Future<void> loadMessages({
    required OrgModel org,
    required String caseId,
    required String threadId,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Find and set current thread
      _currentThread = _threads.firstWhere(
        (t) => t.threadId == threadId,
        orElse: () => throw 'Thread not found',
      );

      final result = await _chatService.getMessages(
        org: org,
        caseId: caseId,
        threadId: threadId,
        limit: 100,
      );

      _messages = result.messages;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AIChatProvider.loadMessages error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a message and get AI response
  Future<bool> sendMessage({
    required OrgModel org,
    required String caseId,
    required String threadId,
    required String message,
    Map<String, String>? jurisdiction,
  }) async {
    if (_isSending) return false;

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _chatService.sendMessage(
        org: org,
        caseId: caseId,
        threadId: threadId,
        message: message,
        jurisdiction: jurisdiction,
      );

      // Add both messages to the list
      _messages = [..._messages, result.userMessage, result.assistantMessage];

      // Update thread in list
      final threadIndex = _threads.indexWhere((t) => t.threadId == threadId);
      if (threadIndex >= 0) {
        final oldThread = _threads[threadIndex];
        _threads[threadIndex] = ChatThreadModel(
          threadId: oldThread.threadId,
          caseId: oldThread.caseId,
          title: oldThread.messageCount == 0 
              ? _generateTitle(message) 
              : oldThread.title,
          createdAt: oldThread.createdAt,
          updatedAt: DateTime.now(),
          createdBy: oldThread.createdBy,
          messageCount: oldThread.messageCount + 2,
          lastMessageAt: DateTime.now(),
          status: oldThread.status,
        );
        _currentThread = _threads[threadIndex];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AIChatProvider.sendMessage error: $e');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Delete a chat thread
  Future<bool> deleteThread({
    required OrgModel org,
    required String caseId,
    required String threadId,
  }) async {
    _errorMessage = null;

    try {
      await _chatService.deleteThread(
        org: org,
        caseId: caseId,
        threadId: threadId,
      );

      // Remove from list
      _threads = _threads.where((t) => t.threadId != threadId).toList();
      _totalThreads--;

      if (_currentThread?.threadId == threadId) {
        _currentThread = null;
        _messages = [];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AIChatProvider.deleteThread error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clear current thread and messages
  void clearCurrentThread() {
    _currentThread = null;
    _messages = [];
    notifyListeners();
  }

  /// Clear all state
  void clear() {
    _threads = [];
    _messages = [];
    _currentThread = null;
    _isLoading = false;
    _isSending = false;
    _errorMessage = null;
    _totalThreads = 0;
    _hasMoreThreads = false;
    notifyListeners();
  }

  /// Generate a title from the first message
  String _generateTitle(String message) {
    final cleaned = message.trim();
    if (cleaned.length <= 50) return cleaned;
    
    // Try to find end of first sentence
    final sentenceEnd = cleaned.indexOf(RegExp(r'[.!?]'));
    if (sentenceEnd > 0 && sentenceEnd < 50) {
      return cleaned.substring(0, sentenceEnd + 1);
    }
    
    return '${cleaned.substring(0, 47)}...';
  }
}
