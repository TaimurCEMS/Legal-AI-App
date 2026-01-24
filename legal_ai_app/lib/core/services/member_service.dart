import 'package:flutter/foundation.dart';

import '../models/member_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service wrapper around CloudFunctionsService for member operations.
class MemberService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<List<MemberModel>> listMembers({
    required OrgModel org,
  }) async {
    final response = await _functionsService.callFunction('memberListMembers', {
      'orgId': org.orgId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final membersList = data['members'] as List<dynamic>? ?? [];
      
      return membersList
          .map((json) => MemberModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ))
          .toList();
    }

    debugPrint('MemberService.listMembers error: $response');
    final message = response['error']?['message'] ??
        'Failed to load members. Please try again.';
    throw message;
  }

  Future<MemberModel> updateMemberRole({
    required OrgModel org,
    required String memberUid,
    required String role,
  }) async {
    final response = await _functionsService.callFunction('memberUpdateRole', {
      'orgId': org.orgId,
      'memberUid': memberUid,
      'role': role,
    });

    if (response['success'] == true && response['data'] != null) {
      // The response contains updated member info, but we need to reconstruct
      // a MemberModel. For now, we'll return a partial model.
      // The provider will reload the full list after update.
      final data = response['data'] as Map<String, dynamic>;
      
      // Return a minimal model - the provider will reload the full list
      return MemberModel(
        uid: data['uid'] as String,
        email: null, // Will be loaded from list
        displayName: null, // Will be loaded from list
        role: data['role'] as String,
        joinedAt: DateTime.parse(data['updatedAt'] as String),
        isCurrentUser: false, // Will be set correctly in list
      );
    }

    debugPrint('MemberService.updateMemberRole error: $response');
    final message = response['error']?['message'] ??
        'Failed to update member role. Please try again.';
    throw message;
  }
}
