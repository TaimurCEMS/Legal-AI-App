import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/models/draft_model.dart';
import '../../../core/models/draft_template_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/models/chat_thread_model.dart';
import '../../../core/services/draft_service.dart';

class DraftProvider extends ChangeNotifier {
  final DraftService _draftService = DraftService();

  List<DraftTemplateModel> _templates = [];
  List<DraftModel> _drafts = [];
  DraftModel? _selectedDraft;

  int _pollGenerationToken = 0;

  bool _isLoadingTemplates = false;
  bool _isLoadingDrafts = false;
  bool _isWorking = false; // generate/export/save actions
  String? _error;

  List<DraftTemplateModel> get templates => _templates;
  List<DraftModel> get drafts => _drafts;
  DraftModel? get selectedDraft => _selectedDraft;
  bool get isLoadingTemplates => _isLoadingTemplates;
  bool get isLoadingDrafts => _isLoadingDrafts;
  bool get isWorking => _isWorking;
  String? get error => _error;

  void cancelActivePolling() {
    _pollGenerationToken++;
  }

  void clear() {
    cancelActivePolling();
    _templates = [];
    _drafts = [];
    _selectedDraft = null;
    _isLoadingTemplates = false;
    _isLoadingDrafts = false;
    _isWorking = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadTemplates({
    required OrgModel org,
    JurisdictionModel? jurisdiction,
  }) async {
    if (_isLoadingTemplates) return;
    try {
      _isLoadingTemplates = true;
      _error = null;
      notifyListeners();

      _templates = await _draftService.listTemplates(
        org: org,
        jurisdiction: jurisdiction,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.loadTemplates error: $e');
    } finally {
      _isLoadingTemplates = false;
      notifyListeners();
    }
  }

  Future<void> loadDrafts({
    required OrgModel org,
    required String caseId,
    bool refresh = false,
  }) async {
    if (_isLoadingDrafts) return;
    try {
      _isLoadingDrafts = true;
      _error = null;
      if (refresh) _drafts = [];
      notifyListeners();

      final result = await _draftService.listDrafts(
        org: org,
        caseId: caseId,
        limit: 50,
        offset: 0,
      );
      _drafts = result.drafts;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.loadDrafts error: $e');
    } finally {
      _isLoadingDrafts = false;
      notifyListeners();
    }
  }

  Future<DraftModel?> createDraft({
    required OrgModel org,
    required String caseId,
    required DraftTemplateModel template,
  }) async {
    if (_isWorking) return null;
    try {
      _isWorking = true;
      _error = null;
      notifyListeners();

      final draft = await _draftService.createDraft(
        org: org,
        caseId: caseId,
        templateId: template.templateId,
        title: template.name,
        variables: const {},
      );
      _selectedDraft = draft;
      // Put it at top of drafts list
      _drafts = [draft, ..._drafts.where((d) => d.draftId != draft.draftId)];
      notifyListeners();
      return draft;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.createDraft error: $e');
      return null;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  Future<DraftModel?> loadDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
  }) async {
    try {
      _error = null;
      notifyListeners();

      final draft = await _draftService.getDraft(
        org: org,
        caseId: caseId,
        draftId: draftId,
      );
      _selectedDraft = draft;
      // Update list copy if present
      final idx = _drafts.indexWhere((d) => d.draftId == draftId);
      if (idx != -1) {
        _drafts[idx] = draft;
      }
      notifyListeners();
      return draft;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.loadDraft error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<DraftModel?> updateDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
    String? title,
    String? content,
    Map<String, String>? variables,
    bool createVersion = true,
    String? versionNote,
  }) async {
    if (_isWorking) return null;
    try {
      _isWorking = true;
      _error = null;
      notifyListeners();

      final updated = await _draftService.updateDraft(
        org: org,
        caseId: caseId,
        draftId: draftId,
        title: title,
        content: content,
        variables: variables,
        createVersion: createVersion,
        versionNote: versionNote,
      );

      _selectedDraft = updated;
      final idx = _drafts.indexWhere((d) => d.draftId == draftId);
      if (idx != -1) {
        _drafts[idx] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.updateDraft error: $e');
      return null;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  Future<DraftModel?> generateDraftAndPoll({
    required OrgModel org,
    required String caseId,
    required String draftId,
    String? prompt,
    required Map<String, String> variables,
    JurisdictionModel? jurisdiction,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_isWorking) return null;
    try {
      _isWorking = true;
      _error = null;
      notifyListeners();

      // Cancel any previous polling loop and start a new one.
      final token = ++_pollGenerationToken;

      await _draftService.generateDraft(
        org: org,
        caseId: caseId,
        draftId: draftId,
        prompt: prompt,
        variables: variables,
        jurisdiction: jurisdiction,
      );

      final deadline = DateTime.now().add(timeout);
      DraftModel? latest;

      while (DateTime.now().isBefore(deadline)) {
        if (token != _pollGenerationToken) break; // cancelled (dispose/org switch/new request)
        await Future.delayed(pollInterval);
        if (token != _pollGenerationToken) break;
        latest = await loadDraft(org: org, caseId: caseId, draftId: draftId);
        if (latest == null) continue;
        if (!latest.isGenerating) {
          break;
        }
      }

      return latest;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.generateDraftAndPoll error: $e');
      return null;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  Future<String?> exportDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
    required String format, // docx | pdf
  }) async {
    if (_isWorking) return null;
    try {
      _isWorking = true;
      _error = null;
      notifyListeners();

      final result = await _draftService.exportDraft(
        org: org,
        caseId: caseId,
        draftId: draftId,
        format: format,
      );
      final documentId = result['documentId'] as String?;
      return documentId;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.exportDraft error: $e');
      return null;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDraft({
    required OrgModel org,
    required String caseId,
    required String draftId,
  }) async {
    if (_isWorking) return false;
    try {
      _isWorking = true;
      _error = null;
      notifyListeners();

      await _draftService.deleteDraft(org: org, caseId: caseId, draftId: draftId);
      _drafts.removeWhere((d) => d.draftId == draftId);
      if (_selectedDraft?.draftId == draftId) _selectedDraft = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('DraftProvider.deleteDraft error: $e');
      return false;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }
}

