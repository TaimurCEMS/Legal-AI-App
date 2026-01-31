import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/services/notification_service.dart';
import '../../home/providers/org_provider.dart';
import '../providers/notification_provider.dart';

/// Category filter options (key = API category, value = label). "All" is handled separately.
const _categoryFilters = <String, String>{
  'matter': 'Matters',
  'task': 'Tasks',
  'document': 'Documents',
  'invoice': 'Billing',
  'client': 'Clients',
};

/// Read status filter options
const _readStatusFilters = <String, String>{
  'all': 'All',
  'unread': 'Unread',
  'read': 'Read',
};

/// P2 In-app notification list – mark read, mark all read, deep link, filters
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    await context.read<NotificationProvider>().loadNotifications(org.orgId);
    if (mounted) {
      context.read<NotificationProvider>().refreshUnreadCount(org.orgId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final org = orgProvider.selectedOrg;

    if (org == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Select a firm')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifProvider.notifications.any((n) => n.isUnread))
            TextButton(
              onPressed: () async {
                await notifProvider.markAllRead(org.orgId);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          _FilterBar(orgId: org.orgId),
          // Content
          Expanded(
            child: notifProvider.loading
                ? const Center(child: CircularProgressIndicator())
                : notifProvider.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                notifProvider.error!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : notifProvider.notifications.isEmpty
                        ? _buildEmptyState(notifProvider)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.md,
                              ),
                              itemCount: notifProvider.notifications.length,
                              itemBuilder: (context, index) {
                                final n = notifProvider.notifications[index];
                                return _NotificationTile(
                                  item: n,
                                  onTap: () async {
                                    if (n.isUnread) {
                                      await notifProvider.markRead(org.orgId, n.id);
                                    }
                                    if (n.deepLink.isNotEmpty && context.mounted) {
                                      context.push(n.deepLink);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(NotificationProvider provider) {
    final hasFilters = !provider.isAllCategories || provider.readStatus != 'all';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.filter_list_off : Icons.notifications_none,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasFilters ? 'No matching notifications' : 'No notifications yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasFilters
                  ? 'Try changing or clearing your filters.'
                  : 'You\'ll see updates here when others create matters, assign tasks, or add documents.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (hasFilters)
              TextButton.icon(
                onPressed: () {
                  final org = context.read<OrgProvider>().selectedOrg;
                  if (org != null) {
                    provider.setAllCategories(org.orgId);
                    provider.setReadStatus(org.orgId, 'all');
                  }
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear filters'),
              )
            else
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filter bar with category chips and read status toggle
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips: All + multi-select (Matters, Tasks, etc.). Clicking a category toggles it; All clears category filter.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: provider.isAllCategories,
                    onSelected: (_) {
                      if (!provider.isAllCategories) {
                        provider.setAllCategories(orgId);
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color: provider.isAllCategories ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                ..._categoryFilters.entries.map((e) {
                  final isSelected = provider.isCategorySelected(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: Text(e.value),
                      selected: isSelected,
                      onSelected: (_) => provider.toggleCategory(orgId, e.key),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: AppTypography.labelMedium.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Read status chips
          Row(
            children: _readStatusFilters.entries.map((e) {
              final isSelected = provider.readStatus == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (_) {
                    // Toggle off when clicking the active filter again (except "All")
                    if (isSelected) {
                      provider.setReadStatus(orgId, 'all');
                    } else {
                      provider.setReadStatus(orgId, e.key);
                    }
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: AppTypography.labelSmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isUnread
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surface,
          child: Icon(
            _iconForCategory(item.category),
            color: item.isUnread ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
        title: Text(
          item.title,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: item.isUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          item.bodyPreview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'matter':
        return Icons.folder;
      case 'task':
        return Icons.task;
      case 'document':
        return Icons.description;
      case 'invoice':
      case 'payment':
        return Icons.receipt_long;
      case 'comment':
        return Icons.comment;
      case 'user':
        return Icons.person;
      case 'client':
        return Icons.business;
      default:
        return Icons.notifications;
    }
  }
}
