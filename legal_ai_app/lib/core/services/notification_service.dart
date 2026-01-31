import 'cloud_functions_service.dart';

/// P2 Notification service – list, mark read, preferences
class NotificationService {
  NotificationService(this._cloud);

  final CloudFunctionsService _cloud;

  /// Throws if backend returned success: false (e.g. validation, auth).
  static void _throwIfError(Map<String, dynamic> res) {
    if (res['success'] == false) {
      final err = res['error'];
      final message = err is Map ? (err['message'] as String?) ?? 'Request failed' : 'Request failed';
      throw message;
    }
  }

  /// List in-app notifications (org-scoped) with optional filters.
  /// When readStatus is 'read', we fetch all and filter client-side to avoid Firestore inequality query errors.
  Future<List<NotificationItem>> list({
    required String orgId,
    String channel = 'in_app',
    int limit = 50,
    String? category, // legacy single category
    List<String>? categories, // multi-select (empty or null = all)
    String? readStatus, // 'all', 'read', 'unread'
  }) async {
    // When readStatus is 'read', fetch all and filter client-side to avoid Firestore inequality query error
    final passReadToBackend = readStatus != null && readStatus != 'all' && readStatus != 'read';
    final res = await _cloud.callFunction('notificationList', {
      'orgId': orgId,
      'channel': channel,
      'limit': limit,
      if (categories != null && categories.isNotEmpty) 'categories': categories,
      if (categories == null && category != null) 'category': category,
      if (passReadToBackend) 'readStatus': readStatus,
      if (readStatus == 'read') 'readStatus': 'all',
    });
    NotificationService._throwIfError(res);
    final data = res['data'];
    if (data is! Map) return [];
    final list = data['notifications'];
    if (list is! List) return [];
    var items = list
        .map((e) => _itemFromMap(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
        .whereType<NotificationItem>()
        .toList();
    if (readStatus == 'read') {
      items = items.where((n) => n.readAt != null && n.readAt!.isNotEmpty).toList();
    }
    return items;
  }

  /// Mark one notification as read
  Future<void> markRead({required String orgId, required String notificationId}) async {
    await _cloud.callFunction('notificationMarkRead', {
      'orgId': orgId,
      'notificationId': notificationId,
    });
  }

  /// Mark all in-app notifications as read
  Future<int> markAllRead({required String orgId}) async {
    final res = await _cloud.callFunction('notificationMarkAllRead', {'orgId': orgId});
    NotificationService._throwIfError(res);
    final data = res['data'];
    if (data is! Map) return 0;
    return (data['marked'] as num?)?.toInt() ?? 0;
  }

  /// Get unread count (in-app, org-scoped)
  Future<int> unreadCount({required String orgId}) async {
    final res = await _cloud.callFunction('notificationUnreadCount', {'orgId': orgId});
    NotificationService._throwIfError(res);
    final data = res['data'];
    if (data is! Map) return 0;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// Get notification preferences (all categories)
  Future<Map<String, NotificationPreferenceValue>> getPreferences({
    required String orgId,
  }) async {
    final res = await _cloud.callFunction('notificationPreferencesGet', {'orgId': orgId});
    NotificationService._throwIfError(res);
    final data = res['data'];
    if (data is! Map) return {};
    final prefs = data['preferences'];
    if (prefs is! Map) return {};
    final out = <String, NotificationPreferenceValue>{};
    for (final e in prefs.entries) {
      final key = e.key as String;
      final v = e.value;
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        out[key] = NotificationPreferenceValue(
          inApp: m['inApp'] as bool? ?? true,
          email: m['email'] as bool? ?? true,
        );
      }
    }
    return out;
  }

  /// Update one category preference
  Future<Map<String, NotificationPreferenceValue>> updatePreference({
    required String orgId,
    required String category,
    bool? inApp,
    bool? email,
  }) async {
    final res = await _cloud.callFunction('notificationPreferencesUpdate', {
      'orgId': orgId,
      'category': category,
      if (inApp != null) 'inApp': inApp,
      if (email != null) 'email': email,
    });
    NotificationService._throwIfError(res);
    final data = res['data'];
    if (data is! Map) return {};
    final prefs = data['preferences'];
    if (prefs is! Map) return {};
    final out = <String, NotificationPreferenceValue>{};
    for (final e in prefs.entries) {
      final key = e.key as String;
      final v = e.value;
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        out[key] = NotificationPreferenceValue(
          inApp: m['inApp'] as bool? ?? true,
          email: m['email'] as bool? ?? true,
        );
      }
    }
    return out;
  }

  static NotificationItem? _itemFromMap(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    if (id == null) return null;
    return NotificationItem(
      id: id,
      orgId: m['orgId'] as String? ?? '',
      eventId: m['eventId'] as String? ?? '',
      channel: m['channel'] as String? ?? 'in_app',
      category: m['category'] as String? ?? 'matter',
      title: m['title'] as String? ?? '',
      bodyPreview: m['bodyPreview'] as String? ?? '',
      deepLink: m['deepLink'] as String? ?? '',
      readAt: m['readAt'] as String?,
      status: m['status'] as String? ?? 'pending',
      createdAt: m['createdAt'] as String?,
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.orgId,
    required this.eventId,
    required this.channel,
    required this.category,
    required this.title,
    required this.bodyPreview,
    required this.deepLink,
    this.readAt,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String orgId;
  final String eventId;
  final String channel;
  final String category;
  final String title;
  final String bodyPreview;
  final String deepLink;
  final String? readAt;
  final String status;
  final String? createdAt;

  bool get isUnread => readAt == null || readAt!.isEmpty;
}

class NotificationPreferenceValue {
  const NotificationPreferenceValue({required this.inApp, required this.email});
  final bool inApp;
  final bool email;
}
