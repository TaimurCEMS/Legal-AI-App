import 'package:flutter/foundation.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/event_service.dart';

/// Provider for Calendar & Court Dates (Slice 7)
///
/// Manages event state including list, selected event, loading states,
/// and pagination with cursor-based navigation.
class EventProvider with ChangeNotifier {
  final EventService _eventService = EventService();

  final List<EventModel> _events = [];
  EventModel? _selectedEvent;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  String? _nextCursor;
  bool _hasMore = false;
  String? _lastLoadedOrgId;
  String? _lastLoadedCaseId;
  String? _lastQuerySignature;

  // Getters
  List<EventModel> get events => List.unmodifiable(_events);
  EventModel? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String? get nextCursor => _nextCursor;
  bool get hasMore => _hasMore;

  /// Get events for today
  List<EventModel> get todayEvents {
    final now = DateTime.now();
    return _events.where((e) {
      return e.startDateTime.year == now.year &&
          e.startDateTime.month == now.month &&
          e.startDateTime.day == now.day;
    }).toList();
  }

  /// Get upcoming events (next 7 days)
  List<EventModel> get upcomingEvents {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _events.where((e) {
      return e.startDateTime.isAfter(now) &&
          e.startDateTime.isBefore(weekFromNow) &&
          e.status == EventStatus.scheduled;
    }).toList();
  }

  /// Get events grouped by date
  Map<DateTime, List<EventModel>> get eventsByDate {
    final grouped = <DateTime, List<EventModel>>{};
    for (final event in _events) {
      final dateOnly = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      grouped.putIfAbsent(dateOnly, () => []).add(event);
    }
    return grouped;
  }

