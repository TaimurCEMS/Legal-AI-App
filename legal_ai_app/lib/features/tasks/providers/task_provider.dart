import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/task_service.dart';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  String? _lastLoadedCaseId;
  String? _lastLoadedOrgId;
  String? _lastQuerySignature;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;

  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  TaskModel? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String? get lastLoadedCaseId => _lastLoadedCaseId;
  bool get isRealtimeActive => _tasksSubscription != null;

  Future<void> loadTasks({
    required OrgModel org,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    final querySignature = '${org.orgId}_${caseId ?? 'null'}_${status?.value ?? 'null'}_${assigneeId ?? 'null'}_${priority?.value ?? 'null'}';
    
    // Skip if same query is already active
    if (_tasksSubscription != null && _lastQuerySignature == querySignature) {
      return;
    }

    // Cancel existing subscription if query changed
    if (_lastQuerySignature != querySignature) {
      await _tasksSubscription?.cancel();
      _tasksSubscription = null;
    }

    _lastQuerySignature = querySignature;
    _lastLoadedCaseId = caseId;
    _lastLoadedOrgId = org.orgId;
    _isLoading = _tasks.isEmpty; // Only show loading if list is empty
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('TaskProvider.loadTasks: Setting up real-time listener - caseId: $caseId, status: ${status?.value}');
      
      // Build Firestore query
      Query<Map<String, dynamic>> query = _firestore
          .collection('organizations')
          .doc(org.orgId)
          .collection('tasks')
          .where('deletedAt', isNull: true);

      // Apply filters
      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }
      if (caseId != null && caseId.isNotEmpty) {
        query = query.where('caseId', isEqualTo: caseId);
      }
      if (assigneeId != null && assigneeId.isNotEmpty) {
        query = query.where('assigneeId', isEqualTo: assigneeId);
      }
      if (priority != null) {
        query = query.where('priority', isEqualTo: priority.value);
      }

      query = query.orderBy('createdAt', descending: true).limit(200);

      // Set up real-time listener
      _tasksSubscription = query.snapshots().listen(
        (snapshot) {
          _tasks.clear();
          for (final doc in snapshot.docs) {
            try {
              final taskModel = TaskModel.fromJson({...doc.data(), 'taskId': doc.id});
              
              // Client-side filtering for search (Firestore can't do text search)
              if (search != null && search.isNotEmpty) {
                final searchLower = search.toLowerCase();
                if (!taskModel.title.toLowerCase().contains(searchLower) &&
                    !(taskModel.description?.toLowerCase().contains(searchLower) ?? false)) {
                  continue;
                }
              }
              
              _tasks.add(taskModel);
            } catch (e) {
              debugPrint('TaskProvider: Error parsing task ${doc.id}: $e');
            }
          }
          
          _isLoading = false;
          _errorMessage = null;
          debugPrint('TaskProvider: Real-time update - ${_tasks.length} tasks');
          notifyListeners();
        },
        onError: (error) {
          debugPrint('TaskProvider: Real-time listener error: $error');
          // Fallback to Cloud Functions on permission errors
          _fallbackToCloudFunctions(
            org: org,
            search: search,
            status: status,
            caseId: caseId,
            assigneeId: assigneeId,
            priority: priority,
          );
        },
      );
    } catch (e) {
      debugPrint('TaskProvider.loadTasks error: $e');
      _fallbackToCloudFunctions(
        org: org,
        search: search,
        status: status,
        caseId: caseId,
        assigneeId: assigneeId,
        priority: priority,
      );
    }
  }

  Future<void> _fallbackToCloudFunctions({
    required OrgModel org,
    String? search,
    TaskStatus? status,
    String? caseId,
    String? assigneeId,
    TaskPriority? priority,
  }) async {
    debugPrint('TaskProvider: Falling back to Cloud Functions');
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
    
    try {
      final result = await _taskService.listTasks(
        org: org,
        search: search,
        status: status,
        caseId: caseId,
        assigneeId: assigneeId,
        priority: priority,
      );
      
      _tasks.clear();
      _tasks.addAll(result.tasks);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
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
    bool restrictedToAssignee = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
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
        restrictedToAssignee: restrictedToAssignee,
      );
      
      // Only add locally if real-time isn't active (it will update via listener)
      if (!isRealtimeActive) {
        _tasks.insert(0, createdTask);
      }
      debugPrint('TaskProvider.createTask: Created task ${createdTask.taskId}');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
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
    bool? restrictedToAssignee,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
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
        restrictedToAssignee: restrictedToAssignee,
      );
      
      // Only update locally if real-time isn't active
      if (!isRealtimeActive) {
        final taskIndex = _tasks.indexWhere((t) => t.taskId == taskId);
        if (taskIndex != -1) {
          _tasks[taskIndex] = updatedTask;
        }
      }
      if (_selectedTask?.taskId == taskId) {
        _selectedTask = updatedTask;
      }
      
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask({
    required OrgModel org,
    required String taskId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _taskService.deleteTask(org: org, taskId: taskId);
      
      // Only remove locally if real-time isn't active
      if (!isRealtimeActive) {
        _tasks.removeWhere((t) => t.taskId == taskId);
      }
      if (_selectedTask?.taskId == taskId) {
        _selectedTask = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearTasks() {
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
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
