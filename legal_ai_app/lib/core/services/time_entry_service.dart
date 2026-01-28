import 'package:flutter/foundation.dart';
import '../models/org_model.dart';
import '../models/time_entry_model.dart';
import 'cloud_functions_service.dart';

class TimeEntryService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  /// Always send timestamps as UTC ISO-8601 with "Z" to avoid timezone ambiguity.
  /// (If we send a local ISO string without an offset, the backend may interpret it as UTC.)
  String _toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

  Future<TimeEntryModel> startTimer({
    required OrgModel org,
    String? caseId,
    String? clientId,
    String? description,
    bool billable = true,
  }) async {
    final response = await _functionsService.callFunction('timeEntryStartTimer', {
      'orgId': org.orgId,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      if (description != null) 'description': description,
      'billable': billable,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return TimeEntryModel.fromJson(Map<String, dynamic>.from(data['timeEntry'] as Map));
    }

    debugPrint('TimeEntryService.startTimer error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to start timer. Please try again.';
    throw message;
  }

  Future<TimeEntryModel> stopTimer({
    required OrgModel org,
    String? timeEntryId,
  }) async {
    final response = await _functionsService.callFunction('timeEntryStopTimer', {
      'orgId': org.orgId,
      if (timeEntryId != null && timeEntryId.trim().isNotEmpty) 'timeEntryId': timeEntryId.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return TimeEntryModel.fromJson(Map<String, dynamic>.from(data['timeEntry'] as Map));
    }

    debugPrint('TimeEntryService.stopTimer error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to stop timer. Please try again.';
    throw message;
  }

  Future<TimeEntryModel> createManualEntry({
    required OrgModel org,
    required DateTime startAt,
    required DateTime endAt,
    required String description,
    bool billable = true,
    String? caseId,
    String? clientId,
  }) async {
    final response = await _functionsService.callFunction('timeEntryCreate', {
      'orgId': org.orgId,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      'description': description,
      'billable': billable,
      'startAt': _toUtcIso(startAt),
      'endAt': _toUtcIso(endAt),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return TimeEntryModel.fromJson(Map<String, dynamic>.from(data['timeEntry'] as Map));
    }

    debugPrint('TimeEntryService.createManualEntry error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to create time entry. Please try again.';
    throw message;
  }

  Future<({List<TimeEntryModel> entries, int total, bool hasMore})> listTimeEntries({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? caseId,
    String? clientId,
    String? userId,
    bool? billable,
    DateTime? from,
    DateTime? to,
    TimeEntryStatus? status,
  }) async {
    final response = await _functionsService.callFunction('timeEntryList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      if (billable != null) 'billable': billable,
      if (from != null) 'from': _toUtcIso(from),
      if (to != null) 'to': _toUtcIso(to),
      if (status != null) 'status': status.value,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['timeEntries'] as List<dynamic>? ?? [])
          .map((e) => TimeEntryModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (entries: list, total: total, hasMore: hasMore);
    }

    debugPrint('TimeEntryService.listTimeEntries error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to load time entries. Please try again.';
    throw message;
  }

  Future<TimeEntryModel> updateTimeEntry({
    required OrgModel org,
    required String timeEntryId,
    String? description,
    bool? billable,
    String? caseId,
    String? clientId,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'timeEntryId': timeEntryId,
    };
    if (description != null) payload['description'] = description;
    if (billable != null) payload['billable'] = billable;
    if (caseId != null) payload['caseId'] = caseId.trim().isEmpty ? null : caseId.trim();
    if (clientId != null) payload['clientId'] = clientId.trim().isEmpty ? null : clientId.trim();
    if (startAt != null) payload['startAt'] = _toUtcIso(startAt);
    if (endAt != null) payload['endAt'] = _toUtcIso(endAt);

    final response = await _functionsService.callFunction('timeEntryUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return TimeEntryModel.fromJson(Map<String, dynamic>.from(data['timeEntry'] as Map));
    }

    debugPrint('TimeEntryService.updateTimeEntry error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to update time entry. Please try again.';
    throw message;
  }

  Future<void> deleteTimeEntry({
    required OrgModel org,
    required String timeEntryId,
  }) async {
    final response = await _functionsService.callFunction('timeEntryDelete', {
      'orgId': org.orgId,
      'timeEntryId': timeEntryId,
    });

    if (response['success'] != true) {
      debugPrint('TimeEntryService.deleteTimeEntry error: $response');
      final message =
          response['error']?['message'] ?? 'Failed to delete time entry. Please try again.';
      throw message;
    }
  }
}

