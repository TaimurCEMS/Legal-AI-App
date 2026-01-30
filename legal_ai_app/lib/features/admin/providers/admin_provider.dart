import 'package:flutter/foundation.dart';

import '../../../core/models/invitation_model.dart';
import '../../../core/models/org_settings_model.dart';
import '../../../core/models/member_profile_model.dart';
import '../../../core/models/org_stats_model.dart';
import '../../../core/services/admin_service.dart';

/// Provider for Slice 15 Advanced Admin state
class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Invitations
  List<InvitationModel> _invitations = [];
  int _invitationsTotalCount = 0;
  bool _invitationsHasMore = false;
  bool _invitationsLoading = false;
  String? _invitationsError;

  List<InvitationModel> get invitations => List.unmodifiable(_invitations);
  int get invitationsTotalCount => _invitationsTotalCount;
  bool get invitationsHasMore => _invitationsHasMore;
  bool get invitationsLoading => _invitationsLoading;
  String? get invitationsError => _invitationsError;

  // Org settings
  OrgSettingsModel? _orgSettings;
  bool _orgSettingsLoading = false;
  String? _orgSettingsError;

  OrgSettingsModel? get orgSettings => _orgSettings;
  bool get orgSettingsLoading => _orgSettingsLoading;
  String? get orgSettingsError => _orgSettingsError;

  // Member profile (for view/edit screen)
  MemberProfileModel? _memberProfile;
  bool _memberProfileLoading = false;
  String? _memberProfileError;

  MemberProfileModel? get memberProfile => _memberProfile;
  bool get memberProfileLoading => _memberProfileLoading;
  String? get memberProfileError => _memberProfileError;

  // Org stats
  OrgStatsModel? _orgStats;
  bool _orgStatsLoading = false;
  String? _orgStatsError;

  OrgStatsModel? get orgStats => _orgStats;
  bool get orgStatsLoading => _orgStatsLoading;
  String? get orgStatsError => _orgStatsError;

  // Export
  OrgExportResult? _lastExport;
  bool _exportLoading = false;
  String? _exportError;

  OrgExportResult? get lastExport => _lastExport;
  bool get exportLoading => _exportLoading;
  String? get exportError => _exportError;

  // Generic loading/error for one-off actions
  bool _actionLoading = false;
  String? _actionError;

  bool get actionLoading => _actionLoading;
  String? get actionError => _actionError;

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  void clear() {
    _invitations = [];
    _invitationsTotalCount = 0;
    _invitationsHasMore = false;
    _invitationsError = null;
    _orgSettings = null;
    _orgSettingsError = null;
    _memberProfile = null;
    _memberProfileError = null;
    _orgStats = null;
    _orgStatsError = null;
    _lastExport = null;
    _exportError = null;
    _actionError = null;
    notifyListeners();
  }

  // --- Invitations ---
  Future<void> loadInvitations({
    required String orgId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    _invitationsLoading = true;
    _invitationsError = null;
    notifyListeners();

    try {
      final result = await _adminService.listInvitations(
        orgId: orgId,
        status: status,
        limit: limit,
        offset: offset,
      );
      _invitations = result.invitations;
      _invitationsTotalCount = result.totalCount;
      _invitationsHasMore = result.hasMore;
      _invitationsError = null;
    } catch (e) {
      _invitationsError = e.toString();
      _invitations = [];
      _invitationsTotalCount = 0;
      _invitationsHasMore = false;
    } finally {
      _invitationsLoading = false;
      notifyListeners();
    }
  }

  Future<InvitationModel?> createInvitation({
    required String orgId,
    required String email,
    required String role,
  }) async {
    _actionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final invitation = await _adminService.createInvitation(
        orgId: orgId,
        email: email,
        role: role,
      );
      _actionError = null;
      notifyListeners();
      return invitation;
    } catch (e) {
      _actionError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> revokeInvitation({
    required String orgId,
    required String invitationId,
  }) async {
    _actionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      await _adminService.revokeInvitation(
        orgId: orgId,
        invitationId: invitationId,
      );
      _actionError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // --- Org Settings ---
  Future<void> loadOrgSettings({required String orgId}) async {
    _orgSettingsLoading = true;
    _orgSettingsError = null;
    notifyListeners();

    try {
      _orgSettings = await _adminService.getOrgSettings(orgId: orgId);
      _orgSettingsError = null;
    } catch (e) {
      _orgSettingsError = e.toString();
      _orgSettings = null;
    } finally {
      _orgSettingsLoading = false;
      notifyListeners();
    }
  }

  Future<OrgSettingsModel?> updateOrgSettings({
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
    _actionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final updated = await _adminService.updateOrgSettings(
        orgId: orgId,
        name: name,
        description: description,
        timezone: timezone,
        businessHours: businessHours,
        defaultCaseVisibility: defaultCaseVisibility,
        defaultTaskVisibility: defaultTaskVisibility,
        website: website,
        address: address,
      );
      _orgSettings = updated;
      _actionError = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _actionError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // --- Member Profile ---
  Future<void> loadMemberProfile({
    required String orgId,
    required String memberUid,
  }) async {
    _memberProfileLoading = true;
    _memberProfileError = null;
    notifyListeners();

    try {
      _memberProfile = await _adminService.getMemberProfile(
        orgId: orgId,
        memberUid: memberUid,
      );
      _memberProfileError = null;
    } catch (e) {
      _memberProfileError = e.toString();
      _memberProfile = null;
    } finally {
      _memberProfileLoading = false;
      notifyListeners();
    }
  }

  void clearMemberProfile() {
    _memberProfile = null;
    _memberProfileError = null;
    notifyListeners();
  }

  Future<MemberProfileModel?> updateMemberProfile({
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
    _actionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final updated = await _adminService.updateMemberProfile(
        orgId: orgId,
        memberUid: memberUid,
        bio: bio,
        title: title,
        specialties: specialties,
        barAdmissions: barAdmissions,
        education: education,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        isPublic: isPublic,
      );
      _memberProfile = updated;
      _actionError = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _actionError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // --- Org Stats ---
  Future<void> loadOrgStats({required String orgId}) async {
    _orgStatsLoading = true;
    _orgStatsError = null;
    notifyListeners();

    try {
      _orgStats = await _adminService.getOrgStats(orgId: orgId);
      _orgStatsError = null;
    } catch (e) {
      _orgStatsError = e.toString();
      _orgStats = null;
    } finally {
      _orgStatsLoading = false;
      notifyListeners();
    }
  }

  // --- Export ---
  Future<OrgExportResult?> exportOrg({required String orgId}) async {
    _exportLoading = true;
    _exportError = null;
    notifyListeners();

    try {
      final result = await _adminService.exportOrg(orgId: orgId);
      _lastExport = result;
      _exportError = null;
      notifyListeners();
      return result;
    } catch (e) {
      _exportError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _exportLoading = false;
      notifyListeners();
    }
  }
}
