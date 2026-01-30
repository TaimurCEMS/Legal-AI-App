import 'package:flutter/foundation.dart';

import '../models/invitation_model.dart';
import '../models/org_settings_model.dart';
import '../models/member_profile_model.dart';
import '../models/org_stats_model.dart';
import 'cloud_functions_service.dart';

/// Service for Slice 15 Advanced Admin APIs
class AdminService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  // --- Invitations ---
  Future<InvitationModel> createInvitation({
    required String orgId,
    required String email,
    required String role,
  }) async {
    final response = await _functionsService.callFunction('invitationCreate', {
      'orgId': orgId,
      'email': email,
      'role': role,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return InvitationModel.fromJson(data);
    }

    debugPrint('AdminService.createInvitation error: $response');
    final message = response['error']?['message'] ??
        'Failed to create invitation. Please try again.';
    throw message;
  }

  Future<void> acceptInvitation({required String inviteCode}) async {
    final response = await _functionsService.callFunction('invitationAccept', {
      'inviteCode': inviteCode,
    });

    if (response['success'] != true) {
      debugPrint('AdminService.acceptInvitation error: $response');
      final message = response['error']?['message'] ??
          'Failed to accept invitation. Please try again.';
      throw message;
    }
  }

  Future<void> revokeInvitation({
    required String orgId,
    required String invitationId,
  }) async {
    final response = await _functionsService.callFunction('invitationRevoke', {
      'orgId': orgId,
      'invitationId': invitationId,
    });

    if (response['success'] != true) {
      debugPrint('AdminService.revokeInvitation error: $response');
      final message = response['error']?['message'] ??
          'Failed to revoke invitation. Please try again.';
      throw message;
    }
  }

  Future<InvitationListResult> listInvitations({
    required String orgId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _functionsService.callFunction('invitationList', {
      'orgId': orgId,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': limit,
      'offset': offset,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final list = (data['invitations'] as List<dynamic>?)
              ?.map((e) => InvitationModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [];
      return InvitationListResult(
        invitations: list,
        totalCount: data['totalCount'] as int? ?? list.length,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    }

    debugPrint('AdminService.listInvitations error: $response');
    final message = response['error']?['message'] ??
        'Failed to list invitations. Please try again.';
    throw message;
  }

  // --- Organization Settings ---
  Future<OrgSettingsModel> getOrgSettings({required String orgId}) async {
    final response = await _functionsService.callFunction('orgGetSettings', {
      'orgId': orgId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return OrgSettingsModel.fromJson(data);
    }

    debugPrint('AdminService.getOrgSettings error: $response');
    final message = response['error']?['message'] ??
        'Failed to load organization settings. Please try again.';
    throw message;
  }

  Future<OrgSettingsModel> updateOrgSettings({
    required String orgId,
    String? name,
    String? description,
    String? timezone,
    BusinessHours? businessHours,
    String? defaultCaseVisibility,
    bool? defaultTaskVisibility,
    String? website,
    Address? address,
  }) async {
    final response = await _functionsService.callFunction('orgUpdate', {
      'orgId': orgId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (timezone != null) 'timezone': timezone,
      if (businessHours != null) 'businessHours': businessHours.toJson(),
      if (defaultCaseVisibility != null)
        'defaultCaseVisibility': defaultCaseVisibility,
      if (defaultTaskVisibility != null)
        'defaultTaskVisibility': defaultTaskVisibility,
      if (website != null) 'website': website,
      if (address != null) 'address': address.toJson(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return OrgSettingsModel.fromJson(data);
    }

    debugPrint('AdminService.updateOrgSettings error: $response');
    final message = response['error']?['message'] ??
        'Failed to update organization settings. Please try again.';
    throw message;
  }

  // --- Member Profiles ---
  Future<MemberProfileModel> getMemberProfile({
    required String orgId,
    required String memberUid,
  }) async {
    final response = await _functionsService.callFunction('memberGetProfile', {
      'orgId': orgId,
      'memberUid': memberUid,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return MemberProfileModel.fromJson(data);
    }

    debugPrint('AdminService.getMemberProfile error: $response');
    final message = response['error']?['message'] ??
        'Failed to load member profile. Please try again.';
    throw message;
  }

  Future<MemberProfileModel> updateMemberProfile({
    required String orgId,
    required String memberUid,
    String? bio,
    String? title,
    List<String>? specialties,
    List<BarAdmission>? barAdmissions,
    List<Education>? education,
    String? phoneNumber,
    String? photoUrl,
    bool? isPublic,
  }) async {
    final response = await _functionsService.callFunction('memberUpdateProfile', {
      'orgId': orgId,
      'memberUid': memberUid,
      if (bio != null) 'bio': bio,
      if (title != null) 'title': title,
      if (specialties != null) 'specialties': specialties,
      if (barAdmissions != null)
        'barAdmissions': barAdmissions.map((e) => e.toJson()).toList(),
      if (education != null)
        'education': education.map((e) => e.toJson()).toList(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (isPublic != null) 'isPublic': isPublic,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return MemberProfileModel.fromJson(data);
    }

    debugPrint('AdminService.updateMemberProfile error: $response');
    final message = response['error']?['message'] ??
        'Failed to update member profile. Please try again.';
    throw message;
  }

  // --- Organization Export ---
  Future<OrgExportResult> exportOrg({required String orgId}) async {
    final response = await _functionsService.callFunction('orgExport', {
      'orgId': orgId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return OrgExportResult(
        downloadUrl: data['downloadUrl'] as String? ?? '',
        fileName: data['fileName'] as String? ?? '',
        exportedAt: data['exportedAt'] as String?,
        counts: data['counts'] != null
            ? Map<String, int>.from(data['counts'] as Map)
            : {},
      );
    }

    debugPrint('AdminService.exportOrg error: $response');
    final message = response['error']?['message'] ??
        'Failed to export organization data. Please try again.';
    throw message;
  }

  // --- Organization Statistics ---
  Future<OrgStatsModel> getOrgStats({required String orgId}) async {
    final response = await _functionsService.callFunction('orgGetStats', {
      'orgId': orgId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      return OrgStatsModel.fromJson(data);
    }

    debugPrint('AdminService.getOrgStats error: $response');
    final message = response['error']?['message'] ??
        'Failed to load organization statistics. Please try again.';
    throw message;
  }
}

class InvitationListResult {
  final List<InvitationModel> invitations;
  final int totalCount;
  final bool hasMore;

  InvitationListResult({
    required this.invitations,
    required this.totalCount,
    required this.hasMore,
  });
}

class OrgExportResult {
  final String downloadUrl;
  final String fileName;
  final String? exportedAt;
  final Map<String, int> counts;

  OrgExportResult({
    required this.downloadUrl,
    required this.fileName,
    this.exportedAt,
    this.counts = const {},
  });
}
