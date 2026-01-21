import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/client_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/client_provider.dart';
import '../../../core/services/client_service.dart';
import '../../cases/providers/case_provider.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailsScreen({super.key, required this.clientId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  ClientModel? _clientModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
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

    try {
      final clientService = ClientService();
      final model = await clientService.getClient(
        org: org,
        clientId: widget.clientId,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
        _clientModel = model;
        _nameController.text = model.name;
        _emailController.text = model.email ?? '';
        _phoneController.text = model.phone ?? '';
        _notesController.text = model.notes ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final clientProvider = context.read<ClientProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final newName = _nameController.text.trim();
    final ok = await clientProvider.updateClient(
      org: org,
      clientId: widget.clientId,
      name: newName,
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = clientProvider.errorMessage;
    });

    if (ok) {
      // Immediately update client name in all cases that reference this client
      final caseProvider = context.read<CaseProvider>();
      caseProvider.updateClientName(widget.clientId, newName);
      
      setState(() {
        _editing = false;
      });
      // Reload details to get updated data
      await _loadDetails();
      // Navigate back to clients list after successful save
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
        title: const Text('Delete client?'),
        content: const Text(
          'This will hide the client from lists but keep it for audit.\n\nYou cannot delete a client that has associated cases.',
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

    final clientProvider = context.read<ClientProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await clientProvider.deleteClient(
      org: org,
      clientId: widget.clientId,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = clientProvider.errorMessage;
    });

    if (ok) {
      // Navigate back to clients list after successful delete
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Show error dialog if delete failed (e.g., client has cases)
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Client'),
            content: Text(clientProvider.errorMessage ??
                'This client cannot be deleted. Please remove it from all cases first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Client Details'),
        ),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_error != null && _clientModel == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Client Details'),
        ),
        body: Center(
          child: ErrorMessage(
            message: _error!,
            onRetry: _loadDetails,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Details'),
        actions: [
          if (!_editing) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _editing = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorMessage(
                    message: _error!,
                    onRetry: null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  label: 'Name',
                  controller: _nameController,
                  enabled: _editing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length > 200) {
                      return 'Name must be 200 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  enabled: _editing,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final emailRegex = RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      if (value.trim().length > 255) {
                        return 'Email must be 255 characters or less';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  enabled: _editing,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.trim().length > 50) {
                      return 'Phone must be 50 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Notes',
                  controller: _notesController,
                  enabled: _editing,
                  maxLines: 4,
                  validator: (value) {
                    if (value != null && value.trim().length > 1000) {
                      return 'Notes must be 1000 characters or less';
                    }
                    return null;
                  },
                ),
                if (_editing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save',
                          isLoading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _editing = false;
                                    // Reset form to original values
                                    if (_clientModel != null) {
                                      _nameController.text = _clientModel!.name;
                                      _emailController.text =
                                          _clientModel!.email ?? '';
                                      _phoneController.text =
                                          _clientModel!.phone ?? '';
                                      _notesController.text =
                                          _clientModel!.notes ?? '';
                                    }
                                  });
                                },
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
