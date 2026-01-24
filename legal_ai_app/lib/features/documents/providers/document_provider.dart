import 'package:flutter/foundation.dart';

import '../../../core/models/document_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/document_service.dart';

class DocumentProvider with ChangeNotifier {
  final DocumentService _documentService = DocumentService();

  final List<DocumentModel> _documents = [];
  DocumentModel? _selectedDocument;
  bool _isLoading = false;
  String? _errorMessage;
  double? _uploadProgress;
  String? _lastLoadedCaseId; // Track last loaded caseId for auto-refresh
  String? _lastLoadedOrgId; // Track last loaded orgId to prevent unnecessary reloads

  List<DocumentModel> get documents => List.unmodifiable(_documents);
  DocumentModel? get selectedDocument => _selectedDocument;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  double? get uploadProgress => _uploadProgress;
  String? get lastLoadedCaseId => _lastLoadedCaseId;

  Future<void> loadDocuments({
    required OrgModel org,
    String? search,
    String? caseId,
  }) async {
    // Prevent duplicate loads for the same org/case/search combination
    if (_isLoading && _lastLoadedOrgId == org.orgId && _lastLoadedCaseId == caseId) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _documents.clear(); // Clear existing documents to show loading state immediately
    _lastLoadedCaseId = caseId; // Track caseId for auto-refresh
    _lastLoadedOrgId = org.orgId; // Track orgId
    notifyListeners();

    try {
      final result = await _documentService.listDocuments(
        org: org,
        search: search,
        caseId: caseId,
      );
      // Clear and replace to prevent duplicates
      _documents.clear();
      // Use a Set to ensure no duplicates by documentId
      final existingIds = <String>{};
      for (final doc in result.documents) {
        if (!existingIds.contains(doc.documentId)) {
          _documents.add(doc);
          existingIds.add(doc.documentId);
        }
      }
      _errorMessage = null; // Clear error on success
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDocumentDetails({
    required OrgModel org,
    required String documentId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final document = await _documentService.getDocument(
        org: org,
        documentId: documentId,
      );
      _selectedDocument = document;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _selectedDocument = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDocument({
    required OrgModel org,
    required String name,
    required String storagePath,
    required String fileType,
    required int fileSize,
    String? description,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _uploadProgress = null; // Clear upload progress when starting document creation
    
    // Optimistic UI update: Add document to list immediately
    // This makes the document appear instantly while backend confirms
    final optimisticDoc = DocumentModel(
      documentId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      orgId: org.orgId,
      caseId: caseId,
      name: name,
      description: description,
      fileType: fileType,
      fileSize: fileSize,
      storagePath: storagePath,
      downloadUrl: null, // Will be set after backend confirms
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: '', // Will be set by backend
      updatedBy: '',
      deletedAt: null,
    );
    
    // Only add optimistically if we're viewing documents for this case/org
    if ((caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) ||
        (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId)) {
      _documents.add(optimisticDoc);
    }
    
    notifyListeners();

    try {
      final createdDoc = await _documentService.createDocument(
        org: org,
        name: name,
        storagePath: storagePath,
        fileType: fileType,
        fileSize: fileSize,
        description: description,
        caseId: caseId,
      );
      
      // Remove optimistic document and add real one
      _documents.removeWhere((d) => d.documentId.startsWith('temp_'));
      _documents.add(createdDoc);
      
      // Reload documents to ensure we have the latest data (download URL, etc.)
      if (caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) {
        // Reload documents for this case (in background, don't block)
        loadDocuments(org: org, caseId: caseId).catchError((e) {
          debugPrint('Error reloading documents after create: $e');
        });
      } else if (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId) {
        // Reload general documents list (in background, don't block)
        loadDocuments(org: org).catchError((e) {
          debugPrint('Error reloading documents after create: $e');
        });
      } else {
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      // Remove optimistic document on error
      _documents.removeWhere((d) => d.documentId.startsWith('temp_'));
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      _uploadProgress = null; // Ensure progress is cleared
      notifyListeners();
    }
  }

  Future<bool> updateDocument({
    required OrgModel org,
    required String documentId,
    String? name,
    String? description,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _documentService.updateDocument(
        org: org,
        documentId: documentId,
        name: name,
        description: description,
        caseId: caseId,
      );
      // Update local document if it exists in the list
      final index = _documents.indexWhere((d) => d.documentId == documentId);
      if (index != -1) {
        _documents[index] = DocumentModel(
          documentId: _documents[index].documentId,
          orgId: _documents[index].orgId,
          caseId: caseId ?? _documents[index].caseId,
          name: name ?? _documents[index].name,
          description: description ?? _documents[index].description,
          fileType: _documents[index].fileType,
          fileSize: _documents[index].fileSize,
          storagePath: _documents[index].storagePath,
          downloadUrl: _documents[index].downloadUrl,
          createdAt: _documents[index].createdAt,
          updatedAt: DateTime.now(),
          createdBy: _documents[index].createdBy,
          updatedBy: _documents[index].updatedBy,
          deletedAt: _documents[index].deletedAt,
        );
      }
      // Reload selected document if it's the one being updated
      if (_selectedDocument?.documentId == documentId) {
        await loadDocumentDetails(org: org, documentId: documentId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDocument({
    required OrgModel org,
    required String documentId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _documentService.deleteDocument(
        org: org,
        documentId: documentId,
      );
      // Remove from local list
      _documents.removeWhere((d) => d.documentId == documentId);
      if (_selectedDocument?.documentId == documentId) {
        _selectedDocument = null;
      }
      // Don't auto-reload - just notify listeners
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUploadProgress(double? progress) {
    // Don't notify listeners on progress updates to prevent refresh loops
    // Progress is handled locally in the upload screen
    _uploadProgress = progress;
    // Only notify on completion (null) or significant milestones
    if (progress == null || progress >= 1.0) {
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all documents (used when switching organizations)
  void clearDocuments() {
    _documents.clear();
    _selectedDocument = null;
    _errorMessage = null;
    _isLoading = false;
    _uploadProgress = null;
    _lastLoadedCaseId = null;
    _lastLoadedOrgId = null;
    notifyListeners();
  }
}
