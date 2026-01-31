import 'package:flutter/foundation.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/cloud_functions_service.dart';

/// P2 Notification provider – list, unread count, preferences
class NotificationProvider extends ChangeNotifier {
  NotificationProvider() : _service = NotificationService(CloudFunctionsService());

  final NotificationService _service;

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  Map<String, NotificationPreferenceValue> _preferences = {};
  bool _loading = false;
  bool _loadingCount = false;
  String? _error;
  Set<String> _savingCategories = {}; // Track which categories are being saved
  
  // Filter state: multi-select categories (empty = show all)
  final Set<String> _selectedCategories = {};
  String _readStatus = 'all'; // 'all', 'read', 'unread'

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  Map<String, NotificationPreferenceValue> get preferences =>
      Map.unmodifiable(_preferences);
  bool get loading => _loading;
  bool get loadingCount => _loadingCount;
  String? get error => _error;

  // Filter getters
  Set<String> get selectedCategories => Set<String>.from(_selectedCategories);
  bool isCategorySelected(String category) => _selectedCategories.contains(category);
  bool get isAllCategories => _selectedCategories.isEmpty;
  String get readStatus => _readStatus;

  /// Check if a specific category is currently being saved
  bool isCategorySaving(String category) => _savingCategories.contains(category);

  /// Toggle a category filter (add or remove). Empty set = show all. Reloads list.
  void toggleCategory(String orgId, String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
    loadNotifications(orgId);
  }

  /// Set "All" categories (clear category filter)
  void setAllCategories(String orgId) {
    if (_selectedCategories.isEmpty) return;
    _selectedCategories.clear();
    notifyListeners();
    loadNotifications(orgId);
  }

  /// Set read status filter and reload
  void setReadStatus(String orgId, String status) {
    if (_readStatus == status) return;
    _readStatus = status;
    notifyListeners();
    loadNotifications(orgId);
  }

  Future<void> loadNotifications(String orgId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _notifications = await _service.list(
        orgId: orgId,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
        readStatus: _readStatus,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount(String orgId) async {
    _loadingCount = true;
    notifyListeners();
    try {
      _unreadCount = await _service.unreadCount(orgId: orgId);
    } catch (_) {
      // Keep previous count on error
    } finally {
      _loadingCount = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String orgId, String notificationId) async {
    try {
      await _service.markRead(orgId: orgId, notificationId: notificationId);
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        final now = DateTime.now().toUtc().toIso8601String();
        _notifications = List.from(_notifications);
        _notifications[idx] = NotificationItem(
          id: _notifications[idx].id,
          orgId: _notifications[idx].orgId,
          eventId: _notifications[idx].eventId,
          channel: _notifications[idx].channel,
          category: _notifications[idx].category,
          title: _notifications[idx].title,
          bodyPreview: _notifications[idx].bodyPreview,
          deepLink: _notifications[idx].deepLink,
          readAt: now,
          status: _notifications[idx].status,
          createdAt: _notifications[idx].createdAt,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead(String orgId) async {
    try {
      final marked = await _service.markAllRead(orgId: orgId);
      _unreadCount = (_unreadCount - marked).clamp(0, 999);
      await loadNotifications(orgId);
    } catch (_) {}
  }

  Future<void> loadPreferences(String orgId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _preferences = await _service.getPreferences(orgId: orgId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreference(
    String orgId,
    String category, {
    bool? inApp,
    bool? email,
  }) async {
    // Prevent multiple simultaneous saves for the same category
    if (_savingCategories.contains(category)) {
      return;
    }
    
    final previous = Map<String, NotificationPreferenceValue>.from(_preferences);
    final current = _preferences[category];
    final currentInApp = current?.inApp ?? true;
    final currentEmail = current?.email ?? true;
    
    // Optimistic update: apply immediately so toggles respond
    _preferences = Map.from(_preferences);
    _preferences[category] = NotificationPreferenceValue(
      inApp: inApp ?? currentInApp,
      email: email ?? currentEmail,
    );
    _savingCategories.add(category);
    _error = null;
    notifyListeners();
    
    try {
      final updated = await _service.updatePreference(
        orgId: orgId,
        category: category,
        inApp: inApp,
        email: email,
      );
      _preferences = updated;
      _error = null;
    } catch (e) {
      _preferences = previous;
      _error = e.toString();
    } finally {
      _savingCategories.remove(category);
      notifyListeners();
    }
  }

  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _preferences = {};
    _savingCategories.clear();
    _selectedCategories.clear();
    _readStatus = 'all';
    _error = null;
    notifyListeners();
  }
}
