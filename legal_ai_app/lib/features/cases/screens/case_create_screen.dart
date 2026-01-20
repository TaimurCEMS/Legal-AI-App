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

  bool _submitting = false;
  String? _error;

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
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _error = caseProvider.error;
    });

    if (success) {
      Navigator.of(context).pop();
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
}

