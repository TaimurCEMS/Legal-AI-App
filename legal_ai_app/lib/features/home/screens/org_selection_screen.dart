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
import '../../common/widgets/text_fields/app_text_field.dart';
import '../providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Organization selection screen
class OrgSelectionScreen extends StatefulWidget {
  const OrgSelectionScreen({super.key});

  @override
  State<OrgSelectionScreen> createState() => _OrgSelectionScreenState();
}

class _OrgSelectionScreenState extends State<OrgSelectionScreen> {
  bool _hasInitialized = false;
  bool _isManualNavigation = false; // Track if user manually navigated here
  
  @override
  void initState() {
    super.initState();
    // Check if this is a manual navigation (user clicked back button or menu)
    // If we can pop, it means user navigated here from another screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.canPop()) {
        _isManualNavigation = true;
      }
    });
    _initializeOrgProvider();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload orgs when screen becomes visible (handles refresh scenario)
    if (!_hasInitialized) {
      _initializeOrgProvider();
    } else if (_isManualNavigation) {
      // If user manually navigated here, always load orgs (don't auto-redirect)
      final orgProvider = context.read<OrgProvider>();
      if (orgProvider.userOrgs.isEmpty && !orgProvider.isLoading) {
        orgProvider.loadUserOrgs();
      }
    }
  }
  
  void _initializeOrgProvider() {
    if (_hasInitialized) return;
    _hasInitialized = true; // Set immediately to prevent duplicate calls
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final orgProvider = context.read<OrgProvider>();
      
      // If user manually navigated here, don't auto-redirect
      // Always show org list and allow selection
      if (_isManualNavigation) {
        if (orgProvider.userOrgs.isEmpty && !orgProvider.isLoading) {
          orgProvider.loadUserOrgs();
        }
        return; // Don't auto-redirect
      }
      
      // Auto-redirect only during initial app load (not manual navigation)
      // Initialize if needed, then load orgs
      if (!orgProvider.isInitialized) {
        orgProvider.initialize().then((_) {
          if (mounted && !_isManualNavigation) {
            if (orgProvider.hasOrg) {
              context.go(RouteNames.home);
            } else {
              // Load user orgs list (only if not already loading)
              orgProvider.loadUserOrgs();
            }
          }
        });
      } else {
        if (orgProvider.hasOrg && !_isManualNavigation) {
          context.go(RouteNames.home);
        } else {
          // Load user orgs list (only if not already loading)
          if (orgProvider.userOrgs.isEmpty && !orgProvider.isLoading) {
            orgProvider.loadUserOrgs();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orgProvider = context.watch<OrgProvider>();
    
    // If user manually navigated here, ensure orgs are loaded
    if (_isManualNavigation && orgProvider.userOrgs.isEmpty && !orgProvider.isLoading && orgProvider.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          orgProvider.loadUserOrgs();
        }
      });
    }
    
    // Clear error when user manually visits this screen (e.g., via menu)
    if (orgProvider.errorMessage != null && orgProvider.userOrgs.isNotEmpty) {
      // If we have orgs but also have an error, clear it (might be stale)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && orgProvider.userOrgs.isNotEmpty) {
          orgProvider.clearError();
        }
      });
    }
    
    // Show error if there is one
    if (orgProvider.errorMessage != null && orgProvider.userOrgs.isEmpty) {
      debugPrint('OrgSelectionScreen: Error loading orgs: ${orgProvider.errorMessage}');
    }

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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinOrgDialog(context, orgProvider),
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join Organization'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Create New',
                      icon: Icons.add,
                      onPressed: () {
                        context.push(RouteNames.orgCreate);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrgList(BuildContext context, OrgProvider orgProvider) {
    // Show error message if there's an error
    if (orgProvider.errorMessage != null && orgProvider.userOrgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading organizations',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              orgProvider.errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                orgProvider.clearError();
                orgProvider.loadUserOrgs();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (orgProvider.userOrgs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No Organizations',
        message: 'Create your first organization to get started.',
      );
    }

    return ListView.builder(
      itemCount: orgProvider.userOrgs.length,
      itemBuilder: (context, index) {
        final org = orgProvider.userOrgs[index];
        final isSelected = orgProvider.selectedOrg?.orgId == org.orgId;
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(
              org.name,
              style: AppTypography.titleMedium,
            ),
            subtitle: Text(
              org.description ?? 'No description',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: AppColors.primary)
                : const Icon(Icons.chevron_right),
            onTap: () {
              orgProvider.setSelectedOrg(org);
              // Always use pop if we can, otherwise go to home
              // This ensures browser back button works
              if (context.canPop()) {
                context.pop(); // Go back if we came from another screen
              } else {
                // If direct navigation, go to home and clear any navigation history issues
                context.go(RouteNames.home);
              }
            },
          ),
        );
      },
    );
  }
  
  void _showJoinOrgDialog(BuildContext context, OrgProvider orgProvider) {
    final orgIdController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Organization'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the Organization ID to join.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Organization ID',
                controller: orgIdController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Organization ID is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Join',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final orgId = orgIdController.text.trim();
              final authProvider = context.read<AuthProvider>();
              final userId = authProvider.currentUser?.uid;
              
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You must be logged in to join an organization')),
                );
                Navigator.of(dialogContext).pop();
                return;
              }
              
              final success = await orgProvider.joinOrg(
                orgId: orgId,
                userId: userId,
              );
              
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully joined organization')),
                );
                // Reload orgs list to show the new one
                orgProvider.loadUserOrgs();
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(orgProvider.errorMessage ?? 'Failed to join organization'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
