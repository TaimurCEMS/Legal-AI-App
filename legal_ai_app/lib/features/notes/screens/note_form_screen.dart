import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/note_model.dart';
import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../providers/note_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../home/providers/org_provider.dart';

/// Screen for creating or editing a note.
/// Notes inherit visibility from their case.
class NoteFormScreen extends StatefulWidget {
  final String? noteId; // null for create, set for edit
  final String? caseId; // Pre-selected case (required for create)
  final String? caseName; // Optional case name for display

  const NoteFormScreen({
    super.key,
    this.noteId,
    this.caseId,
    this.caseName,
  });

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  NoteCategory _category = NoteCategory.other;
  bool _isPinned = false;
  bool _isPrivate = false;
  bool _isLoading = false;
  bool _isEdit = false;
  NoteModel? _existingNote;
  String? _selectedCaseId;
  bool _loadingCases = false;

  String? get _orgId => context.read<OrgProvider>().selectedOrg?.orgId;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.noteId != null;
    _selectedCaseId = widget.caseId;
    
    if (_isEdit) {
      // Load available cases so user can change case while editing
      _loadCases();
      _loadExistingNote();
    } else if (widget.caseId == null) {
      // Need to load cases for selection
      _loadCases();
    }
  }
  
  Future<void> _loadCases() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;
    
    setState(() => _loadingCases = true);
    
    try {
      final caseProvider = context.read<CaseProvider>();
      await caseProvider.loadCases(org: org);
    } finally {
      if (mounted) {
        setState(() => _loadingCases = false);
      }
    }
  }

  Future<void> _loadExistingNote() async {
    final orgId = _orgId;
    if (orgId == null) return;

    final noteProvider = context.read<NoteProvider>();
    await noteProvider.loadNoteDetails(orgId: orgId, noteId: widget.noteId!);
    
    if (!mounted) return;
    
    final note = noteProvider.selectedNote;
    if (note != null) {
      setState(() {
        _existingNote = note;
        _selectedCaseId = note.caseId;
        _titleController.text = note.title;
        _contentController.text = note.content;
        _category = note.category;
        _isPinned = note.isPinned;
        _isPrivate = note.isPrivate;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    
    final orgId = _orgId;
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization selected')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final noteProvider = context.read<NoteProvider>();
    
    try {
      if (_isEdit && _existingNote != null) {
        if (_selectedCaseId == null || _selectedCaseId!.isEmpty) {
          throw Exception('Please select a matter for this note');
        }

        // Update existing note
        final updatedNote = await noteProvider.updateNote(
          orgId: orgId,
          noteId: _existingNote!.noteId,
          caseId: _selectedCaseId != _existingNote!.caseId ? _selectedCaseId : null,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          isPinned: _isPinned,
          isPrivate: _isPrivate,
        );
        
        if (updatedNote != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note updated successfully')),
          );
          context.pop(true);
        }
      } else {
        // Create new note
        if (_selectedCaseId == null) {
          throw Exception('Please select a matter for this note');
        }
        
        final newNote = await noteProvider.createNote(
          orgId: orgId,
          caseId: _selectedCaseId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          isPinned: _isPinned,
          isPrivate: _isPrivate,
        );
        
        if (newNote != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note created successfully')),
          );
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingNote = context.watch<NoteProvider>().isLoading && _isEdit && _existingNote == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Note' : 'New Note'),
        actions: [
          TextButton(
            onPressed: _isLoading || isLoadingNote ? null : _saveNote,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: isLoadingNote
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Case selector (for edit, or for new notes without pre-selected case)
                    if (_isEdit || widget.caseId == null) ...[
                      Consumer<CaseProvider>(
                        builder: (context, caseProvider, child) {
                          if (_loadingCases) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final cases = caseProvider.cases;
                          
                          return DropdownButtonFormField<String>(
                            value: _selectedCaseId,
                            decoration: const InputDecoration(
                              labelText: 'Matter *',
                              hintText: 'Select a matter',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            items: cases.map((caseModel) {
                              return DropdownMenuItem(
                                value: caseModel.caseId,
                                child: Text(
                                  caseModel.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCaseId = value);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a matter';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],
                    
                    // Case info (when pre-selected for create)
                    if (!_isEdit && widget.caseName != null) ...[
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined, size: 20),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.caseName!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],
                    
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter note title',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        if (value.trim().length > 200) {
                          return 'Title must be 200 characters or less';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    
                    // Category
                    DropdownButtonFormField<NoteCategory>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: NoteCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(_getCategoryIcon(category), size: 20),
                              SizedBox(width: AppSpacing.sm),
                              Text(category.displayLabel),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    
                    // Content
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Enter your note...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      minLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Content is required';
                        }
                        if (value.trim().length > 10000) {
                          return 'Content must be 10,000 characters or less';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    
                    // Pin toggle
                    SwitchListTile(
                      title: const Text('Pin this note'),
                      subtitle: const Text('Pinned notes appear at the top'),
                      value: _isPinned,
                      onChanged: (value) {
                        setState(() => _isPinned = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    // Private toggle
                    SwitchListTile(
                      title: const Text('Private note'),
                      subtitle: const Text('Only visible to you, even on shared matters'),
                      value: _isPrivate,
                      onChanged: (value) {
                        setState(() => _isPrivate = value);
                      },
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _isPrivate ? Icons.lock : Icons.lock_open_outlined,
                        color: _isPrivate ? Colors.orange : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
}
