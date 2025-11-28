import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/constants.dart';
import '../services/firebase_analytics_service.dart';

class StoryAnalyticsService {
  final firestore = FirebaseFirestore.instance;

  CollectionReference get _analytics => firestore
      .collection('analytics')
      .doc(AppConstants.storiesCollection)
      .collection(AppConstants.storiesCollection);

  DocumentReference _userRef(String userId, String storyId) => firestore
      .collection('user_interactions')
      .doc(userId)
      .collection(AppConstants.storiesCollection)
      .doc(storyId);

  Stream<bool> isStoryLikedStream(String userId, String storyId) =>
      _userRef(userId, storyId).snapshots().map(
        (snap) => (snap.data() as Map<String, dynamic>?)?['liked'] == true,
      );

  Stream<int> storyViewsStream(String storyId) => _analytics
      .doc(storyId)
      .snapshots()
      .map((snap) => (snap.data() as Map<String, dynamic>?)?['views'] ?? 0);

  Stream<int> storySharesStream(String storyId) => _analytics
      .doc(storyId)
      .snapshots()
      .map((snap) => (snap.data() as Map<String, dynamic>?)?['shares'] ?? 0);

  Future<bool> isStoryLiked(String userId, String storyId) async {
    final doc = await _userRef(userId, storyId).get();
    return doc.exists && (doc.data() as Map<String, dynamic>)['liked'] == true;
  }

  Future<void> viewStory(String userId, String storyId) async {
    final alreadyViewed = await isStoryViewedStream(userId, storyId).first;
    if (alreadyViewed) return;

    // Check if analytics document exists, then use update or create accordingly
    final analyticsDoc = _analytics.doc(storyId);
    final analyticsSnapshot = await analyticsDoc.get();

    if (analyticsSnapshot.exists) {
      // Document exists, use update (allows FieldValue operations)
      await analyticsDoc.update({
        'views': FieldValue.increment(1),
        'viewedBy': FieldValue.arrayUnion([userId]),
      });
    } else {
      // Document doesn't exist, create with initial numeric values
      await analyticsDoc.set({
        'views': 1,
        'viewedBy': [userId],
      });
    }

    await _userRef(userId, storyId).set({
      'viewed': true,
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Track story view in Firebase Analytics
    await FirebaseAnalyticsService.logStoryViewed();
  }

  Stream<bool> isStoryViewedStream(String userId, String storyId) =>
      _userRef(userId, storyId).snapshots().map(
        (snap) =>
            snap.exists &&
            (snap.data() as Map<String, dynamic>?)?['viewed'] == true,
      );

  Future<void> toggleLikeStory(String userId, String storyId) async {
    final userDoc = await _userRef(userId, storyId).get();
    final isLiked =
        userDoc.exists &&
        (userDoc.data() as Map<String, dynamic>)['liked'] == true;

    final analyticsDoc = _analytics.doc(storyId);
    final analyticsSnapshot = await analyticsDoc.get();

    if (isLiked) {
      if (analyticsSnapshot.exists) {
        await analyticsDoc.update({'likes': FieldValue.increment(-1)});
      } else {
        await analyticsDoc.set({'likes': 0});
      }
      await _userRef(userId, storyId).set({
        'liked': false,
        'likedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      if (analyticsSnapshot.exists) {
        await analyticsDoc.update({'likes': FieldValue.increment(1)});
      } else {
        await analyticsDoc.set({'likes': 1});
      }
      await _userRef(userId, storyId).set({
        'liked': true,
        'likedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> replyStory(String storyId) async {
    final analyticsDoc = _analytics.doc(storyId);
    final analyticsSnapshot = await analyticsDoc.get();

    if (analyticsSnapshot.exists) {
      await analyticsDoc.update({'comments': FieldValue.increment(1)});
    } else {
      await analyticsDoc.set({'comments': 1});
    }
  }

  Future<void> shareStory(String storyId) async {
    final analyticsDoc = _analytics.doc(storyId);
    final analyticsSnapshot = await analyticsDoc.get();

    if (analyticsSnapshot.exists) {
      await analyticsDoc.update({'shares': FieldValue.increment(1)});
    } else {
      await analyticsDoc.set({'shares': 1});
    }
  }

  Stream<List<String>> getStoriesLikedBy(String userId) {
    return firestore
        .collection('user_interactions')
        .doc(userId)
        .collection('stories')
        .where('liked', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
