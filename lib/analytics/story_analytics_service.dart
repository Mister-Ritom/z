import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/constants.dart';

class StoryAnalyticsService {
  final firestore = FirebaseFirestore.instance;

  CollectionReference get _analytics => firestore
      .collection('analytics')
      .doc('stories')
      .collection(AppConstants.storiesCollection);

  DocumentReference _userRef(String userId, String storyId) => firestore
      .collection('user_interactions')
      .doc(userId)
      .collection('stories')
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
    if (await isStoryViewed(userId, storyId)) return;
    await _analytics.doc(storyId).set({
      'views': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _userRef(userId, storyId).set({
      'viewed': true,
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isStoryViewed(String userId, String storyId) async {
    final doc = await _userRef(userId, storyId).get();
    return doc.exists && (doc.data() as Map<String, dynamic>)['viewed'] == true;
  }

  Future<void> likeStory(String userId, String storyId) async {
    if (await isStoryLiked(userId, storyId)) return;
    await _analytics.doc(storyId).set({
      'likes': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _userRef(userId, storyId).set({
      'liked': true,
      'likedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> replyStory(String storyId) async {
    await _analytics.doc(storyId).set({
      'replies': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> shareStory(String storyId) async {
    await _analytics.doc(storyId).set({
      'shares': FieldValue.increment(1),
    }, SetOptions(merge: true));
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
