import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Organization selection screen
class OrgSelectionScreen extends StatelessWidget {
  const OrgSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrgProvider>();

    // If user is not authenticated, redirect to login
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(RouteNames.login);
      });
      return const Scaffold(
        body: LoadingSpinner(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Organization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                context.go(RouteNames.login);
              }
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Organizations',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: orgProvider.isLoading
                    ? const Center(child: LoadingSpinner())
                    : _buildOrgList(context, orgProvider),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Create New Organization',
                icon: Icons.add,
                onPressed: () {
                  context.push(RouteNames.orgCreate);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrgList(BuildContext context, OrgProvider orgProvider) {
    // TODO: Fetch user's organizations from backend
    // For now, show empty state or placeholder
    return const EmptyStateWidget(
      icon: Icons.business_outlined,
      title: 'No Organizations',
      message: 'Create your first organization to get started.',
    );
  }
}
