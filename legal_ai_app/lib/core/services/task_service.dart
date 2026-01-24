import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

class TaskService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<TaskModel> createTask({
    required OrgModel org,
    required String title,
    String? description,
    required TaskStatus status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    String? caseId,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'title': title.trim(),
      'status': status.value,
      'priority': priority.value,
    };
    
    if (caseId != null && caseId.trim().isNotEmpty) {
      payload['caseId'] = caseId.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }
    if (dueDate != null) {
      // Normalize to date-only (UTC midnight) to avoid timezone issues
      final dateOnly = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
      payload['dueDate'] = dateOnly.toIso8601String().split('T')[0];
    }
    if (assigneeId != null && assigneeId.trim().isNotEmpty) {
      payload['assigneeId'] = assigneeId.trim();
    }
    
    final response = await _functionsService.callFunction('taskCreate', payload);

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.createTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to create task. Please try again.';
    throw message;
  }

  Future<TaskModel> getTask({
    required OrgModel org,
    required String taskId,
  }) async {
    final response = await _functionsService.callFunction('taskGet', {
      'orgId': org.orgId,
      'taskId': taskId,
    });

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.getTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to load task. Please try again.';
    throw message;
  }

  Future<({List<TaskModel> tasks, int total, bool hasMore})> listTasks({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    final response = await _functionsService.callFunction('taskList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status.value,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (assigneeId != null && assigneeId.trim().isNotEmpty) 'assigneeId': assigneeId.trim(),
      if (priority != null) 'priority': priority.value,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (tasks: list, total: total, hasMore: hasMore);
    }

    debugPrint('TaskService.listTasks error: $response');
    final error = response['error'];
    final message = error?['message'] ?? 'Failed to load tasks. Please try again.';
    final code = error?['code'];
    debugPrint('TaskService.listTasks: Error code: $code, message: $message');
    throw message;
  }

  Future<TaskModel> updateTask({
    required OrgModel org,
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority? priority,
    String? caseId, // Support case linking/unlinking
    // Explicit flags for clearing fields (fixes "null vs not passed" issue)
    bool clearDueDate = false,
    bool unassign = false,
    bool unlinkCase = false,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'taskId': taskId,
    };

    if (title != null) payload['title'] = title.trim();
    if (description != null) {
      payload['description'] = description.trim().isEmpty ? null : description.trim();
    }
    if (status != null) payload['status'] = status.value;
    
    // Handle dueDate: explicit clear flag vs new date
    if (clearDueDate) {
      payload['dueDate'] = null; // Explicitly clear
    } else if (dueDate != null) {
      // Normalize to date-only (UTC midnight) to avoid timezone issues
      final dateOnly = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
      payload['dueDate'] = dateOnly.toIso8601String().split('T')[0];
    }
    
    // Handle assigneeId: explicit unassign flag vs new assignee
    if (unassign) {
      payload['assigneeId'] = null; // Explicitly unassign
    } else if (assigneeId != null && assigneeId.trim().isNotEmpty) {
      payload['assigneeId'] = assigneeId.trim();
    }
    
    // Handle caseId: explicit unlink flag vs new case link
    if (unlinkCase) {
      payload['caseId'] = null; // Explicitly unlink
    } else if (caseId != null && caseId.trim().isNotEmpty) {
      payload['caseId'] = caseId.trim();
    }
    
    if (priority != null) payload['priority'] = priority.value;

    final response = await _functionsService.callFunction('taskUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return TaskModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('TaskService.updateTask error: $response');
    final message = response['error']?['message'] ??
        'Failed to update task. Please try again.';
    throw message;
  }

  Future<void> deleteTask({
    required OrgModel org,
    required String taskId,
  }) async {
    final response = await _functionsService.callFunction('taskDelete', {
      'orgId': org.orgId,
      'taskId': taskId,
    });

    if (response['success'] != true) {
      debugPrint('TaskService.deleteTask error: $response');
      final message = response['error']?['message'] ??
          'Failed to delete task. Please try again.';
      throw message;
    }
  }
}
