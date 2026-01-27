import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/note_model.dart';
import '../../../core/theme/spacing.dart';
import '../../home/providers/org_provider.dart';
import '../providers/note_provider.dart';

/// Screen for viewing note details.
/// Notes inherit visibility from their case.
class NoteDetailsScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailsScreen({
    super.key,
    required this.noteId,
  });

  @override
  State<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends State<NoteDetailsScreen> {
  String? get _orgId => context.read<OrgProvider>().selectedOrg?.orgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNote();
    });
  }

  Future<void> _loadNote() async {
    final orgId = _orgId;
    if (orgId == null) return;

    final noteProvider = context.read<NoteProvider>();
    await noteProvider.loadNoteDetails(orgId: orgId, noteId: widget.noteId);
  }

  Future<void> _togglePin() async {
    final orgId = _orgId;
    if (orgId == null) return;

    final noteProvider = context.read<NoteProvider>();
    await noteProvider.togglePin(orgId: orgId, noteId: widget.noteId);
  }

  Future<void> _deleteNote() async {
    final orgId = _orgId;
    if (orgId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final noteProvider = context.read<NoteProvider>();
      final success = await noteProvider.deleteNote(orgId: orgId, noteId: widget.noteId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully')),
        );
        context.pop(true);
      }
    }
  }

  void _editNote() {
    final note = context.read<NoteProvider>().selectedNote;
    if (note != null) {
      context.push('/notes/edit/${note.noteId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final note = noteProvider.selectedNote;
        final isLoading = noteProvider.isLoading;

        if (isLoading && note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: const Center(child: Text('Note not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Note'),
            actions: [
              IconButton(
                icon: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                tooltip: note.isPinned ? 'Unpin' : 'Pin',
                onPressed: _togglePin,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: _editNote,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _deleteNote,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with pin indicator
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isPinned) ...[
                      const Icon(Icons.push_pin, size: 20, color: Colors.orange),
                      SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                      child: Text(
                        note.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                
                // Category and metadata
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Chip(
                      avatar: Icon(_getCategoryIcon(note.category), size: 18),
                      label: Text(note.category.displayLabel),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.access_time, size: 18),
                      label: Text(_formatDate(note.updatedAt)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                
                // Divider
                const Divider(),
                SizedBox(height: AppSpacing.md),
                
                // Content
                SelectableText(
                  note.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                
                // Footer metadata
                const Divider(),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Created: ${_formatDateTime(note.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                if (note.updatedAt != note.createdAt)
                  Text(
                    'Updated: ${_formatDateTime(note.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(NoteCategory category) {
    switch (category) {
      case NoteCategory.clientMeeting:
        return Icons.people_outline;
      case NoteCategory.research:
        return Icons.search;
      case NoteCategory.strategy:
        return Icons.lightbulb_outline;
      case NoteCategory.internal:
        return Icons.lock_outline;
      case NoteCategory.other:
        return Icons.note_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return DateFormat('MMM d, y').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(date);
  }
}
