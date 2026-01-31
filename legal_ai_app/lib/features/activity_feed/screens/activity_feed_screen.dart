import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/activity_feed_model.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/colors.dart';
import '../providers/activity_feed_provider.dart';
import '../../home/providers/org_provider.dart';

/// Activity feed screen (Slice 16) - timeline from domain_events
class ActivityFeedScreen extends StatefulWidget {
  final String? matterId;

  const ActivityFeedScreen({super.key, this.matterId});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load({bool refresh = true}) {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    context.read<ActivityFeedProvider>().loadActivity(
          orgId: org.orgId,
          matterId: widget.matterId,
          refresh: refresh,
        );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<OrgProvider>();
    final provider = context.watch<ActivityFeedProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.matterId == null ? 'Activity' : 'Matter activity'),
      ),
      body: provider.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.error!, style: AppTypography.bodyMedium.copyWith(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: () => _load(), child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : provider.isLoading && items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Text(
                        'No activity yet',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: items.length + (provider.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            if (provider.hasMore && !provider.isLoading) {
                              _load(refresh: false);
                            }
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: InkWell(
                              onTap: () {
                                if (item.deepLink.isNotEmpty && item.deepLink != '/home') {
                                  context.go(item.deepLink);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _iconForEvent(item.eventType),
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.summary,
                                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                                          ),
                                          if (item.actorDisplayName != null && item.actorDisplayName!.isNotEmpty)
                                            Text(
                                              item.actorDisplayName!,
                                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                            ),
                                          Text(
                                            _formatTime(item.timestamp),
                                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.deepLink.isNotEmpty && item.deepLink != '/home')
                                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _iconForEvent(String eventType) {
    if (eventType.startsWith('matter.')) return Icons.folder_outlined;
    if (eventType.startsWith('task.')) return Icons.check_circle_outline;
    if (eventType.startsWith('document.')) return Icons.description_outlined;
    if (eventType.startsWith('invoice.') || eventType.startsWith('payment.')) return Icons.receipt_long_outlined;
    if (eventType.startsWith('comment.')) return Icons.comment_outlined;
    if (eventType.startsWith('user.')) return Icons.person_outline;
    if (eventType.startsWith('client.')) return Icons.business_center_outlined;
    return Icons.history;
  }
}
