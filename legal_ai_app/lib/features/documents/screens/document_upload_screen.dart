import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../../common/widgets/error_message.dart' as error_widget;
import '../../home/providers/org_provider.dart';
import '../providers/document_provider.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String? caseId; // Optional case ID to link document to case

  const DocumentUploadScreen({super.key, this.caseId});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  html.File? _selectedFile;
  bool _submitting = false;
  String? _error;
  double? _uploadProgress;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()..accept = '.pdf,.doc,.docx,.txt,.rtf';
    input.click();

    input.onChange.listen((e) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        if (file.size > 10 * 1024 * 1024) {
          // 10MB limit
          setState(() {
            _error = 'File size must be less than 10MB';
          });
          return;
        }

        setState(() {
          _selectedFile = file;
          _nameController.text = file.name;
          _error = null;
        });
      }
    });
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'pdf';
      case 'doc':
        return 'doc';
      case 'docx':
        return 'docx';
      case 'txt':
        return 'txt';
      case 'rtf':
        return 'rtf';
      default:
        return 'pdf';
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      setState(() {
        _error = 'Please select a file to upload';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      setState(() {
        _error = 'No organization selected.';
      });
      return;
    }

    final documentProvider = context.read<DocumentProvider>();

    setState(() {
      _submitting = true;
      _error = null;
      _uploadProgress = 0.0;
    });

    try {
      // Generate document ID for storage path
      final documentId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = _selectedFile!.name;
      final storagePath = 'organizations/${org.orgId}/documents/$documentId/$fileName';

      // Upload to Firebase Storage
      final storage = FirebaseStorage.instance;
      final ref = storage.ref(storagePath);
      
      // Read file as bytes for web
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as Uint8List);
      });
      reader.onError.listen((_) {
        completer.completeError(reader.error ?? 'Failed to read file');
      });
      reader.readAsArrayBuffer(_selectedFile!);
      final fileBytes = await completer.future;
      
      final uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: _selectedFile!.type,
        ),
      );

      // Track upload progress (only update local state, don't trigger provider notifications)
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
        // Don't call setUploadProgress to avoid triggering refresh loops
      });

      // Wait for upload to complete
      await uploadTask;

      // Create document metadata
      // Ensure caseId is properly passed (not empty string)
      final caseIdToLink = widget.caseId != null && widget.caseId!.trim().isNotEmpty
          ? widget.caseId!.trim()
          : null;
      
      debugPrint('DocumentUploadScreen: Uploading document with caseId: $caseIdToLink');
      
      final success = await documentProvider.createDocument(
        org: org,
        name: _nameController.text.trim(),
        storagePath: storagePath,
        fileType: _getFileType(fileName),
        fileSize: _selectedFile!.size,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        caseId: caseIdToLink, // Link to case if provided
      );

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _uploadProgress = null;
        _error = documentProvider.errorMessage;
      });

      if (success) {
        // Clear upload progress in provider
        documentProvider.setUploadProgress(null);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
        // Reduced delay - optimistic update makes document appear immediately
        // Just give a moment for the UI to update
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Show error message clearly
        final errorMsg = documentProvider.errorMessage ?? 'Failed to upload document';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _uploadProgress = null;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Document',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  error_widget.InlineErrorMessage(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                _buildFilePicker(),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Document Name',
                  controller: _nameController,
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
                  label: 'Description (Optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.trim().length > 1000) {
                      return 'Description must be 1000 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_uploadProgress != null) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Uploading: ${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: 'Upload Document',
                  onPressed: _submitting ? null : _uploadFile,
                  isLoading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.upload_file,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFile == null
                        ? 'Select File (PDF, DOC, DOCX, TXT, RTF)'
                        : _selectedFile!.name,
                    style: AppTypography.bodyLarge,
                  ),
                  if (_selectedFile != null)
                    Text(
                      '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (_selectedFile != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                    _nameController.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
