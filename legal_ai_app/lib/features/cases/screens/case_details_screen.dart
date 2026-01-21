import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/case_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../../core/models/client_model.dart';

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
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
      _loadClients();
    });
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

  Future<void> _loadDetails() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      setState(() {
        _loading = false;
        _error = 'No organization selected.';
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Details'),
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
                                title: const Text('Organization-wide'),
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
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
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
}

