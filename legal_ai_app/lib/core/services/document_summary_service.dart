import 'package:flutter/foundation.dart';

import '../models/document_summary_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service for Document Summarization (Slice 14)
class DocumentSummaryService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  /// Summarize a document
  Future<DocumentSummaryModel> summarizeDocument({
    required OrgModel org,
    required String documentId,
    String? model,
    int? maxLength,
  }) async {
    final response = await _functionsService.callFunction('summarizeDocument', {
      'orgId': org.orgId,
      'documentId': documentId,
      if (model != null || maxLength != null)
        'options': {
          if (model != null) 'model': model,
          if (maxLength != null) 'maxLength': maxLength,
        },
    });

    if (response['success'] == true && response['data'] != null) {
      return DocumentSummaryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('DocumentSummaryService.summarizeDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to summarize document. Please try again.';
    throw message;
  }

  /// Get a document summary
  Future<DocumentSummaryModel> getSummary({
    required OrgModel org,
    required String summaryId,
  }) async {
    final response = await _functionsService.callFunction('documentSummaryGet', {
      'orgId': org.orgId,
      'summaryId': summaryId,
    });

    if (response['success'] == true && response['data'] != null) {
      return DocumentSummaryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('DocumentSummaryService.getSummary error: $response');
    final message = response['error']?['message'] ??
        'Failed to get document summary. Please try again.';
    throw message;
  }

  /// List document summaries
  Future<({
    List<DocumentSummaryModel> summaries,
    int total,
    bool hasMore,
  })> listSummaries({
    required OrgModel org,
    String? documentId,
    String? caseId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _functionsService.callFunction('documentSummaryList', {
      'orgId': org.orgId,
      if (documentId != null) 'documentId': documentId,
      if (caseId != null) 'caseId': caseId,
      'limit': limit,
      'offset': offset,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final summaries = (data['summaries'] as List<dynamic>? ?? [])
          .map((s) {
            final map = Map<String, dynamic>.from(s as Map);
            return DocumentSummaryModel.fromJson(map);
          })
          .toList();
      final total = data['total'] as int? ?? summaries.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (summaries: summaries, total: total, hasMore: hasMore);
    }

    debugPrint('DocumentSummaryService.listSummaries error: $response');
    final message = response['error']?['message'] ??
        'Failed to list document summaries. Please try again.';
    throw message;
  }
}
