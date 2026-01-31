import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_labels.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart';
import '../providers/admin_provider.dart';
import '../../home/providers/org_provider.dart';

/// Organization Dashboard screen (Slice 15) - statistics and metrics
class OrganizationDashboardScreen extends StatefulWidget {
  const OrganizationDashboardScreen({super.key});

  @override
  State<OrganizationDashboardScreen> createState() =>
      _OrganizationDashboardScreenState();
}

class _OrganizationDashboardScreenState
    extends State<OrganizationDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    await context.read<AdminProvider>().loadOrgStats(orgId: org.orgId);
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final org = orgProvider.selectedOrg;

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppLabels.firmDashboard)),
        body: const Center(child: Text('No firm selected.')),
      );
    }

    if (adminProvider.orgStatsLoading && adminProvider.orgStats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppLabels.firmDashboard)),
        body: const Center(child: LoadingSpinner()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppLabels.firmDashboard),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AdminProvider>().loadOrgStats(orgId: org.orgId),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<AdminProvider>().loadOrgStats(orgId: org.orgId),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (adminProvider.orgStatsError != null)
                ErrorMessage(message: adminProvider.orgStatsError!),
              if (adminProvider.orgStats == null &&
                  !adminProvider.orgStatsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('Could not load statistics.'),
                  ),
                )
              else if (adminProvider.orgStats != null) ...[
                _StatCard(
                  title: adminProvider.orgStats!.orgName,
                  subtitle: 'Plan: ${adminProvider.orgStats!.plan}',
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Counts', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatChip(
                        label: 'Members',
                        value: adminProvider.orgStats!.counts.members),
                    _StatChip(
                        label: AppLabels.matters,
                        value: adminProvider.orgStats!.counts.cases),
                    _StatChip(
                        label: 'Clients',
                        value: adminProvider.orgStats!.counts.clients),
                    _StatChip(
                        label: 'Documents',
                        value: adminProvider.orgStats!.counts.documents),
                    _StatChip(
                        label: 'Tasks',
                        value: adminProvider.orgStats!.counts.tasks),
                    _StatChip(
                        label: 'Events',
                        value: adminProvider.orgStats!.counts.events),
                    _StatChip(
                        label: 'Notes',
                        value: adminProvider.orgStats!.counts.notes),
                    _StatChip(
                        label: 'Time entries',
                        value: adminProvider.orgStats!.counts.timeEntries),
                    _StatChip(
                        label: 'Invoices',
                        value: adminProvider.orgStats!.counts.invoices),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Recent activity (last 30 days)',
                    style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (adminProvider.orgStats!.recentActivity.last30Days != null) ...[
                  _StatCard(
                    title: AppLabels.mattersCreated,
                    value: adminProvider
                        .orgStats!.recentActivity.last30Days!.casesCreated
                        .toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    title: 'Documents uploaded',
                    value: adminProvider
                        .orgStats!.recentActivity.last30Days!.documentsUploaded
                        .toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    title: 'Tasks created',
                    value: adminProvider
                        .orgStats!.recentActivity.last30Days!.tasksCreated
                        .toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    title: 'Events created',
                    value: adminProvider
                        .orgStats!.recentActivity.last30Days!.eventsCreated
                        .toString(),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No recent activity data.'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Storage', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _StatCard(
                  title: 'Total storage',
                  value:
                      '${adminProvider.orgStats!.storage.totalMB.toStringAsFixed(2)} MB',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;

  const _StatCard({
    required this.title,
    this.subtitle,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (value != null)
              Text(value!, style: AppTypography.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
    );
  }
}
