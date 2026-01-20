import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../providers/auth_provider.dart';
import '../../home/providers/org_provider.dart';

/// Splash screen that checks auth state and redirects accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait a bit for providers to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final orgProvider = context.read<OrgProvider>();

    // Wait for auth state to be determined
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Check if user is authenticated
    if (!authProvider.isAuthenticated) {
      // Not authenticated - go to login
      if (mounted) {
        context.go(RouteNames.login);
      }
      return;
    }

    // Ensure user_id is saved (in case it wasn't saved during sign in)
    if (authProvider.currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', authProvider.currentUser!.uid);
    }

    // User is authenticated - initialize org provider (loads saved org)
    if (!orgProvider.isInitialized) {
      await orgProvider.initialize();
    }

    if (!mounted) return;

    // Check if they have an org (either loaded from storage or need to select)
    if (!orgProvider.hasOrg) {
      // No org selected - go to org selection
      if (mounted) {
        context.go(RouteNames.orgSelection);
      }
      return;
    }

    // User is authenticated and has org - go to home
    if (mounted) {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon would go here
            Icon(
              Icons.gavel,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Legal AI App',
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const LoadingSpinner(
              size: 32,
              message: 'Loading...',
            ),
          ],
        ),
      ),
    );
  }
}
