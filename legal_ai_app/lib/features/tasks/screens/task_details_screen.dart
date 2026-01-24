import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/task_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../../core/models/case_model.dart';
import '../../home/providers/member_provider.dart';
import '../../../core/models/member_model.dart';
import '../../../core/routing/route_names.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TaskStatus? _status;
  TaskPriority? _priority;
  DateTime? _dueDate;
  String? _selectedCaseId;
  String? _selectedAssigneeId;
  bool _loadingCases = false;
  bool _loadingMembers = false;
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
      _loadCases();
      _loadMembers();
    });
  }

  Future<void> _loadDetails() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final taskProvider = context.read<TaskProvider>();
    await taskProvider.loadTaskDetails(org: org, taskId: widget.taskId);

    if (!mounted) return;

    final task = taskProvider.selectedTask;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _status = task.status;
      _priority = task.priority;
      _dueDate = task.dueDate;
      _selectedCaseId = task.caseId;
      _selectedAssigneeId = task.assigneeId;
    }

    setState(() {
      _loading = false;
      _error = taskProvider.errorMessage;
    });
  }

  Future<void> _loadCases() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loadingCases = true;
    });

    final caseProvider = context.read<CaseProvider>();
    await caseProvider.loadCases(org: org);

    if (mounted) {
      setState(() {
        _loadingCases = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loadingMembers = true;
    });

    final memberProvider = context.read<MemberProvider>();
    await memberProvider.loadMembers(org: org);

    if (mounted) {
      setState(() {
        _loadingMembers = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 1, 12, 31);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _dueDate = null;
    });
  }

  List<TaskStatus> _getAllowedStatusTransitions(TaskStatus currentStatus) {
    switch (currentStatus) {
      case TaskStatus.pending:
        return [TaskStatus.inProgress, TaskStatus.completed, TaskStatus.cancelled];
      case TaskStatus.inProgress:
        return [TaskStatus.completed, TaskStatus.cancelled, TaskStatus.pending];
      case TaskStatus.completed:
        return [TaskStatus.cancelled]; // Anti-accidental reopen design
      case TaskStatus.cancelled:
        return [TaskStatus.pending]; // Reopen
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final taskProvider = context.read<TaskProvider>();
    final currentTask = taskProvider.selectedTask;
    if (currentTask == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Determine if we need to clear due date or unassign
    final clearDueDate = currentTask.dueDate != null && _dueDate == null;
    final unassign = currentTask.assigneeId != null && _selectedAssigneeId == null;
    final unlinkCase = currentTask.caseId != null && _selectedCaseId == null;

    final ok = await taskProvider.updateTask(
      org: org,
      taskId: widget.taskId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: _status,
      dueDate: _dueDate,
      assigneeId: _selectedAssigneeId,
      priority: _priority,
      caseId: _selectedCaseId,
      clearDueDate: clearDueDate,
      unassign: unassign,
      unlinkCase: unlinkCase,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = taskProvider.errorMessage;
    });

    if (ok) {
      setState(() {
        _editing = false;
      });
      await _loadDetails(); // Reload to get updated data
    } else {
      final errorMsg = taskProvider.errorMessage ?? 'Failed to update task';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text(
          'This will hide the task from lists but keep it for audit.\n\nYou can\'t undo this from the UI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final taskProvider = context.read<TaskProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await taskProvider.deleteTask(
      org: org,
      taskId: widget.taskId,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = taskProvider.errorMessage;
    });

    if (ok) {
      Navigator.of(context).pop();
    } else {
      final errorMsg = taskProvider.errorMessage ?? 'Failed to delete task';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.selectedTask;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            tooltip: _editing ? 'Cancel edit' : 'Edit',
            onPressed: _saving ? null : () {
              setState(() {
                _editing = !_editing;
                if (!_editing && task != null) {
                  // Reset to original values
                  _titleController.text = task.title;
                  _descriptionController.text = task.description ?? '';
                  _status = task.status;
                  _priority = task.priority;
                  _dueDate = task.dueDate;
                  _selectedCaseId = task.caseId;
                  _selectedAssigneeId = task.assigneeId;
                }
              });
            },
            icon: Icon(_editing ? Icons.close : Icons.edit),
          ),
          IconButton(
            tooltip: 'Delete task',
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: LoadingSpinner())
            : task == null
                ? Center(
                    child: ErrorMessage(
                      message: _error ?? 'Task not found',
                      onRetry: _loadDetails,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: ErrorMessage(
                                  message: _error!,
                                  onRetry: _loadDetails,
                                ),
                              ),
                            AppTextField(
                              label: 'Title',
                              controller: _titleController,
                              enabled: _editing && !_saving,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Title is required';
                                }
                                if (value.trim().length > 200) {
                                  return 'Title must be at most 200 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Description',
                              controller: _descriptionController,
                              enabled: _editing && !_saving,
                              maxLines: 4,
                              validator: (value) {
                                if (value != null && value.length > 2000) {
                                  return 'Description must be at most 2000 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<TaskStatus>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              items: _getAllowedStatusTransitions(task.status)
                                  .map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status.statusDisplayName),
                                );
                              }).toList()
                                ..insert(0, DropdownMenuItem(
                                  value: task.status,
                                  child: Text(task.status.statusDisplayName),
                                )),
                              onChanged: (_editing && !_saving)
                                  ? (value) {
                                      if (value != null) {
                                        setState(() {
                                          _status = value;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<TaskPriority>(
                              value: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                              ),
                              items: TaskPriority.values.map((priority) {
                                return DropdownMenuItem(
                                  value: priority,
                                  child: Text(priority.priorityDisplayName),
                                );
                              }).toList(),
                              onChanged: (_editing && !_saving)
                                  ? (value) {
                                      if (value != null) {
                                        setState(() {
                                          _priority = value;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: (_editing && !_saving) ? _selectDueDate : null,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Due Date (optional)',
                                        suffixIcon: _dueDate != null && _editing && !_saving
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: _clearDueDate,
                                              )
                                            : const Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        _dueDate == null
                                            ? 'No due date'
                                            : _dueDate!.toLocal().toIso8601String().substring(0, 10),
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              value: _selectedCaseId != null && 
                                     !_loadingCases &&
                                     context.read<CaseProvider>().cases.any((c) => c.caseId == _selectedCaseId)
                                  ? _selectedCaseId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Link to Case (optional)',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No case'),
                                ),
                                ...(_loadingCases
                                    ? []
                                    : context.read<CaseProvider>().cases.map((c) {
                                        return DropdownMenuItem(
                                          value: c.caseId,
                                          child: Text(c.title),
                                        );
                                      })),
                              ],
                              onChanged: (_editing && !_saving)
                                  ? (value) {
                                      setState(() {
                                        _selectedCaseId = value;
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              value: _selectedAssigneeId != null && 
                                     !_loadingMembers &&
                                     context.read<MemberProvider>().members.any((m) => m.uid == _selectedAssigneeId)
                                  ? _selectedAssigneeId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Assign to (optional)',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Unassigned'),
                                ),
                                ...(_loadingMembers
                                    ? []
                                    : context.read<MemberProvider>().members.map((m) {
                                        return DropdownMenuItem(
                                          value: m.uid,
                                          child: Text(m.displayName ?? m.email ?? 'Unknown'),
                                        );
                                      })),
                              ],
                              onChanged: (_editing && !_saving)
                                  ? (value) {
                                      setState(() {
                                        _selectedAssigneeId = value;
                                      });
                                    }
                                  : null,
                            ),
                            if (task.caseId != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              InkWell(
                                onTap: () {
                                  context.push(
                                    RouteNames.caseDetails,
                                    extra: task.caseId,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.folder, size: 20),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          'Linked to case: ${_getCaseTitle(task.caseId!)}',
                                          style: AppTypography.bodyMedium,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            if (_editing)
                              PrimaryButton(
                                label: 'Save Changes',
                                onPressed: _saving ? null : _save,
                                isLoading: _saving,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  String _getCaseTitle(String caseId) {
    final cases = context.read<CaseProvider>().cases;
    final caseModel = cases.firstWhere(
      (c) => c.caseId == caseId,
      orElse: () => CaseModel(
        caseId: caseId,
        orgId: '',
        title: 'Unknown Case',
        visibility: CaseVisibility.orgWide,
        status: CaseStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
        updatedBy: '',
      ),
    );
    return caseModel.title;
  }
}
