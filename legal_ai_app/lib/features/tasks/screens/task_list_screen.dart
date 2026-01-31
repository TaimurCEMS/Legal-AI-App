import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/cards/app_card.dart';
import '../../home/providers/org_provider.dart';
import '../providers/task_provider.dart';
import '../../../core/routing/route_names.dart';

class TaskListScreen extends StatefulWidget {
  /// When used in app shell, [selectedTabIndex] and [tabIndex] trigger load when this tab becomes visible.
  const TaskListScreen({
    super.key,
    this.selectedTabIndex,
    this.tabIndex,
  });

  final int? selectedTabIndex;
  final int? tabIndex;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;
  String? _assigneeFilter;
  bool _isLoading = false;
  String? _lastLoadedOrgId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
      final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
      final isVisibleInShell = widget.selectedTabIndex != null &&
          widget.tabIndex != null &&
          widget.selectedTabIndex == widget.tabIndex;
      if (isStandalone || isVisibleInShell) {
        _checkAndLoadTasks();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nowVisible = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final wasVisible = oldWidget.selectedTabIndex != null &&
        oldWidget.tabIndex != null &&
        oldWidget.selectedTabIndex == oldWidget.tabIndex;
    
    // Load when we become visible
    if (nowVisible && !wasVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoading) _checkAndLoadTasks();
      });
    }
  }
  
  Timer? _searchDebounce;
  
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _lastLoadedOrgId = null;
        _tryLoadTasks();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _checkAndLoadTasks() {
    if (_isLoading) return;
    _tryLoadTasks();
  }

  Future<void> _tryLoadTasks() async {
    if (_isLoading) return;
    
    _isLoading = true;
    final startTime = DateTime.now();
    
    try {
      final orgProvider = context.read<OrgProvider>();
      final taskProvider = context.read<TaskProvider>();
      
      int retries = 0;
      const maxRetries = 30;
      while (orgProvider.selectedOrg == null && retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
        if (!mounted) {
          _isLoading = false;
          return;
        }
      }
      
      final currentOrg = orgProvider.selectedOrg;
      if (currentOrg == null) {
        _isLoading = false;
        return;
      }
      
      final currentSearch = _searchController.text.trim();
      final orgChanged = _lastLoadedOrgId != currentOrg.orgId;
      final searchChanged = _lastLoadedSearch != currentSearch;
      final filterChanged = _lastLoadedStatusFilter != _statusFilter || 
                           _lastLoadedPriorityFilter != _priorityFilter ||
                           _lastLoadedAssigneeFilter != _assigneeFilter;
      
      if (!orgChanged && !searchChanged && !filterChanged) {
        _isLoading = false;
        return;
      }
      
      await taskProvider.loadTasks(
        org: currentOrg,
        search: currentSearch.isEmpty ? null : currentSearch,
        status: _statusFilter,
        priority: _priorityFilter,
        assigneeId: _assigneeFilter,
      );
      
      if (taskProvider.errorMessage == null) {
        _lastLoadedOrgId = currentOrg.orgId;
        _lastLoadedStatusFilter = _statusFilter;
        _lastLoadedPriorityFilter = _priorityFilter;
        _lastLoadedAssigneeFilter = _assigneeFilter;
        _lastLoadedSearch = currentSearch;
      } else {
        _lastLoadedOrgId = null;
        _lastLoadedStatusFilter = null;
        _lastLoadedPriorityFilter = null;
        _lastLoadedAssigneeFilter = null;
        _lastLoadedSearch = null;
      }
    } catch (e) {
      debugPrint('TaskListScreen._tryLoadTasks: ERROR - $e');
      _lastLoadedOrgId = null;
      _lastLoadedStatusFilter = null;
      _lastLoadedPriorityFilter = null;
      _lastLoadedAssigneeFilter = null;
      _lastLoadedSearch = null;
    } finally {
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  String? _lastLoadedSearch;
  TaskStatus? _lastLoadedStatusFilter;
  TaskPriority? _lastLoadedPriorityFilter;
  String? _lastLoadedAssigneeFilter;

  Future<void> _refresh() async {
    _lastLoadedOrgId = null;
    _lastLoadedStatusFilter = null;
    _lastLoadedPriorityFilter = null;
    _lastLoadedAssigneeFilter = null;
    _lastLoadedSearch = null;
    _isLoading = false;
    final taskProvider = context.read<TaskProvider>();
    taskProvider.clearError();
    await _tryLoadTasks();
  }

  void _handleStatusFilterChange(TaskStatus? newStatus) {
    setState(() {
      _statusFilter = newStatus;
    });
    _lastLoadedOrgId = null;
    _lastLoadedStatusFilter = null;
    _lastLoadedSearch = null;
    final taskProvider = context.read<TaskProvider>();
    taskProvider.clearTasks();
    _tryLoadTasks();
  }

  void _handlePriorityFilterChange(TaskPriority? newPriority) {
    setState(() {
      _priorityFilter = newPriority;
    });
    _lastLoadedOrgId = null;
    _lastLoadedPriorityFilter = null;
    _lastLoadedSearch = null;
    final taskProvider = context.read<TaskProvider>();
    taskProvider.clearTasks();
    _tryLoadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    final taskProvider = context.watch<TaskProvider>();
    final isStandalone = GoRouterState.of(context).uri.path == RouteNames.taskList;

    // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
    final isStandaloneMode = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final shouldLoad = isStandaloneMode || isVisibleInShell;
    
    if (shouldLoad && org != null && _lastLoadedOrgId != org.orgId && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndLoadTasks();
      });
    }

    return Scaffold(
      appBar: isStandalone
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to home',
                onPressed: () => context.go(RouteNames.home),
              ),
              title: const Text('Tasks'),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'task_fab',
        onPressed: () {
          context.push(RouteNames.taskCreate);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasks',
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildFilters(taskProvider),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(taskProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(TaskProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search tasks…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PopupMenuButton<TaskStatus?>(
              tooltip: 'Filter by status',
              // Only handle non-null selections here.
              // "All statuses" is handled explicitly via onTap in its menu item
              onSelected: (status) {
                if (status != null) {
                  _handleStatusFilterChange(status);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<TaskStatus?>(
                  value: null,
                  onTap: () {
                    // Ensure "All statuses" ALWAYS clears the filter and reloads
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        _handleStatusFilterChange(null);
                      }
                    });
                  },
                  child: const Text('All statuses'),
                ),
                const PopupMenuItem(
                  value: TaskStatus.pending,
                  child: Text('Pending'),
                ),
                const PopupMenuItem(
                  value: TaskStatus.inProgress,
                  child: Text('In Progress'),
                ),
                const PopupMenuItem(
                  value: TaskStatus.completed,
                  child: Text('Completed'),
                ),
                const PopupMenuItem(
                  value: TaskStatus.cancelled,
                  child: Text('Cancelled'),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _statusFilter == null
                        ? 'All statuses'
                        : _statusFilter!.statusDisplayName,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            PopupMenuButton<TaskPriority?>(
              tooltip: 'Filter by priority',
              // Only handle non-null selections here.
              // "All priorities" is handled explicitly via onTap in its menu item
              onSelected: (priority) {
                if (priority != null) {
                  _handlePriorityFilterChange(priority);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<TaskPriority?>(
                  value: null,
                  onTap: () {
                    // Ensure "All priorities" ALWAYS clears the filter and reloads
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        _handlePriorityFilterChange(null);
                      }
                    });
                  },
                  child: const Text('All priorities'),
                ),
                const PopupMenuItem(
                  value: TaskPriority.low,
                  child: Text('Low'),
                ),
                const PopupMenuItem(
                  value: TaskPriority.medium,
                  child: Text('Medium'),
                ),
                const PopupMenuItem(
                  value: TaskPriority.high,
                  child: Text('High'),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _priorityFilter == null
                        ? 'All priorities'
                        : _priorityFilter!.priorityDisplayName,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(TaskProvider provider) {
    final orgProvider = context.read<OrgProvider>();
    
    if (orgProvider.selectedOrg == null) {
      if (orgProvider.isLoading || !orgProvider.isInitialized) {
        return const Center(
          child: LoadingSpinner(message: 'Loading organization...'),
        );
      }
      return const Center(
        child: LoadingSpinner(message: 'No organization selected'),
      );
    }

    if (provider.isLoading && provider.tasks.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    if (provider.errorMessage != null && 
        provider.tasks.isEmpty && 
        !provider.isLoading) {
      return Center(
        child: ErrorMessage(
          message: provider.errorMessage!.contains('Failed to list tasks')
              ? provider.errorMessage!
              : 'Failed to list tasks: ${provider.errorMessage}',
          onRetry: () {
            provider.clearError();
            _tryLoadTasks();
          },
        ),
      );
    }

    if (provider.tasks.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.task_alt,
        title: 'No tasks yet',
        message: 'Create your first task to start managing work.',
        actionLabel: 'New Task',
        onAction: () {
          context.push(RouteNames.taskCreate);
        },
      );
    }

    return ListView.separated(
      itemCount: provider.tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final task = provider.tasks[index];
        return _TaskListItem(taskModel: task);
      },
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final TaskModel taskModel;

  const _TaskListItem({required this.taskModel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push(
          RouteNames.taskDetails,
          extra: taskModel.taskId,
        );
      },
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      taskModel.title,
                      style: AppTypography.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusChip(status: taskModel.status),
                  const SizedBox(width: AppSpacing.xs),
                  _PriorityChip(priority: taskModel.priority),
                ],
              ),
              if (taskModel.description != null &&
                  taskModel.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  taskModel.description!,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (taskModel.assigneeName != null)
                    Text(
                      taskModel.assigneeName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  if (taskModel.dueDate != null) ...[
                    if (taskModel.assigneeName != null)
                      const SizedBox(width: AppSpacing.sm),
                    Icon(
                      taskModel.isOverdue
                          ? Icons.warning
                          : taskModel.isDueSoon
                              ? Icons.schedule
                              : Icons.calendar_today,
                      size: 14,
                      color: taskModel.isOverdue
                          ? Colors.red
                          : taskModel.isDueSoon
                              ? Colors.orange
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      taskModel.dueDate!.toLocal().toIso8601String().substring(0, 10),
                      style: AppTypography.bodySmall.copyWith(
                        color: taskModel.isOverdue
                            ? Colors.red
                            : taskModel.isDueSoon
                                ? Colors.orange
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Updated ${taskModel.updatedAt.toLocal().toIso8601String().substring(0, 10)}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case TaskStatus.pending:
        color = Colors.grey;
        break;
      case TaskStatus.inProgress:
        color = Colors.blue;
        break;
      case TaskStatus.completed:
        color = Colors.green;
        break;
      case TaskStatus.cancelled:
        color = Colors.red;
        break;
    }
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        status.statusDisplayName,
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final TaskPriority priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case TaskPriority.low:
        color = Colors.green;
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        break;
      case TaskPriority.high:
        color = Colors.red;
        break;
    }
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        priority.priorityDisplayName,
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}
