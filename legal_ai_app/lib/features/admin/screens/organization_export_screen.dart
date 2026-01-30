import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../providers/admin_provider.dart';
import '../../home/providers/org_provider.dart';

/// Organization Export screen (Slice 15)
class OrganizationExportScreen extends StatelessWidget {
  const OrganizationExportScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final adminProvider = context.read<AdminProvider>();
    final result = await adminProvider.exportOrg(orgId: org.orgId);

    if (!context.mounted) return;
    if (result != null && result.downloadUrl.isNotEmpty) {
      final uri = Uri.parse(result.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export ready. ${result.counts.length} entity types exported.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminProvider.exportError ?? 'Export failed',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final org = orgProvider.selectedOrg;

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Data')),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export all organization data',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Download a JSON file containing members, cases, clients, documents, tasks, events, notes, time entries, invoices, and audit events. The download link is valid for 1 hour.',
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (adminProvider.exportError != null)
                ErrorMessage(message: adminProvider.exportError!),
              if (adminProvider.exportLoading)
                const Center(child: LoadingSpinner())
              else
                PrimaryButton(
                  onPressed: () => _export(context),
                  label: 'Export data',
                ),
              if (adminProvider.lastExport != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last export',
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'File: ${adminProvider.lastExport!.fileName}',
                          style: AppTypography.bodySmall,
                        ),
                        if (adminProvider.lastExport!.counts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              adminProvider.lastExport!.counts.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', '),
                              style: AppTypography.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
