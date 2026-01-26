import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart' as error_widget;
import '../../home/providers/org_provider.dart';
import '../providers/ai_chat_provider.dart';
import 'chat_thread_screen.dart';

/// Screen showing list of AI chat threads for a case
class CaseAIChatScreen extends StatefulWidget {
  final String caseId;
  final String caseTitle;

  const CaseAIChatScreen({
    super.key,
    required this.caseId,
    required this.caseTitle,
  });

  @override
  State<CaseAIChatScreen> createState() => _CaseAIChatScreenState();
}

class _CaseAIChatScreenState extends State<CaseAIChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadThreads();
    });
  }

  Future<void> _loadThreads({bool refresh = false}) async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    await context.read<AIChatProvider>().loadThreads(
      org: org,
      caseId: widget.caseId,
      refresh: refresh,
    );
  }

  Future<void> _createNewThread() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    final thread = await context.read<AIChatProvider>().createThread(
      org: org,
      caseId: widget.caseId,
    );

    if (thread != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatThreadScreen(
            caseId: widget.caseId,
            threadId: thread.threadId,
            threadTitle: thread.title,
          ),
        ),
      );
      // Refresh threads when returning to update message counts
      if (mounted) {
        _loadThreads(refresh: true);
      }
    }
  }
  
  Future<void> _openThread(dynamic thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatThreadScreen(
          caseId: widget.caseId,
          threadId: thread.threadId,
          threadTitle: thread.title,
          initialJurisdiction: thread.jurisdiction,
        ),
      ),
    );
    // Refresh threads when returning to update message counts
    if (mounted) {
      _loadThreads(refresh: true);
    }
  }

  Future<void> _deleteThread(String threadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    await context.read<AIChatProvider>().deleteThread(
      org: org,
      caseId: widget.caseId,
      threadId: threadId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Research'),
            Text(
              widget.caseTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<AIChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.threads.isEmpty) {
            return const Center(child: LoadingSpinner());
          }

          if (provider.errorMessage != null && provider.threads.isEmpty) {
            return Center(
              child: error_widget.ErrorMessage(
                message: provider.errorMessage!,
                onRetry: () => _loadThreads(refresh: true),
              ),
            );
          }

          if (provider.threads.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              title: 'No Research Chats Yet',
              message: 'Start a new AI research chat to analyze your case documents and get legal opinions. Your chat history will be saved here.',
              actionLabel: 'Start New Chat',
              onAction: _createNewThread,
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadThreads(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: provider.threads.length,
              itemBuilder: (context, index) {
                final thread = provider.threads[index];
                return _buildThreadCard(thread);
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AIChatProvider>(
        builder: (context, provider, child) {
          if (provider.threads.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'ai_chat_fab',
            onPressed: _createNewThread,
            icon: const Icon(Icons.add),
            label: const Text('New Chat'),
          );
        },
      ),
    );
  }

  Widget _buildThreadCard(thread) {
    final hasMessages = thread.messageCount > 0;
    final hasJurisdiction = thread.hasJurisdiction;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _openThread(thread),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.smart_toy,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${thread.messageCount} messages',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Text(' • '),
                        Text(
                          thread.lastMessageAgo,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    // Show jurisdiction if set
                    if (hasJurisdiction) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              thread.jurisdiction!.displayLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasMessages && !hasJurisdiction) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tap to continue conversation',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteThread(thread.threadId);
                      }
                    },
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
