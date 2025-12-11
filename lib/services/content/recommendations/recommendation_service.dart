import 'package:cloud_functions/cloud_functions.dart';
import 'package:z/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/utils/constants.dart';
import '../../shared/firestore_utils.dart';

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
  /// [lastViewedZapId] - ID of the last zap the user viewed (for resuming position)
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
    String? lastViewedZapId,
    bool isShort = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to get recommendations');
    }

    try {
      final data = await _invokeRecommendationFunction(
        userId: user.uid,
        perPage: perPage,
        lastZap: lastZap,
        lastViewedZapId: lastViewedZapId,
        isShort: isShort,
      );

      return {
        'zapIds': List<String>.from(data['zapIds'] ?? []),
        'hasMore': data['hasMore'] ?? false,
        'nextLastZap': data['nextLastZap'],
        'source': data['source'] ?? 'unknown',
        'generatedAt': data['generatedAt'],
      };
    } catch (e, st) {
      await FirestoreUtils.handleError(
        serviceName: 'RecommendationService',
        operation: 'Error getting recommendations',
        error: e,
        stackTrace: st,
        data: {'perPage': perPage, 'isShort': isShort},
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _invokeRecommendationFunction({
    required String userId,
    required int perPage,
    String? lastZap,
    String? lastViewedZapId,
    required bool isShort,
  }) async {
    final functionName =
        isShort ? 'generateShortRecommendations' : 'generateZapRecommendations';
    final callable = _functions.httpsCallable(functionName);

    try {
      final result = await callable.call({
        'userId': userId,
        'perPage': perPage,
        if (lastZap != null) 'lastZap': lastZap,
        if (lastViewedZapId != null) 'lastViewedZapId': lastViewedZapId,
      });

      final data = result.data as Map<String, dynamic>;

      return data;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
        'RecommendationService',
        'Recommendation function failed',
        error: e,
        data: {
          'functionName': functionName,
          'code': e.code,
          'message': e.message,
          'isShort': isShort,
        },
      );

      // Don't fallback for shorts - let the error propagate so it can be handled properly
      // The fallback was causing issues where regular zap IDs were fetched from shorts collection
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
    try {
      final firestore = FirebaseFirestore.instance;
      final collection = firestore.collection(
        isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection,
      );

      final zaps = await FirestoreUtils.fetchDocumentsByIds<ZapModel>(
        collection: collection,
        ids: zapIds,
        parser: (doc) {
          final data = doc.data() as Map<String, dynamic>;
          return ZapModel.fromMap({'id': doc.id, ...data}, snapshot: doc);
        },
        filter: (data) => data['isDeleted'] != true,
      );

      return zaps;
    } catch (e, st) {
      await FirestoreUtils.handleError(
        serviceName: 'RecommendationService',
        operation: 'Error fetching zap models from IDs',
        error: e,
        stackTrace: st,
        data: {'requestedCount': zapIds.length, 'isShort': isShort},
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
    String? lastViewedZapId,
    bool isShort = false,
  }) async {
    try {
      // Get recommendation IDs
      final recommendations = await getRecommendations(
        perPage: perPage,
        lastZap: lastZap,
        lastViewedZapId: lastViewedZapId,
        isShort: isShort,
      );

      final zapIds = recommendations['zapIds'] as List<String>;
      final source = recommendations['source'] as String? ?? 'unknown';

      // If we got no zap IDs, return empty result
      if (zapIds.isEmpty) {
        AppLogger.warn(
          'RecommendationService',
          'Received empty zapIds from recommendation function',
          data: {'isShort': isShort, 'source': source, 'perPage': perPage},
        );
        return {
          'zaps': <ZapModel>[],
          'hasMore': recommendations['hasMore'] ?? false,
          'nextLastZap': recommendations['nextLastZap'],
          'source': source,
          'generatedAt': recommendations['generatedAt'],
        };
      }

      // Fetch full zap models
      final zaps = await getZapModelsFromIds(zapIds, isShort: isShort);

      // If we got fewer zaps than requested IDs, some might not exist
      if (zaps.length < zapIds.length) {
        AppLogger.warn(
          'RecommendationService',
          'Some zap IDs were not found in Firestore',
          data: {
            'requestedCount': zapIds.length,
            'fetchedCount': zaps.length,
            'missingCount': zapIds.length - zaps.length,
            'isShort': isShort,
          },
        );
      }

      return {
        'zaps': zaps,
        'hasMore': recommendations['hasMore'],
        'nextLastZap': recommendations['nextLastZap'],
        'source': source,
        'generatedAt': recommendations['generatedAt'],
      };
    } catch (e, st) {
      await FirestoreUtils.handleError(
        serviceName: 'RecommendationService',
        operation: 'Error getting recommendations with zaps',
        error: e,
        stackTrace: st,
        data: {'perPage': perPage, 'isShort': isShort},
      );
      rethrow;
    }
  }

  Future<List<String>> getStoryRecommendations({int limit = 200}) async {
    try {
      final user = _auth.currentUser;
      final callable = _functions.httpsCallable('generateStoryRecommendations');

      final result = await callable.call({
        if (user != null) 'userId': user.uid,
        'limit': limit,
      });

      final data = result.data as Map<String, dynamic>? ?? {};

      return List<String>.from(data['storyIds'] ?? const <String>[]);
    } on FirebaseFunctionsException catch (e, st) {
      await FirestoreUtils.handleError(
        serviceName: 'RecommendationService',
        operation: 'Story cloud function error',
        error: e,
        stackTrace: st,
        data: {'code': e.code, 'message': e.message, 'limit': limit},
      );
      rethrow;
    } catch (e, st) {
      await FirestoreUtils.handleError(
        serviceName: 'RecommendationService',
        operation: 'Error getting story recommendations',
        error: e,
        stackTrace: st,
        data: {'limit': limit},
      );
      rethrow;
    }
  }
}