  /// Load events with optional filters
  Future<void> loadEvents({
    required OrgModel org,
    String? search,
    String? caseId,
    EventType? eventType,
    EventStatus? status,
    EventPriority? priority,
    String? startDate,
    String? endDate,
    bool refresh = false,
  }) async {
    // Create query signature to prevent duplicate loads
    final querySignature =
        '${org.orgId}_${caseId ?? 'null'}_${search ?? 'null'}_${eventType?.value ?? 'null'}_${status?.value ?? 'null'}_${priority?.value ?? 'null'}_${startDate ?? 'null'}_${endDate ?? 'null'}';

    // Prevent duplicate loads
    if (_isLoading && _lastQuerySignature == querySignature && !refresh) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    
    if (refresh) {
      _events.clear();
      _nextCursor = null;
    }
    
    _lastLoadedOrgId = org.orgId;
    _lastLoadedCaseId = caseId;
    _lastQuerySignature = querySignature;
    notifyListeners();

    try {
      debugPrint(
          'EventProvider.loadEvents: Loading with filters - caseId: $caseId, eventType: ${eventType?.value}');
      
      final result = await _eventService.listEvents(
        org: org,
        pageSize: 50,
        cursor: refresh ? null : _nextCursor,
        search: search,
        caseId: caseId,
        eventType: eventType,
        status: status,
        priority: priority,
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint(
          'EventProvider.loadEvents: Received ${result.events.length} events');

      // Use Set to avoid duplicates
      final existingIds = _events.map((e) => e.eventId).toSet();
      for (final event in result.events) {
        if (!existingIds.contains(event.eventId)) {
          _events.add(event);
          existingIds.add(event.eventId);
        }
      }

      _nextCursor = result.nextCursor;
      _hasMore = result.hasMore;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      debugPrint('EventProvider.loadEvents error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more events (pagination)
  Future<void> loadMoreEvents({required OrgModel org}) async {
    if (_isLoading || !_hasMore || _nextCursor == null) return;
    
    await loadEvents(
      org: org,
      caseId: _lastLoadedCaseId,
    );
  }

  /// Load event details
  Future<void> loadEventDetails({
    required OrgModel org,
    required String eventId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final event = await _eventService.getEvent(org: org, eventId: eventId);
      _selectedEvent = event;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _selectedEvent = null;
      debugPrint('EventProvider.loadEventDetails error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new event
  Future<bool> createEvent({
    required OrgModel org,
    required String title,
    String? description,
    required EventType eventType,
    required DateTime startDateTime,
    DateTime? endDateTime,
    bool allDay = false,
    String? location,
    List<String>? attendeeUids,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    EventVisibility visibility = EventVisibility.org,
    String? caseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    // Optimistic UI update
    final optimisticEventId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticEvent = EventModel(
      eventId: optimisticEventId,
      orgId: org.orgId,
      caseId: caseId,
      title: title,
      description: description,
      eventType: eventType,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      allDay: allDay,
      location: location,
      attendeeUids: attendeeUids ?? [],
      reminders: reminders ?? [],
      recurrence: recurrence,
      priority: priority ?? EventPriority.medium,
      notes: notes,
      status: EventStatus.scheduled,
      visibility: visibility,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: '',
      updatedBy: '',
    );

    // Only add optimistically if we're viewing matching context
    if ((caseId != null && _lastLoadedCaseId == caseId && _lastLoadedOrgId == org.orgId) ||
        (caseId == null && _lastLoadedCaseId == null && _lastLoadedOrgId == org.orgId)) {
      _events.insert(0, optimisticEvent);
      // Re-sort by start date
      _events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    }

    notifyListeners();

    try {
      final createdEvent = await _eventService.createEvent(
        org: org,
        title: title,
        description: description,
        eventType: eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: allDay,
        location: location,
        attendeeUids: attendeeUids,
        reminders: reminders,
        recurrence: recurrence,
        priority: priority,
        notes: notes,
        visibility: visibility,
        caseId: caseId,
      );

      // Replace optimistic event with real one
      _events.removeWhere((e) => e.eventId == optimisticEventId);
      _events.add(createdEvent);
      _events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      debugPrint(
          'EventProvider.createEvent: Created event ${createdEvent.eventId}');
      notifyListeners();
      return true;
    } catch (e) {
      // Rollback optimistic update
      _events.removeWhere((e) => e.eventId == optimisticEventId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing event
  Future<bool> updateEvent({
    required OrgModel org,
    required String eventId,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? allDay,
    String? location,
    List<String>? attendeeUids,
    List<ReminderModel>? reminders,
    RecurrenceModel? recurrence,
    EventPriority? priority,
    String? notes,
    EventStatus? status,
    EventVisibility? visibility,
    String? caseId,
    bool clearDescription = false,
    bool clearEndDateTime = false,
    bool clearLocation = false,
    bool clearNotes = false,
    bool clearRecurrence = false,
    bool clearCaseId = false,
  }) async {
    _isUpdating = true;
    _errorMessage = null;

    // Optimistic UI update
    final eventIndex = _events.indexWhere((e) => e.eventId == eventId);
    EventModel? previousEvent;
    
    if (eventIndex != -1) {
      previousEvent = _events[eventIndex];
      _events[eventIndex] = previousEvent.copyWith(
        title: title ?? previousEvent.title,
        description: clearDescription ? null : (description ?? previousEvent.description),
        eventType: eventType ?? previousEvent.eventType,
        startDateTime: startDateTime ?? previousEvent.startDateTime,
        endDateTime: clearEndDateTime ? null : (endDateTime ?? previousEvent.endDateTime),
        allDay: allDay ?? previousEvent.allDay,
        location: clearLocation ? null : (location ?? previousEvent.location),
        attendeeUids: attendeeUids ?? previousEvent.attendeeUids,
        reminders: reminders ?? previousEvent.reminders,
        recurrence: clearRecurrence ? null : (recurrence ?? previousEvent.recurrence),
        priority: priority ?? previousEvent.priority,
        notes: clearNotes ? null : (notes ?? previousEvent.notes),
        status: status ?? previousEvent.status,
        visibility: visibility ?? previousEvent.visibility,
        caseId: clearCaseId ? null : (caseId ?? previousEvent.caseId),
        updatedAt: DateTime.now(),
      );
    }

    if (_selectedEvent?.eventId == eventId && previousEvent != null) {
      _selectedEvent = _events[eventIndex];
    }

    notifyListeners();

    try {
      final updatedEvent = await _eventService.updateEvent(
        org: org,
        eventId: eventId,
        title: title,
        description: description,
        eventType: eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: allDay,
        location: location,
        attendeeUids: attendeeUids,
        reminders: reminders,
        recurrence: recurrence,
        priority: priority,
        notes: notes,
        status: status,
        visibility: visibility,
        caseId: caseId,
        clearDescription: clearDescription,
        clearEndDateTime: clearEndDateTime,
        clearLocation: clearLocation,
        clearNotes: clearNotes,
        clearRecurrence: clearRecurrence,
        clearCaseId: clearCaseId,
      );

      // Replace with server data
      if (eventIndex != -1) {
        _events[eventIndex] = updatedEvent;
        // Re-sort if start date changed
        _events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      }
      if (_selectedEvent?.eventId == eventId) {
        _selectedEvent = updatedEvent;
      }

      notifyListeners();
      return true;
    } catch (e) {
      // Rollback
      if (eventIndex != -1 && previousEvent != null) {
        _events[eventIndex] = previousEvent;
      }
      if (_selectedEvent?.eventId == eventId && previousEvent != null) {
        _selectedEvent = previousEvent;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Delete an event
  Future<bool> deleteEvent({
    required OrgModel org,
    required String eventId,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    // Optimistic UI update
    final eventIndex = _events.indexWhere((e) => e.eventId == eventId);
    EventModel? removedEvent;
    
    if (eventIndex != -1) {
      removedEvent = _events.removeAt(eventIndex);
    }
    if (_selectedEvent?.eventId == eventId) {
      _selectedEvent = null;
    }
    notifyListeners();

    try {
      await _eventService.deleteEvent(org: org, eventId: eventId);
      return true;
    } catch (e) {
      // Rollback
      if (removedEvent != null && eventIndex != -1) {
        _events.insert(eventIndex, removedEvent);
      }
      if (removedEvent != null && _selectedEvent == null && removedEvent.eventId == eventId) {
        _selectedEvent = removedEvent;
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all events (used when switching organizations)
  void clearEvents() {
    _events.clear();
    _selectedEvent = null;
    _errorMessage = null;
    _isLoading = false;
    _isUpdating = false;
    _nextCursor = null;
    _hasMore = false;
    _lastLoadedOrgId = null;
    _lastLoadedCaseId = null;
    _lastQuerySignature = null;
    notifyListeners();
  }
}
