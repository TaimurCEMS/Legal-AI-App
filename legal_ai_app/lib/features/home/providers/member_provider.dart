import 'package:flutter/foundation.dart';

import '../../../core/models/member_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/member_service.dart';

class MemberProvider with ChangeNotifier {
  final MemberService _memberService = MemberService();

  final List<MemberModel> _members = [];
  bool _isLoading = false;
  bool _isUpdatingRole = false;
  String? _errorMessage;
  
  // Optimistic UI: Track pending role updates
  final Map<String, String> _pendingRoleUpdates = {};

  List<MemberModel> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;
  bool get isUpdatingRole => _isUpdatingRole;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Get the effective role for a member (including pending updates)
  String getEffectiveRole(String uid) {
    if (_pendingRoleUpdates.containsKey(uid)) {
      return _pendingRoleUpdates[uid]!;
    }
    final member = _members.firstWhere(
      (m) => m.uid == uid,
      orElse: () => MemberModel(
        uid: uid,
        role: 'VIEWER',
        joinedAt: DateTime.now(),
        isCurrentUser: false,
      ),
    );
    return member.role;
  }

  /// Check if a member has a pending role update
  bool hasPendingUpdate(String uid) {
    return _pendingRoleUpdates.containsKey(uid);
  }

  Future<void> loadMembers({
    required OrgModel org,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _members.clear();
    notifyListeners();

    try {
      final members = await _memberService.listMembers(org: org);
      _members.addAll(members);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('MemberProvider.loadMembers error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMemberRole({
    required OrgModel org,
    required String memberUid,
    required String role,
  }) async {
    // Optimistic UI: Update immediately
    final previousRole = _members
        .firstWhere(
          (m) => m.uid == memberUid,
          orElse: () => MemberModel(
            uid: memberUid,
            role: 'VIEWER',
            joinedAt: DateTime.now(),
            isCurrentUser: false,
          ),
        )
        .role;

    _pendingRoleUpdates[memberUid] = role;
    _isUpdatingRole = true;
    _errorMessage = null;
    
    // Update local member list optimistically
    final memberIndex = _members.indexWhere((m) => m.uid == memberUid);
    if (memberIndex != -1) {
      final member = _members[memberIndex];
      _members[memberIndex] = MemberModel(
        uid: member.uid,
        email: member.email,
        displayName: member.displayName,
        role: role,
        joinedAt: member.joinedAt,
        isCurrentUser: member.isCurrentUser,
      );
    }
    
    notifyListeners();

    try {
      await _memberService.updateMemberRole(
        org: org,
        memberUid: memberUid,
        role: role,
      );

      // Success: Remove from pending and reload to get fresh data
      _pendingRoleUpdates.remove(memberUid);
      await loadMembers(org: org);
      return true;
    } catch (e) {
      // Rollback: Restore previous role
      _pendingRoleUpdates.remove(memberUid);
      _errorMessage = e.toString();
      debugPrint('MemberProvider.updateMemberRole error: $e');

      // Rollback local member list
      if (memberIndex != -1) {
        final member = _members[memberIndex];
        _members[memberIndex] = MemberModel(
          uid: member.uid,
          email: member.email,
          displayName: member.displayName,
          role: previousRole,
          joinedAt: member.joinedAt,
          isCurrentUser: member.isCurrentUser,
        );
      }

      notifyListeners();
      return false;
    } finally {
      _isUpdatingRole = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all members (used when switching organizations or logging out)
  void clearMembers() {
    _members.clear();
    _pendingRoleUpdates.clear();
    _errorMessage = null;
    _isLoading = false;
    _isUpdatingRole = false;
    notifyListeners();
  }
}
