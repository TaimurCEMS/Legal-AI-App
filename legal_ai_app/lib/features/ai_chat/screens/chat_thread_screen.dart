import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message_model.dart';
import '../../../core/models/chat_thread_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart' as error_widget;
import '../../home/providers/org_provider.dart';
import '../providers/ai_chat_provider.dart';

/// Screen for a single chat conversation with AI
class ChatThreadScreen extends StatefulWidget {
  final String caseId;
  final String threadId;
  final String threadTitle;
  final JurisdictionModel? initialJurisdiction;

  const ChatThreadScreen({
    super.key,
    required this.caseId,
    required this.threadId,
    required this.threadTitle,
    this.initialJurisdiction,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isComposing = false;
  
  // Jurisdiction context for legal opinions
  String? _selectedCountry;
  String? _selectedState;
  
  // Common jurisdictions - can be expanded
  static const List<String> _countries = [
    'United States',
    'United Kingdom',
    'United Arab Emirates',
    'Canada',
    'Australia',
    'India',
    'Pakistan',
    'Singapore',
    'Hong Kong',
    'Germany',
    'France',
    'Other',
  ];
  
  static const Map<String, List<String>> _statesByCountry = {
    'United States': [
      'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
      'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
      'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana',
      'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
      'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
      'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
      'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon',
      'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
      'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
      'West Virginia', 'Wisconsin', 'Wyoming', 'District of Columbia',
    ],
    'United Arab Emirates': [
      'Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Umm Al Quwain',
      'Ras Al Khaimah', 'Fujairah', 'DIFC', 'ADGM',
    ],
    'Canada': [
      'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
      'Newfoundland and Labrador', 'Nova Scotia', 'Ontario',
      'Prince Edward Island', 'Quebec', 'Saskatchewan',
    ],
    'Australia': [
      'New South Wales', 'Victoria', 'Queensland', 'Western Australia',
      'South Australia', 'Tasmania', 'Northern Territory', 'ACT',
    ],
    'India': [
      'Delhi', 'Maharashtra', 'Karnataka', 'Tamil Nadu', 'Gujarat',
      'West Bengal', 'Telangana', 'Uttar Pradesh', 'Other',
    ],
    'Pakistan': [
      'Punjab', 'Sindh', 'Khyber Pakhtunkhwa', 'Balochistan',
      'Islamabad Capital Territory', 'Azad Kashmir', 'Gilgit-Baltistan',
    ],
    'United Kingdom': [
      'England & Wales', 'Scotland', 'Northern Ireland',
    ],
  };

  @override
  void initState() {
    super.initState();
    // Load initial jurisdiction from thread if available
    if (widget.initialJurisdiction != null) {
      _selectedCountry = widget.initialJurisdiction!.country;
      _selectedState = widget.initialJurisdiction!.state;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    await context.read<AIChatProvider>().loadMessages(
      org: org,
      caseId: widget.caseId,
      threadId: widget.threadId,
    );

    // Load jurisdiction from thread if not already set
    if (_selectedCountry == null) {
      final thread = context.read<AIChatProvider>().currentThread;
      if (thread?.jurisdiction != null && thread!.jurisdiction!.isNotEmpty) {
        setState(() {
          _selectedCountry = thread.jurisdiction!.country;
          _selectedState = thread.jurisdiction!.state;
        });
      }
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final org = context.read<OrgProvider>().selectedOrg;
    if (org == null) return;

    _messageController.clear();
    setState(() {
      _isComposing = false;
    });

    // Build jurisdiction context
    Map<String, String>? jurisdiction;
    if (_selectedCountry != null) {
      jurisdiction = {
        'country': _selectedCountry!,
        if (_selectedState != null) 'state': _selectedState!,
      };
    }

    final success = await context.read<AIChatProvider>().sendMessage(
      org: org,
      caseId: widget.caseId,
      threadId: widget.threadId,
      message: message,
      jurisdiction: jurisdiction,
    );

    if (success) {
      _scrollToBottom();
    }
  }
  
  void _showJurisdictionSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => _buildJurisdictionSheet(scrollController),
      ),
    );
  }
  
  Widget _buildJurisdictionSheet(ScrollController scrollController) {
    return StatefulBuilder(
      builder: (context, setSheetState) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Jurisdiction',
                  style: AppTypography.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCountry = null;
                      _selectedState = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Country selection
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                    items: _countries.map((country) => DropdownMenuItem(
                      value: country,
                      child: Text(country),
                    )).toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        setState(() {
                          _selectedCountry = value;
                          _selectedState = null;
                        });
                      });
                    },
                  ),
                ),
                
                // State selection (if country has states)
                if (_selectedCountry != null && _statesByCountry.containsKey(_selectedCountry))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: DropdownButtonFormField<String>(
                      value: _selectedState,
                      decoration: const InputDecoration(
                        labelText: 'State / Region',
                        border: OutlineInputBorder(),
                      ),
                      items: _statesByCountry[_selectedCountry]!.map((state) => DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      )).toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          setState(() {
                            _selectedState = value;
                          });
                        });
                      },
                    ),
                  ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Info text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Jurisdiction Context',
                                style: AppTypography.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Setting a jurisdiction helps the AI provide more relevant legal analysis, considering local laws, regulations, and court procedures.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Done button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _jurisdictionLabel {
    if (_selectedCountry == null) return 'Set Jurisdiction';
    if (_selectedState != null) return '$_selectedState, $_selectedCountry';
    return _selectedCountry!;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.threadTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_selectedCountry != null)
              Text(
                _jurisdictionLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        actions: [
          // Jurisdiction selector
          TextButton.icon(
            onPressed: _showJurisdictionSelector,
            icon: Icon(
              Icons.gavel,
              size: 18,
              color: _selectedCountry != null 
                  ? Theme.of(context).colorScheme.primary 
                  : null,
            ),
            label: Text(
              _selectedCountry != null ? 'Change' : 'Set Jurisdiction',
              style: TextStyle(
                color: _selectedCountry != null 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Legal disclaimer banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI-generated content. Review before use in legal matters.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Jurisdiction indicator banner (always visible when set)
          if (_selectedCountry != null)
            InkWell(
              onTap: _showJurisdictionSelector,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.gavel,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Jurisdiction: $_jurisdictionLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          
          // Messages list
          Expanded(
            child: Consumer<AIChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: LoadingSpinner());
                }

                if (provider.errorMessage != null && provider.messages.isEmpty) {
                  return Center(
                    child: error_widget.ErrorMessage(
                      message: provider.errorMessage!,
                      onRetry: _loadMessages,
                    ),
                  );
                }

                if (provider.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Your Legal AI Assistant',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'I can help you with:\n'
                            '• Analyzing your case documents\n'
                            '• Providing legal research and opinions\n'
                            '• Answering jurisdiction-specific questions\n'
                            '• Drafting assistance and strategy guidance',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_selectedCountry == null)
                            TextButton.icon(
                              onPressed: _showJurisdictionSelector,
                              icon: const Icon(Icons.gavel, size: 18),
                              label: const Text('Set jurisdiction for better legal advice'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // Loading indicator when AI is responding
          Consumer<AIChatProvider>(
            builder: (context, provider, child) {
              if (!provider.isSending) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'AI is thinking...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Error message
          Consumer<AIChatProvider>(
            builder: (context, provider, child) {
              if (provider.errorMessage == null || provider.messages.isNotEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: error_widget.InlineErrorMessage(
                  message: provider.errorMessage!,
                ),
              );
            },
          ),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.smart_toy,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.content,
                        style: TextStyle(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        message.timeDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: AppSpacing.sm),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ],
          ),
          
          // Citations
          if (message.hasCitations) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 40,
                right: isUser ? 40 : 0,
              ),
              child: _buildCitations(message.citations!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitations(List<CitationModel> citations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...citations.map((citation) => _buildCitationChip(citation)),
      ],
    );
  }

  Widget _buildCitationChip(CitationModel citation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () {
          // Could navigate to document
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Source: ${citation.documentName}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  citation.documentName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Consumer<AIChatProvider>(
      builder: (context, provider, child) {
        final canSend = _isComposing && !provider.isSending;
        
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    enabled: !provider.isSending,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask legal questions or about your documents...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    onChanged: (text) {
                      final wasComposing = _isComposing;
                      final isComposing = text.trim().isNotEmpty;
                      if (wasComposing != isComposing) {
                        setState(() {
                          _isComposing = isComposing;
                        });
                      }
                    },
                    onSubmitted: (_) {
                      if (canSend) _sendMessage();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: canSend ? _sendMessage : null,
                  icon: provider.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
