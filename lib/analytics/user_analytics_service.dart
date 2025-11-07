import 'package:cloud_firestore/cloud_firestore.dart';

class UserAnalyticsService {
  final firestore = FirebaseFirestore.instance;

  CollectionReference get _analytics =>
      firestore.collection('analytics').doc('users').collection('users');

  DocumentReference _userInteractionRef(String userId, String targetUserId) =>
      firestore
          .collection('user_interactions')
          .doc(userId)
          .collection('users')
          .doc(targetUserId);

  Stream<bool> isUserLikedStream(String userId, String targetUserId) =>
      _userInteractionRef(userId, targetUserId).snapshots().map(
        (snap) => (snap.data() as Map<String, dynamic>?)?['liked'] == true,
      );

  Future<bool> isUserLiked(String userId, String targetUserId) async {
    final doc = await _userInteractionRef(userId, targetUserId).get();
    return doc.exists && (doc.data() as Map<String, dynamic>)['liked'] == true;
  }

  Future<void> likeUser(String userId, String targetUserId) async {
    if (await isUserLiked(userId, targetUserId)) return;
    await _analytics.doc(targetUserId).set({
      'likes': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _userInteractionRef(userId, targetUserId).set({
      'liked': true,
      'likedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<int> userTotalLikesStream(String userId) => _analytics
      .doc(userId)
      .snapshots()
      .map((snap) => (snap.data() as Map<String, dynamic>?)?['likes'] ?? 0);

  Stream<List<String>> getUsersLikedBy(String userId) {
    return firestore
        .collection('user_interactions')
        .doc(userId)
        .collection('users')
        .where('liked', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
