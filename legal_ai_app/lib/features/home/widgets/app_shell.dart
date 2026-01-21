import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../screens/home_screen.dart';
import '../../cases/screens/case_list_screen.dart';
import '../../clients/screens/client_list_screen.dart';
import '../providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Main app shell with navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Use IndexedStack to preserve widget state when switching tabs
  final List<Widget> _screens = [
    const HomeScreen(),
    const CaseListScreen(),
    const ClientListScreen(),
    const PlaceholderScreen(title: 'Documents'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize org provider early to load saved org (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final orgProvider = context.read<OrgProvider>();
      if (!orgProvider.isInitialized) {
        await orgProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrgProvider>();

    // If user is not authenticated, redirect to login
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(RouteNames.login);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Don't duplicate initialization - it's already done in initState

    // If no org selected, redirect to org selection
    if (!orgProvider.hasOrg && orgProvider.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(RouteNames.orgSelection);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(orgProvider.selectedOrg?.name ?? 'Legal AI App'),
        leading: IconButton(
          icon: const Icon(Icons.business),
          tooltip: 'Switch Organization',
          onPressed: () {
            context.push(RouteNames.orgSelection);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  context.push(RouteNames.settings);
                  break;
                case 'org':
                  context.push(RouteNames.orgSelection);
                  break;
                case 'logout':
                  _handleLogout(context, authProvider);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'org',
                child: Row(
                  children: [
                    Icon(Icons.business, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Switch Organization'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Cases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Documents',
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    await authProvider.signOut();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }
}

/// Placeholder screen for future features
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$title Coming Soon',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This feature will be available in a future slice.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
