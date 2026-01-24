import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/case_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../../core/models/client_model.dart';
import '../../documents/providers/document_provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/routing/route_names.dart';
import 'package:go_router/go_router.dart';

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
  bool _isLoadingDocumentsFromProvider = false; // Guard to prevent infinite loop
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<DocumentModel> _caseDocuments = [];

  DocumentProvider? _documentProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
      _loadClients();
      _loadDocuments();
      
      // Listen to document provider changes for auto-refresh
      // Only listen after initial load to prevent loops
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _documentProvider = context.read<DocumentProvider>();
          _documentProvider!.addListener(_onDocumentsChanged);
        }
      });
    });
  }

  @override
  void dispose() {
    _documentProvider?.removeListener(_onDocumentsChanged);
    _documentsRefreshDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Timer? _documentsRefreshDebounce;

  void _onDocumentsChanged() {
    if (!mounted || _isLoadingDocumentsFromProvider || _loadingDocuments) return;
    
    final documentProvider = context.read<DocumentProvider>();
    
    // Don't reload if:
    // 1. Provider is currently loading (might be upload progress or initial load)
    // 2. Upload is in progress (uploadProgress is not null)
    // 3. Provider was loading documents for a different case (ignore changes from other cases)
    if (documentProvider.isLoading || 
        documentProvider.uploadProgress != null ||
        documentProvider.lastLoadedCaseId != widget.caseId) {
      return;
    }
    
    // Only reload if this change is relevant to our case
    // Reduced debounce from 800ms to 300ms for faster updates
    _documentsRefreshDebounce?.cancel();
    _documentsRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && 
          !_loadingDocuments && 
          !_isLoadingDocumentsFromProvider &&
          !documentProvider.isLoading &&
          documentProvider.uploadProgress == null &&
          documentProvider.lastLoadedCaseId == widget.caseId) {
        _loadDocuments();
      }
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

  Future<void> _loadDocuments() async {
    if (_loadingDocuments) return; // Prevent concurrent loads
    
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _loadingDocuments = true;
    });

    try {
      _isLoadingDocumentsFromProvider = true; // Set guard to prevent callback loop
      final documentProvider = context.read<DocumentProvider>();
      await documentProvider.loadDocuments(
        org: org,
        caseId: widget.caseId,
      );

      if (mounted) {
        // Filter documents to only show those linked to this case
        final caseDocs = documentProvider.documents
            .where((doc) => doc.caseId == widget.caseId)
            .toList();
        setState(() {
          _loadingDocuments = false;
          _caseDocuments = caseDocs;
        });
      }
    } finally {
      _isLoadingDocumentsFromProvider = false; // Clear guard
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
                        const SizedBox(height: AppSpacing.xl),
                        _buildDocumentsSection(),
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

