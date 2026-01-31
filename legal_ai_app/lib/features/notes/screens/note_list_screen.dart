import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/note_model.dart';
import '../../../core/theme/spacing.dart';
import '../../home/providers/org_provider.dart';
import '../providers/note_provider.dart';

/// Screen for listing notes with filtering and search.
/// Notes inherit visibility from their case.
class NoteListScreen extends StatefulWidget {
  final String? caseId; // Optional - filter by case
  final String? caseName; // Optional - for display
  /// When used in app shell, [selectedTabIndex] and [tabIndex] trigger load when this tab becomes visible.
  final int? selectedTabIndex;
  final int? tabIndex;

  const NoteListScreen({
    super.key,
    this.caseId,
    this.caseName,
    this.selectedTabIndex,
    this.tabIndex,
  });

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  
  NoteCategory? _categoryFilter;
  bool _pinnedOnly = false;
  String? _lastLoadedOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load if: standalone mode (both null) OR visible in shell (both non-null and equal) OR case-specific view
      final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
      final isVisibleInShell = widget.selectedTabIndex != null &&
          widget.tabIndex != null &&
          widget.selectedTabIndex == widget.tabIndex;
      if (isStandalone || isVisibleInShell || widget.caseId != null) {
        _loadNotes();
      }
    });
  }

  @override
  void didUpdateWidget(covariant NoteListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nowVisible = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final wasVisible = oldWidget.selectedTabIndex != null &&
        oldWidget.tabIndex != null &&
        oldWidget.selectedTabIndex == oldWidget.tabIndex;
    
    // Load when we become visible
    if (nowVisible && !wasVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadNotes(refresh: true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes({bool refresh = false}) async {
    final orgId = context.read<OrgProvider>().selectedOrg?.orgId;
    if (orgId == null) {
      debugPrint('NoteListScreen._loadNotes: orgId is null, cannot load notes');
      return;
    }

    debugPrint('NoteListScreen._loadNotes: Loading notes for orgId=$orgId, caseId=${widget.caseId}, refresh=$refresh');
    
    final noteProvider = context.read<NoteProvider>();
    // Always load all notes - pinned filtering is done client-side
    await noteProvider.loadNotes(
      orgId: orgId,
      caseId: widget.caseId,
      category: _categoryFilter,
      pinnedOnly: null, // Always get all notes, filter client-side
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      refresh: refresh,
    );
    
    debugPrint('NoteListScreen._loadNotes: After load, notes count=${noteProvider.notes.length}, error=${noteProvider.error}');
    _lastLoadedOrgId = orgId;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadNotes(refresh: true);
    });
  }

  void _onCategoryChanged(NoteCategory? category) {
    setState(() => _categoryFilter = category);
    _loadNotes(refresh: true);
  }

  void _onPinnedOnlyChanged(bool value) {
    // Just update the filter state - no need to reload from server
    // Client-side filtering is sufficient since we have all notes
    setState(() => _pinnedOnly = value);
  }

  void _createNote() {
    if (widget.caseId != null) {
      context.push('/notes/create?caseId=${widget.caseId}&caseName=${Uri.encodeComponent(widget.caseName ?? '')}');
    } else {
      // Navigate to create without pre-selected case (user can select in form)
      context.push('/notes/create');
    }
  }

  void _openNote(NoteModel note) {
    context.push('/notes/details/${note.noteId}');
  }

  @override
  Widget build(BuildContext context) {
    // Watch org provider to react when org becomes available
    final orgProvider = context.watch<OrgProvider>();
    final currentOrgId = orgProvider.selectedOrg?.orgId;
    
    // Load if: standalone mode (both null) OR visible in shell (both non-null and equal) OR case-specific view
    final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final shouldLoad = isStandalone || isVisibleInShell || widget.caseId != null;
    
    if (currentOrgId != null && 
        currentOrgId != _lastLoadedOrgId && 
        shouldLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNotes(refresh: true);
        }
      });
    }
    
    // Show loading while waiting for org
    if (currentOrgId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.caseName != null ? 'Notes: ${widget.caseName}' : 'Notes'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading organization...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.caseName != null ? 'Notes: ${widget.caseName}' : 'Notes'),
      ),
      body: Column(
        children: [
          // Search and filters
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadNotes(refresh: true);
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                SizedBox(height: AppSpacing.sm),
                
                // Filters row
                Row(
                  children: [
                    // Category filter
                    Expanded(
                      child: DropdownButtonFormField<NoteCategory?>(
                        value: _categoryFilter,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<NoteCategory?>(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...NoteCategory.values.map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.displayLabel),
                              )),
                        ],
                        onChanged: _onCategoryChanged,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    
                    // Pinned filter - segmented button style
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('All'),
                          icon: Icon(Icons.notes, size: 16),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Pinned'),
                          icon: Icon(Icons.push_pin, size: 16),
                        ),
                      ],
                      selected: {_pinnedOnly},
                      onSelectionChanged: (Set<bool> selection) {
                        _onPinnedOnlyChanged(selection.first);
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Notes list
          Expanded(
            child: Consumer<NoteProvider>(
              builder: (context, noteProvider, child) {
                if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (noteProvider.error != null && noteProvider.notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: AppSpacing.md),
                        Text('Error: ${noteProvider.error}'),
                        SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () => _loadNotes(refresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (noteProvider.notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          _searchController.text.isNotEmpty || _categoryFilter != null || _pinnedOnly
                              ? 'No notes match your filters'
                              : 'No notes yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: _createNote,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Note'),
                        ),
                      ],
                    ),
                  );
                }

                // Sort notes: pinned first, then by updatedAt
                final sortedNotes = List<NoteModel>.from(noteProvider.notes);
                sortedNotes.sort((a, b) {
                  if (a.isPinned && !b.isPinned) return -1;
                  if (!a.isPinned && b.isPinned) return 1;
                  return b.updatedAt.compareTo(a.updatedAt);
                });
                
                // If filtering by pinned only, show only pinned notes
                final displayNotes = _pinnedOnly 
                    ? sortedNotes.where((n) => n.isPinned).toList() 
                    : sortedNotes;
                
                if (displayNotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.push_pin_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No pinned notes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => _onPinnedOnlyChanged(false),
                          child: const Text('Show All Notes'),
                        ),
                      ],
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: () => _loadNotes(refresh: true),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: displayNotes.length + (noteProvider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Load more indicator
                      if (index >= displayNotes.length) {
                        if (!noteProvider.isLoading) {
                          _loadNotes();
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final note = displayNotes[index];
                      return _buildNoteCard(note);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'note_fab',
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note, {bool showPinIcon = true}) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: note.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: note.isPinned 
            ? BorderSide(color: Colors.orange.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _openNote(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with pin toggle button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Pin/Unpin toggle button
                  IconButton(
                    icon: Icon(
                      note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                      color: note.isPinned ? Colors.orange : Colors.grey,
                    ),
                    onPressed: () => _togglePin(note),
                    tooltip: note.isPinned ? 'Unpin note' : 'Pin note',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              
              // Content preview
              Text(
                note.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppSpacing.sm),
              
                  // Metadata row
                  Row(
                    children: [
                      Icon(_getCategoryIcon(note.category), size: 16, color: Colors.grey),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        note.category.displayLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      if (note.isPrivate) ...[
                        SizedBox(width: AppSpacing.sm),
                        Icon(Icons.lock, size: 14, color: Colors.orange),
                        SizedBox(width: 2),
                        Text(
                          'Private',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange,
                              ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.access_time, size: 14, color: Colors.grey),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        _formatDate(note.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _togglePin(NoteModel note) async {
    final orgId = context.read<OrgProvider>().selectedOrg?.orgId;
    if (orgId == null) return;

    final noteProvider = context.read<NoteProvider>();
    await noteProvider.togglePin(orgId: orgId, noteId: note.noteId);
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
    
    return DateFormat('MMM d').format(date);
  }
}
