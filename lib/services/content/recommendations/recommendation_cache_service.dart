import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/utils/logger.dart';
import 'package:z/utils/constants.dart';

/// Service to handle offline caching of recommendations
class RecommendationCacheService {
  static const String _cacheKeyPrefix = 'recommendation_cache_';
  static const String _metadataKeyPrefix = 'recommendation_metadata_';
  static const String _lastViewedKeyPrefix = 'recommendation_last_viewed_';

  /// Save recommendations to local cache
  Future<void> saveRecommendations({
    required bool isShort,
    required List<ZapModel> zaps,
    required bool hasMore,
    String? nextLastZap,
    String? lastViewedZapId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isShort ? "shorts" : "zaps"}';
      final metadataKey = '$_metadataKeyPrefix${isShort ? "shorts" : "zaps"}';
      final lastViewedKey = '$_lastViewedKeyPrefix${isShort ? "shorts" : "zaps"}';

      // Convert ZapModel list to JSON (using toMap and handling DateTime)
      final zapsJson = zaps.map((zap) {
        final map = zap.toMap();
        // Convert DateTime to ISO string for JSON serialization
        map['createdAt'] = zap.createdAt.toIso8601String();
        return map;
      }).toList();
      final zapsJsonString = jsonEncode(zapsJson);

      // Save zaps
      await prefs.setString(cacheKey, zapsJsonString);

      // Save metadata
      final metadata = {
        'hasMore': hasMore,
        'nextLastZap': nextLastZap,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(metadataKey, jsonEncode(metadata));

      // Save last viewed zap ID
      if (lastViewedZapId != null) {
        await prefs.setString(lastViewedKey, lastViewedZapId);
      }

      AppLogger.info(
        'RecommendationCacheService',
        'Saved recommendations to cache',
        data: {
          'isShort': isShort,
          'count': zaps.length,
          'hasMore': hasMore,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'RecommendationCacheService',
        'Failed to save recommendations to cache',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort},
      );
    }
  }

  /// Load recommendations from local cache
  Future<CachedRecommendations?> loadRecommendations({
    required bool isShort,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isShort ? "shorts" : "zaps"}';
      final metadataKey = '$_metadataKeyPrefix${isShort ? "shorts" : "zaps"}';
      final lastViewedKey = '$_lastViewedKeyPrefix${isShort ? "shorts" : "zaps"}';

      // Check if cache exists
      final zapsJsonString = prefs.getString(cacheKey);
      final metadataJsonString = prefs.getString(metadataKey);
      final lastViewedZapId = prefs.getString(lastViewedKey);

      if (zapsJsonString == null || metadataJsonString == null) {
        return null;
      }

      // Check if cache is expired (older than cacheExpiration)
      final metadata = jsonDecode(metadataJsonString) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(metadata['cachedAt'] as String);
      final now = DateTime.now();
      final age = now.difference(cachedAt);

      if (age > AppConstants.cacheExpiration) {
        AppLogger.info(
          'RecommendationCacheService',
          'Cache expired, clearing',
          data: {
            'isShort': isShort,
            'age': age.inHours,
            'maxAge': AppConstants.cacheExpiration.inHours,
          },
        );
        await clearCache(isShort: isShort);
        return null;
      }

      // Parse zaps from JSON (using fromMap and handling DateTime)
      final zapsJson = jsonDecode(zapsJsonString) as List<dynamic>;
      final zaps = zapsJson.map((json) {
        final map = json as Map<String, dynamic>;
        // Convert ISO string back to DateTime
        if (map['createdAt'] is String) {
          map['createdAt'] = DateTime.parse(map['createdAt'] as String);
        }
        return ZapModel.fromMap(map);
      }).toList();

      AppLogger.info(
        'RecommendationCacheService',
        'Loaded recommendations from cache',
        data: {
          'isShort': isShort,
          'count': zaps.length,
          'hasMore': metadata['hasMore'],
          'age': age.inMinutes,
        },
      );

      return CachedRecommendations(
        zaps: zaps,
        hasMore: metadata['hasMore'] as bool? ?? false,
        nextLastZap: metadata['nextLastZap'] as String?,
        lastViewedZapId: lastViewedZapId,
        cachedAt: cachedAt,
      );
    } catch (e, st) {
      AppLogger.error(
        'RecommendationCacheService',
        'Failed to load recommendations from cache',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort},
      );
      return null;
    }
  }

  /// Clear cache for recommendations
  Future<void> clearCache({required bool isShort}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isShort ? "shorts" : "zaps"}';
      final metadataKey = '$_metadataKeyPrefix${isShort ? "shorts" : "zaps"}';
      final lastViewedKey = '$_lastViewedKeyPrefix${isShort ? "shorts" : "zaps"}';

      await prefs.remove(cacheKey);
      await prefs.remove(metadataKey);
      await prefs.remove(lastViewedKey);

      AppLogger.info(
        'RecommendationCacheService',
        'Cleared cache',
        data: {'isShort': isShort},
      );
    } catch (e, st) {
      AppLogger.error(
        'RecommendationCacheService',
        'Failed to clear cache',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort},
      );
    }
  }

  /// Update last viewed zap ID in cache
  Future<void> updateLastViewedZapId({
    required bool isShort,
    required String zapId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewedKey = '$_lastViewedKeyPrefix${isShort ? "shorts" : "zaps"}';
      await prefs.setString(lastViewedKey, zapId);
    } catch (e, st) {
      AppLogger.error(
        'RecommendationCacheService',
        'Failed to update last viewed zap ID',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort, 'zapId': zapId},
      );
    }
  }

  /// Get last viewed zap ID from cache
  Future<String?> getLastViewedZapId({required bool isShort}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewedKey = '$_lastViewedKeyPrefix${isShort ? "shorts" : "zaps"}';
      return prefs.getString(lastViewedKey);
    } catch (e, st) {
      AppLogger.error(
        'RecommendationCacheService',
        'Failed to get last viewed zap ID',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort},
      );
      return null;
    }
  }
}

/// Data class for cached recommendations
class CachedRecommendations {
  const CachedRecommendations({
    required this.zaps,
    required this.hasMore,
    this.nextLastZap,
    this.lastViewedZapId,
    required this.cachedAt,
  });

  final List<ZapModel> zaps;
  final bool hasMore;
  final String? nextLastZap;
  final String? lastViewedZapId;
  final DateTime cachedAt;
}

