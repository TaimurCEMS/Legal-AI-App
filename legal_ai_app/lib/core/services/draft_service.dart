import 'package:flutter/foundation.dart';

import '../models/draft_model.dart';
import '../models/draft_template_model.dart';
import '../models/org_model.dart';
import '../models/chat_thread_model.dart';
import 'cloud_functions_service.dart';

class DraftService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<List<DraftTemplateModel>> listTemplates({
    required OrgModel org,
    JurisdictionModel? jurisdiction,
  }) async {
    final response = await _functionsService.callFunction('draftTemplateList', {
      'orgId': org.orgId,
      if (jurisdiction != null && jurisdiction.isNotEmpty)
        'jurisdiction': jurisdiction.toJson(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['templates'] as List<dynamic>? ?? [])
          .map((e) => DraftTemplateModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list;
    }

    debugPrint('DraftService.listTemplates error: $response');
    final message = response['error']?['message'] ??
        'Failed to load templates. Please try again.';
    throw message;
  }

  Future<DraftModel> createDraft({
    required OrgModel org,
    required String caseId,
    required String templateId,
    String? title,
    Map<String, String>? variables,
    JurisdictionModel? jurisdiction,
  }) async {
    final response = await _functionsService.callFunction('draftCreate', {
      'orgId': org.orgId,
      'caseId': caseId,
      'templateId': templateId,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (variables != null) 'variables': variables,
      if (jurisdiction != null && jurisdiction.isNotEmpty)
        'jurisdiction': jurisdiction.toJson(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return DraftModel.fromJson(Map<String, dynamic>.from(data['draft'] as Map));
    }

    debugPrint('DraftService.createDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to create draft. Please try again.';
    throw message;
  }

  Future<Map<String, dynamic>> generateDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
    String? prompt,
    Map<String, String>? variables,
    String model = 'gpt-4o-mini',
    JurisdictionModel? jurisdiction,
  }) async {
    final response = await _functionsService.callFunction('draftGenerate', {
      'orgId': org.orgId,
      'caseId': caseId,
      'draftId': draftId,
      if (prompt != null) 'prompt': prompt,
      if (variables != null) 'variables': variables,
      'options': {'model': model},
      if (jurisdiction != null && jurisdiction.isNotEmpty)
        'jurisdiction': jurisdiction.toJson(),
    });

    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    debugPrint('DraftService.generateDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to start draft generation. Please try again.';
    throw message;
  }

  Future<DraftModel> getDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
  }) async {
    final response = await _functionsService.callFunction('draftGet', {
      'orgId': org.orgId,
      'caseId': caseId,
      'draftId': draftId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return DraftModel.fromJson(Map<String, dynamic>.from(data['draft'] as Map));
    }

    debugPrint('DraftService.getDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to load draft. Please try again.';
    throw message;
  }

  Future<({List<DraftModel> drafts, int total, bool hasMore})> listDrafts({
    required OrgModel org,
    required String caseId,
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final response = await _functionsService.callFunction('draftList', {
      'orgId': org.orgId,
      'caseId': caseId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final drafts = (data['drafts'] as List<dynamic>? ?? [])
          .map((e) => DraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? drafts.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (drafts: drafts, total: total, hasMore: hasMore);
    }

    debugPrint('DraftService.listDrafts error: $response');
    final message = response['error']?['message'] ??
        'Failed to load drafts. Please try again.';
    throw message;
  }

  Future<DraftModel> updateDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
    String? title,
    String? content,
    Map<String, String>? variables,
    bool createVersion = true,
    String? versionNote,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'caseId': caseId,
      'draftId': draftId,
      'createVersion': createVersion,
    };
    if (title != null) payload['title'] = title;
    if (content != null) payload['content'] = content;
    if (variables != null) payload['variables'] = variables;
    if (versionNote != null && versionNote.trim().isNotEmpty) {
      payload['versionNote'] = versionNote.trim();
    }

    final response = await _functionsService.callFunction('draftUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return DraftModel.fromJson(Map<String, dynamic>.from(data['draft'] as Map));
    }

    debugPrint('DraftService.updateDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to update draft. Please try again.';
    throw message;
  }

  Future<void> deleteDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
  }) async {
    final response = await _functionsService.callFunction('draftDelete', {
      'orgId': org.orgId,
      'caseId': caseId,
      'draftId': draftId,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('DraftService.deleteDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to delete draft. Please try again.';
    throw message;
  }

  Future<Map<String, dynamic>> exportDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
    required String format, // 'docx' | 'pdf'
  }) async {
    final response = await _functionsService.callFunction('draftExport', {
      'orgId': org.orgId,
      'caseId': caseId,
      'draftId': draftId,
      'format': format,
    });

    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    debugPrint('DraftService.exportDraft error: $response');
    final message = response['error']?['message'] ??
        'Failed to export draft. Please try again.';
    throw message;
  }
}

