import 'package:flutter/foundation.dart';
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
import '../../documents/screens/document_list_screen.dart';
import '../../tasks/screens/task_list_screen.dart';
import '../../notes/screens/note_list_screen.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../calendar/providers/event_provider.dart';
import '../providers/member_provider.dart';

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
    const DocumentListScreen(),
    const TaskListScreen(),
    const NoteListScreen(),
    const CalendarScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String? _lastUserId; // Track last user ID to detect changes
  AuthProvider? _authProvider; // Store reference for dispose
  
  @override
  void initState() {
    super.initState();
    // Track current user ID and store reference for dispose
    _authProvider = context.read<AuthProvider>();
    _lastUserId = _authProvider?.currentUser?.uid;
    
    // Listen to auth state changes to detect user switches
    _authProvider?.addListener(_onAuthStateChanged);
    
    // Initialize org provider early to load saved org (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final orgProvider = context.read<OrgProvider>();
      final authProvider = context.read<AuthProvider>();
      if (!orgProvider.isInitialized) {
        await orgProvider.initialize(currentUserId: authProvider.currentUser?.uid);
      }
    });
  }
  
  void _onAuthStateChanged() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.uid;
    
    // If user changed (not just logged out), clear all state
    if (_lastUserId != null && currentUserId != null && _lastUserId != currentUserId) {
      debugPrint('AppShell: User changed from $_lastUserId to $currentUserId. Clearing state.');
      final orgProvider = context.read<OrgProvider>();
      final caseProvider = context.read<CaseProvider>();
      final clientProvider = context.read<ClientProvider>();
      final documentProvider = context.read<DocumentProvider>();
      final taskProvider = context.read<TaskProvider>();
      final eventProvider = context.read<EventProvider>();
      final memberProvider = context.read<MemberProvider>();
      
      orgProvider.clearOrg();
      caseProvider.clearCases();
      clientProvider.clearClients();
      documentProvider.clearDocuments();
      taskProvider.clearTasks();
      eventProvider.clearEvents();
      memberProvider.clearMembers();
      
      // Re-initialize org provider for new user
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await orgProvider.initialize(currentUserId: currentUserId);
        }
      });
    } else if (_lastUserId != null && currentUserId == null) {
      // User logged out - clear everything
      debugPrint('AppShell: User logged out. Clearing state.');
      final orgProvider = context.read<OrgProvider>();
      final caseProvider = context.read<CaseProvider>();
      final clientProvider = context.read<ClientProvider>();
      final documentProvider = context.read<DocumentProvider>();
      final taskProvider = context.read<TaskProvider>();
      final eventProvider = context.read<EventProvider>();
      final memberProvider = context.read<MemberProvider>();
      
      orgProvider.clearOrg();
      caseProvider.clearCases();
      clientProvider.clearClients();
      documentProvider.clearDocuments();
      taskProvider.clearTasks();
      eventProvider.clearEvents();
      memberProvider.clearMembers();
    }
    
    _lastUserId = currentUserId;
  }
  
  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
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
            label: 'Docs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_outlined),
            activeIcon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // Clear all provider state before logout
    final orgProvider = context.read<OrgProvider>();
    final caseProvider = context.read<CaseProvider>();
    final clientProvider = context.read<ClientProvider>();
    final documentProvider = context.read<DocumentProvider>();
    final taskProvider = context.read<TaskProvider>();
    final eventProvider = context.read<EventProvider>();
    
    // Clear all state
    orgProvider.clearOrg();
    caseProvider.clearCases();
    clientProvider.clearClients();
    documentProvider.clearDocuments();
    taskProvider.clearTasks();
    eventProvider.clearEvents();
    
    // Then sign out
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
