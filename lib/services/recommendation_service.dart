import 'package:cloud_functions/cloud_functions.dart';
import 'package:z/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/zap_model.dart';
import '../utils/constants.dart';
import 'firebase_analytics_service.dart';

/// Service to interact with the recommendation cloud function
class RecommendationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get personalized zap recommendations
  ///
  /// [perPage] - Number of recommendations per page (default: 20)
  /// [lastZap] - ID of the last zap from previous page (for pagination)
  ///
  /// Returns a map with:
  /// - `zapIds`: List of zap IDs to fetch
  /// - `hasMore`: Whether there are more recommendations
  /// - `nextLastZap`: ID of the last zap for next page pagination
  /// - `source`: Where recommendations came from ("cache", "curated", "personalized", etc.)
  /// - `generatedAt`: Timestamp when recommendations were generated
  Future<Map<String, dynamic>> getRecommendations({
    int perPage = 20,
    String? lastZap,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to get recommendations');
      }

      final callable = _functions.httpsCallable('generateZapRecommendations');

      final result = await callable.call({
        'userId': user.uid,
        'perPage': perPage,
        if (lastZap != null) 'lastZap': lastZap,
      });

      final data = result.data as Map<String, dynamic>;

      AppLogger.info('RecommendationService', 'Recommendations received', data: {
        'zapCount': data['zapIds']?.length ?? 0,
        'source': data['source'] ?? 'unknown',
        'perPage': perPage,
      });

      return {
        'zapIds': List<String>.from(data['zapIds'] ?? []),
        'hasMore': data['hasMore'] ?? false,
        'nextLastZap': data['nextLastZap'],
        'source': data['source'] ?? 'unknown',
        'generatedAt': data['generatedAt'],
      };
    } on FirebaseFunctionsException catch (e, st) {
      AppLogger.error('RecommendationService', 'Cloud function error', error: e, stackTrace: st, data: {
        'code': e.code,
        'message': e.message,
        'perPage': perPage,
      });

      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to get recommendations from cloud function',
        fatal: false,
      );

      rethrow;
    } catch (e, st) {
      AppLogger.error('RecommendationService', 'Error getting recommendations', error: e, stackTrace: st, data: {'perPage': perPage});

      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to get recommendations',
        fatal: false,
      );

      rethrow;
    }
  }

  /// Fetch full ZapModel objects from a list of zap IDs
  ///
  /// [zapIds] - List of zap IDs to fetch
  /// [isShort] - Whether to fetch from shorts collection (default: false)
  ///
  /// Returns a list of ZapModel objects in the same order as the input IDs.
  /// Zaps that don't exist or are deleted will be filtered out.
  Future<List<ZapModel>> getZapModelsFromIds(
    List<String> zapIds, {
    bool isShort = false,
  }) async {
    if (zapIds.isEmpty) return [];

    try {
      final firestore = FirebaseFirestore.instance;
      final collection = firestore.collection(
        isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection,
      );

      // Firestore 'whereIn' query supports up to 10 items
      const batchSize = 10;
      final allZaps = <ZapModel>[];
      final zapMap = <String, ZapModel>{};

      // Fetch in batches
      for (var i = 0; i < zapIds.length; i += batchSize) {
        final batch = zapIds.sublist(
          i,
          i + batchSize > zapIds.length ? zapIds.length : i + batchSize,
        );

        final snapshot =
            await collection.where(FieldPath.documentId, whereIn: batch).get();

        for (final doc in snapshot.docs) {
          final data = doc.data();

          // Filter out deleted zaps
          if (data['isDeleted'] == true) continue;

          try {
            final zap = ZapModel.fromMap({
              'id': doc.id,
              ...data,
            }, snapshot: doc);
            zapMap[doc.id] = zap;
          } catch (e, st) {
            AppLogger.error('RecommendationService', 'Error parsing zap', error: e, stackTrace: st, data: {'zapId': doc.id, 'isShort': isShort});
            // Continue with other zaps
          }
        }
      }

      // Preserve order from original zapIds list
      for (final id in zapIds) {
        final zap = zapMap[id];
        if (zap != null) {
          allZaps.add(zap);
        }
      }

      AppLogger.info('RecommendationService', 'Fetched zap models from IDs', data: {
        'requestedCount': zapIds.length,
        'fetchedCount': allZaps.length,
        'isShort': isShort,
      });

      return allZaps;
    } catch (e, st) {
      AppLogger.error('RecommendationService', 'Error fetching zap models from IDs', error: e, stackTrace: st, data: {
        'requestedCount': zapIds.length,
        'isShort': isShort,
      });

      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to fetch zap models from IDs',
        fatal: false,
      );

      rethrow;
    }
  }

  /// Get recommendations with full ZapModel objects
  ///
  /// This is a convenience method that combines getRecommendations and getZapModelsFromIds.
  ///
  /// [perPage] - Number of recommendations per page (default: 20)
  /// [lastZap] - ID of the last zap from previous page (for pagination)
  /// [isShort] - Whether to fetch shorts instead of regular zaps (default: false)
  ///
  /// Returns a map with:
  /// - `zaps`: List of ZapModel objects
  /// - `hasMore`: Whether there are more recommendations
  /// - `nextLastZap`: ID of the last zap for next page pagination
  /// - `source`: Where recommendations came from ("cache", "curated", "personalized", etc.)
  /// - `generatedAt`: Timestamp when recommendations were generated
  Future<Map<String, dynamic>> getRecommendationsWithZaps({
    int perPage = 20,
    String? lastZap,
    bool isShort = false,
  }) async {
    try {
      // Get recommendation IDs
      final recommendations = await getRecommendations(
        perPage: perPage,
        lastZap: lastZap,
      );

      final zapIds = recommendations['zapIds'] as List<String>;

      // Fetch full zap models
      final zaps = await getZapModelsFromIds(zapIds, isShort: isShort);

      return {
        'zaps': zaps,
        'hasMore': recommendations['hasMore'],
        'nextLastZap': recommendations['nextLastZap'],
        'source': recommendations['source'],
        'generatedAt': recommendations['generatedAt'],
      };
    } catch (e, st) {
      AppLogger.error('RecommendationService', 'Error getting recommendations with zaps', error: e, stackTrace: st, data: {
        'perPage': perPage,
        'isShort': isShort,
      });

      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to get recommendations with zaps',
        fatal: false,
      );

      rethrow;
    }
  }
}
