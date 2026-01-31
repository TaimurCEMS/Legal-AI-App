import 'package:flutter/foundation.dart';
import '../../../core/models/activity_feed_model.dart';
import '../../../core/services/activity_feed_service.dart';

/// Provider for activity feed (Slice 16)
class ActivityFeedProvider extends ChangeNotifier {
  final ActivityFeedService _service = ActivityFeedService();

  List<ActivityFeedItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = false;
  String? _currentOrgId;
  String? _currentMatterId;

  List<ActivityFeedItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadActivity({
    required String orgId,
    String? matterId,
    bool refresh = true,
  }) async {
    if (_isLoading) return;
    if (!refresh && _currentOrgId == orgId && _currentMatterId == matterId && _items.isNotEmpty) return;

    try {
      _isLoading = true;
      _error = null;
      _currentOrgId = orgId;
      _currentMatterId = matterId;
      if (refresh) _items = [];
      notifyListeners();

      final result = await _service.list(
        orgId: orgId,
        matterId: matterId,
        limit: 50,
        offset: refresh ? 0 : _items.length,
      );
      if (refresh) {
        _items = result.items;
      } else {
        _items = [..._items, ...result.items];
      }
      _hasMore = result.hasMore;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
