import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/cards/app_card.dart';
import '../../home/providers/org_provider.dart';

/// Admin Settings Hub - entry point for Slice 15 features (ADMIN only)
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final org = orgProvider.selectedOrg;
    final currentMembership = orgProvider.currentMembership;
    final isAdmin = currentMembership?.role == 'ADMIN';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Settings')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Only administrators can access Admin Settings.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
      );
    }

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Settings')),
        body: const Center(
          child: Text('No organization selected.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Advanced organization and team management',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AdminCard(
              icon: Icons.mail_outline,
              title: 'Member Invitations',
              subtitle: 'Send and manage email invitations',
              onTap: () => context.push(RouteNames.invitationManagement),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminCard(
              icon: Icons.settings,
              title: 'Organization Settings',
              subtitle: 'Name, timezone, business hours, defaults',
              onTap: () => context.push(RouteNames.organizationSettings),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminCard(
              icon: Icons.people,
              title: 'Team Members',
              subtitle: 'View members and edit profiles',
              onTap: () => context.push(RouteNames.memberManagement),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminCard(
              icon: Icons.download,
              title: 'Export Data',
              subtitle: 'Download all organization data as JSON',
              onTap: () => context.push(RouteNames.organizationExport),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminCard(
              icon: Icons.analytics_outlined,
              title: 'Organization Dashboard',
              subtitle: 'Statistics and activity metrics',
              onTap: () => context.push(RouteNames.organizationDashboard),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
