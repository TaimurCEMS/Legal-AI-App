import 'package:flutter/foundation.dart';
import '../../../core/models/audit_event_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/audit_service.dart';

class AuditProvider with ChangeNotifier {
  final AuditService _service = AuditService();

  final List<AuditEventModel> _events = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;

  // Current filters
  String? _search;
  String? _entityType;
  String? _action;
  String? _actorUid;
  String? _entityId;
  String? _caseId;
  DateTime? _fromAt;
  DateTime? _toAt;

  int _offset = 0;
  final int _pageSize = 50;

  List<AuditEventModel> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clear() {
    _events.clear();
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = false;
    _errorMessage = null;
    _search = null;
    _entityType = null;
    _action = null;
    _actorUid = null;
    _entityId = null;
    _caseId = null;
    _fromAt = null;
    _toAt = null;
    _offset = 0;
    notifyListeners();
  }

  Future<void> refresh({
    required OrgModel org,
    String? search,
    String? entityType,
    String? action,
    String? actorUid,
    String? entityId,
    String? caseId,
    DateTime? fromAt,
    DateTime? toAt,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _search = search;
    _entityType = entityType;
    _action = action;
    _actorUid = actorUid;
    _entityId = entityId;
    _caseId = caseId;
    _fromAt = fromAt;
    _toAt = toAt;
    _offset = 0;

    try {
      final res = await _service.listAuditEvents(
        org: org,
        limit: _pageSize,
        offset: 0,
        search: _search,
        entityType: _entityType,
        action: _action,
        actorUid: _actorUid,
        entityId: _entityId,
        caseId: _caseId,
        fromAt: _fromAt,
        toAt: _toAt,
      );
      _events
        ..clear()
        ..addAll(res.events);
      _hasMore = res.hasMore;
      _offset = _events.length;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({required OrgModel org}) async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.listAuditEvents(
        org: org,
        limit: _pageSize,
        offset: _offset,
        search: _search,
        entityType: _entityType,
        action: _action,
        actorUid: _actorUid,
        entityId: _entityId,
        caseId: _caseId,
        fromAt: _fromAt,
        toAt: _toAt,
      );
      _events.addAll(res.events);
      _hasMore = res.hasMore;
      _offset = _events.length;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Export audit events as CSV using the given filters. Returns CSV string.
  Future<String> export({
    required OrgModel org,
    String? search,
    String? entityType,
    String? actorUid,
    DateTime? fromAt,
    DateTime? toAt,
  }) async {
    return _service.exportAuditEvents(
      org: org,
      limit: 2000,
      search: search,
      entityType: entityType,
      action: _action,
      actorUid: actorUid ?? _actorUid,
      entityId: _entityId,
      caseId: _caseId,
      fromAt: fromAt,
      toAt: toAt,
    );
  }
}

