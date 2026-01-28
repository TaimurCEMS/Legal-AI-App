import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../home/providers/org_provider.dart';
import '../providers/draft_provider.dart';
import '../../../core/models/draft_model.dart';

class DraftEditorScreen extends StatefulWidget {
  final String draftId;
  final String caseId;
  final String caseTitle;

  const DraftEditorScreen({
    super.key,
    required this.draftId,
    required this.caseId,
    required this.caseTitle,
  });

  @override
  State<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends State<DraftEditorScreen> {
  final _promptController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // Local editable variables state (simple key/value map)
  final List<MapEntry<TextEditingController, TextEditingController>> _varControllers = [];

  bool _loading = true;
  bool _isLoading = false;
  String? _loadedOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If org becomes available after navigation, auto-load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  @override
  void dispose() {
    // Stop any in-flight polling if user navigates away.
    try {
      context.read<DraftProvider>().cancelActivePolling();
    } catch (_) {
      // ignore: provider may not be available during teardown
    }
    _promptController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    for (final pair in _varControllers) {
      pair.key.dispose();
      pair.value.dispose();
    }
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) {
      return;
    }
    if (_isLoading) return;
    if (_loadedOrgId == org.orgId && !_loading) return;

    _isLoading = true;

    final draftProvider = context.read<DraftProvider>();
    final draft = await draftProvider.loadDraft(
      org: org,
      caseId: widget.caseId,
      draftId: widget.draftId,
    );

    if (!mounted) return;

    if (draft != null) {
      _hydrateFromDraft(draft);
    }

    _loadedOrgId = org.orgId;
    _isLoading = false;
    setState(() => _loading = false);
  }

  void _hydrateFromDraft(DraftModel draft) {
    _titleController.text = draft.title;
    _promptController.text = draft.prompt ?? '';
    _contentController.text = draft.content;

    // Reset variable controllers
    for (final pair in _varControllers) {
      pair.key.dispose();
      pair.value.dispose();
    }
    _varControllers.clear();

    final entries = draft.variables.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      _varControllers.add(
        MapEntry(TextEditingController(text: e.key), TextEditingController(text: e.value)),
      );
    }

    if (_varControllers.isEmpty) {
      _addVariableRow();
    }
  }

  void _addVariableRow() {
    _varControllers.add(
      MapEntry(TextEditingController(), TextEditingController()),
    );
    setState(() {});
  }

  Map<String, String> _collectVariables() {
    final vars = <String, String>{};
    for (final pair in _varControllers) {
      final key = pair.key.text.trim();
      final value = pair.value.text.trim();
      if (key.isEmpty) continue;
      vars[key] = value;
    }
    return vars;
  }

  Future<void> _save() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final draftProvider = context.read<DraftProvider>();
    final updated = await draftProvider.updateDraft(
      org: org,
      caseId: widget.caseId,
      draftId: widget.draftId,
      title: _titleController.text.trim(),
      content: _contentController.text,
      variables: _collectVariables(),
      createVersion: true,
      versionNote: 'Manual save',
    );

    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved')),
    );
  }

  Future<void> _generate() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final draftProvider = context.read<DraftProvider>();
    final generated = await draftProvider.generateDraftAndPoll(
      org: org,
      caseId: widget.caseId,
      draftId: widget.draftId,
      prompt: _promptController.text.trim().isEmpty ? null : _promptController.text.trim(),
      variables: _collectVariables(),
    );

    if (!mounted || generated == null) return;
    _hydrateFromDraft(generated);
  }

  Future<void> _export() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Export'),
                subtitle: Text('Save this draft as a Document'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('DOCX'),
                onTap: () => Navigator.of(context).pop('docx'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || format == null) return;

    final draftProvider = context.read<DraftProvider>();
    final documentId = await draftProvider.exportDraft(
      org: org,
      caseId: widget.caseId,
      draftId: widget.draftId,
      format: format,
    );

    if (!mounted || documentId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exported to Documents')),
    );

    context.push('${RouteNames.documentDetails}/$documentId');
  }

  Future<void> _delete() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This will hide the draft (soft delete).'),
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

    if (confirmed != true || !mounted) return;

    final draftProvider = context.read<DraftProvider>();
    final ok = await draftProvider.deleteDraft(
      org: org,
      caseId: widget.caseId,
      draftId: widget.draftId,
    );

    if (!mounted || !ok) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    final draftProvider = context.watch<DraftProvider>();

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Draft Editor')),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Draft Editor')),
        body: const Center(child: LoadingSpinner()),
      );
    }

    final draft = draftProvider.selectedDraft;
    final isBusy = draftProvider.isWorking;

    return Scaffold(
      appBar: AppBar(
        title: Text('Draft • ${widget.caseTitle}'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: isBusy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListView(
            children: [
              if (draftProvider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ErrorMessage(
                    message: draftProvider.error!,
                    onRetry: _ensureLoaded,
                  ),
                ),
              if (draft != null) ...[
                Text(
                  'Status: ${draft.status.displayLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (draft.error != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    draft.error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.red),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Title',
                controller: _titleController,
                enabled: !isBusy,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  if (v.trim().length > 200) return 'Max 200 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Variables', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              ..._varControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final pair = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          label: 'Key',
                          controller: pair.key,
                          enabled: !isBusy,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          label: 'Value',
                          controller: pair.value,
                          enabled: !isBusy,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: isBusy
                            ? null
                            : () {
                                pair.key.dispose();
                                pair.value.dispose();
                                _varControllers.removeAt(index);
                                setState(() {});
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isBusy ? null : _addVariableRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add variable'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'AI instructions (optional)',
                controller: _promptController,
                enabled: !isBusy,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Generate with AI',
                      isLoading: isBusy && (draft?.isGenerating ?? false),
                      onPressed: isBusy ? null : _generate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      isLoading: isBusy && !(draft?.isGenerating ?? false),
                      onPressed: isBusy ? null : _save,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Export to Document (DOCX/PDF)',
                isLoading: isBusy,
                onPressed: isBusy ? null : _export,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Draft Content', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Content',
                controller: _contentController,
                enabled: !isBusy,
                maxLines: 18,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'AI-generated content. Review before use in legal matters.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

