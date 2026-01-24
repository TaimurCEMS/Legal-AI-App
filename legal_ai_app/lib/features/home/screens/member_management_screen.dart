import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/member_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';
import '../providers/org_provider.dart';
import '../providers/member_provider.dart';
import '../../auth/providers/auth_provider.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
    });
  }

  Future<void> _loadMembers() async {
    final orgProvider = context.read<OrgProvider>();
    final memberProvider = context.read<MemberProvider>();
    final org = orgProvider.selectedOrg;

    if (org == null) {
      return;
    }

    await memberProvider.loadMembers(org: org);
  }

  Future<void> _onRoleChanged(
    MemberModel member,
    String? newRole,
  ) async {
    if (newRole == null || newRole == member.role) {
      return;
    }

    final orgProvider = context.read<OrgProvider>();
    final memberProvider = context.read<MemberProvider>();
    final org = orgProvider.selectedOrg;

    if (org == null) {
      return;
    }

    final success = await memberProvider.updateMemberRole(
      org: org,
      memberUid: member.uid,
      role: newRole,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Role updated successfully'
                : memberProvider.errorMessage ?? 'Failed to update role',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.red;
      case 'LAWYER':
        return Colors.blue;
      case 'PARALEGAL':
        return Colors.orange;
      case 'VIEWER':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final memberProvider = context.watch<MemberProvider>();
    final authProvider = context.watch<AuthProvider>();
    final org = orgProvider.selectedOrg;
    final currentMembership = orgProvider.currentMembership;
    final currentUser = authProvider.currentUser;

    // Check if user is ADMIN
    final isAdmin = currentMembership?.role == 'ADMIN';

    // If not admin, show permission denied message
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Team Members'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'You do not have permission to manage team members. Only administrators can access this page.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Member',
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: _buildBody(memberProvider, currentUser?.uid),
      ),
    );
  }

  Widget _buildBody(MemberProvider memberProvider, String? currentUserId) {
    if (memberProvider.isLoading && memberProvider.members.isEmpty) {
      return const Center(
        child: LoadingSpinner(),
      );
    }

    if (memberProvider.hasError && memberProvider.members.isEmpty) {
      return Center(
        child: ErrorMessage(
          message: memberProvider.errorMessage ?? 'Failed to load members',
          onRetry: _loadMembers,
        ),
      );
    }

    if (memberProvider.members.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.people_outline,
          title: 'No Members',
          message: 'No members found in this organization.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: memberProvider.members.length,
      itemBuilder: (context, index) {
        final member = memberProvider.members[index];
        final effectiveRole = memberProvider.getEffectiveRole(member.uid);
        final hasPendingUpdate = memberProvider.hasPendingUpdate(member.uid);

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                member.displayLabel[0].toUpperCase(),
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    member.displayLabel,
                    style: AppTypography.titleMedium,
                  ),
                ),
                if (member.isCurrentUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'You',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.email != null && member.email != member.displayLabel)
                  Text(
                    member.email!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(effectiveRole).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        effectiveRole,
                        style: AppTypography.bodySmall.copyWith(
                          color: _getRoleColor(effectiveRole),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasPendingUpdate) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Joined: ${_formatDate(member.joinedAt)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: member.isCurrentUser
                ? null
                : DropdownButton<String>(
                    value: effectiveRole,
                    items: const [
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('ADMIN'),
                      ),
                      DropdownMenuItem(
                        value: 'LAWYER',
                        child: Text('LAWYER'),
                      ),
                      DropdownMenuItem(
                        value: 'PARALEGAL',
                        child: Text('PARALEGAL'),
                      ),
                      DropdownMenuItem(
                        value: 'VIEWER',
                        child: Text('VIEWER'),
                      ),
                    ],
                    onChanged: memberProvider.isUpdatingRole
                        ? null
                        : (newRole) => _onRoleChanged(member, newRole),
                  ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    final orgProvider = context.read<OrgProvider>();
    final org = orgProvider.selectedOrg;
    
    if (org == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Team Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'To add a new member to your organization:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '1. Share your Organization ID with the person you want to add:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: SelectableText(
                org.orgId,
                style: AppTypography.bodyMedium.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '2. The person should:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Sign up or log in to the app'),
                  Text('• Go to Organization Selection'),
                  Text('• Click "Join Organization"'),
                  Text('• Enter the Organization ID above'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Note: New members will join with VIEWER role. You can change their role after they join.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
