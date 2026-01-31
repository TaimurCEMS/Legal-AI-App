import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/colors.dart';
import '../providers/comment_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/member_provider.dart';

/// Reusable comment list + add field for matter, task, or document (Slice 16)
class CommentListSection extends StatefulWidget {
  final String orgId;
  final String matterId;
  final String? taskId;
  final String? documentId;
  final int maxVisible;

  const CommentListSection({
    super.key,
    required this.orgId,
    required this.matterId,
    this.taskId,
    this.documentId,
    this.maxVisible = 10,
  });

  @override
  State<CommentListSection> createState() => _CommentListSectionState();
}

class _CommentListSectionState extends State<CommentListSection> {
  final _bodyController = TextEditingController();
  String? _editingCommentId;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context.read<CommentProvider>().loadComments(
          orgId: widget.orgId,
          matterId: widget.matterId,
          taskId: widget.taskId,
          documentId: widget.documentId,
          refresh: true,
        );
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  String? get _currentUid => context.read<AuthProvider>().currentUser?.uid;

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    final provider = context.read<CommentProvider>();
    provider.clearError();
    final comment = await provider.addComment(
      orgId: widget.orgId,
      matterId: widget.matterId,
      taskId: widget.taskId,
      documentId: widget.documentId,
      body: body,
    );
    if (!mounted) return;
    _bodyController.clear();
    if (comment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment posted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to post comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveEdit(String commentId) async {
    final body = _editController.text.trim();
    if (body.isEmpty) return;
    await context.read<CommentProvider>().updateComment(
          orgId: widget.orgId,
          commentId: commentId,
          body: body,
        );
    if (mounted) setState(() => _editingCommentId = null);
  }

  Future<void> _delete(CommentModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('Remove this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<CommentProvider>().deleteComment(orgId: widget.orgId, commentId: c.commentId);
    }
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _getAuthorDisplayName(String authorUid) {
    final memberProvider = context.read<MemberProvider>();
    try {
      final member = memberProvider.members.firstWhere((m) => m.uid == authorUid);
      return member.displayName ?? member.email ?? 'User ${authorUid.substring(0, 8)}';
    } catch (_) {
      return 'User ${authorUid.substring(0, 8)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommentProvider>();
    final comments = provider.comments;
    final visible = comments.take(widget.maxVisible).toList();
    final hasMore = comments.length > widget.maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            hintText: 'Add a comment...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          maxLines: 2,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: provider.isLoading ? null : _submit,
            child: const Text('Post'),
          ),
        ),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(provider.error!, style: AppTypography.bodySmall.copyWith(color: Colors.red)),
          ),
        const SizedBox(height: AppSpacing.md),
        if (provider.isLoading && comments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('No comments yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          )
        else
          ...visible.map((c) {
            final isEditing = _editingCommentId == c.commentId;
            final canEdit = _currentUid == c.authorUid;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: isEditing
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _editController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _editingCommentId = null),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => _saveEdit(c.commentId),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getAuthorDisplayName(c.authorUid),
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(c.createdAt),
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                              if (canEdit) ...[
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () {
                                    _editController.text = c.body;
                                    setState(() => _editingCommentId = c.commentId);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _delete(c),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c.body, style: AppTypography.bodyMedium),
                        ],
                      ),
              ),
            );
          }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${comments.length - widget.maxVisible} more',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
