import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service for Calendar & Court Dates (Slice 7)
///
/// Handles all event-related API calls to Cloud Functions.
class EventService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  /// Create a new event
  Future<EventModel> createEvent({
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
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'title': title.trim(),
      'eventType': eventType.value,
      'startDateTime': startDateTime.toUtc().toIso8601String(),
      'allDay': allDay,
      'visibility': visibility.value,
    };

    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }
    if (endDateTime != null) {
      payload['endDateTime'] = endDateTime.toUtc().toIso8601String();
    }
    if (location != null && location.trim().isNotEmpty) {
      payload['location'] = location.trim();
    }
    if (attendeeUids != null && attendeeUids.isNotEmpty) {
      payload['attendeeUids'] = attendeeUids;
    }
    if (reminders != null && reminders.isNotEmpty) {
      payload['reminders'] = reminders.map((r) => r.toJson()).toList();
    }
    if (recurrence != null) {
      payload['recurrence'] = recurrence.toJson();
    }
    if (priority != null) {
      payload['priority'] = priority.value;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    if (caseId != null && caseId.trim().isNotEmpty) {
      payload['caseId'] = caseId.trim();
    }

    final response = await _functionsService.callFunction('eventCreate', payload);

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('EventService.createEvent error: $response');
    final message = response['error']?['message'] ?? 'Failed to create event. Please try again.';
    throw message;
  }

  /// Get event details by ID
  Future<EventModel> getEvent({
    required OrgModel org,
    required String eventId,
  }) async {
    final response = await _functionsService.callFunction('eventGet', {
      'orgId': org.orgId,
      'eventId': eventId,
    });

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('EventService.getEvent error: $response');
    final message = response['error']?['message'] ?? 'Failed to load event. Please try again.';
    throw message;
  }

  /// List events with filtering and cursor-based pagination
  Future<({List<EventModel> events, String? nextCursor, bool hasMore})> listEvents({
    required OrgModel org,
    int pageSize = 50,
    String? cursor,
    String? search,
    String? caseId,
    EventType? eventType,
    EventStatus? status,
    EventPriority? priority,
    String? startDate,
    String? endDate,
    bool includeRecurring = true,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'pageSize': pageSize,
      'includeRecurring': includeRecurring,
    };

    if (cursor != null && cursor.isNotEmpty) {
      payload['cursor'] = cursor;
    }
    if (search != null && search.trim().isNotEmpty) {
      payload['search'] = search.trim();
    }
    if (caseId != null && caseId.trim().isNotEmpty) {
      payload['caseId'] = caseId.trim();
    }
    if (eventType != null) {
      payload['eventType'] = eventType.value;
    }
    if (status != null) {
      payload['status'] = status.value;
    }
    if (priority != null) {
      payload['priority'] = priority.value;
    }
    if (startDate != null && startDate.isNotEmpty) {
      payload['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      payload['endDate'] = endDate;
    }

    final response = await _functionsService.callFunction('eventList', payload);

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['events'] as List<dynamic>? ?? [])
          .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (events: list, nextCursor: nextCursor, hasMore: hasMore);
    }

    debugPrint('EventService.listEvents error: $response');
    final error = response['error'];
    final message = error?['message'] ?? 'Failed to load events. Please try again.';
    throw message;
  }

  /// Update an existing event
  Future<EventModel> updateEvent({
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
    // Explicit flags for clearing optional fields
    bool clearDescription = false,
    bool clearEndDateTime = false,
    bool clearLocation = false,
    bool clearNotes = false,
    bool clearRecurrence = false,
    bool clearCaseId = false,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'eventId': eventId,
    };

    if (title != null) {
      payload['title'] = title.trim();
    }
    
    // Handle optional fields with clear flags
    if (clearDescription) {
      payload['description'] = null;
    } else if (description != null) {
      payload['description'] = description.trim().isEmpty ? null : description.trim();
    }

    if (eventType != null) {
      payload['eventType'] = eventType.value;
    }
    if (startDateTime != null) {
      payload['startDateTime'] = startDateTime.toUtc().toIso8601String();
    }
    
    if (clearEndDateTime) {
      payload['endDateTime'] = null;
    } else if (endDateTime != null) {
      payload['endDateTime'] = endDateTime.toUtc().toIso8601String();
    }

    if (allDay != null) {
      payload['allDay'] = allDay;
    }
    
    if (clearLocation) {
      payload['location'] = null;
    } else if (location != null) {
      payload['location'] = location.trim().isEmpty ? null : location.trim();
    }

    if (attendeeUids != null) {
      payload['attendeeUids'] = attendeeUids;
    }
    if (reminders != null) {
      payload['reminders'] = reminders.map((r) => r.toJson()).toList();
    }
    
    if (clearRecurrence) {
      payload['recurrence'] = null;
    } else if (recurrence != null) {
      payload['recurrence'] = recurrence.toJson();
    }

    if (priority != null) {
      payload['priority'] = priority.value;
    }
    
    if (clearNotes) {
      payload['notes'] = null;
    } else if (notes != null) {
      payload['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    if (status != null) {
      payload['status'] = status.value;
    }
    if (visibility != null) {
      payload['visibility'] = visibility.value;
    }
    
    if (clearCaseId) {
      payload['caseId'] = null;
    } else if (caseId != null) {
      payload['caseId'] = caseId.trim().isEmpty ? null : caseId.trim();
    }

    final response = await _functionsService.callFunction('eventUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }

    debugPrint('EventService.updateEvent error: $response');
    final message = response['error']?['message'] ?? 'Failed to update event. Please try again.';
    throw message;
  }

  /// Delete an event (soft delete)
  Future<void> deleteEvent({
    required OrgModel org,
    required String eventId,
  }) async {
    final response = await _functionsService.callFunction('eventDelete', {
      'orgId': org.orgId,
      'eventId': eventId,
    });

    if (response['success'] != true) {
      debugPrint('EventService.deleteEvent error: $response');
      final message = response['error']?['message'] ?? 'Failed to delete event. Please try again.';
      throw message;
    }
  }
}
