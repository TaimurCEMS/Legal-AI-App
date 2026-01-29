import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/audit_event_model.dart';
import '../../../core/models/org_model.dart';
import '../../home/providers/org_provider.dart';
import '../../home/providers/member_provider.dart';
import '../../../core/models/member_model.dart';
import '../providers/audit_provider.dart';
import '../../common/widgets/text_fields/app_text_field.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _entityType;
  String? _actorUid;
  DateTime? _fromAt;
  DateTime? _toAt;
  bool _membersLoaded = false;

  static const List<String> _entityTypes = [
    'All',
    'case',
    'client',
    'document',
    'task',
    'timeEntry',
    'invoice',
    'note',
    'event',
    'draft',
    'membership',
    'org',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final orgProvider = context.read<OrgProvider>();
    final org = orgProvider.selectedOrg;
    if (org == null) return;

    // Load members for the user filter (once)
    if (!_membersLoaded) {
      _membersLoaded = true;
      context.read<MemberProvider>().loadMembers(org: org);
    }

    await context.read<AuditProvider>().refresh(
          org: org,
          search: _searchController.text,
          entityType: (_entityType == null || _entityType == 'All') ? null : _entityType,
          actorUid: _actorUid,
          fromAt: _fromAt,
          toAt: _toAt,
        );
  }

  Future<void> _export(OrgModel org) async {
    final provider = context.read<AuditProvider>();
    try {
      final csv = await provider.export(
        org: org,
        search: _searchController.text,
        entityType: (_entityType == null || _entityType == 'All') ? null : _entityType,
        actorUid: _actorUid,
        fromAt: _fromAt,
        toAt: _toAt,
      );
      if (csv.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No events to export.')),
          );
        }
        return;
      }
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to clipboard. Paste into a spreadsheet to save.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _fromAt : _toAt;
    final first = _fromAt ?? DateTime.now().subtract(const Duration(days: 365));
    final last = _toAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? (isFrom ? first : last),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => isFrom ? _fromAt = picked : _toAt = picked);
  }

  void _openDetails(AuditEventModel e) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _AuditEventDetailDialog(event: e);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final org = orgProvider.selectedOrg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
        actions: [
          if (org != null)
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.download),
              onPressed: () => _export(org),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: org == null
            ? const Center(child: Text('Select an organization to view audit events.'))
            : Consumer<AuditProvider>(
                builder: (context, provider, _) {
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        AppTextField(
                          label: 'Search',
                          hint: 'Search action, entity type, or entity id',
                          controller: _searchController,
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (_) {
                            // Keep it simple: user taps "Apply"
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_entityType ?? 'All'),
                                value: _entityType ?? 'All',
                                items: _entityTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _entityType = v),
                                decoration: InputDecoration(
                                  labelText: 'Entity type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ElevatedButton.icon(
                              onPressed: provider.isLoading ? null : _load,
                              icon: const Icon(Icons.filter_alt),
                              label: const Text('Apply'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Consumer<MemberProvider>(
                          builder: (context, memberProvider, _) {
                            final members = memberProvider.members;
                            return DropdownButtonFormField<String?>(
                              key: ValueKey('actor-$_actorUid'),
                              value: _actorUid,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All users'),
                                ),
                                ...members.map(
                                  (m) => DropdownMenuItem<String?>(
                                    value: m.uid,
                                    child: Text(m.displayLabel),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _actorUid = v),
                              decoration: InputDecoration(
                                labelText: 'Filter by user',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(true),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'From date',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                    ),
                                  ),
                                  child: Text(
                                    _fromAt == null
                                        ? 'Any'
                                        : '${_fromAt!.year}-${_fromAt!.month.toString().padLeft(2, '0')}-${_fromAt!.day.toString().padLeft(2, '0')}',
                                    style: _fromAt == null
                                        ? AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)
                                        : AppTypography.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(false),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'To date',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                    ),
                                  ),
                                  child: Text(
                                    _toAt == null
                                        ? 'Any'
                                        : '${_toAt!.year}-${_toAt!.month.toString().padLeft(2, '0')}-${_toAt!.day.toString().padLeft(2, '0')}',
                                    style: _toAt == null
                                        ? AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)
                                        : AppTypography.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (provider.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              provider.errorMessage ?? 'Failed to load audit events.',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                            ),
                          ),
                        if (provider.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.lg),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (provider.events.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.lg),
                            child: Center(
                              child: Text(
                                'No audit events found.',
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else ...[
                          ...provider.events.map(
                            (e) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(e.actionDisplayLabel),
                                subtitle: Text(
                                  [
                                    '${e.entityTypeDisplayLabel} • ${e.entityId}',
                                    if (e.actorDisplayName?.isNotEmpty == true)
                                      e.actorDisplayName
                                    else if (e.actorEmail?.isNotEmpty == true)
                                      e.actorEmail
                                    else
                                      e.actorUid,
                                    e.timestamp.toLocal().toString(),
                                  ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n'),
                                ),
                                isThreeLine: true,
                                trailing: e.caseId != null && e.caseId!.isNotEmpty
                                    ? const Icon(Icons.folder_open, size: 18)
                                    : null,
                                onTap: () => _openDetails(e),
                              ),
                            ),
                          ),
                          if (provider.hasMore)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              child: Center(
                                child: OutlinedButton(
                                  onPressed: provider.isLoadingMore
                                      ? null
                                      : () => provider.loadMore(org: org),
                                  child: provider.isLoadingMore
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Load more'),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Detail dialog with collapsible metadata section
class _AuditEventDetailDialog extends StatefulWidget {
  final AuditEventModel event;

  const _AuditEventDetailDialog({required this.event});

  @override
  State<_AuditEventDetailDialog> createState() => _AuditEventDetailDialogState();
}

class _AuditEventDetailDialogState extends State<_AuditEventDetailDialog> {
  bool _showMetadata = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final hasMetadata = e.metadata != null && e.metadata!.isNotEmpty;

    return AlertDialog(
      title: const Text('Audit Event'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action', style: AppTypography.labelLarge),
            Text(e.actionDisplayLabel),
            const SizedBox(height: AppSpacing.sm),
            Text('Entity', style: AppTypography.labelLarge),
            Text('${e.entityTypeDisplayLabel} • ${e.entityId}'),
            if (e.caseId != null && e.caseId!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Case', style: AppTypography.labelLarge),
              Text(e.caseId!),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('Actor', style: AppTypography.labelLarge),
            Text(e.actorDisplayName?.isNotEmpty == true
                ? '${e.actorDisplayName} (${e.actorEmail ?? e.actorUid})'
                : (e.actorEmail ?? e.actorUid)),
            const SizedBox(height: AppSpacing.sm),
            Text('Timestamp', style: AppTypography.labelLarge),
            Text(e.timestamp.toString()),
            // Collapsible metadata section
            if (hasMetadata) ...[
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () => setState(() => _showMetadata = !_showMetadata),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        _showMetadata ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Technical Details',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showMetadata) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    e.prettyMetadata(),
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
