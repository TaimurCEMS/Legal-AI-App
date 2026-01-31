import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../home/providers/org_provider.dart';
import '../providers/notification_provider.dart';

/// P2 Notification preferences – in-app and email toggles per category
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const List<Map<String, String>> _categories = [
    {'key': 'matter', 'label': 'Matters'},
    {'key': 'task', 'label': 'Tasks'},
    {'key': 'document', 'label': 'Documents'},
    {'key': 'invoice', 'label': 'Invoices & payments'},
    {'key': 'comment', 'label': 'Comments'},
    {'key': 'user', 'label': 'Team'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    await context.read<NotificationProvider>().loadPreferences(org.orgId);
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    final notifProvider = context.watch<NotificationProvider>();

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification preferences')),
        body: const Center(child: Text('Select a firm')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification preferences'),
      ),
      body: notifProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (notifProvider.error != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Material(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(
                          notifProvider.error!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                Text(
                  'Choose how you receive notifications for each category.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._categories.map((cat) {
                  final key = cat['key']!;
                  final label = cat['label']!;
                  final pref = notifProvider.preferences[key];
                  final inApp = pref?.inApp ?? true;
                  final email = pref?.email ?? true;
                  final saving = notifProvider.isCategorySaving(key);
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                label,
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (saving) ...[
                                const SizedBox(width: AppSpacing.sm),
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                            title: const Text('In-app'),
                            subtitle: const Text('Bell notifications'),
                            value: inApp,
                            onChanged: saving
                                ? null
                                : (v) {
                                    notifProvider.updatePreference(
                                      org.orgId,
                                      key,
                                      inApp: v,
                                    );
                                  },
                          ),
                          SwitchListTile(
                            title: const Text('Email'),
                            subtitle: const Text('Email notifications'),
                            value: email,
                            onChanged: saving
                                ? null
                                : (v) {
                                    notifProvider.updatePreference(
                                      org.orgId,
                                      key,
                                      email: v,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
