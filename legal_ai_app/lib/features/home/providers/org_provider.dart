import 'package:flutter/foundation.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/models/org_model.dart';

/// Organization provider for managing org state
class OrgProvider with ChangeNotifier {
  final CloudFunctionsService _functionsService = CloudFunctionsService();
  OrgModel? _selectedOrg;
  MembershipModel? _currentMembership;
  bool _isLoading = false;
  String? _errorMessage;

  OrgModel? get selectedOrg => _selectedOrg;
  MembershipModel? get currentMembership => _currentMembership;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasOrg => _selectedOrg != null;

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

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error']?['message'] ?? 'Failed to create organization';
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
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error']?['message'] ?? 'Failed to join organization';
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

  void setSelectedOrg(OrgModel org) {
    _selectedOrg = org;
    notifyListeners();
  }

  void clearOrg() {
    _selectedOrg = null;
    _currentMembership = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
