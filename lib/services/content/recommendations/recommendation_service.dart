import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/utils/logger.dart';
import 'package:z/supabase/database.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/utils/constants.dart';
import '../../analytics/analytics_service.dart';

/// RecommendationService — calls Supabase Edge Functions for ML-powered recommendations.
class RecommendationService {
  final SupabaseClient _db = Database.client;
  final AnalyticsService? analytics;

  RecommendationService({this.analytics});

  /// Get personalized zap recommendations from edge function.
  /// Falls back to recent popular content if edge function fails.
  Future<Map<String, dynamic>> getRecommendations({
    int perPage = 20,
    String? lastZap,
    String? lastViewedZapId,
    bool isShort = false,
  }) async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _db.functions.invoke(
        isShort ? 'get-short-recommendations' : 'get-recommendations',
        body: {
          'userId': user.id,
          'perPage': perPage,
          if (lastZap != null) 'lastZap': lastZap,
          if (lastViewedZapId != null) 'lastViewedZapId': lastViewedZapId,
        },
      );

      if (response.status != 200) {
        AppLogger.warn(
          'RecommendationService',
          'Edge function returned ${response.status}, falling back',
        );
        return _fallbackRecommendations(perPage: perPage, isShort: isShort);
      }

      final data = response.data as Map<String, dynamic>;
      final results = {
        'zapIds': List<String>.from(data['zapIds'] ?? []),
        'hasMore': data['hasMore'] ?? false,
        'nextLastZap': data['nextLastZap'],
        'source': data['source'] ?? 'edge_function',
      };

      analytics?.capture(
        eventName: 'recommendations_served',
        properties: {
          'count': (results['zapIds'] as List).length,
          'source': results['source'],
          'is_short': isShort,
          'feed_type': isShort ? 'short' : 'personalized',
        },
      );

      return results;
    } catch (e, st) {
      AppLogger.error(
        'RecommendationService',
        'Recommendation fetch failed',
        error: e,
        stackTrace: st,
      );
      return _fallbackRecommendations(perPage: perPage, isShort: isShort);
    }
  }

  /// Fallback: return recent popular content sorted by engagement
  Future<Map<String, dynamic>> _fallbackRecommendations({
    int perPage = 20,
    bool isShort = false,
  }) async {
    try {
      final table =
          isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection;
      final data = await _db
          .from(table)
          .select('id')
          .eq('is_deleted', false)
          .isFilter('parent_zap_id', null)
          .order('created_at', ascending: false)
          .limit(perPage);

      final ids = data.map<String>((d) => d['id'] as String).toList();
      return {
        'zapIds': ids,
        'hasMore': ids.length >= perPage,
        'nextLastZap': ids.isNotEmpty ? ids.last : null,
        'source': 'fallback_recent',
      };
    } catch (e) {
      return {
        'zapIds': <String>[],
        'hasMore': false,
        'nextLastZap': null,
        'source': 'error',
      };
    }
  }

  /// Fetch full ZapModel objects from IDs
  Future<List<ZapModel>> getZapModelsFromIds(
    List<String> zapIds, {
    bool isShort = false,
  }) async {
    if (zapIds.isEmpty) return [];
    try {
      final table =
          isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection;
      final data = await _db
          .from(table)
          .select()
          .inFilter('id', zapIds)
          .eq('is_deleted', false);

      // Preserve order from input IDs
      final zapMap = <String, ZapModel>{};
      for (final d in data) {
        final zap = ZapModel.fromMap(d);
        zapMap[zap.id] = zap;
      }

      return zapIds
          .where((id) => zapMap.containsKey(id))
          .map((id) => zapMap[id]!)
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'RecommendationService',
        'Failed to fetch zap models',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Convenience: get recommendations with full ZapModel objects
  Future<Map<String, dynamic>> getRecommendationsWithZaps({
    int perPage = 20,
    String? lastZap,
    String? lastViewedZapId,
    bool isShort = false,
  }) async {
    final recommendations = await getRecommendations(
      perPage: perPage,
      lastZap: lastZap,
      lastViewedZapId: lastViewedZapId,
      isShort: isShort,
    );

    final zapIds = recommendations['zapIds'] as List<String>;
    if (zapIds.isEmpty) {
      return {
        'zaps': <ZapModel>[],
        'hasMore': false,
        'nextLastZap': null,
        'source': recommendations['source'],
      };
    }

    final zaps = await getZapModelsFromIds(zapIds, isShort: isShort);

    return {
      'zaps': zaps,
      'hasMore': recommendations['hasMore'],
      'nextLastZap': recommendations['nextLastZap'],
      'source': recommendations['source'],
    };
  }

  /// Get story recommendations
  Future<List<String>> getStoryRecommendations({int limit = 200}) async {
    try {
      final user = _db.auth.currentUser;

      final response = await _db.functions.invoke(
        'get-story-recommendations',
        body: {if (user != null) 'userId': user.id, 'limit': limit},
      );

      if (response.status != 200) {
        return [];
      }

      final data = response.data as Map<String, dynamic>? ?? {};
      return List<String>.from(data['storyIds'] ?? []);
    } catch (e, st) {
      AppLogger.error(
        'RecommendationService',
        'Story recommendations failed',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
