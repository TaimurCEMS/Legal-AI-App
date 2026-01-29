import 'package:flutter/foundation.dart';
import '../models/audit_event_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

class AuditService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<({List<AuditEventModel> events, int total, bool hasMore})> listAuditEvents({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? search,
    String? entityType,
    String? action,
    String? actorUid,
    String? entityId,
    String? caseId,
    DateTime? fromAt,
    DateTime? toAt,
  }) async {
    final response = await _functionsService.callFunction('auditList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (entityType != null && entityType.trim().isNotEmpty)
        'entityType': entityType.trim(),
      if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
      if (actorUid != null && actorUid.trim().isNotEmpty) 'actorUid': actorUid.trim(),
      if (entityId != null && entityId.trim().isNotEmpty) 'entityId': entityId.trim(),
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (fromAt != null) 'fromAt': fromAt.toUtc().toIso8601String(),
      if (toAt != null) 'toAt': toAt.toUtc().toIso8601String(),
      'includeMetadata': true,
      'includeActorDetails': true,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['events'] as List<dynamic>? ?? [])
          .map((e) => AuditEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['totalCount'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (events: list, total: total, hasMore: hasMore);
    }

    debugPrint('AuditService.listAuditEvents error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to load audit events. Please try again.';
    throw message;
  }

  /// Export audit events as CSV using current filters. Returns CSV string.
  Future<String> exportAuditEvents({
    required OrgModel org,
    int limit = 2000,
    String? search,
    String? entityType,
    String? action,
    String? actorUid,
    String? entityId,
    String? caseId,
    DateTime? fromAt,
    DateTime? toAt,
  }) async {
    final response = await _functionsService.callFunction('auditExport', {
      'orgId': org.orgId,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (entityType != null && entityType.trim().isNotEmpty)
        'entityType': entityType.trim(),
      if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
      if (actorUid != null && actorUid.trim().isNotEmpty) 'actorUid': actorUid.trim(),
      if (entityId != null && entityId.trim().isNotEmpty) 'entityId': entityId.trim(),
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (fromAt != null) 'fromAt': fromAt.toUtc().toIso8601String(),
      if (toAt != null) 'toAt': toAt.toUtc().toIso8601String(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final csv = data['csv'] as String? ?? '';
      return csv;
    }

    debugPrint('AuditService.exportAuditEvents error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to export audit events. Please try again.';
    throw message;
  }
}

