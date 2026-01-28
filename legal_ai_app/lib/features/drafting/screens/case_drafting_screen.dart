import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/loading/loading_spinner.dart';
import '../../home/providers/org_provider.dart';
import '../providers/draft_provider.dart';
import '../../../core/models/draft_template_model.dart';

class CaseDraftingScreen extends StatefulWidget {
  final String caseId;
  final String caseTitle;

  const CaseDraftingScreen({
    super.key,
    required this.caseId,
    required this.caseTitle,
  });

  @override
  State<CaseDraftingScreen> createState() => _CaseDraftingScreenState();
}

class _CaseDraftingScreenState extends State<CaseDraftingScreen> {
  bool _isLoading = false;
  String? _loadedOrgId;
  String? _loadedCaseId;

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
    // If the org becomes available after navigation, auto-load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    if (_isLoading) return;
    if (!forceRefresh &&
        _loadedOrgId == org.orgId &&
        _loadedCaseId == widget.caseId) {
      return;
    }

    final draftProvider = context.read<DraftProvider>();
    _isLoading = true;
    try {
      await draftProvider.loadTemplates(org: org);
      await draftProvider.loadDrafts(
        org: org,
        caseId: widget.caseId,
        refresh: true,
      );
      _loadedOrgId = org.orgId;
      _loadedCaseId = widget.caseId;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _createFromTemplate(DraftTemplateModel template) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final draftProvider = context.read<DraftProvider>();
    final draft = await draftProvider.createDraft(
      org: org,
      caseId: widget.caseId,
      template: template,
    );

    if (!mounted || draft == null) return;
    context.push(
      '${RouteNames.draftEditor}/${draft.draftId}?caseId=${Uri.encodeComponent(widget.caseId)}&caseTitle=${Uri.encodeComponent(widget.caseTitle)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    final draftProvider = context.watch<DraftProvider>();

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Drafting')),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    final isLoading = draftProvider.isLoadingTemplates || draftProvider.isLoadingDrafts;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Drafting • ${widget.caseTitle}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () async {
                    await _ensureLoaded(forceRefresh: true);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: LoadingSpinner())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (draftProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ErrorMessage(
                        message: draftProvider.error!,
                        onRetry: _ensureLoaded,
                      ),
                    ),
                  Text('Templates', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (draftProvider.templates.isEmpty)
                    Text(
                      'No templates available (or your plan does not include drafting).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...draftProvider.templates.map(
                      (t) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            '${t.category.displayLabel}${t.jurisdiction?.isNotEmpty == true ? ' • ${t.jurisdiction!.displayLabel}' : ''}\n${t.description}',
                          ),
                          isThreeLine: true,
                          trailing: TextButton(
                            onPressed: draftProvider.isWorking
                                ? null
                                : () => _createFromTemplate(t),
                            child: const Text('Create'),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Drafts', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (draftProvider.drafts.isEmpty)
                    Text(
                      'No drafts yet. Create one from a template above.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...draftProvider.drafts.map(
                      (d) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          title: Text(d.title),
                          subtitle: Text(
                            '${d.templateName} • ${d.status.displayLabel}${d.error != null ? ' • ${d.error}' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            context.push(
                              '${RouteNames.draftEditor}/${d.draftId}?caseId=${Uri.encodeComponent(widget.caseId)}&caseTitle=${Uri.encodeComponent(widget.caseTitle)}',
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

