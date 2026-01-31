import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/case_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/case_service.dart';

class CaseProvider with ChangeNotifier {
  final CaseService _caseService = CaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<CaseModel> _cases = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  String? _lastQuerySignature;
  StreamSubscription<QuerySnapshot>? _casesSubscription;

  CaseModel? _selectedCase;

  List<CaseModel> get cases => List.unmodifiable(_cases);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  CaseModel? get selectedCase => _selectedCase;
  bool get isRealtimeActive => _casesSubscription != null;

  static List<CaseModel> _dedupeByCaseId(Iterable<CaseModel> input) {
    final map = <String, CaseModel>{};
    for (final c in input) {
      map[c.caseId] = c;
    }
    return map.values.toList();
  }

  Future<void> loadCases({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    final querySignature = '${org.orgId}_${status?.value ?? 'null'}_${clientId ?? 'null'}_${search ?? 'null'}';
    
    // Skip if same query is already active
    if (_casesSubscription != null && _lastQuerySignature == querySignature) {
      return;
    }

    // Cancel existing subscription if query changed
    if (_lastQuerySignature != querySignature) {
      await _casesSubscription?.cancel();
      _casesSubscription = null;
    }

    _lastQuerySignature = querySignature;
    _isLoading = _cases.isEmpty; // Only show loading if list is empty
    _error = null;
    _offset = 0;
    _hasMore = false; // Real-time mode doesn't use pagination
    notifyListeners();

    try {
      debugPrint('CaseProvider.loadCases: Setting up real-time listener for org=${org.orgId}');
      
      // Build Firestore query with real-time listener
      Query<Map<String, dynamic>> query = _firestore
          .collection('organizations')
          .doc(org.orgId)
          .collection('cases')
          .where('deletedAt', isNull: true);

      // Apply Firestore filters
      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }
      if (clientId != null && clientId.isNotEmpty) {
        query = query.where('clientId', isEqualTo: clientId);
      }

      query = query.orderBy('createdAt', descending: true).limit(200);

      // Set up real-time listener
      _casesSubscription = query.snapshots().listen(
        (snapshot) {
          _cases.clear();
          for (final doc in snapshot.docs) {
            try {
              final caseModel = CaseModel.fromJson({...doc.data(), 'caseId': doc.id});
              
              // Client-side filtering for search (Firestore can't do text search)
              if (search != null && search.isNotEmpty) {
                final searchLower = search.toLowerCase();
                if (!caseModel.title.toLowerCase().contains(searchLower) &&
                    !(caseModel.description?.toLowerCase().contains(searchLower) ?? false)) {
                  continue;
                }
              }
              
              _cases.add(caseModel);
            } catch (e) {
              debugPrint('CaseProvider: Error parsing case ${doc.id}: $e');
            }
          }
          
          _isLoading = false;
          _error = null;
          debugPrint('CaseProvider: Real-time update - ${_cases.length} cases');
          notifyListeners();
        },
        onError: (error) {
          debugPrint('CaseProvider: Real-time listener error: $error');
          // Fallback to Cloud Functions on permission errors
          _fallbackToCloudFunctions(
            org: org,
            status: status,
            clientId: clientId,
            search: search,
          );
        },
      );
    } catch (e) {
      debugPrint('CaseProvider.loadCases error: $e');
      _fallbackToCloudFunctions(
        org: org,
        status: status,
        clientId: clientId,
        search: search,
      );
    }
  }

  Future<void> _fallbackToCloudFunctions({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    debugPrint('CaseProvider: Falling back to Cloud Functions');
    _casesSubscription?.cancel();
    _casesSubscription = null;
    
    try {
      final result = await _caseService.listCases(
        org: org,
        limit: _limit,
        offset: 0,
        status: status,
        clientId: clientId,
        search: search,
      );
      
      _cases.clear();
      _cases.addAll(_dedupeByCaseId(result.cases));
      _hasMore = result.hasMore;
      _offset = _cases.length;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _casesSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadMoreCases({
    required OrgModel org,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    // Real-time mode loads all data upfront, no pagination needed
    if (isRealtimeActive) {
      _hasMore = false;
      return;
    }
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
    // Force re-subscribe by clearing signature
    _lastQuerySignature = null;
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
      
      // Only add locally if real-time isn't active
      if (!isRealtimeActive) {
        _cases.insert(0, model);
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
      
      // Only update locally if real-time isn't active
      if (!isRealtimeActive) {
        final index = _cases.indexWhere((c) => c.caseId == caseId);
        if (index != -1) {
          _cases[index] = model;
        }
      }
      _selectedCase = _selectedCase?.caseId == caseId ? model : _selectedCase;
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
      
      // Only remove locally if real-time isn't active
      if (!isRealtimeActive) {
        _cases.removeWhere((c) => c.caseId == caseId);
      }
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

  void updateClientName(String clientId, String newName) {
    bool updated = false;
    for (int i = 0; i < _cases.length; i++) {
      if (_cases[i].clientId == clientId) {
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

  void clearCases() {
    _casesSubscription?.cancel();
    _casesSubscription = null;
    _cases.clear();
    _selectedCase = null;
    _error = null;
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _isLoadingMore = false;
    _lastQuerySignature = null;
    notifyListeners();
    debugPrint('CaseProvider.clearCases: Cleared all cases');
  }
}
