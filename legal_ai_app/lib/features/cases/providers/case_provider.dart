import 'package:flutter/foundation.dart';

import '../../../core/models/case_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/case_service.dart';

class CaseProvider with ChangeNotifier {
  final CaseService _caseService = CaseService();

  final List<CaseModel> _cases = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _limit = 20;

  CaseModel? _selectedCase;

  List<CaseModel> get cases => List.unmodifiable(_cases);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  CaseModel? get selectedCase => _selectedCase;

  static List<CaseModel> _dedupeByCaseId(Iterable<CaseModel> input) {
    final map = <String, CaseModel>{};
    for (final c in input) {
      map[c.caseId] = c; // keep last occurrence (usually newest fetch)
    }
    return map.values.toList();
  }

  Future<void> loadCases({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    _isLoading = true;
    _error = null; // Clear previous errors
    _offset = 0;
    _hasMore = true;
    _cases.clear(); // Clear existing cases to show fresh state
    notifyListeners();

    try {
      final result = await _caseService.listCases(
        org: org,
        limit: _limit,
        offset: _offset,
        status: status,
        clientId: clientId,
        search: search,
      );
      _cases
        ..clear()
        ..addAll(_dedupeByCaseId(result.cases));
      _hasMore = result.hasMore;
      _offset = _cases.length;
      // Clear error on success
      _error = null;
      debugPrint('CaseProvider.loadCases: Successfully loaded ${_cases.length} cases');
    } catch (e) {
      _error = e.toString();
      debugPrint('CaseProvider.loadCases: ERROR - $e');
      // Don't clear cases if we had some before (preserve state on error)
      // But if this is a fresh load, cases will be empty which is correct
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreCases({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _caseService.listCases(
        org: org,
        limit: _limit,
        offset: _offset,
        status: status,
        clientId: clientId,
        search: search,
      );
      // Merge + de-dupe to avoid duplicates from offset pagination edge cases
      final merged = _dedupeByCaseId([..._cases, ...result.cases]);
      _cases
        ..clear()
        ..addAll(merged);
      _hasMore = result.hasMore;
      _offset = _cases.length;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshCases({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    await loadCases(
      org: org,
      status: status,
      clientId: clientId,
      search: search,
    );
  }

  Future<bool> loadCaseDetails({
    required OrgModel org,
    required String caseId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final model = await _caseService.getCase(org: org, caseId: caseId);
      _selectedCase = model;
      // Also update in list if present
      final index = _cases.indexWhere((c) => c.caseId == caseId);
      if (index != -1) {
        _cases[index] = model;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCase({
    required OrgModel org,
    required String title,
    String? description,
    String? clientId,
    CaseVisibility visibility = CaseVisibility.orgWide,
    CaseStatus status = CaseStatus.open,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final model = await _caseService.createCase(
        org: org,
        title: title,
        description: description,
        clientId: clientId,
        visibility: visibility,
        status: status,
      );
      _cases.insert(0, model);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCase({
    required OrgModel org,
    required String caseId,
    String? title,
    String? description,
    String? clientId,
    CaseVisibility? visibility,
    CaseStatus? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final model = await _caseService.updateCase(
        org: org,
        caseId: caseId,
        title: title,
        description: description,
        clientId: clientId,
        visibility: visibility,
        status: status,
      );
      final index = _cases.indexWhere((c) => c.caseId == caseId);
      if (index != -1) {
        _cases[index] = model;
      }
      _selectedCase =
          _selectedCase?.caseId == caseId ? model : _selectedCase;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCase({
    required OrgModel org,
    required String caseId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _caseService.deleteCase(org: org, caseId: caseId);
      _cases.removeWhere((c) => c.caseId == caseId);
      if (_selectedCase?.caseId == caseId) {
        _selectedCase = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update client name for all cases with the given clientId
  /// This is called when a client's name is updated to immediately reflect the change
  void updateClientName(String clientId, String newName) {
    bool updated = false;
    for (int i = 0; i < _cases.length; i++) {
      if (_cases[i].clientId == clientId) {
        // Create a new CaseModel with updated clientName
        _cases[i] = CaseModel(
          caseId: _cases[i].caseId,
          orgId: _cases[i].orgId,
          title: _cases[i].title,
          description: _cases[i].description,
          clientId: _cases[i].clientId,
          clientName: newName,
          visibility: _cases[i].visibility,
          status: _cases[i].status,
          createdAt: _cases[i].createdAt,
          updatedAt: _cases[i].updatedAt,
          createdBy: _cases[i].createdBy,
          updatedBy: _cases[i].updatedBy,
          deletedAt: _cases[i].deletedAt,
        );
        updated = true;
      }
    }
    
    // Also update selected case if it matches
    if (_selectedCase?.clientId == clientId) {
      _selectedCase = CaseModel(
        caseId: _selectedCase!.caseId,
        orgId: _selectedCase!.orgId,
        title: _selectedCase!.title,
        description: _selectedCase!.description,
        clientId: _selectedCase!.clientId,
        clientName: newName,
        visibility: _selectedCase!.visibility,
        status: _selectedCase!.status,
        createdAt: _selectedCase!.createdAt,
        updatedAt: _selectedCase!.updatedAt,
        createdBy: _selectedCase!.createdBy,
        updatedBy: _selectedCase!.updatedBy,
        deletedAt: _selectedCase!.deletedAt,
      );
      updated = true;
    }
    
    if (updated) {
      notifyListeners();
    }
  }

  /// Clear all cases (used when switching organizations)
  void clearCases() {
    _cases.clear();
    _selectedCase = null;
    _error = null;
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
    debugPrint('CaseProvider.clearCases: Cleared all cases');
  }
}

