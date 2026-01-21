import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/client_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/colors.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/cards/app_card.dart';
import '../../home/providers/org_provider.dart';
import '../providers/client_provider.dart';
import '../../../core/routing/route_names.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _lastLoadedOrgId;
  String? _lastLoadedSearch;
  OrgProvider? _orgProvider; // Store reference for safe disposal

  @override
  void initState() {
    super.initState();

    // Listen to search text changes (with debouncing)
    _searchController.addListener(_onSearchChanged);

    // Listen to OrgProvider changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _orgProvider = context.read<OrgProvider>();
      final clientProvider = context.read<ClientProvider>();

      // Clear any previous errors
      clientProvider.clearError();

      // Set up listener for org changes
      _orgProvider!.addListener(_onOrgChanged);

      // Initial load if org is already available
      _checkAndLoadClients();
    });
  }

  // Debounce timer for search
  Timer? _searchDebounce;

  void _onSearchChanged() {
    // Cancel previous timer
    _searchDebounce?.cancel();

    // Set new timer to trigger search after 500ms of no typing
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Reset tracking to force reload with new search
        _lastLoadedOrgId = null;
        _lastLoadedSearch = null;
        _tryLoadClients();
      }
    });
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    _orgProvider?.removeListener(_onOrgChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// React to org changes
  void _onOrgChanged() {
    if (!mounted) return;

    final orgProvider = context.read<OrgProvider>();
    final currentOrg = orgProvider.selectedOrg;
    final currentOrgId = currentOrg?.orgId;

    // Only react if org actually changed
    if (currentOrgId != null && currentOrgId != _lastLoadedOrgId) {
      _handleOrgChange(currentOrgId);
    } else if (currentOrgId == null && _lastLoadedOrgId != null) {
      // Org was cleared
      _lastLoadedOrgId = null;
      final clientProvider = context.read<ClientProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clientProvider.clearClients();
      });
    }
  }

  /// Handle org change
  void _handleOrgChange(String newOrgId) {
    if (!mounted || _isLoading) return;

    final orgProvider = context.read<OrgProvider>();
    final clientProvider = context.read<ClientProvider>();

    // Wait for org to be initialized
    if (!orgProvider.isInitialized || orgProvider.isLoading) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && orgProvider.selectedOrg?.orgId == newOrgId) {
          _handleOrgChange(newOrgId);
        }
      });
      return;
    }

    // Reset all tracking when org changes
    _lastLoadedOrgId = null;
    _lastLoadedSearch = null;

    // Clear search when switching orgs
    setState(() {
      _searchController.clear();
    });

    // Clear clients for new org
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && orgProvider.selectedOrg?.orgId == newOrgId) {
        clientProvider.clearClients();
        _tryLoadClients();
      }
    });
  }

  /// Check if we need to load clients
  void _checkAndLoadClients() {
    if (!mounted || _isLoading) return;

    final orgProvider = context.read<OrgProvider>();
    final currentOrg = orgProvider.selectedOrg;

    // Wait for org to be available and initialized
    if (currentOrg == null ||
        !orgProvider.isInitialized ||
        orgProvider.isLoading) {
      return;
    }

    // Load if we haven't loaded for this org yet
    if (_lastLoadedOrgId != currentOrg.orgId) {
      _tryLoadClients();
    }
  }

  /// Try to load clients with retries
  Future<void> _tryLoadClients() async {
    if (_isLoading) return;

    _isLoading = true;
    final startTime = DateTime.now();

    try {
      final orgProvider = context.read<OrgProvider>();
      final clientProvider = context.read<ClientProvider>();

      // Wait for org to be available (with retries)
      int retries = 0;
      const maxRetries = 30; // 6 seconds max wait
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

      // Final guard: Don't reload if we already loaded for this exact org with same search
      final currentSearch = _searchController.text.trim();

      // Check if org or search changed
      final orgChanged = _lastLoadedOrgId != currentOrg.orgId;
      final searchChanged = _lastLoadedSearch != currentSearch;

      // Only skip if nothing changed
      if (!orgChanged && !searchChanged) {
        _isLoading = false;
        return;
      }

      await clientProvider.loadClients(
        org: currentOrg,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      // Mark as loaded if successful
      if (clientProvider.errorMessage == null) {
        _lastLoadedOrgId = currentOrg.orgId;
        _lastLoadedSearch = currentSearch;
      } else {
        // Reset on error to allow retry
        _lastLoadedOrgId = null;
        _lastLoadedSearch = null;
      }
    } catch (e) {
      // Reset on error to allow retry
      _lastLoadedOrgId = null;
      _lastLoadedSearch = null;
    } finally {
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  Future<void> _loadInitial() async {
    await _tryLoadClients();
  }

  Future<void> _refresh() async {
    // Force reload on refresh
    _lastLoadedOrgId = null;
    _lastLoadedSearch = null;
    _isLoading = false;
    final clientProvider = context.read<ClientProvider>();
    clientProvider.clearError();
    await _tryLoadClients();
  }

  @override
  Widget build(BuildContext context) {
    final clientProvider = context.watch<ClientProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'client_fab',
        onPressed: () {
          context.push(RouteNames.clientCreate);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Client'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clients',
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSearchBar(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(clientProvider),
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
        hintText: 'Search clients by name…',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildBody(ClientProvider provider) {
    if (provider.isLoading && provider.clients.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    if (provider.hasError && provider.clients.isEmpty) {
      return ErrorMessage(
        message: provider.errorMessage ?? 'Failed to load clients',
        onRetry: _loadInitial,
      );
    }

    if (provider.clients.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No clients yet',
        message: 'Create your first client to start managing contacts.',
        actionLabel: 'New Client',
        onAction: () {
          context.push(RouteNames.clientCreate);
        },
      );
    }

    return ListView.separated(
      itemCount: provider.clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final client = provider.clients[index];
        return _ClientListItem(clientModel: client);
      },
    );
  }
}

class _ClientListItem extends StatelessWidget {
  final ClientModel clientModel;

  const _ClientListItem({required this.clientModel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push(
          RouteNames.clientDetails,
          extra: clientModel.clientId,
        );
      },
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clientModel.name,
                style: AppTypography.titleMedium,
              ),
              if (clientModel.email != null && clientModel.email!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.email,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        clientModel.email!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (clientModel.phone != null && clientModel.phone!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.phone,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        clientModel.phone!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
