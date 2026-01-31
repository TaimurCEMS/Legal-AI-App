import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_labels.dart';
import '../../../core/models/org_settings_model.dart';
import '../../../core/theme/spacing.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../providers/admin_provider.dart';
import '../../home/providers/org_provider.dart';

/// Organization Settings screen (Slice 15)
class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends State<OrganizationSettingsScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _businessStartController = TextEditingController();
  final _businessEndController = TextEditingController();
  final _websiteController = TextEditingController();
  String _defaultCaseVisibility = 'ORG_WIDE';
  bool _defaultTaskVisibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _timezoneController.dispose();
    _businessStartController.dispose();
    _businessEndController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    await context.read<AdminProvider>().loadOrgSettings(orgId: org.orgId);
    _populateFromSettings();
  }

  void _populateFromSettings() {
    final settings = context.read<AdminProvider>().orgSettings;
    if (settings == null) return;
    _nameController.text = settings.name;
    _descriptionController.text = settings.description ?? '';
    _timezoneController.text = settings.timezone ?? 'UTC';
    _businessStartController.text = settings.businessHours?.start ?? '09:00';
    _businessEndController.text = settings.businessHours?.end ?? '17:00';
    _websiteController.text = settings.website ?? '';
    setState(() {
      _defaultCaseVisibility = settings.defaultCaseVisibility ?? 'ORG_WIDE';
      _defaultTaskVisibility = settings.defaultTaskVisibility ?? false;
    });
  }

  Future<void> _save() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firm name is required')),
        );
      }
      return;
    }

    final adminProvider = context.read<AdminProvider>();
    final updated = await adminProvider.updateOrgSettings(
      orgId: org.orgId,
      name: name,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      timezone: _timezoneController.text.trim().isEmpty
          ? null
          : _timezoneController.text.trim(),
      businessHours: BusinessHours(
        start: _businessStartController.text.trim().isEmpty
            ? '09:00'
            : _businessStartController.text.trim(),
        end: _businessEndController.text.trim().isEmpty
            ? '17:00'
            : _businessEndController.text.trim(),
      ),
      defaultCaseVisibility: _defaultCaseVisibility,
      defaultTaskVisibility: _defaultTaskVisibility,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
    );

    if (!mounted) return;
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      context.read<OrgProvider>().refreshSelectedOrgName(updated.name);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adminProvider.actionError ?? 'Failed to save'),
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
        appBar: AppBar(title: const Text(AppLabels.firmSettings)),
        body: const Center(child: Text('No organization selected.')),
      );
    }

    if (adminProvider.orgSettingsLoading && adminProvider.orgSettings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppLabels.firmSettings)),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (adminProvider.orgSettings != null && _nameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _populateFromSettings();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppLabels.firmSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (adminProvider.orgSettingsError != null)
              ErrorMessage(message: adminProvider.orgSettingsError!),
            AppTextField(
              controller: _nameController,
              label: AppLabels.firmName,
              hint: 'My Law Firm',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _descriptionController,
              label: 'Description (optional)',
              hint: 'Brief description',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _timezoneController,
              label: 'Timezone',
              hint: 'e.g. America/New_York',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _businessStartController,
                    label: 'Business hours start',
                    hint: '09:00',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _businessEndController,
                    label: 'Business hours end',
                    hint: '17:00',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _defaultCaseVisibility,
              decoration: const InputDecoration(
                labelText: 'Default case visibility',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ORG_WIDE', child: Text('Org-wide')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
              ],
              onChanged: (v) =>
                  setState(() => _defaultCaseVisibility = v ?? 'ORG_WIDE'),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              title: const Text('Default task visibility: Assignee only'),
              value: _defaultTaskVisibility,
              onChanged: (v) => setState(() => _defaultTaskVisibility = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _websiteController,
              label: 'Website (optional)',
              hint: 'https://example.com',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (adminProvider.actionLoading)
              const Center(child: LoadingSpinner())
            else
              PrimaryButton(onPressed: _save, label: 'Save settings'),
          ],
        ),
      ),
    );
  }
}
