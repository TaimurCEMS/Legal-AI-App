import 'package:flutter/foundation.dart';

import '../models/contract_analysis_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service for Contract Analysis functionality (Slice 13)
class ContractAnalysisService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  /// Analyze a contract document
  Future<ContractAnalysisModel> analyzeContract({
    required OrgModel org,
    required String documentId,
    String? model,
  }) async {
    final response = await _functionsService.callFunction('contractAnalyze', {
      'orgId': org.orgId,
      'documentId': documentId,
      if (model != null) 'options': {'model': model},
    });

    if (response['success'] == true && response['data'] != null) {
      return ContractAnalysisModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('ContractAnalysisService.analyzeContract error: $response');
    final message = response['error']?['message'] ??
        'Failed to analyze contract. Please try again.';
    throw message;
  }

  /// Get a contract analysis
  Future<ContractAnalysisModel> getAnalysis({
    required OrgModel org,
    required String analysisId,
  }) async {
    final response = await _functionsService.callFunction('contractAnalysisGet', {
      'orgId': org.orgId,
      'analysisId': analysisId,
    });

    if (response['success'] == true && response['data'] != null) {
      return ContractAnalysisModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('ContractAnalysisService.getAnalysis error: $response');
    final message = response['error']?['message'] ??
        'Failed to get contract analysis. Please try again.';
    throw message;
  }

  /// List contract analyses
  Future<({
    List<ContractAnalysisModel> analyses,
    int total,
    bool hasMore,
  })> listAnalyses({
    required OrgModel org,
    String? documentId,
    String? caseId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _functionsService.callFunction('contractAnalysisList', {
      'orgId': org.orgId,
      if (documentId != null) 'documentId': documentId,
      if (caseId != null) 'caseId': caseId,
      'limit': limit,
      'offset': offset,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final analyses = (data['analyses'] as List<dynamic>? ?? [])
          .map((a) {
            // Convert summary list item to full analysis model
            // Note: List endpoint returns summary, but we need full model
            // For MVP, we'll create a minimal model from list data
            final analysisData = Map<String, dynamic>.from(a as Map);
            final createdAt = analysisData['createdAt'];
            return ContractAnalysisModel(
              analysisId: analysisData['analysisId'] as String? ?? '',
              documentId: analysisData['documentId'] as String? ?? '',
              caseId: analysisData['caseId'] as String?,
              status: analysisData['status'] as String? ?? 'completed',
              error: analysisData['error'] as String?,
              summary: analysisData['summary'] as String?,
              clauses: [], // List endpoint doesn't return full clauses
              risks: [], // List endpoint doesn't return full risks
              createdAt: createdAt != null
                  ? DateTime.tryParse(createdAt.toString()) ?? DateTime.now()
                  : DateTime.now(),
              completedAt: analysisData['completedAt'] != null
                  ? DateTime.tryParse(analysisData['completedAt'].toString())
                  : null,
              createdBy: analysisData['createdBy'] as String? ?? '',
              model: analysisData['model'] as String? ?? 'gpt-4o-mini',
            );
          })
          .toList();
      final total = data['total'] as int? ?? analyses.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (analyses: analyses, total: total, hasMore: hasMore);
    }

    debugPrint('ContractAnalysisService.listAnalyses error: $response');
    final message = response['error']?['message'] ??
        'Failed to list contract analyses. Please try again.';
    throw message;
  }
}
