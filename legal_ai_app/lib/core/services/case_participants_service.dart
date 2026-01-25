import 'package:flutter/foundation.dart';

import '../models/case_participant_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service wrapper around CloudFunctionsService for case participant operations.
class CaseParticipantsService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<List<CaseParticipantModel>> listParticipants({
    required OrgModel org,
    required String caseId,
  }) async {
    final response = await _functionsService.callFunction('caseListParticipants', {
      'orgId': org.orgId,
      'caseId': caseId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['participants'] as List<dynamic>? ?? [])
          .map(
            (e) => CaseParticipantModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      return list;
    }

    debugPrint('CaseParticipantsService.listParticipants error: $response');
    final message = response['error']?['message'] ??
        'Failed to load participants. Please try again.';
    throw message;
  }

  Future<void> addParticipant({
    required OrgModel org,
    required String caseId,
    required String participantUid,
  }) async {
    final response = await _functionsService.callFunction('caseAddParticipant', {
      'orgId': org.orgId,
      'caseId': caseId,
      'participantUid': participantUid,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('CaseParticipantsService.addParticipant error: $response');
    final message = response['error']?['message'] ??
        'Failed to add participant. Please try again.';
    throw message;
  }

  Future<void> removeParticipant({
    required OrgModel org,
    required String caseId,
    required String participantUid,
  }) async {
    final response = await _functionsService.callFunction('caseRemoveParticipant', {
      'orgId': org.orgId,
      'caseId': caseId,
      'participantUid': participantUid,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('CaseParticipantsService.removeParticipant error: $response');
    final message = response['error']?['message'] ??
        'Failed to remove participant. Please try again.';
    throw message;
  }
}

