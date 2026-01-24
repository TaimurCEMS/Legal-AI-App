import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../home/providers/org_provider.dart';
import '../providers/case_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../../core/models/client_model.dart';

class CaseCreateScreen extends StatefulWidget {
  const CaseCreateScreen({super.key});

  @override
  State<CaseCreateScreen> createState() => _CaseCreateScreenState();
}

class _CaseCreateScreenState extends State<CaseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  CaseVisibility _visibility = CaseVisibility.orgWide;
  String? _selectedClientId;
  bool _loadingClients = false;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    final caseProvider = context.read<CaseProvider>();

    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await caseProvider.createCase(
      org: org,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      visibility: _visibility,
      clientId: _selectedClientId,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _error = caseProvider.error;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      Navigator.of(context).pop();
    } else {
      // Show error message
      final errorMsg = caseProvider.error ?? 'Failed to create case';
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
        title: const Text('New Case'),
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
                  'Create Case',
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
                      return 'Title must be at most 200 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Description',
                  controller: _descriptionController,
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
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _visibility = v;
                            });
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<CaseVisibility>(
                        title: const Text('Private'),
                        value: CaseVisibility.private,
                        groupValue: _visibility,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _visibility = v;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ErrorMessage(
                      message: _error!,
                      onRetry: _submit,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Create',
                        isLoading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
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
      onChanged: (value) {
        setState(() {
          _selectedClientId = value;
        });
      },
    );
  }
}

