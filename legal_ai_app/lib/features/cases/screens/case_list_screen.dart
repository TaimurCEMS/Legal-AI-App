import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_labels.dart';
import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/cards/app_card.dart';
import '../../home/providers/org_provider.dart';
import '../providers/case_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/routing/route_names.dart';

class CaseListScreen extends StatefulWidget {
  /// When used in app shell, [selectedTabIndex] and [tabIndex] trigger load when this tab becomes visible.
  const CaseListScreen({
    super.key,
    this.selectedTabIndex,
    this.tabIndex,
  });

  final int? selectedTabIndex;
  final int? tabIndex;

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  CaseStatus? _statusFilter;
  bool _isLoading = false; // Prevent multiple simultaneous loads
  String? _lastLoadedOrgId; // Track which org we loaded cases for (prevents reload loops)
  CaseStatus? _lastLoadedStatusFilter; // Track last loaded filter to detect changes
  String? _lastLoadedSearch; // Track last loaded search to detect changes

  @override
  void initState() {
    super.initState();
    
    // Listen to search text changes (with debouncing)
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
      final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
      final isVisibleInShell = widget.selectedTabIndex != null &&
          widget.tabIndex != null &&
          widget.selectedTabIndex == widget.tabIndex;
      if (isStandalone || isVisibleInShell) {
        _checkAndLoadCases();
      }
    });
  }
  
  // Debounce timer for search
  Timer? _searchDebounce;
  
  void _onSearchChanged() {
    // Cancel previous timer
    _searchDebounce?.cancel();
    
    // Set new timer to trigger search after 300ms of no typing (reduced for better responsiveness)
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        // Reset tracking to force reload with new search
        _lastLoadedOrgId = null;
        _lastLoadedSearch = null;
        _tryLoadCases();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Check if we need to load cases (for initial load after refresh)
  void _checkAndLoadCases() {
    if (!mounted || _isLoading) return;
    
    final orgProvider = context.read<OrgProvider>();
    final currentOrg = orgProvider.selectedOrg;
    
    // Wait for org to be available and initialized
    if (currentOrg == null || !orgProvider.isInitialized || orgProvider.isLoading) {
      return;
    }
    
    final currentOrgId = currentOrg.orgId;
    
    // If we haven't loaded for this org yet, load it
    if (_lastLoadedOrgId != currentOrgId) {
      _tryLoadCases();
    }
  }

  @override
  void didUpdateWidget(covariant CaseListScreen oldWidget) {
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
        if (mounted && !_isLoading) _checkAndLoadCases();
      });
    }
  }

  Future<void> _tryLoadCases() async {
    final startTime = DateTime.now();
    
    // Prevent multiple simultaneous calls
    if (_isLoading) {
      return;
    }
    
    final orgProvider = context.read<OrgProvider>();
    final org = orgProvider.selectedOrg;
    
    // Guard: Don't reload if we're already loading for this org
    if (org?.orgId != null) {
      final orgId = org!.orgId;
      if (_lastLoadedOrgId == orgId && _isLoading) {
        return;
      }
    }
    
    _isLoading = true;
    
    try {
      final caseProvider = context.read<CaseProvider>();
      
      // Wait for org provider to initialize
      final authProvider = context.read<AuthProvider>();
      if (!orgProvider.isInitialized) {
        await orgProvider.initialize(currentUserId: authProvider.currentUser?.uid);
      }
      
      // Wait for org to be available (with timeout for refresh scenarios)
      int retries = 0;
      final maxRetries = 30; // Increased to 6 seconds for refresh scenarios
      while (orgProvider.selectedOrg == null && retries < maxRetries) {
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
      
      // Final guard: Don't reload if we already loaded for this exact org with same search/filter
      // This double-check prevents race conditions
      final currentSearch = _searchController.text.trim();
      
      // Check if org, search, or filter changed
      final orgChanged = _lastLoadedOrgId != currentOrg.orgId;
      final searchChanged = _lastLoadedSearch != currentSearch;
      final filterChanged = _lastLoadedStatusFilter != _statusFilter;
      
      // Only skip if nothing changed
      if (!orgChanged && !searchChanged && !filterChanged) {
        _isLoading = false;
        return;
      }
      
      await caseProvider.loadCases(
        org: currentOrg,
        status: _statusFilter,
        search: _searchController.text,
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final caseCount = caseProvider.cases.length;
      
      // Mark as loaded if successful (no error)
      if (caseProvider.error == null) {
        _lastLoadedOrgId = currentOrg.orgId;
        _lastLoadedStatusFilter = _statusFilter;
        _lastLoadedSearch = currentSearch;
      } else {
        // Log error for debugging
        debugPrint('CaseListScreen._tryLoadCases: ERROR - ${caseProvider.error}');
        // Reset on error to allow retry
        _lastLoadedOrgId = null;
        _lastLoadedStatusFilter = null;
        _lastLoadedSearch = null;
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('CaseListScreen._tryLoadCases: ERROR - $e');
      // Reset on error to allow retry
      _lastLoadedOrgId = null;
      _lastLoadedStatusFilter = null;
      _lastLoadedSearch = null;
    } finally {
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  Future<void> _loadInitial() async {
    await _tryLoadCases();
  }

  Future<void> _refresh() async {
    // Force reload on refresh (pull-to-refresh)
    _lastLoadedOrgId = null; // Reset to force reload
    _lastLoadedStatusFilter = null; // Reset filter tracking
    _lastLoadedSearch = null; // Reset search tracking
    _isLoading = false; // Reset loading flag
    // Clear cases and errors to ensure fresh load
    final caseProvider = context.read<CaseProvider>();
    caseProvider.clearError(); // Clear any previous errors
    // Clear cases list to show loading state
    await _tryLoadCases();
  }

  /// Handle filter change - ensures it always works, including "All statuses"
  void _handleFilterChange(CaseStatus? newStatus) {
    setState(() {
      _statusFilter = newStatus;
    });
    
    // Reset ALL tracking to force reload
    _lastLoadedOrgId = null;
    _lastLoadedStatusFilter = null;
    _lastLoadedSearch = null;
    
    // Clear cases and reload
    final caseProvider = context.read<CaseProvider>();
    caseProvider.clearCases();
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final caseProvider = context.watch<CaseProvider>();
    final currentOrg = orgProvider.selectedOrg;

    // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
    final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final shouldLoad = isStandalone || isVisibleInShell;

    if (shouldLoad &&
        currentOrg != null &&
        _lastLoadedOrgId != currentOrg.orgId &&
        !_isLoading &&
        orgProvider.isInitialized &&
        !orgProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndLoadCases();
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'case_fab',
        onPressed: () {
          context.push(RouteNames.caseCreate);
        },
        icon: const Icon(Icons.add),
        label: const Text(AppLabels.createMatter),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLabels.matters,
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildFilters(caseProvider),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(caseProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(CaseProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search matter titles…',
              prefixIcon: Icon(Icons.search),
            ),
            // Search is handled by _onSearchChanged listener with debouncing
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<CaseStatus?>(
          tooltip: 'Filter by status',
          onSelected: (status) {
            _handleFilterChange(status);
          },
          itemBuilder: (context) => [
            PopupMenuItem<CaseStatus?>(
              value: null,
              onTap: () {
                // Explicitly handle "All statuses" to ensure it always works
                // Use a small delay to let the menu close first
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    _handleFilterChange(null);
                  }
                });
              },
              child: const Text('All statuses'),
            ),
            const PopupMenuItem(
              value: CaseStatus.open,
              child: Text('Open'),
            ),
            const PopupMenuItem(
              value: CaseStatus.closed,
              child: Text('Closed'),
            ),
            const PopupMenuItem(
              value: CaseStatus.archived,
              child: Text('Archived'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _statusFilter == null
                    ? 'All'
                    : _statusFilter!.value,
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(CaseProvider provider) {
    // Use read instead of watch to prevent unnecessary rebuilds
    final orgProvider = context.read<OrgProvider>();
    
    // If org not available yet, show loading only if still initializing
    // If initialized but no org, redirect to org selection (handled by router)
    if (orgProvider.selectedOrg == null) {
      // Only show loading if org provider is still initializing or loading
      if (orgProvider.isLoading || !orgProvider.isInitialized) {
        return const Center(
          child: LoadingSpinner(message: 'Loading firm...'),
        );
      }
      // If initialized but no org selected, show empty state (router should redirect)
      // This prevents infinite loading loop
      return const Center(
        child: LoadingSpinner(message: 'No firm selected'),
      );
    }

    if (provider.isLoading && provider.cases.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    // Show error UI only if:
    // 1. We have an error
    // 2. Cases are empty (full error UI)
    // 3. Not currently loading
    if (provider.error != null && 
        provider.cases.isEmpty && 
        !provider.isLoading) {
      return Center(
        child: ErrorMessage(
          message: provider.error!,
          onRetry: _loadInitial,
        ),
      );
    }
    
    // Show soft warning if cases exist but there was an error (e.g., refresh failed)
    // This is non-blocking - user can still see their cases
    if (provider.error != null && 
        provider.cases.isNotEmpty && 
        !provider.isLoading) {
      // Show a subtle banner (could be enhanced with ScaffoldMessenger snackbar)
      debugPrint('CaseListScreen: Warning - Error occurred but cases exist: ${provider.error}');
      // Note: In a production app, you might want to show a SnackBar here
      // For now, we just log it to avoid UI clutter
    }

    if (provider.cases.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.folder_open,
        title: AppLabels.noMattersYet,
        message: 'Create your first matter to get started.',
        actionLabel: AppLabels.createMatter,
        onAction: () {
          context.push(RouteNames.caseCreate);
        },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200 &&
            provider.hasMore &&
            !provider.isLoadingMore) {
          final org = context.read<OrgProvider>().selectedOrg;
          if (org != null) {
            provider.loadMoreCases(
              org: org,
              status: _statusFilter,
              search: _searchController.text,
            );
          }
        }
        return false;
      },
      child: ListView.separated(
        itemCount: provider.cases.length + (provider.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= provider.cases.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: LoadingSpinner()),
            );
          }
          final c = provider.cases[index];
          return _CaseListItem(caseModel: c);
        },
      ),
    );
  }
}

class _CaseListItem extends StatelessWidget {
  final CaseModel caseModel;

  const _CaseListItem({required this.caseModel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push(
          RouteNames.caseDetails,
          extra: caseModel.caseId,
        );
      },
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caseModel.title,
                      style: AppTypography.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusChip(status: caseModel.status),
                  const SizedBox(width: AppSpacing.xs),
                  _VisibilityChip(visibility: caseModel.visibility),
                ],
              ),
              if (caseModel.description != null &&
                  caseModel.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  caseModel.description!,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (caseModel.clientName != null)
                    Text(
                      caseModel.clientName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  const Spacer(),
                  Text(
                    'Updated ${caseModel.updatedAt.toLocal().toIso8601String().substring(0, 10)}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary),
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

class _StatusChip extends StatelessWidget {
  final CaseStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case CaseStatus.open:
        color = Colors.green;
        break;
      case CaseStatus.closed:
        color = Colors.blue;
        break;
      case CaseStatus.archived:
        color = Colors.grey;
        break;
    }
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        status.value,
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final CaseVisibility visibility;

  const _VisibilityChip({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final isPrivate = visibility == CaseVisibility.private;
    final color = isPrivate ? Colors.red : Colors.teal;
    return Chip(
      backgroundColor: color.withOpacity(0.12),
      label: Text(
        isPrivate ? 'PRIVATE' : 'ORG WIDE',
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}

