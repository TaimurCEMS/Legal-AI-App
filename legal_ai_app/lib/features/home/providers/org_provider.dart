import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/models/org_model.dart';

/// Organization provider for managing org state
class OrgProvider with ChangeNotifier {
  final CloudFunctionsService _functionsService = CloudFunctionsService();
  OrgModel? _selectedOrg;
  MembershipModel? _currentMembership;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  OrgModel? get selectedOrg => _selectedOrg;
  MembershipModel? get currentMembership => _currentMembership;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasOrg => _selectedOrg != null;
  bool get isInitialized => _isInitialized;
  
  // List of all orgs user belongs to
  final List<OrgModel> _userOrgs = [];
  List<OrgModel> get userOrgs => List.unmodifiable(_userOrgs);

  bool _isInitializing = false; // Guard against multiple simultaneous initializations
  
  /// Initialize provider - load saved org from storage
  /// Requires currentUserId to verify saved state belongs to current user
  /// If currentUserId is provided and doesn't match saved user, clears all state
  Future<void> initialize({String? currentUserId, bool forceReinit = false}) async {
    // If forcing reinit, reset initialization state
    if (forceReinit) {
      _isInitialized = false;
    }
    
    if (_isInitialized && !forceReinit) {
      // If already initialized, verify user still matches
      if (currentUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null && savedUserId != currentUserId) {
          // User changed - force reinit
          debugPrint('OrgProvider.initialize: User changed. Force reinitializing.');
          return initialize(currentUserId: currentUserId, forceReinit: true);
        }
      }
      return;
    }
    
    // Prevent multiple simultaneous initializations
    if (_isInitializing) {
      return;
    }
    
    _isInitializing = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getString('selected_org_id');
      final savedUserId = prefs.getString('user_id');
      
      // Verify user ID matches to prevent cross-user state leakage
      if (currentUserId != null && savedUserId != null && currentUserId != savedUserId) {
        // Different user - clear all stale data
        debugPrint('OrgProvider.initialize: User ID mismatch. Clearing stale state.');
        await prefs.remove('selected_org');
        await prefs.remove('selected_org_id');
        await prefs.remove('user_org_ids');
        _selectedOrg = null;
        _currentMembership = null;
        _userOrgs.clear();
        _isInitialized = true;
        _isInitializing = false;
        notifyListeners();
        return;
      }
      
