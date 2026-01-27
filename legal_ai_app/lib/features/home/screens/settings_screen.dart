import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/org_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../clients/providers/client_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../providers/member_provider.dart';
import '../../notes/providers/note_provider.dart';

/// Settings/Profile screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasCheckedMembership = false;

  @override
  void initState() {
    super.initState();
    // Ensure membership is loaded when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureMembershipLoaded();
    });
  }

  Future<void> _ensureMembershipLoaded() async {
    if (_hasCheckedMembership) return;
    
    final orgProvider = context.read<OrgProvider>();
    final org = orgProvider.selectedOrg;

    // If org is selected but membership is not loaded, load it
    if (org != null && orgProvider.currentMembership == null && !orgProvider.isLoading) {
      _hasCheckedMembership = true; // Set before async call to prevent duplicate calls
      await orgProvider.getMyMembership(orgId: org.orgId);
      if (mounted) {
        setState(() {}); // Refresh UI
      }
    } else if (org == null) {
      _hasCheckedMembership = true; // No org selected, nothing to load
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrgProvider>();
    final user = authProvider.currentUser;

    // Ensure membership is loaded if org is selected
    if (orgProvider.selectedOrg != null && 
        orgProvider.currentMembership == null && 
        !orgProvider.isLoading &&
        !_hasCheckedMembership) {
      _ensureMembershipLoaded();
    }

    // Show loading if org is selected but membership is still loading
    if (orgProvider.selectedOrg != null && 
        orgProvider.currentMembership == null && 
        orgProvider.isLoading)
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );

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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orgProvider.selectedOrg!.name,
                            style: AppTypography.bodyMedium,
                          ),
                          if (orgProvider.currentMembership != null)
                            Text(
                              'Role: ${orgProvider.currentMembership!.role}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Team Members (ADMIN only)
                  if (orgProvider.selectedOrg != null &&
                      orgProvider.currentMembership?.role == 'ADMIN')
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Team Members'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push(RouteNames.memberManagement);
                      },
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
                        // Clear all provider state before logout
                        final caseProvider = context.read<CaseProvider>();
                        final clientProvider = context.read<ClientProvider>();
                        final documentProvider = context.read<DocumentProvider>();
                        final memberProvider = context.read<MemberProvider>();
                        final noteProvider = context.read<NoteProvider>();
                        
                        orgProvider.clearOrg();
                        caseProvider.clearCases();
                        clientProvider.clearClients();
                        documentProvider.clearDocuments();
                        memberProvider.clearMembers();
                        noteProvider.clearNotes();
                        
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
