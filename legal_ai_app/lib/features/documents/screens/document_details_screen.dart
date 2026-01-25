import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/models/document_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../../common/widgets/error_message.dart' as error_widget;
import '../../common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/document_provider.dart';
import '../../../core/services/document_service.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailsScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  bool _downloading = false;
  bool _extracting = false;
  bool _showFullText = false;
  String? _error;
  DocumentModel? _documentModel;

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
    _descriptionController.dispose();
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
      final documentService = DocumentService();
      final model = await documentService.getDocument(
        org: org,
        documentId: widget.documentId,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
        _documentModel = model;
        _nameController.text = model.name;
        _descriptionController.text = model.description ?? '';
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

    final documentProvider = context.read<DocumentProvider>();

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await documentProvider.updateDocument(
      org: org,
      documentId: widget.documentId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = documentProvider.errorMessage;
    });

    if (ok) {
      setState(() {
        _editing = false;
      });
      await _loadDetails();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _download() async {
    if (_documentModel == null || _downloading) {
      debugPrint('DocumentDetailsScreen._download: Skipping - model: ${_documentModel != null}, downloading: $_downloading');
      return;
    }

    debugPrint('DocumentDetailsScreen._download: Starting download for ${_documentModel!.name}');
    setState(() {
      _downloading = true;
    });

    try {
      String? downloadUrl = _documentModel!.downloadUrl;
      debugPrint('DocumentDetailsScreen._download: Initial downloadUrl: ${downloadUrl != null ? "exists" : "null"}');

      // If no download URL, try to generate one from Storage
      if (downloadUrl == null || downloadUrl.isEmpty) {
        debugPrint('DocumentDetailsScreen._download: Generating URL from Storage path: ${_documentModel!.storagePath}');
        final storage = FirebaseStorage.instance;
        final ref = storage.ref(_documentModel!.storagePath);
        
        // Get download URL (this works for web without signed URLs)
        downloadUrl = await ref.getDownloadURL();
        debugPrint('DocumentDetailsScreen._download: Generated URL: ${downloadUrl != null ? "success" : "failed"}');
        
        // Update the document model with the new URL
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          setState(() {
            _documentModel = DocumentModel(
              documentId: _documentModel!.documentId,
              orgId: _documentModel!.orgId,
              caseId: _documentModel!.caseId,
              name: _documentModel!.name,
              description: _documentModel!.description,
              fileType: _documentModel!.fileType,
              fileSize: _documentModel!.fileSize,
              storagePath: _documentModel!.storagePath,
              downloadUrl: downloadUrl,
              createdAt: _documentModel!.createdAt,
              updatedAt: _documentModel!.updatedAt,
              createdBy: _documentModel!.createdBy,
              updatedBy: _documentModel!.updatedBy,
              deletedAt: _documentModel!.deletedAt,
            );
          });
        }
      }

      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        debugPrint('DocumentDetailsScreen._download: Opening URL in new tab');
        html.window.open(downloadUrl, '_blank');
      } else {
        debugPrint('DocumentDetailsScreen._download: No download URL available');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate download URL. Please try again later.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('DocumentDetailsScreen._download: Error - $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download document: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<void> _extractText() async {
    if (_documentModel == null || _extracting) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    setState(() {
      _extracting = true;
      _error = null;
    });

    try {
      final documentService = DocumentService();
      await documentService.extractDocument(
        org: org,
        documentId: widget.documentId,
        forceReExtract: _documentModel!.extractionFailed,
      );

      // Update local state to show pending
      if (mounted) {
        setState(() {
          _documentModel = _documentModel!.copyWithExtractionStatus(
            extractionStatus: 'pending',
            extractionError: null,
          );
          _extracting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text extraction started. This may take a few moments.'),
            duration: Duration(seconds: 3),
          ),
        );

        // Poll for status updates
        _pollExtractionStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pollExtractionStatus() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null || _documentModel == null) return;

    // Poll every 2 seconds for up to 2 minutes
    const maxAttempts = 60;
    const pollInterval = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      if (!mounted) return;

      // Stop polling if document is no longer in extracting state
      if (!_documentModel!.isExtracting) return;

      try {
        final documentService = DocumentService();
        final status = await documentService.getExtractionStatus(
          org: org,
          documentId: widget.documentId,
        );

        if (!mounted) return;

        final newStatus = status['extractionStatus'] as String? ?? 'none';

        if (newStatus == 'completed' || newStatus == 'failed') {
          // Reload the full document to get extracted text
          await _loadDetails();
          return;
        }

        // Update status locally
        setState(() {
          _documentModel = _documentModel!.copyWithExtractionStatus(
            extractionStatus: newStatus,
          );
        });
      } catch (e) {
        debugPrint('Error polling extraction status: $e');
        // Continue polling on error
      }
    }

    // Timeout - reload to get final state
    if (mounted) {
      await _loadDetails();
    }
  }

  Future<void> _delete() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final documentProvider = context.read<DocumentProvider>();

    setState(() {
      _saving = true;
      _downloading = false; // Reset download state
      _error = null;
    });

    try {
      final ok = await documentProvider.deleteDocument(
        org: org,
        documentId: widget.documentId,
      );

      if (!mounted) return;

      if (ok) {
        // Show success message briefly before navigating back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              duration: Duration(seconds: 1),
            ),
          );
          // Small delay for user to see the message
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        setState(() {
          _saving = false;
          _error = documentProvider.errorMessage ?? 'Failed to delete document';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Details')),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_error != null && _documentModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Details')),
        body: Center(
          child: error_widget.ErrorMessage(
            message: _error!,
            onRetry: _loadDetails,
          ),
        ),
      );
    }

    if (_documentModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Details')),
        body: const Center(child: Text('Document not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _editing = true;
                });
              },
            ),
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
                  error_widget.InlineErrorMessage(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_editing) ...[
                  AppTextField(
                    label: 'Document Name',
                    controller: _nameController,
                    enabled: _editing,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Document name is required';
                      }
                      if (value.trim().length > 200) {
                        return 'Document name must be 200 characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Description',
                    controller: _descriptionController,
                    enabled: _editing,
                    maxLines: 3,
                    validator: (value) {
                      if (value != null && value.trim().length > 1000) {
                        return 'Description must be 1000 characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save',
                          onPressed: _saving ? null : _save,
                          isLoading: _saving,
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
                                    _nameController.text = _documentModel!.name;
                                    _descriptionController.text =
                                        _documentModel!.description ?? '';
                                  });
                                },
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildInfoCard('Name', _documentModel!.name),
                  const SizedBox(height: AppSpacing.sm),
                  if (_documentModel!.description != null &&
                      _documentModel!.description!.isNotEmpty)
                    _buildInfoCard('Description', _documentModel!.description!),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInfoCard('File Type', _documentModel!.fileType.toUpperCase()),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInfoCard('File Size', _documentModel!.fileSizeFormatted),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Text Extraction Section (Slice 6a)
                  _buildExtractionSection(),
                  const SizedBox(height: AppSpacing.md),
                  
                  PrimaryButton(
                    label: 'Download Document',
                    onPressed: _downloading ? null : _download,
                    icon: Icons.download,
                    isLoading: _downloading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Delete Document'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  /// Build the text extraction section (Slice 6a)
  Widget _buildExtractionSection() {
    final doc = _documentModel!;
    
    // Check if file type supports extraction
    if (!doc.isExtractable) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_snippet, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Text Extraction',
                  style: AppTypography.titleMedium,
                ),
                const Spacer(),
                _buildExtractionStatusBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Show different content based on extraction status
            if (doc.extractionStatus == 'none') ...[
              Text(
                'Extract text from this document to enable AI features.',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _extracting ? null : _extractText,
                icon: _extracting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_extracting ? 'Starting...' : 'Extract Text'),
              ),
            ] else if (doc.isExtracting) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    doc.extractionStatus == 'pending' 
                        ? 'Extraction queued...'
                        : 'Extracting text...',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ] else if (doc.extractionFailed) ...[
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      doc.extractionError ?? 'Extraction failed',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _extracting ? null : _extractText,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Extraction'),
              ),
            ] else if (doc.extractionCompleted) ...[
              // Show extraction stats
              Row(
                children: [
                  if (doc.pageCount != null) ...[
                    _buildStatChip(Icons.description, '${doc.pageCount} pages'),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (doc.wordCount != null) ...[
                    _buildStatChip(Icons.text_fields, '${doc.wordCount} words'),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Show extracted text preview
              if (doc.hasExtractedText) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showFullText
                            ? doc.extractedText!
                            : _truncateText(doc.extractedText!, 500),
                        style: AppTypography.bodySmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: _showFullText ? null : 10,
                        overflow: _showFullText ? null : TextOverflow.fade,
                      ),
                      if (doc.extractedText!.length > 500) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showFullText = !_showFullText;
                            });
                          },
                          child: Text(_showFullText ? 'Show Less' : 'Show More'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractionStatusBadge() {
    final doc = _documentModel!;
    
    Color backgroundColor;
    Color textColor;
    String label;
    
    switch (doc.extractionStatus) {
      case 'completed':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Completed';
        break;
      case 'pending':
      case 'processing':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'In Progress';
        break;
      case 'failed':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Failed';
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = 'Not Extracted';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: textColor),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
