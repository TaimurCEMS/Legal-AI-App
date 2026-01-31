import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/case_model.dart';
import '../../../core/models/case_participant_model.dart';
import '../../../core/models/client_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/case_participants_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../clients/providers/client_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../home/providers/member_provider.dart';
import '../../home/providers/org_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../notes/providers/note_provider.dart';
import '../../../core/models/note_model.dart';
import '../providers/case_provider.dart';
import 'package:go_router/go_router.dart';

import '../../ai_chat/screens/case_ai_chat_screen.dart';

class CaseDetailsScreen extends StatefulWidget {
  final String caseId;

  const CaseDetailsScreen({super.key, required this.caseId});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  CaseVisibility _visibility = CaseVisibility.orgWide;
  CaseStatus _status = CaseStatus.open;
  String? _selectedClientId;
  bool _loadingClients = false;
  bool _loadingDocuments = false;
  bool _loadingTasks = false;
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<DocumentModel> _caseDocuments = [];
  List<TaskModel> _caseTasks = [];
  List<CaseParticipantModel> _participants = [];
  bool _loadingParticipants = false;
  String? _selectedMemberToAdd;
  final CaseParticipantsService _participantsService = CaseParticipantsService();
  bool _loadingMembers = false;
  bool _loadingNotes = false;
  List<NoteModel> _caseNotes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgressively();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only retry when org becomes available after "No firm selected" (do not retry docs/tasks/notes when empty - that causes an infinite loop)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final org = context.read<OrgProvider>().selectedOrg;
      if (org == null) return;
      if (_error == 'No firm selected.') {
        setState(() {
          _error = null;
          _loading = true;
        });
        _loadProgressively();
      }
    });
  }

  /// Load data progressively - critical data first, then secondary
  Future<void> _loadProgressively() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      setState(() {
        _loading = false;
        _error = 'No firm selected.';
      });
      return;
    }
    
    // Priority 1: Case details (what user came to see)
    await _loadDetails();
    
    // If case failed to load, don't bother loading secondary data
    if (_error != null || !mounted) return;
    
    // Priority 2: Load secondary data with small delays to not overwhelm
    // These run in parallel but staggered - pass org to avoid race conditions
    _loadDocuments(org);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    _loadTasks(org);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    _loadNotes(org);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    // Priority 3: Load less critical data
    _loadClients(); // Only needed if editing
    _loadParticipants();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loadingClients = true;
    });

    final clientProvider = context.read<ClientProvider>();
    await clientProvider.loadClients(org: org);

    if (mounted) {
      setState(() {
        _loadingClients = false;
      });
    }
  }

  Future<void> _loadDocuments(OrgModel org) async {
    if (_loadingDocuments || !mounted) return; // Prevent concurrent loads

    setState(() {
      _loadingDocuments = true;
    });

    try {
      debugPrint('CaseDetailsScreen._loadDocuments: Starting for caseId=${widget.caseId}');
      final documentProvider = context.read<DocumentProvider>();
      await documentProvider.loadDocuments(
        org: org,
        caseId: widget.caseId,
      );

      debugPrint('CaseDetailsScreen._loadDocuments: Provider has ${documentProvider.documents.length} documents');
      
      if (mounted) {
        // Filter documents to only show those linked to this case
        final caseDocs = documentProvider.documents
            .where((doc) => doc.caseId == widget.caseId)
            .toList();
        debugPrint('CaseDetailsScreen._loadDocuments: Filtered to ${caseDocs.length} docs for caseId=${widget.caseId}');
        setState(() {
          _caseDocuments = caseDocs;
        });
      }
    } catch (e) {
      debugPrint('CaseDetailsScreen._loadDocuments: Error - $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDocuments = false;
        });
      }
    }
  }

  Future<void> _loadTasks(OrgModel org) async {
    if (_loadingTasks || !mounted) return;

    setState(() {
      _loadingTasks = true;
    });

    try {
      debugPrint('CaseDetailsScreen._loadTasks: Starting for caseId=${widget.caseId}');
      final taskProvider = context.read<TaskProvider>();
      await taskProvider.loadTasks(
        org: org,
        caseId: widget.caseId,
      );

      debugPrint('CaseDetailsScreen._loadTasks: Provider has ${taskProvider.tasks.length} tasks');

      if (mounted) {
        // Filter tasks to only show those linked to this case
        final caseTasks = taskProvider.tasks
            .where((task) => task.caseId == widget.caseId)
            .toList();
        debugPrint('CaseDetailsScreen._loadTasks: Filtered to ${caseTasks.length} tasks for caseId=${widget.caseId}');
        setState(() {
          _caseTasks = caseTasks;
        });
      }
    } catch (e) {
      debugPrint('CaseDetailsScreen._loadTasks: Error - $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingTasks = false;
        });
      }
    }
  }

  Future<void> _loadNotes(OrgModel org) async {
    if (_loadingNotes || !mounted) return;

    setState(() {
      _loadingNotes = true;
    });

    try {
      final noteProvider = context.read<NoteProvider>();
      await noteProvider.loadNotes(
        orgId: org.orgId,
        caseId: widget.caseId,
        refresh: true,
      );

      if (mounted) {
        setState(() {
          _loadingNotes = false;
          _caseNotes = noteProvider.notes;
        });
      }
    } catch (e) {
      debugPrint('CaseDetailsScreen._loadNotes: Error loading notes: $e');
      if (mounted) {
        setState(() {
          _loadingNotes = false;
        });
      }
    }
  }

  Future<void> _loadParticipants() async {
    if (_loadingParticipants) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final caseProvider = context.read<CaseProvider>();
    final caseModel = caseProvider.selectedCase;

    // Only load participants for PRIVATE cases
    if (caseModel == null || caseModel.visibility != CaseVisibility.private) {
      setState(() {
        _participants = [];
        _loadingParticipants = false;
      });
      return;
    }

    setState(() {
      _loadingParticipants = true;
    });

    try {
      final participants = await _participantsService.listParticipants(
        org: org,
        caseId: widget.caseId,
      );

      if (mounted) {
        setState(() {
          _participants = participants;
          _loadingParticipants = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingParticipants = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_loadingMembers) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loadingMembers = true;
    });

    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadMembers(org: org);
    } finally {
      if (mounted) {
        setState(() {
          _loadingMembers = false;
        });
      }
    }
  }

  Future<void> _addParticipant(String participantUid) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    try {
      await _participantsService.addParticipant(
        org: org,
        caseId: widget.caseId,
        participantUid: participantUid,
      );

      await _loadParticipants();

      if (mounted) {
        setState(() {
          _selectedMemberToAdd = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _removeParticipant(String participantUid) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    try {
      await _participantsService.removeParticipant(
        org: org,
        caseId: widget.caseId,
        participantUid: participantUid,
      );

      await _loadParticipants();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDetails() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      setState(() {
        _loading = false;
        _error = 'No firm selected.';
      });
      return;
    }

    final caseProvider = context.read<CaseProvider>();
    final ok = await caseProvider.loadCaseDetails(
      org: org,
      caseId: widget.caseId,
    );

    if (!mounted) return;

    final model = caseProvider.selectedCase;
    if (!ok || model == null) {
      setState(() {
        _loading = false;
        _error = caseProvider.error ?? 'Failed to load case.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _error = null;
      _titleController.text = model.title;
      _descriptionController.text = model.description ?? '';
      _visibility = model.visibility;
      _status = model.status;
      _selectedClientId = model.clientId;
    });

    // Once case details are loaded, refresh participants for PRIVATE cases
    await _loadParticipants();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final caseProvider = context.read<CaseProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await caseProvider.updateCase(
      org: org,
      caseId: widget.caseId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      visibility: _visibility,
      status: _status,
      clientId: _selectedClientId,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = caseProvider.error;
    });

    if (ok) {
      setState(() {
        _editing = false;
      });
      // Navigate back to cases list after successful save
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _delete() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete case?'),
        content: const Text(
          'This will hide the case from lists but keep it for audit.\n\nYou can\'t undo this from the UI.',
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

    final caseProvider = context.read<CaseProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await caseProvider.deleteCase(
      org: org,
      caseId: widget.caseId,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = caseProvider.error;
    });

    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matter Details'),
        actions: [
          IconButton(
            tooltip: _editing ? 'Cancel edit' : 'Edit',
            onPressed: () {
              setState(() {
                _editing = !_editing;
              });
            },
            icon: Icon(_editing ? Icons.close : Icons.edit),
          ),
          IconButton(
            tooltip: 'Delete case',
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: LoadingSpinner())
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
                        Text(
                          'Client (optional)',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildClientDropdown(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Visibility',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<CaseVisibility>(
                                title: const Text('Firm-wide'),
                                value: CaseVisibility.orgWide,
                                groupValue: _visibility,
                                onChanged: _editing && !_saving
                                    ? (v) {
                                        if (v != null) {
                                          setState(() {
                                            _visibility = v;
                                          });
                                        }
                                      }
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<CaseVisibility>(
                                title: const Text('Private'),
                                value: CaseVisibility.private,
                                groupValue: _visibility,
                                onChanged: _editing && !_saving
                                    ? (v) {
                                        if (v != null) {
                                          setState(() {
                                            _visibility = v;
                                          });
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Status',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<CaseStatus>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(
                              value: CaseStatus.open,
                              child: Text('Open'),
                            ),
                            DropdownMenuItem(
                              value: CaseStatus.closed,
                              child: Text('Closed'),
                            ),
                            DropdownMenuItem(
                              value: CaseStatus.archived,
                              child: Text('Archived'),
                            ),
                          ],
                          onChanged: _editing && !_saving
                              ? (v) {
                                  if (v != null) {
                                    setState(() {
                                      _status = v;
                                    });
                                  }
                                }
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_editing)
                          PrimaryButton(
                            label: 'Save changes',
                            isLoading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildParticipantsSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildDocumentsSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildTasksSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildNotesSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildAIResearchSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildAIDraftingSection(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documentProvider = context.watch<DocumentProvider>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: () {
                context.push('${RouteNames.documentUpload}?caseId=${widget.caseId}');
              },
              icon: const Icon(Icons.add),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Show upload progress if document is being uploaded
        if (documentProvider.uploadProgress != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Uploading document... ${(documentProvider.uploadProgress! * 100).toStringAsFixed(0)}%',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_loadingDocuments && documentProvider.uploadProgress == null)
          const Center(child: CircularProgressIndicator())
        else if (_caseDocuments.isEmpty && documentProvider.uploadProgress == null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'No documents linked to this case',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ..._caseDocuments.map((doc) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    doc.fileTypeIcon,
                    size: 32,
                  ),
                  title: Text(doc.name),
                  subtitle: Text(
                    '${doc.fileSizeFormatted} • ${doc.fileType.toUpperCase()}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      context.push(
                        '${RouteNames.documentDetails}/${doc.documentId}',
                      );
                    },
                  ),
                  onTap: () {
                    context.push(
                      '${RouteNames.documentDetails}/${doc.documentId}',
                    );
                  },
                ),
              )),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    final caseProvider = context.watch<CaseProvider>();
    final memberProvider = context.watch<MemberProvider>();
    final caseModel = caseProvider.selectedCase;

    if (caseModel == null) {
      return const SizedBox.shrink();
    }

    // ORG_WIDE cases: simple info message
    if (caseModel.visibility == CaseVisibility.orgWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People with access',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All members of this firm can see this matter.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // PRIVATE cases
    MemberModel? currentUser;
    try {
      currentUser = memberProvider.members.firstWhere((m) => m.isCurrentUser);
    } catch (_) {
      currentUser = null;
    }
    final bool isCreator =
        currentUser != null && currentUser.uid == caseModel.createdBy;
    final bool isAdmin = currentUser?.role == 'ADMIN';
    final bool canManageParticipants = isCreator || isAdmin;

    final participantsByUid = {
      for (final p in _participants) p.uid: p,
    };

    final ownerDisplayName = currentUser != null && isCreator
        ? '${currentUser.displayLabel} (You, Owner)'
        : 'Owner (${caseModel.createdBy.substring(0, 8)}...)';

    final availableMembers = memberProvider.members;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'People with access',
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(ownerDisplayName),
            subtitle: const Text('Matter owner'),
          ),
        ),
        if (_loadingParticipants)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_participants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'No additional participants. Only you can see this private case.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ..._participants.map(
            (participant) {
              MemberModel? member;
              try {
                member = availableMembers
                    .firstWhere((m) => m.uid == participant.uid);
              } catch (_) {
                member = null;
              }
              final label = member?.displayLabel ??
                  participant.displayName ??
                  participant.email ??
                  participant.uid;
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(label),
                  subtitle: const Text('Participant'),
                  trailing: canManageParticipants &&
                          participant.uid != caseModel.createdBy
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Remove from case',
                          onPressed: () {
                            _removeParticipant(participant.uid);
                          },
                        )
                      : null,
                ),
              );
            },
          ),
        if (canManageParticipants) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Add person',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMemberToAdd,
                  decoration: const InputDecoration(
                    hintText: 'Select a team member',
                  ),
                  items: [
                    ...availableMembers
                        .where((member) =>
                            member.uid != caseModel.createdBy &&
                            !participantsByUid.containsKey(member.uid))
                        .map(
                          (member) => DropdownMenuItem<String>(
                            value: member.uid,
                            child: Text(member.displayLabel),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMemberToAdd = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PrimaryButton(
                label: 'Add',
                onPressed: _selectedMemberToAdd == null
                    ? null
                    : () {
                        final uid = _selectedMemberToAdd;
                        if (uid != null) {
                          _addParticipant(uid);
                        }
                      },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTasksSection() {
    final taskProvider = context.watch<TaskProvider>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: () {
                context.push('${RouteNames.taskCreate}?caseId=${widget.caseId}');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loadingTasks)
          const Center(child: CircularProgressIndicator())
        else if (_caseTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'No tasks linked to this case',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ..._caseTasks.map((task) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    _getStatusIcon(task.status),
                    color: _getStatusColor(task.status),
                    size: 32,
                  ),
                  title: Text(task.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.description != null && task.description!.isNotEmpty)
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (task.assigneeName != null)
                            Text(
                              task.assigneeName!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (task.dueDate != null) ...[
                            if (task.assigneeName != null)
                              const SizedBox(width: AppSpacing.sm),
                            Icon(
                              task.isOverdue
                                  ? Icons.warning
                                  : task.isDueSoon
                                      ? Icons.schedule
                                      : Icons.calendar_today,
                              size: 14,
                              color: task.isOverdue
                                  ? Colors.red
                                  : task.isDueSoon
                                      ? Colors.orange
                                      : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              task.dueDate!.toLocal().toIso8601String().substring(0, 10),
                              style: AppTypography.bodySmall.copyWith(
                                color: task.isOverdue
                                    ? Colors.red
                                    : task.isDueSoon
                                        ? Colors.orange
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      context.push(
                        RouteNames.taskDetails,
                        extra: task.taskId,
                      );
                    },
                  ),
                  onTap: () {
                    context.push(
                      RouteNames.taskDetails,
                      extra: task.taskId,
                    );
                  },
                ),
              )),
      ],
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.pending;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildNotesSection() {
    final caseProvider = context.watch<CaseProvider>();
    final caseModel = caseProvider.selectedCase;
    final caseName = caseModel?.title ?? 'Matter';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notes',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: () {
                context.push('${RouteNames.noteCreate}?caseId=${widget.caseId}&caseName=${Uri.encodeComponent(caseName)}');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loadingNotes)
          const Center(child: CircularProgressIndicator())
        else if (_caseNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'No notes for this case',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ..._caseNotes.take(3).map((note) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    note.isPinned ? Icons.push_pin : _getCategoryIcon(note.category),
                    color: note.isPinned ? Colors.orange : AppColors.textSecondary,
                    size: 24,
                  ),
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${note.category.displayLabel} • ${_formatRelativeTime(note.updatedAt)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('${RouteNames.noteDetails}/${note.noteId}');
                  },
                ),
              )),
        if (_caseNotes.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Center(
              child: TextButton(
                onPressed: () {
                  context.push('${RouteNames.noteList}?caseId=${widget.caseId}&caseName=${Uri.encodeComponent(caseName)}');
                },
                child: Text('View all ${_caseNotes.length} notes'),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getCategoryIcon(NoteCategory category) {
    switch (category) {
      case NoteCategory.clientMeeting:
        return Icons.people_outline;
      case NoteCategory.research:
        return Icons.search;
      case NoteCategory.strategy:
        return Icons.lightbulb_outline;
      case NoteCategory.internal:
        return Icons.lock_outline;
      case NoteCategory.other:
        return Icons.note_outlined;
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildClientDropdown() {
    final clientProvider = context.watch<ClientProvider>();

    if (_loadingClients) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final clients = clientProvider.clients;

    return DropdownButtonFormField<String>(
      value: _selectedClientId,
      decoration: const InputDecoration(
        hintText: 'Select a client (optional)',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('No client'),
        ),
        ...clients.map((client) {
          return DropdownMenuItem<String>(
            value: client.clientId,
            child: Text(client.name),
          );
        }),
      ],
      onChanged: _editing && !_saving
          ? (value) {
              setState(() {
                _selectedClientId = value;
              });
            }
          : null,
    );
  }

  Widget _buildAIResearchSection() {
    final caseProvider = context.watch<CaseProvider>();
    final caseModel = caseProvider.selectedCase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Research',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CaseAIChatScreen(
                      caseId: widget.caseId,
                      caseTitle: caseModel?.title ?? 'Matter',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.smart_toy, size: 18),
              label: const Text('Open AI Chat'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CaseAIChatScreen(
                    caseId: widget.caseId,
                    caseTitle: caseModel?.title ?? 'Matter',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat with your documents',
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ask questions about case documents and get AI-powered answers with citations.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIDraftingSection() {
    final caseProvider = context.watch<CaseProvider>();
    final caseModel = caseProvider.selectedCase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Drafting',
              style: AppTypography.titleLarge,
            ),
            TextButton.icon(
              onPressed: () {
                final title = caseModel?.title ?? 'Matter';
                context.push('${RouteNames.drafts}?caseId=${Uri.encodeComponent(widget.caseId)}&caseTitle=${Uri.encodeComponent(title)}');
              },
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Open Drafting'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: InkWell(
            onTap: () {
              final title = caseModel?.title ?? 'Matter';
              context.push('${RouteNames.drafts}?caseId=${Uri.encodeComponent(widget.caseId)}&caseTitle=${Uri.encodeComponent(title)}');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_note,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate legal drafts from templates',
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Choose a template, provide variables, and generate a draft using case documents for context. Export to DOCX/PDF as a Document.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

