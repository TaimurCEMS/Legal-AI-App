import 'package:flutter/foundation.dart';

import '../../../core/models/document_summary_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/document_summary_service.dart';

/// Provider for Document Summary state (Slice 14)
class DocumentSummaryProvider with ChangeNotifier {
  final DocumentSummaryService _service = DocumentSummaryService();

  DocumentSummaryModel? _currentSummary;
  bool _isSummarizing = false;
  String? _errorMessage;

  DocumentSummaryModel? get currentSummary => _currentSummary;
  bool get isSummarizing => _isSummarizing;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Summarize a document
  Future<bool> summarizeDocument({
    required OrgModel org,
    required String documentId,
    String? model,
    int? maxLength,
  }) async {
    if (_isSummarizing) return false;

    _isSummarizing = true;
    _errorMessage = null;
    _currentSummary = null;
    notifyListeners();

    try {
      final summary = await _service.summarizeDocument(
        org: org,
        documentId: documentId,
        model: model,
        maxLength: maxLength,
      );
      _currentSummary = summary;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DocumentSummaryProvider.summarizeDocument error: $e');
      return false;
    } finally {
      _isSummarizing = false;
      notifyListeners();
    }
  }

  /// Get a document summary
  Future<bool> getSummary({
    required OrgModel org,
    required String summaryId,
  }) async {
    _isSummarizing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final summary = await _service.getSummary(
        org: org,
        summaryId: summaryId,
      );
      _currentSummary = summary;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DocumentSummaryProvider.getSummary error: $e');
      return false;
    } finally {
      _isSummarizing = false;
      notifyListeners();
    }
  }

  /// Load latest summary for a document
  Future<void> loadSummaryForDocument({
    required OrgModel org,
    required String documentId,
  }) async {
    try {
      final result = await _service.listSummaries(
        org: org,
        documentId: documentId,
        limit: 1,
      );

      if (result.summaries.isNotEmpty) {
        final latest = result.summaries.first;
        await getSummary(org: org, summaryId: latest.summaryId);
      } else {
        _currentSummary = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DocumentSummaryProvider.loadSummaryForDocument error: $e');
    }
  }

  /// Clear current summary
  void clear() {
    _currentSummary = null;
    _errorMessage = null;
    _isSummarizing = false;
    notifyListeners();
  }
}
