import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/logger.dart';
import 'package:z/services/analytics/firebase_analytics_service.dart';

/// Shared utilities for Firestore operations
class FirestoreUtils {
  /// Maximum items per batch for Firestore whereIn queries
  static const int maxBatchSize = 10;

  /// Fetch documents by IDs in batches (Firestore whereIn limit is 10)
  /// 
  /// [collection] - The Firestore collection reference
  /// [ids] - List of document IDs to fetch
  /// [parser] - Function to parse document to model type T
  /// [filter] - Optional filter function to exclude documents
  /// [preserveOrder] - Whether to preserve the order of input IDs (default: true)
  /// 
  /// Returns list of parsed models in the same order as input IDs (if preserveOrder is true)
  static Future<List<T>> fetchDocumentsByIds<T>({
    required CollectionReference collection,
    required List<String> ids,
    required T Function(DocumentSnapshot doc) parser,
    bool Function(Map<String, dynamic> data)? filter,
    bool preserveOrder = true,
  }) async {
    if (ids.isEmpty) return [];

    try {
      final results = <T>[];
      final resultMap = <String, T>{};

      // Fetch in batches
      for (var i = 0; i < ids.length; i += maxBatchSize) {
        final batch = ids.sublist(
          i,
          i + maxBatchSize > ids.length ? ids.length : i + maxBatchSize,
        );

        final snapshot = await collection
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          if (!doc.exists) continue;

          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          // Apply filter if provided
          if (filter != null && !filter(data)) continue;

          try {
            final parsed = parser(doc);
            resultMap[doc.id] = parsed;
          } catch (e, st) {
            AppLogger.error(
              'FirestoreUtils',
              'Error parsing document',
              error: e,
              stackTrace: st,
              data: {'docId': doc.id},
            );
            // Continue with other documents
          }
        }
      }

      // Preserve order from original IDs list
      if (preserveOrder) {
        for (final id in ids) {
          final result = resultMap[id];
          if (result != null) {
            results.add(result);
          }
        }
      } else {
        results.addAll(resultMap.values);
      }

      return results;
    } catch (e, st) {
      AppLogger.error(
        'FirestoreUtils',
        'Error fetching documents by IDs',
        error: e,
        stackTrace: st,
        data: {'idsCount': ids.length},
      );
      rethrow;
    }
  }

  /// Fetch documents by field value in batches
  /// 
  /// [collection] - The Firestore collection reference
  /// [field] - The field name to query
  /// [values] - List of values to match (will be batched)
  /// [parser] - Function to parse document to model type T
  /// [additionalQuery] - Optional function to add additional query constraints
  /// 
  /// Returns list of parsed models
  static Future<List<T>> fetchDocumentsByFieldInBatches<T>({
    required CollectionReference collection,
    required String field,
    required List<String> values,
    required T Function(DocumentSnapshot doc) parser,
    Query Function(Query query)? additionalQuery,
  }) async {
    if (values.isEmpty) return [];

    try {
      final results = <T>[];

      // Fetch in batches
      for (var i = 0; i < values.length; i += maxBatchSize) {
        final batch = values.sublist(
          i,
          i + maxBatchSize > values.length ? values.length : i + maxBatchSize,
        );

        Query query = collection.where(field, whereIn: batch);
        
        // Apply additional query constraints if provided
        if (additionalQuery != null) {
          query = additionalQuery(query);
        }

        final snapshot = await query.get();

        for (final doc in snapshot.docs) {
          if (!doc.exists) continue;

          try {
            final parsed = parser(doc);
            results.add(parsed);
          } catch (e, st) {
            AppLogger.error(
              'FirestoreUtils',
              'Error parsing document',
              error: e,
              stackTrace: st,
              data: {'docId': doc.id},
            );
            // Continue with other documents
          }
        }
      }

      return results;
    } catch (e, st) {
      AppLogger.error(
        'FirestoreUtils',
        'Error fetching documents by field',
        error: e,
        stackTrace: st,
        data: {'field': field, 'valuesCount': values.length},
      );
      rethrow;
    }
  }

  /// Handle service errors with consistent logging and analytics
  /// 
  /// [serviceName] - Name of the service for logging
  /// [operation] - Description of the operation
  /// [error] - The error that occurred
  /// [stackTrace] - Stack trace
  /// [data] - Additional data for logging
  /// [fatal] - Whether the error is fatal (default: false)
  static Future<void> handleError({
    required String serviceName,
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) async {
    AppLogger.error(
      serviceName,
      operation,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );

    await FirebaseAnalyticsService.recordError(
      error,
      stackTrace,
      reason: '$serviceName: $operation',
      fatal: fatal,
    );
  }

  /// Parse document to model with error handling
  /// 
  /// [doc] - The Firestore document
  /// [parser] - Function to parse document to model type T
  /// [serviceName] - Name of the service for logging
  /// 
  /// Returns parsed model or null if parsing fails
  static T? parseDocumentSafely<T>({
    required DocumentSnapshot doc,
    required T Function(DocumentSnapshot doc) parser,
    String? serviceName,
  }) {
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    try {
      return parser(doc);
    } catch (e, st) {
      AppLogger.error(
        serviceName ?? 'FirestoreUtils',
        'Error parsing document',
        error: e,
        stackTrace: st,
        data: {'docId': doc.id},
      );
      return null;
    }
  }

  /// Parse multiple documents to models with error handling
  /// 
  /// [docs] - List of Firestore documents
  /// [parser] - Function to parse document to model type T
  /// [serviceName] - Name of the service for logging
  /// 
  /// Returns list of successfully parsed models
  static List<T> parseDocumentsSafely<T>({
    required List<DocumentSnapshot> docs,
    required T Function(DocumentSnapshot doc) parser,
    String? serviceName,
  }) {
    return docs
        .map((doc) => parseDocumentSafely(
              doc: doc,
              parser: parser,
              serviceName: serviceName,
            ))
        .whereType<T>()
        .toList();
  }
}

