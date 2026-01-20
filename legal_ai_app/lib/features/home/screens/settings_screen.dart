import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/org_provider.dart';

/// Settings/Profile screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrgProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // User Profile Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user?.email?.isNotEmpty == true
                              ? user!.email![0].toUpperCase()
                              : 'U',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        user?.email ?? 'No email',
                        style: AppTypography.titleMedium,
                      ),
                      subtitle: Text(
                        'User ID: ${user?.uid ?? 'N/A'}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Organization Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Switch Organization'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(RouteNames.orgSelection);
                    },
                  ),
                  if (orgProvider.selectedOrg != null)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Current Organization'),
                      subtitle: Text(
                        orgProvider.selectedOrg!.name,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Account Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true && context.mounted) {
                        await authProvider.signOut();
                        if (context.mounted) {
                          context.go(RouteNames.login);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // App Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Legal AI App',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Version 1.0.0',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
