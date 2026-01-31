import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/document_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart' as error_widget;
import '../../common/widgets/cards/app_card.dart';
import '../../home/providers/org_provider.dart';
import '../providers/document_provider.dart';
import '../../../core/routing/route_names.dart';

class DocumentListScreen extends StatefulWidget {
  /// When used in app shell, [selectedTabIndex] and [tabIndex] trigger load when this tab becomes visible.
  const DocumentListScreen({
    super.key,
    this.selectedTabIndex,
    this.tabIndex,
  });

  final int? selectedTabIndex;
  final int? tabIndex;

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _lastLoadedOrgId;
  String? _lastLoadedSearch;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _documentProvider = context.read<DocumentProvider>();
      _documentProvider!.clearError();
      _documentProvider!.addListener(_onDocumentsChanged);

      // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
      final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
      final isVisibleInShell = widget.selectedTabIndex != null &&
          widget.tabIndex != null &&
          widget.selectedTabIndex == widget.tabIndex;
      if (isStandalone || isVisibleInShell) {
        _checkAndLoadDocuments();
      }
    });
  }

  Timer? _searchDebounce;

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _lastLoadedOrgId = null;
        _lastLoadedSearch = null;
        _tryLoadDocuments();
      }
    });
  }

  DocumentProvider? _documentProvider;

  @override
  void didUpdateWidget(covariant DocumentListScreen oldWidget) {
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
        if (mounted && !_isLoading) _checkAndLoadDocuments();
      });
    }
  }

  @override
  void dispose() {
    _documentProvider?.removeListener(_onDocumentsChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onDocumentsChanged() {
    if (!mounted) return;
    // Auto-refresh when documents are created/updated/deleted
    // Only if standalone or visible in shell
    final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    
    final org = context.read<OrgProvider>().selectedOrg;
    if (org != null && !_isLoading && (isStandalone || isVisibleInShell)) {
      _lastLoadedOrgId = null;
      _lastLoadedSearch = null;
      _tryLoadDocuments();
    }
  }

  void _checkAndLoadDocuments() {
    if (!mounted || _isLoading) return;
    final orgProvider = context.read<OrgProvider>();
    final currentOrg = orgProvider.selectedOrg;

    if (currentOrg == null ||
        !orgProvider.isInitialized ||
        orgProvider.isLoading) {
      return;
    }

    if (_lastLoadedOrgId != currentOrg.orgId) {
      _tryLoadDocuments();
    }
  }

  Future<void> _tryLoadDocuments() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final orgProvider = context.read<OrgProvider>();
      final documentProvider = context.read<DocumentProvider>();

      int retries = 0;
      const maxRetries = 30;
      while ((orgProvider.selectedOrg == null ||
              !orgProvider.isInitialized ||
              orgProvider.isLoading) &&
          retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
        if (!mounted) {
          _isLoading = false;
          return;
        }
      }

      final currentOrg = orgProvider.selectedOrg;
      if (currentOrg == null) {
        _isLoading = false;
        return;
      }

      final currentSearch = _searchController.text.trim();
      final orgChanged = _lastLoadedOrgId != currentOrg.orgId;
      final searchChanged = _lastLoadedSearch != currentSearch;

      if (!orgChanged && !searchChanged) {
        _isLoading = false;
        return;
      }

      await documentProvider.loadDocuments(
        org: currentOrg,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (documentProvider.errorMessage == null) {
        _lastLoadedOrgId = currentOrg.orgId;
        _lastLoadedSearch = currentSearch;
      } else {
        _lastLoadedOrgId = null;
        _lastLoadedSearch = null;
      }
    } catch (e) {
      _lastLoadedOrgId = null;
      _lastLoadedSearch = null;
    } finally {
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  Future<void> _refresh() async {
    _lastLoadedOrgId = null;
    _lastLoadedSearch = null;
    _isLoading = false;
    final documentProvider = context.read<DocumentProvider>();
    documentProvider.clearError();
    await _tryLoadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    final documentProvider = context.watch<DocumentProvider>();

    // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
    final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final shouldLoad = isStandalone || isVisibleInShell;
    
    if (shouldLoad && org != null && _lastLoadedOrgId != org.orgId && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndLoadDocuments();
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'document_fab',
        onPressed: () {
          context.push(RouteNames.documentUpload);
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Document'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents',
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSearchBar(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(documentProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Search documents by name…',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildBody(DocumentProvider provider) {
    if (provider.isLoading && provider.documents.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    if (provider.hasError && provider.documents.isEmpty) {
      return Center(
        child: error_widget.ErrorMessage(
          message: provider.errorMessage ?? 'Failed to load documents',
          onRetry: _refresh,
        ),
      );
    }

    if (provider.documents.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.description,
        title: 'No documents yet',
        message: 'Upload your first document to get started',
      );
    }

    // Filter out duplicates by documentId (defensive check)
    final uniqueDocuments = <String, DocumentModel>{};
    for (final doc in provider.documents) {
      if (!uniqueDocuments.containsKey(doc.documentId)) {
        uniqueDocuments[doc.documentId] = doc;
      }
    }
    final documentsList = uniqueDocuments.values.toList();
    
    return ListView.builder(
      itemCount: documentsList.length,
      itemBuilder: (context, index) {
        final document = documentsList[index];
        return _buildDocumentCard(document);
      },
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    return AppCard(
      onTap: () {
        context.push('${RouteNames.documentDetails}/${document.documentId}');
      },
      child: ListTile(
        leading: Icon(
          document.fileTypeIcon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(document.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (document.description != null && document.description!.isNotEmpty)
              Text(
                document.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              '${document.fileSizeFormatted} • ${document.fileType.toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
