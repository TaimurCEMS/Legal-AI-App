import 'package:flutter/foundation.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/task_service.dart';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();

  final List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  String? _lastLoadedCaseId; // Track last loaded caseId for auto-refresh
  String? _lastLoadedOrgId; // Track last loaded orgId
  String? _lastQuerySignature; // Track query signature to prevent duplicate loads

  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  TaskModel? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String? get lastLoadedCaseId => _lastLoadedCaseId;

  Future<void> loadTasks({
    required OrgModel org,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    // Create query signature to prevent duplicate loads (includes all filters)
    final querySignature = '${org.orgId}_${caseId ?? 'null'}_${search ?? 'null'}_${status?.value ?? 'null'}_${assigneeId ?? 'null'}_${priority?.value ?? 'null'}';
    
    // Prevent duplicate loads - only block if exact same query is already loading
    if (_isLoading && _lastQuerySignature == querySignature) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _tasks.clear(); // Clear existing tasks to show loading state immediately
    _lastLoadedCaseId = caseId;
    _lastLoadedOrgId = org.orgId;
    _lastQuerySignature = querySignature;
    notifyListeners();

    try {
      debugPrint('TaskProvider.loadTasks: Loading with filters - caseId: $caseId, status: ${status?.value}, search: $search');
      final result = await _taskService.listTasks(
        org: org,
        search: search,
        status: status,
        caseId: caseId,
        assigneeId: assigneeId,
        priority: priority,
      );
      
      debugPrint('TaskProvider.loadTasks: Received ${result.tasks.length} tasks from backend');
      _tasks.clear();
      // Use a Set to ensure no duplicates by taskId
      final existingIds = <String>{};
      for (final task in result.tasks) {
        if (!existingIds.contains(task.taskId)) {
          _tasks.add(task);
          existingIds.add(task.taskId);
          debugPrint('TaskProvider.loadTasks: Added task ${task.taskId} with caseId: ${task.caseId}');
        }
      }
      debugPrint('TaskProvider.loadTasks: Total tasks in provider: ${_tasks.length}');
      _errorMessage = null;
    } catch (e) {
      // Extract user-friendly error message
      final errorStr = e.toString();
      // Remove "Exception: " prefix if present for cleaner error messages
      _errorMessage = errorStr.replaceFirst(RegExp(r'^Exception:\s*'), '');
      debugPrint('TaskProvider.loadTasks error: $e');
      debugPrint('TaskProvider.loadTasks: Error message: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTaskDetails({
    required OrgModel org,
    required String taskId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final task = await _taskService.getTask(org: org, taskId: taskId);
      _selectedTask = task;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _selectedTask = null;
      debugPrint('TaskProvider.loadTaskDetails error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask({
    required OrgModel org,
    required String title,
    String? description,
    required TaskStatus status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    
    // Optimistic UI update: Add task to list immediately
    final optimisticTaskId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticTask = TaskModel(
      taskId: optimisticTaskId,
      orgId: org.orgId,
      caseId: caseId,
      title: title,
      description: description,
      status: status,
      dueDate: dueDate,
      assigneeId: assigneeId,
      assigneeName: null, // Will be set after backend confirms
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: '',
      updatedBy: '',
    );
    
    // Only add optimistically if we're viewing tasks for this case/org
    if ((caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) ||
        (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId)) {
      _tasks.add(optimisticTask);
    }
    
    notifyListeners();

    try {
      final createdTask = await _taskService.createTask(
        org: org,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        assigneeId: assigneeId,
        priority: priority,
        caseId: caseId,
      );
      
      // Remove ONLY the specific optimistic task (ID-specific removal)
      _tasks.removeWhere((t) => t.taskId == optimisticTaskId);
      _tasks.add(createdTask);
      
      // Reload tasks to ensure we have latest data (assignee names, etc.)
      debugPrint('TaskProvider.createTask: Created task ${createdTask.taskId} with caseId: ${createdTask.caseId}');
      if (caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) {
        debugPrint('TaskProvider.createTask: Reloading tasks for case $caseId');
        loadTasks(org: org, caseId: caseId).catchError((e) {
          debugPrint('Error reloading tasks after create: $e');
        });
      } else if (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId) {
        debugPrint('TaskProvider.createTask: Reloading all tasks');
        loadTasks(org: org).catchError((e) {
          debugPrint('Error reloading tasks after create: $e');
        });
      } else {
        debugPrint('TaskProvider.createTask: Not reloading (different context)');
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      // Remove ONLY the specific optimistic task on error (ID-specific removal)
      _tasks.removeWhere((t) => t.taskId == optimisticTaskId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTask({
    required OrgModel org,
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? assigneeId,
    TaskPriority? priority,
    String? caseId,
    bool clearDueDate = false,
    bool unassign = false,
    bool unlinkCase = false,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    
    // Optimistic UI update: Update task in list immediately
    final taskIndex = _tasks.indexWhere((t) => t.taskId == taskId);
    TaskModel? previousTask;
    if (taskIndex != -1) {
      previousTask = _tasks[taskIndex];
      _tasks[taskIndex] = TaskModel(
        taskId: previousTask.taskId,
        orgId: previousTask.orgId,
        caseId: unlinkCase ? null : (caseId ?? previousTask.caseId),
        title: title ?? previousTask.title,
        description: description ?? previousTask.description,
        status: status ?? previousTask.status,
        dueDate: clearDueDate ? null : (dueDate ?? previousTask.dueDate),
        assigneeId: unassign ? null : (assigneeId ?? previousTask.assigneeId),
        assigneeName: previousTask.assigneeName, // Will be updated after backend confirms
        priority: priority ?? previousTask.priority,
        createdAt: previousTask.createdAt,
        updatedAt: DateTime.now(),
        createdBy: previousTask.createdBy,
        updatedBy: previousTask.updatedBy,
      );
    }
    
    // Update selected task if it's the one being updated
    if (_selectedTask?.taskId == taskId && previousTask != null) {
      _selectedTask = _tasks[taskIndex];
    }
    
    notifyListeners();

    try {
      final updatedTask = await _taskService.updateTask(
        org: org,
        taskId: taskId,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        assigneeId: assigneeId,
        priority: priority,
        caseId: caseId,
        clearDueDate: clearDueDate,
        unassign: unassign,
        unlinkCase: unlinkCase,
      );
      
      // Replace optimistic update with real data
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
      }
      if (_selectedTask?.taskId == taskId) {
        _selectedTask = updatedTask;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      if (taskIndex != -1 && previousTask != null) {
        _tasks[taskIndex] = previousTask;
      }
      if (_selectedTask?.taskId == taskId && previousTask != null) {
        _selectedTask = previousTask;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTask({
    required OrgModel org,
    required String taskId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    
    // Optimistic UI update: Remove task from list immediately
    final taskIndex = _tasks.indexWhere((t) => t.taskId == taskId);
    TaskModel? removedTask;
    if (taskIndex != -1) {
      removedTask = _tasks.removeAt(taskIndex);
    }
    if (_selectedTask?.taskId == taskId) {
      _selectedTask = null;
    }
    notifyListeners();

    try {
      await _taskService.deleteTask(org: org, taskId: taskId);
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      if (removedTask != null && taskIndex != -1) {
        _tasks.insert(taskIndex, removedTask);
      }
      if (removedTask != null && _selectedTask == null && removedTask.taskId == taskId) {
        _selectedTask = removedTask;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all tasks (used when switching organizations)
  void clearTasks() {
    _tasks.clear();
    _selectedTask = null;
    _errorMessage = null;
    _isLoading = false;
    _isUpdating = false;
    _lastLoadedCaseId = null;
    _lastLoadedOrgId = null;
    _lastQuerySignature = null;
    notifyListeners();
  }
}
