import 'package:flutter/foundation.dart';

import '../models/case_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service wrapper around CloudFunctionsService for case operations.
class CaseService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<CaseModel> createCase({
    required OrgModel org,
    required String title,
    String? description,
    String? clientId,
    CaseVisibility visibility = CaseVisibility.orgWide,
    CaseStatus status = CaseStatus.open,
  }) async {
    final response = await _functionsService.callFunction('caseCreate', {
      'orgId': org.orgId,
      'title': title,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      'visibility': visibility.value,
      'status': status.value,
    });

    if (response['success'] == true && response['data'] != null) {
      return CaseModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('CaseService.createCase error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to create case. Please try again.';
    throw message;
  }

  Future<CaseModel> getCase({
    required OrgModel org,
    required String caseId,
  }) async {
    final response = await _functionsService.callFunction('caseGet', {
      'orgId': org.orgId,
      'caseId': caseId,
    });

    if (response['success'] == true && response['data'] != null) {
      return CaseModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('CaseService.getCase error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to load case. Please try again.';
    throw message;
  }

  Future<({List<CaseModel> cases, int total, bool hasMore})> listCases({
    required OrgModel org,
    int limit = 20,
    int offset = 0,
    CaseStatus? status,
    String? clientId,
    String? search,
  }) async {
    final response = await _functionsService.callFunction('caseList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (status != null) 'status': status.value,
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['cases'] as List<dynamic>? ?? [])
          .map((e) => CaseModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (cases: list, total: total, hasMore: hasMore);
    }

    debugPrint('CaseService.listCases error: $response');
    
    // Extract error message with more detail
    String message;
    if (response['error'] != null) {
      final error = response['error'] as Map<String, dynamic>;
      message = error['message'] as String? ?? 'Failed to load cases';
      final code = error['code'] as String?;
      if (code != null) {
        debugPrint('CaseService.listCases: Error code: $code, message: $message');
      }
    } else {
      message = 'Failed to load cases. Please try again.';
    }
    
    throw message;
  }

  Future<CaseModel> updateCase({
    required OrgModel org,
    required String caseId,
    String? title,
    String? description,
    String? clientId,
    CaseVisibility? visibility,
    CaseStatus? status,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'caseId': caseId,
    };

    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (clientId != null) payload['clientId'] = clientId;
    if (visibility != null) payload['visibility'] = visibility.value;
    if (status != null) payload['status'] = status.value;

    final response = await _functionsService.callFunction('caseUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return CaseModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('CaseService.updateCase error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to update case. Please try again.';
    throw message;
  }

  Future<void> deleteCase({
    required OrgModel org,
    required String caseId,
  }) async {
    final response = await _functionsService.callFunction('caseDelete', {
      'orgId': org.orgId,
      'caseId': caseId,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('CaseService.deleteCase error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to delete case. Please try again.';
    throw message;
  }
}

