import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_feed_model.dart';

/// Service for activity feed (Slice 16) - list from domain_events
class ActivityFeedService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<ActivityFeedListResult> list({
    required String orgId,
    String? matterId,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _functions.httpsCallable('activityFeedList').call<Map<String, dynamic>>({
      'orgId': orgId,
      if (matterId != null && matterId.isNotEmpty) 'matterId': matterId,
      'limit': limit,
      'offset': offset,
    });
    final data = result.data;
    if (data['success'] != true) {
      throw Exception(data['error']?['message'] ?? 'Failed to load activity');
    }
    final responseData = data['data'] as Map<String, dynamic>;
    final items = (responseData['items'] as List<dynamic>)
        .map((e) => ActivityFeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ActivityFeedListResult(
      items: items,
      hasMore: responseData['hasMore'] as bool? ?? false,
    );
  }
}

class ActivityFeedListResult {
  final List<ActivityFeedItem> items;
  final bool hasMore;
  ActivityFeedListResult({required this.items, required this.hasMore});
}
