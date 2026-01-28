import 'package:flutter/foundation.dart';
import '../../../core/models/org_model.dart';
import '../../../core/models/time_entry_model.dart';
import '../../../core/services/time_entry_service.dart';

class TimeEntryProvider with ChangeNotifier {
  final TimeEntryService _service = TimeEntryService();

  final List<TimeEntryModel> _todayEntries = [];
  TimeEntryModel? _runningEntry;

  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;

  List<TimeEntryModel> get todayEntries => List.unmodifiable(_todayEntries);
  TimeEntryModel? get runningEntry => _runningEntry;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  int get todayTotalSeconds {
    var total = 0;
    for (final e in _todayEntries) {
      total += e.durationSeconds;
    }
    return total;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clear() {
    _todayEntries.clear();
    _runningEntry = null;
    _isLoading = false;
    _isUpdating = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadMyTimeToday({
    required OrgModel org,
    String? userId,
    DateTime? from,
    DateTime? to,
    String? caseId,
    bool? billable,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final effectiveUserId = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : null;
      final effectiveCaseId = (caseId != null && caseId.trim().isNotEmpty) ? caseId.trim() : null;

      // 1) Running entry (personal view only)
      if (effectiveUserId != null) {
        final running = await _service.listTimeEntries(
          org: org,
          userId: effectiveUserId,
          status: TimeEntryStatus.running,
          limit: 1,
          offset: 0,
        );
        _runningEntry = running.entries.isNotEmpty ? running.entries.first : null;
      } else {
        _runningEntry = null;
      }

      // 2) Stopped entries for requested range (default: today)
      final now = DateTime.now();
      final defaultStart = DateTime(now.year, now.month, now.day);
      final defaultEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final rangeFrom = from ?? defaultStart;
      final rangeTo = to ?? defaultEnd;

      // Case-scoped view can include running timers for that case (across users)
      final runningForCase = (effectiveUserId == null && effectiveCaseId != null)
          ? await _service.listTimeEntries(
              org: org,
              caseId: effectiveCaseId,
              billable: billable,
              status: TimeEntryStatus.running,
              from: rangeFrom,
              to: rangeTo,
              limit: 100,
              offset: 0,
            )
          : (entries: <TimeEntryModel>[], total: 0, hasMore: false);

      final stopped = await _service.listTimeEntries(
        org: org,
        userId: effectiveUserId,
        status: TimeEntryStatus.stopped,
        from: rangeFrom,
        to: rangeTo,
        caseId: effectiveCaseId,
        billable: billable,
        limit: 200,
        offset: 0,
      );

      final combined = <TimeEntryModel>[
        ...runningForCase.entries,
        ...stopped.entries,
      ]..sort((a, b) => b.startAt.compareTo(a.startAt));

      _todayEntries
        ..clear()
        ..addAll(combined);
      _errorMessage = null;
    } catch (e) {
      final errorStr = e.toString();
      _errorMessage = errorStr.replaceFirst(RegExp(r'^Exception:\s*'), '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startTimer({
    required OrgModel org,
    required String userId,
    String? caseId,
    String? description,
    bool billable = true,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final entry = await _service.startTimer(
        org: org,
        caseId: caseId,
        description: description,
        billable: billable,
      );
      _runningEntry = entry;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> stopTimer({
    required OrgModel org,
    required String userId,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stopped = await _service.stopTimer(org: org);
      _runningEntry = null;
      // Add to today's list if it stopped today
      final now = DateTime.now();
      final endedAt = stopped.endAt ?? now;
      final isToday =
          endedAt.year == now.year &&
          endedAt.month == now.month &&
          endedAt.day == now.day;
      if (isToday) {
        _todayEntries.insert(0, stopped);
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> addManualEntry({
    required OrgModel org,
    required String userId,
    required DateTime startAt,
    required DateTime endAt,
    required String description,
    bool billable = true,
    String? caseId,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _service.createManualEntry(
        org: org,
        startAt: startAt,
        endAt: endAt,
        description: description,
        billable: billable,
        caseId: caseId,
      );
      _todayEntries.insert(0, created);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateEntry({
    required OrgModel org,
    required String timeEntryId,
    String? description,
    bool? billable,
    String? caseId,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _service.updateTimeEntry(
        org: org,
        timeEntryId: timeEntryId,
        description: description,
        billable: billable,
        caseId: caseId,
      );

      final idx = _todayEntries.indexWhere((e) => e.timeEntryId == timeEntryId);
      if (idx != -1) {
        _todayEntries[idx] = updated;
      }
      if (_runningEntry?.timeEntryId == timeEntryId) {
        _runningEntry = updated;
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry({
    required OrgModel org,
    required String timeEntryId,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    final idx = _todayEntries.indexWhere((e) => e.timeEntryId == timeEntryId);
    TimeEntryModel? removed;
    if (idx != -1) {
      removed = _todayEntries.removeAt(idx);
      notifyListeners();
    }

    try {
      await _service.deleteTimeEntry(org: org, timeEntryId: timeEntryId);
      if (_runningEntry?.timeEntryId == timeEntryId) {
        _runningEntry = null;
      }
      return true;
    } catch (e) {
      // rollback
      if (removed != null && idx != -1) {
        _todayEntries.insert(idx, removed);
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}

