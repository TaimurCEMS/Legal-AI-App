import 'package:flutter/foundation.dart';

import '../../../core/models/contract_analysis_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/contract_analysis_service.dart';

/// Provider for Contract Analysis state management (Slice 13)
class ContractAnalysisProvider with ChangeNotifier {
  final ContractAnalysisService _service = ContractAnalysisService();

  ContractAnalysisModel? _currentAnalysis;
  bool _isAnalyzing = false;
  String? _errorMessage;

  ContractAnalysisModel? get currentAnalysis => _currentAnalysis;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Analyze a contract document
  Future<bool> analyzeContract({
    required OrgModel org,
    required String documentId,
    String? model,
  }) async {
    if (_isAnalyzing) return false;

    _isAnalyzing = true;
    _errorMessage = null;
    _currentAnalysis = null;
    notifyListeners();

    try {
      final analysis = await _service.analyzeContract(
        org: org,
        documentId: documentId,
        model: model,
      );
      _currentAnalysis = analysis;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('ContractAnalysisProvider.analyzeContract error: $e');
      return false;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Get a contract analysis
  Future<bool> getAnalysis({
    required OrgModel org,
    required String analysisId,
  }) async {
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final analysis = await _service.getAnalysis(
        org: org,
        analysisId: analysisId,
      );
      _currentAnalysis = analysis;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('ContractAnalysisProvider.getAnalysis error: $e');
      return false;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Load analysis for a document (get latest or create new)
  Future<void> loadAnalysisForDocument({
    required OrgModel org,
    required String documentId,
  }) async {
    try {
      // Try to get latest analysis for this document
      final result = await _service.listAnalyses(
        org: org,
        documentId: documentId,
        limit: 1,
      );

      if (result.analyses.isNotEmpty) {
        // Get full analysis details
        final latest = result.analyses.first;
        await getAnalysis(org: org, analysisId: latest.analysisId);
      } else {
        // No analysis found, clear current
        _currentAnalysis = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ContractAnalysisProvider.loadAnalysisForDocument error: $e');
      // Don't set error - this is just a load attempt
    }
  }

  /// Clear current analysis
  void clear() {
    _currentAnalysis = null;
    _errorMessage = null;
    _isAnalyzing = false;
    notifyListeners();
  }
}
