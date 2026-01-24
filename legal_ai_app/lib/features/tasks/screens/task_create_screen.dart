import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/task_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../../home/providers/org_provider.dart';
import '../providers/task_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../../core/models/case_model.dart';
import '../../home/providers/member_provider.dart';
import '../../../core/models/member_model.dart';

class TaskCreateScreen extends StatefulWidget {
  final String? caseId; // Optional case ID if creating from case details

  const TaskCreateScreen({super.key, this.caseId});

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TaskStatus _status = TaskStatus.pending;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  String? _selectedCaseId;
  String? _selectedAssigneeId;
  bool _loadingCases = false;
  bool _loadingMembers = false;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCaseId = widget.caseId; // Pre-select case if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCases();
      _loadMembers();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      setState(() {
        _error = 'No organization selected.';
      });
      return;
    }

    final taskProvider = context.read<TaskProvider>();

    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await taskProvider.createTask(
      org: org,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: _status,
      dueDate: _dueDate,
      assigneeId: _selectedAssigneeId,
      priority: _priority,
      caseId: _selectedCaseId,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _error = taskProvider.errorMessage;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // Reduced delay from 800ms to 300ms for faster navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      final errorMsg = taskProvider.errorMessage ?? 'Failed to create task';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Task',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Title',
                  controller: _titleController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    if (value.trim().length > 200) {
                      return 'Title must be 200 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Description (optional)',
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: (value) {
                    if (value != null && value.trim().length > 2000) {
                      return 'Description must be 2000 characters or less';
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
                  items: TaskStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.statusDisplayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _status = value;
                      });
                    }
                  },
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
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _priority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _selectDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date (optional)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _dueDate == null
                          ? 'Select date'
                          : _dueDate!.toLocal().toIso8601String().substring(0, 10),
                      style: AppTypography.bodyMedium,
                    ),
                  ),
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
                  onChanged: (value) {
                    setState(() {
                      _selectedCaseId = value;
                    });
                  },
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
                  onChanged: (value) {
                    setState(() {
                      _selectedAssigneeId = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AppTypography.bodyMedium.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: 'Create Task',
                  onPressed: _submitting ? null : _submit,
                  isLoading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
