import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/utils/logger.dart';

class MomentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'moments';

  /// Creates a new moment.
  /// Enforces no-media, text-only, no-engagement rules by design.
  Future<void> createMoment(MomentModel moment) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final newMoment = moment.copyWith(id: docRef.id);
      await docRef.set(newMoment.toMap());
      AppLogger.info('MomentService', 'Created moment: ${docRef.id}');
    } catch (e, st) {
      AppLogger.error(
        'MomentService',
        'Failed to create moment',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Fetches recent active moments for a specific user.
  Stream<List<MomentModel>> getUserMoments(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isExpired', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20) // Cap exposure
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MomentModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Fetches recent active moments from a list of users (e.g., following).
  /// Note: Firestore 'in' query is limited to 10 items.
  /// For a real feed, we'd need a more complex solution (cloud functions fan-out),
  /// but for this prototype, we'll fetch recently created moments globally
  /// and filter client-side or use a simple query if the following list is small.
  ///
  /// Strategy for this implementation:
  /// Query most recent moments globally (or filtered by visibility) and client-side filter for followed users.
  /// This is acceptable for a "Moment Rail" which only shows ~5-10 items.
  Stream<List<MomentModel>> getMomentsFeed({
    required List<String> followingIds,
    required String currentUserId,
  }) {
    // Optimization: If following is empty, return empty
    if (followingIds.isEmpty) return Stream.value([]);

    // Fetch recent moments (last 24h)
    // We rely on backend security rules to enforce "Circle" visibility if we were doing strict filtering,
    // but here we fetch candidates and filter.
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    return _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final allMoments = snapshot.docs.map(
            (doc) => MomentModel.fromMap(doc.data(), doc.id),
          );

          // Filter: Included if (Author is Followed AND Visibility is Public/Circle) OR (Author is Self)
          return allMoments
              .where((m) {
                if (m.userId == currentUserId) return true;
                if (!followingIds.contains(m.userId)) return false;

                // Visibility check
                if (m.visibility == MomentVisibility.private) return false;
                // Public and Circle are visible since we are following them
                return true;
              })
              .take(10)
              .toList(); // Only show top 10 in the rail
        });
  }
}
