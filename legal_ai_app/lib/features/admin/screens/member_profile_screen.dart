import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../providers/admin_provider.dart';
import '../../home/providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Member Profile screen (Slice 15) - view/edit member profile
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    this.memberUid,
  });

  /// If null, shows current user's profile
  final String? memberUid;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  bool _editing = false;
  final _bioController = TextEditingController();
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();
  List<String> _specialties = [];
  final _specialtyInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _bioController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _specialtyInputController.dispose();
    super.dispose();
  }

  String get _effectiveMemberUid {
    return widget.memberUid ?? context.read<AuthProvider>().currentUser?.uid ?? '';
  }

  Future<void> _load() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null || _effectiveMemberUid.isEmpty) return;
    await context.read<AdminProvider>().loadMemberProfile(
          orgId: org.orgId,
          memberUid: _effectiveMemberUid,
        );
    _populateFromProfile();
  }

  void _populateFromProfile() {
    final profile = context.read<AdminProvider>().memberProfile;
    if (profile == null) return;
    _bioController.text = profile.bio ?? '';
    _titleController.text = profile.title ?? '';
    _phoneController.text = profile.phoneNumber ?? '';
    _specialties = List.from(profile.specialties);
    setState(() {});
  }

  Future<void> _save() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final adminProvider = context.read<AdminProvider>();
    final updated = await adminProvider.updateMemberProfile(
      orgId: org.orgId,
      memberUid: _effectiveMemberUid,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      specialties: _specialties.isEmpty ? null : _specialties,
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (!mounted) return;
    if (updated != null) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adminProvider.actionError ?? 'Failed to save'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addSpecialty() {
    final s = _specialtyInputController.text.trim();
    if (s.isNotEmpty && !_specialties.contains(s)) {
      setState(() {
        _specialties.add(s);
        _specialtyInputController.clear();
      });
    }
  }

  void _removeSpecialty(String s) {
    setState(() => _specialties.remove(s));
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final authProvider = context.watch<AuthProvider>();
    final org = orgProvider.selectedOrg;
    final isSelf = widget.memberUid == null || widget.memberUid == authProvider.currentUser?.uid;
    final isAdmin = orgProvider.currentMembership?.role == 'ADMIN';
    final canEdit = isSelf || isAdmin;

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    if (adminProvider.memberProfileLoading && adminProvider.memberProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (adminProvider.memberProfile != null && _bioController.text.isEmpty && !_editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _populateFromProfile();
      });
    }

    final profile = adminProvider.memberProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'My Profile' : 'Member Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.push(RouteNames.adminSettings);
            }
          },
        ),
        actions: [
          if (canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SafeArea(
        child: profile == null
            ? Center(
                child: adminProvider.memberProfileError != null
                    ? ErrorMessage(message: adminProvider.memberProfileError!)
                    : const Text('Could not load profile.'),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (adminProvider.memberProfileError != null)
                    ErrorMessage(message: adminProvider.memberProfileError!),
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(profile.displayLabel.isNotEmpty
                          ? profile.displayLabel[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(profile.displayLabel),
                    subtitle: Text(profile.email ?? profile.role),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_editing) ...[
                    AppTextField(
                      controller: _bioController,
                      label: 'Bio (optional)',
                      hint: 'Brief bio',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _titleController,
                      label: 'Title (optional)',
                      hint: 'e.g. Senior Partner',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone (optional)',
                      hint: 'Phone number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Specialties', style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Add practice area',
                            controller: _specialtyInputController,
                            hint: 'e.g. Corporate Law',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addSpecialty,
                        ),
                      ],
                    ),
                    if (_specialties.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _specialties
                            .map((s) => Chip(
                                  label: Text(s),
                                  onDeleted: () => _removeSpecialty(s),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (adminProvider.actionLoading)
                      const Center(child: LoadingSpinner())
                    else
                      Row(
                        children: [
                          PrimaryButton(onPressed: _save, label: 'Save'),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () => setState(() => _editing = false),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                  ] else ...[
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      _ProfileSection(title: 'Bio', content: profile.bio!),
                    if (profile.title != null && profile.title!.isNotEmpty)
                      _ProfileSection(title: 'Title', content: profile.title!),
                    if (profile.specialties.isNotEmpty)
                      _ProfileSection(
                        title: 'Specialties',
                        content: profile.specialties.join(', '),
                      ),
                    if (profile.barAdmissions.isNotEmpty)
                      _ProfileSection(
                        title: 'Bar admissions',
                        content: profile.barAdmissions
                            .map((b) =>
                                '${b.jurisdiction}${b.barNumber != null ? ' (${b.barNumber})' : ''}')
                            .join('; '),
                      ),
                    if (profile.phoneNumber != null &&
                        profile.phoneNumber!.isNotEmpty)
                      _ProfileSection(
                          title: 'Phone', content: profile.phoneNumber!),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final String content;

  const _ProfileSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(content, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
