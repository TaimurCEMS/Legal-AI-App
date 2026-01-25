import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service wrapper around CloudFunctionsService for document operations.
class DocumentService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<DocumentModel> createDocument({
    required OrgModel org,
    required String name,
    required String storagePath,
    required String fileType,
    required int fileSize,
    String? description,
    String? caseId,
  }) async {
    final response = await _functionsService.callFunction('documentCreate', {
      'orgId': org.orgId,
      'name': name,
      'storagePath': storagePath,
      'fileType': fileType,
      'fileSize': fileSize,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      return DocumentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('DocumentService.createDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to create document. Please try again.';
    throw message;
  }

  Future<DocumentModel> getDocument({
    required OrgModel org,
    required String documentId,
  }) async {
    final response = await _functionsService.callFunction('documentGet', {
      'orgId': org.orgId,
      'documentId': documentId,
    });

    if (response['success'] == true && response['data'] != null) {
      return DocumentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('DocumentService.getDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to load document. Please try again.';
    throw message;
  }

  Future<({List<DocumentModel> documents, int total, bool hasMore})> listDocuments({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? search,
    String? caseId,
  }) async {
    final response = await _functionsService.callFunction('documentList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['documents'] as List<dynamic>? ?? [])
          .map((e) => DocumentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (documents: list, total: total, hasMore: hasMore);
    }

    debugPrint('DocumentService.listDocuments error: $response');
    final message = response['error']?['message'] ??
        'Failed to load documents. Please try again.';
    throw message;
  }

  Future<DocumentModel> updateDocument({
    required OrgModel org,
    required String documentId,
    String? name,
    String? description,
    String? caseId,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'documentId': documentId,
    };

    if (name != null) payload['name'] = name.trim();
    if (description != null) {
      payload['description'] = description.trim().isEmpty ? null : description.trim();
    }
    if (caseId != null) {
      payload['caseId'] = caseId.trim().isEmpty ? null : caseId.trim();
    }

    final response = await _functionsService.callFunction('documentUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return DocumentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('DocumentService.updateDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to update document. Please try again.';
    throw message;
  }

  Future<void> deleteDocument({
    required OrgModel org,
    required String documentId,
  }) async {
    final response = await _functionsService.callFunction('documentDelete', {
      'orgId': org.orgId,
      'documentId': documentId,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('DocumentService.deleteDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to delete document. Please try again.';
    throw message;
  }

  // ============================================================
  // Text Extraction Methods (Slice 6a)
  // ============================================================

  /// Trigger text extraction for a document
  /// Returns the job ID for tracking extraction progress
  Future<Map<String, dynamic>> extractDocument({
    required OrgModel org,
    required String documentId,
    bool forceReExtract = false,
  }) async {
    final response = await _functionsService.callFunction('documentExtract', {
      'orgId': org.orgId,
      'documentId': documentId,
      'forceReExtract': forceReExtract,
    });

    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    debugPrint('DocumentService.extractDocument error: $response');
    final message = response['error']?['message'] ??
        'Failed to start text extraction. Please try again.';
    throw message;
  }

  /// Get the extraction status for a document
  Future<Map<String, dynamic>> getExtractionStatus({
    required OrgModel org,
    required String documentId,
  }) async {
    final response = await _functionsService.callFunction('documentGetExtractionStatus', {
      'orgId': org.orgId,
      'documentId': documentId,
    });

    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    debugPrint('DocumentService.getExtractionStatus error: $response');
    final message = response['error']?['message'] ??
        'Failed to get extraction status. Please try again.';
    throw message;
  }
}