      // Load user's org list first (this populates _userOrgs)
      // Only load if not already loading
      if (!_isLoadingUserOrgs && _userOrgs.isEmpty) {
        await loadUserOrgs();
      } else if (_userOrgs.isEmpty) {
        // Wait for existing load to complete
        while (_isLoadingUserOrgs) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      if (orgId != null && savedUserId != null) {
        // Verify org exists in the loaded org list before restoring
        final orgExistsInList = _userOrgs.any((o) => o.orgId == orgId);
        
        if (orgExistsInList) {
          // Org exists in list, try to load full membership details
          final success = await getMyMembership(orgId: orgId);
          if (success && _selectedOrg != null) {
            _isInitialized = true;
            notifyListeners();
            return;
          }
        }
      }
      
      // No saved org or failed to load - clear stale data
      await prefs.remove('selected_org');
      await prefs.remove('selected_org_id');
      _selectedOrg = null;
      _currentMembership = null;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('OrgProvider.initialize: ERROR - $e');
      _isInitialized = true;
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> createOrg({
    required String name,
    String? description,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _functionsService.createOrg(
        name: name,
        description: description,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        // Handle createdAt - could be Timestamp or String
        DateTime createdAt;
        if (data['createdAt'] is String) {
          createdAt = DateTime.parse(data['createdAt'] as String);
        } else {
          createdAt = (data['createdAt'] as dynamic).toDate();
        }

        _selectedOrg = OrgModel(
          orgId: data['orgId'] as String,
          name: data['name'] as String,
          description: data['description'] as String?,
          plan: data['plan'] as String? ?? 'FREE',
          createdAt: createdAt,
          createdBy: data['createdBy'] as String? ?? userId,
        );

        // Auto-join the org
        await joinOrg(orgId: _selectedOrg!.orgId, userId: userId);

        // Save to persistent storage
        await _saveOrgToStorage(_selectedOrg!);
        
        // Add to user orgs list
        _addToUserOrgsList(_selectedOrg!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error']?['message'] ?? 'Failed to create firm';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('OrgProvider.createOrg error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinOrg({
    required String orgId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _functionsService.joinOrg(orgId: orgId);

      if (response['success'] == true) {
        // Fetch membership details
        await getMyMembership(orgId: orgId);
        // Reload user orgs list to ensure it's up to date
        await loadUserOrgs();
        // Add to user orgs list (in case it wasn't added by loadUserOrgs)
        if (_selectedOrg != null) {
          _addToUserOrgsList(_selectedOrg!);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error']?['message'] ?? 'Failed to join firm';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> getMyMembership({required String orgId}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _functionsService.getMyMembership(orgId: orgId);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        
        // Update selected org
        _selectedOrg = OrgModel(
          orgId: data['orgId'] as String,
          name: data['orgName'] as String,
          plan: data['plan'] as String? ?? 'FREE',
          createdAt: DateTime.now(), // Will be updated from actual data
          createdBy: '', // Will be updated from actual data
        );

        // Handle joinedAt - could be Timestamp or String
        DateTime joinedAt;
        if (data['joinedAt'] is String) {
          joinedAt = DateTime.parse(data['joinedAt'] as String);
        } else if (data['joinedAt'] != null) {
          joinedAt = (data['joinedAt'] as dynamic).toDate();
        } else {
          joinedAt = DateTime.now();
        }

        // Update membership
        _currentMembership = MembershipModel(
          orgId: data['orgId'] as String,
          uid: data['uid'] as String? ?? '',
          role: data['role'] as String,
          joinedAt: joinedAt,
        );

        // Save to persistent storage
        await _saveOrgToStorage(_selectedOrg!);
        
        // Add to user orgs list
        _addToUserOrgsList(_selectedOrg!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error']?['message'] ?? 'Failed to get membership';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  bool _isSettingOrg = false; // Guard against concurrent setSelectedOrg calls
  
  Future<void> setSelectedOrg(OrgModel org) async {
    // Prevent concurrent calls for different orgs
    if (_isSettingOrg) {
      return;
    }
    
    // Set org immediately for instant UI feedback (before any async work)
    _selectedOrg = org;
    _saveOrgToStorage(org);
    notifyListeners();
    
    // Verify org exists in user's org list
    final existsInList = _userOrgs.any((o) => o.orgId == org.orgId);
    if (!existsInList) {
      _addToUserOrgsList(org);
    }
    
    // Load membership details in background (don't block navigation)
    _isSettingOrg = true;
    try {
      await getMyMembership(orgId: org.orgId);
    } catch (e) {
      debugPrint('OrgProvider.setSelectedOrg: Error loading membership: $e');
    } finally {
      _isSettingOrg = false;
    }
  }

  void clearOrg() {
    _selectedOrg = null;
    _currentMembership = null;
    _userOrgs.clear(); // Clear user orgs list
    _isInitialized = false; // Reset initialization state
    _clearOrgFromStorage();
    notifyListeners();
  }

  /// Test-only: set org and membership for widget tests (no async/API).
  @visibleForTesting
  void setStateForTest({OrgModel? org, MembershipModel? membership}) {
    _selectedOrg = org;
    _currentMembership = membership;
    notifyListeners();
  }

  /// Update selected org display name (e.g. after org settings update)
  void refreshSelectedOrgName(String name) {
    if (_selectedOrg == null) return;
    _selectedOrg = OrgModel(
      orgId: _selectedOrg!.orgId,
      name: name,
      description: _selectedOrg!.description,
      plan: _selectedOrg!.plan,
      createdAt: _selectedOrg!.createdAt,
      createdBy: _selectedOrg!.createdBy,
    );
    // Update in _userOrgs if present
    final idx = _userOrgs.indexWhere((o) => o.orgId == _selectedOrg!.orgId);
    if (idx >= 0) {
      _userOrgs[idx] = _selectedOrg!;
    }
    notifyListeners();
  }

  bool _isLoadingUserOrgs = false; // Guard against multiple simultaneous calls
  
  /// Load list of user's organizations from Firebase
  Future<void> loadUserOrgs() async {
    // Prevent multiple simultaneous calls
    if (_isLoadingUserOrgs) {
      return;
    }
    
    _isLoadingUserOrgs = true;
    
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      try {
        final response = await _functionsService.listMyOrgs();
        
        if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final orgsList = data['orgs'] as List<dynamic>? ?? [];
        
        _userOrgs.clear();
        
        for (final orgData in orgsList) {
          try {
            final orgMap = orgData as Map<String, dynamic>;
            
            // Parse joinedAt if available
            DateTime createdAt;
            if (orgMap['joinedAt'] != null && orgMap['joinedAt'] is String) {
              createdAt = DateTime.parse(orgMap['joinedAt'] as String);
            } else {
              createdAt = DateTime.now();
            }
            
            final org = OrgModel(
              orgId: orgMap['orgId'] as String,
              name: orgMap['name'] as String,
              description: orgMap['description'] as String?,
              plan: orgMap['plan'] as String? ?? 'FREE',
              createdAt: createdAt,
              createdBy: '', // Not available from list
            );
            
            _userOrgs.add(org);
          } catch (e) {
            // Log parse errors but continue with other orgs
            debugPrint('OrgProvider.loadUserOrgs: Failed to parse org: $e');
          }
        }
        
        // Save org IDs to local storage for quick access
        await _saveUserOrgsList();
        } else {
          _errorMessage = response['error']?['message'] ?? 'Failed to load firms';
          _userOrgs.clear();
        }
      } catch (e) {
        // If function doesn't exist, show helpful error
        if (e.toString().contains('not-found') || e.toString().contains('memberListMyOrgs')) {
          _errorMessage = 'Backend function not deployed. Please deploy memberListMyOrgs function.';
        } else if (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION')) {
          _errorMessage = 'Firestore index required. Please create index in Firebase Console for collection group "members" on field "uid". See FIREBASE_INDEX_SETUP.md for instructions.';
        } else {
          _errorMessage = e.toString();
        }
        _userOrgs.clear();
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('OrgProvider.loadUserOrgs: ERROR - $e');
      _errorMessage = e.toString();
      _userOrgs.clear();
      _isLoading = false;
      notifyListeners();
    } finally {
      _isLoadingUserOrgs = false;
    }
  }

  void _addToUserOrgsList(OrgModel org) {
    if (!_userOrgs.any((o) => o.orgId == org.orgId)) {
      _userOrgs.add(org);
      _saveUserOrgsList();
      notifyListeners();
    }
  }

  Future<void> _saveUserOrgsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgIds = _userOrgs.map((o) => o.orgId).toList();
      await prefs.setString('user_org_ids', jsonEncode(orgIds));
    } catch (e) {
      debugPrint('OrgProvider._saveUserOrgsList error: $e');
    }
  }

  Future<void> _saveOrgToStorage(OrgModel org) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_org_id', org.orgId);
      await prefs.setString('selected_org', jsonEncode({
        'orgId': org.orgId,
        'name': org.name,
        'plan': org.plan,
      }));
    } catch (e) {
      debugPrint('OrgProvider._saveOrgToStorage error: $e');
    }
  }

  Future<void> _clearOrgFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_org');
      await prefs.remove('selected_org_id');
      await prefs.remove('user_org_ids'); // Clear cached org IDs
    } catch (e) {
      debugPrint('OrgProvider._clearOrgFromStorage error: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
