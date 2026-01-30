import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/invitation_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../providers/admin_provider.dart';
import '../../home/providers/org_provider.dart';

/// Member Invitations screen (Slice 15) - send and manage invitations
class InvitationManagementScreen extends StatefulWidget {
  const InvitationManagementScreen({super.key});

  @override
  State<InvitationManagementScreen> createState() =>
      _InvitationManagementScreenState();
}

class _InvitationManagementScreenState extends State<InvitationManagementScreen> {
  String _statusFilter = 'pending';
  final _emailController = TextEditingController();
  String _selectedRole = 'LAWYER';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    await context.read<AdminProvider>().loadInvitations(
          orgId: org.orgId,
          status: _statusFilter,
        );
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
      }
      return;
    }

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final adminProvider = context.read<AdminProvider>();
    final invitation = await adminProvider.createInvitation(
      orgId: org.orgId,
      email: email,
      role: _selectedRole,
    );

    if (!mounted) return;
    if (invitation != null) {
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitation sent. Share this code: ${invitation.inviteCode ?? 'N/A'}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adminProvider.actionError ?? 'Failed to send invitation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _revoke(InvitationModel inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text(
          'Revoke the invitation for ${inv.email}? They will no longer be able to join with this code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final ok = await context.read<AdminProvider>().revokeInvitation(
          orgId: org.orgId,
          invitationId: inv.invitationId,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation revoked')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AdminProvider>().actionError ?? 'Failed to revoke',
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
        appBar: AppBar(title: const Text('Member Invitations')),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Invitations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Send invite card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Send invitation', style: AppTypography.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        hint: 'colleague@example.com',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'LAWYER', child: Text('Lawyer')),
                          DropdownMenuItem(value: 'PARALEGAL', child: Text('Paralegal')),
                          DropdownMenuItem(value: 'VIEWER', child: Text('Viewer')),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v ?? 'LAWYER'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (adminProvider.actionLoading)
                        const LoadingSpinner()
                      else
                        PrimaryButton(
                          onPressed: _sendInvite,
                          label: 'Send invitation',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Filter
              Row(
                children: [
                  Text('Filter:', style: AppTypography.bodyMedium),
                  const SizedBox(width: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pending', label: Text('Pending')),
                      ButtonSegment(value: 'accepted', label: Text('Accepted')),
                      ButtonSegment(value: 'revoked', label: Text('Revoked')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (Set<String> s) {
                      setState(() {
                        _statusFilter = s.first;
                        _load();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (adminProvider.invitationsError != null)
                ErrorMessage(message: adminProvider.invitationsError!),
              if (adminProvider.invitationsLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: LoadingSpinner()),
                )
              else if (adminProvider.invitations.isEmpty)
                EmptyStateWidget(
                  icon: Icons.mail_outline,
                  title: _statusFilter == 'pending'
                      ? 'No pending invitations'
                      : 'No ${_statusFilter} invitations',
                  message: _statusFilter == 'pending'
                      ? 'Send an invitation above.'
                      : null,
                )
              else
                ...adminProvider.invitations.map((inv) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(inv.email),
                        subtitle: Text(
                          '${inv.role} • ${inv.status}${inv.inviteCode != null ? ' • Code: ${inv.inviteCode}' : ''}',
                          style: AppTypography.bodySmall,
                        ),
                        trailing: inv.isPending
                            ? IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _revoke(inv),
                              )
                            : null,
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
