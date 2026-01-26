import 'package:flutter/foundation.dart';

import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service for AI Chat/Research functionality (Slice 6b)
class AIChatService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  /// Create a new chat thread for a case
  Future<ChatThreadModel> createThread({
    required OrgModel org,
    required String caseId,
    String? title,
  }) async {
    final response = await _functionsService.callFunction('aiChatCreate', {
      'orgId': org.orgId,
      'caseId': caseId,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      return ChatThreadModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('AIChatService.createThread error: $response');
    final message = response['error']?['message'] ??
        'Failed to create chat thread. Please try again.';
    throw message;
  }

  /// Send a message and get AI response
  Future<({ChatMessageModel userMessage, ChatMessageModel assistantMessage})> sendMessage({
    required OrgModel org,
    required String caseId,
    required String threadId,
    required String message,
    String? model,
    List<String>? documentIds,
    Map<String, String>? jurisdiction,
  }) async {
    final response = await _functionsService.callFunction('aiChatSend', {
      'orgId': org.orgId,
      'caseId': caseId,
      'threadId': threadId,
      'message': message,
      if (model != null || documentIds != null)
        'options': {
          if (model != null) 'model': model,
          if (documentIds != null) 'documentIds': documentIds,
        },
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      
      final userMessage = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(data['userMessage'] as Map),
      );
      final assistantMessage = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(data['assistantMessage'] as Map),
      );
      
      return (userMessage: userMessage, assistantMessage: assistantMessage);
    }

    debugPrint('AIChatService.sendMessage error: $response');
    final errorMessage = response['error']?['message'] ??
        'Failed to get AI response. Please try again.';
    throw errorMessage;
  }

  /// List chat threads for a case
  Future<({List<ChatThreadModel> threads, int total, bool hasMore})> listThreads({
    required OrgModel org,
    required String caseId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _functionsService.callFunction('aiChatList', {
      'orgId': org.orgId,
      'caseId': caseId,
      'limit': limit,
      'offset': offset,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final threads = (data['threads'] as List<dynamic>? ?? [])
          .map((t) => ChatThreadModel.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      final total = data['total'] as int? ?? threads.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (threads: threads, total: total, hasMore: hasMore);
    }

    debugPrint('AIChatService.listThreads error: $response');
    final message = response['error']?['message'] ??
        'Failed to load chat threads. Please try again.';
    throw message;
  }

  /// Get messages for a thread
  Future<({List<ChatMessageModel> messages, int total, bool hasMore})> getMessages({
    required OrgModel org,
    required String caseId,
    required String threadId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _functionsService.callFunction('aiChatGetMessages', {
      'orgId': org.orgId,
      'caseId': caseId,
      'threadId': threadId,
      'limit': limit,
      'offset': offset,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .map((m) => ChatMessageModel.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
      final total = data['total'] as int? ?? messages.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (messages: messages, total: total, hasMore: hasMore);
    }

    debugPrint('AIChatService.getMessages error: $response');
    final message = response['error']?['message'] ??
        'Failed to load messages. Please try again.';
    throw message;
  }

  /// Delete a chat thread
  Future<void> deleteThread({
    required OrgModel org,
    required String caseId,
    required String threadId,
  }) async {
    final response = await _functionsService.callFunction('aiChatDelete', {
      'orgId': org.orgId,
      'caseId': caseId,
      'threadId': threadId,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('AIChatService.deleteThread error: $response');
    final message = response['error']?['message'] ??
        'Failed to delete chat thread. Please try again.';
    throw message;
  }
}
