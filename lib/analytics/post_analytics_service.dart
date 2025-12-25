import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/constants.dart';
import '../services/analytics/firebase_analytics_service.dart';

class PostAnalyticsService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final bool isShortVideo;

  PostAnalyticsService({this.isShortVideo = false});

  CollectionReference get _analytics => firestore
      .collection('analytics')
      .doc(
        isShortVideo
            ? AppConstants.shortsCollection
            : AppConstants.zapsCollection,
      )
      .collection(
        isShortVideo
            ? AppConstants.shortsCollection
            : AppConstants.zapsCollection,
      );

  DocumentReference _userInteractionRef(String userId, String id) => firestore
      .collection('user_interactions')
      .doc(userId)
      .collection(
        isShortVideo
            ? AppConstants.shortsCollection
            : AppConstants.zapsCollection,
      )
      .doc(id);

  Stream<bool> isLikedStream(String userId, String id) =>
      _userInteractionRef(userId, id).snapshots().map(
        (snap) => (snap.data() as Map<String, dynamic>?)?['liked'] == true,
      );

  Stream<bool> isResharedStream(String userId, String id) =>
      _userInteractionRef(userId, id).snapshots().map(
        (snap) => (snap.data() as Map<String, dynamic>?)?['reshared'] == true,
      );

  Stream<int> viewsStream(String id) => _analytics
      .doc(id)
      .snapshots()
      .map((s) => (s.data() as Map<String, dynamic>?)?['views'] ?? 0);

  Stream<int> commentsCountStream(String id) => _analytics
      .doc(id)
      .snapshots()
      .map((s) => (s.data() as Map<String, dynamic>?)?['comments'] ?? 0);

  Stream<int> sharesStream(String id) => _analytics
      .doc(id)
      .snapshots()
      .map((s) => (s.data() as Map<String, dynamic>?)?['shares'] ?? 0);

  Stream<int> reshareCountStream(String id) => _analytics
      .doc(id)
      .snapshots()
      .map((s) => (s.data() as Map<String, dynamic>?)?['reposts'] ?? 0);

  Future<bool> isLiked(String userId, String id) async {
    final doc = await _userInteractionRef(userId, id).get();
    return doc.exists && (doc.data() as Map<String, dynamic>)['liked'] == true;
  }

  Future<bool> isViewed(String userId, String id) async {
    final doc = await _userInteractionRef(userId, id).get();
    return doc.exists && (doc.data() as Map<String, dynamic>)['viewed'] == true;
  }

  Future<void> view(String userId, String id) async {
    if (await isViewed(userId, id)) return;
    await _analytics.doc(id).set({
      'views': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _userInteractionRef(userId, id).set({
      'viewed': true,
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleLike(
    String userId,
    String id,
    List<String> tags, {
    String? creatorUserId,
  }) async {
    final liked = await isLiked(userId, id);

    await _analytics.doc(id).set({
      'likes': FieldValue.increment(liked ? -1 : 1),
    }, SetOptions(merge: true));

    await _userInteractionRef(userId, id).set({
      'liked': !liked,
      'likedAt': !liked ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));

    if (!liked) {
      await _updateUserTagWeights(userId, tags);
      // Update user liking weights if creator is different from current user
      if (creatorUserId != null && creatorUserId != userId) {
        await _updateUserLikingWeights(userId, creatorUserId);
      }
      // Track like event in Firebase Analytics
      await FirebaseAnalyticsService.logPostLiked(isShort: isShortVideo);
    } else {
      // When unliking, decrease the weight
      if (creatorUserId != null && creatorUserId != userId) {
        await _updateUserLikingWeights(userId, creatorUserId, increment: -1);
      }
    }
  }

  Future<void> comment(String id) async {
    await _analytics.doc(id).set({
      'comments': FieldValue.increment(1),
    }, SetOptions(merge: true));
    // Track comment event in Firebase Analytics
    await FirebaseAnalyticsService.logPostCommented(isShort: isShortVideo);
  }

  Future<void> share(String id) async {
    await _analytics.doc(id).set({
      'shares': FieldValue.increment(1),
    }, SetOptions(merge: true));
    // Track share event in Firebase Analytics
    await FirebaseAnalyticsService.logPostShared(isShort: isShortVideo);
  }

  Future<void> toggleRepost(String userId, String id) async {
    final doc = await _userInteractionRef(userId, id).get();
    final data = doc.data() as Map<String, dynamic>?;

    final isReshared = data?['reshared'] == true;
    await _analytics.doc(id).set({
      'reposts': FieldValue.increment(isReshared ? -1 : 1),
    }, SetOptions(merge: true));

    await _userInteractionRef(userId, id).set({
      'reshared': !isReshared,
      'resharedAt': !isReshared ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }

  Future<void> repostPost({
    required String originalPostId,
    required String originalUserId,
    required String currentUserId,
  }) async {
    final postsRef = firestore.collection(AppConstants.zapsCollection);
    final originalPostRef = postsRef.doc(originalPostId);
    final analyticsRef = _analytics.doc(originalPostId);

    await firestore.runTransaction((transaction) async {
      final originalSnap = await transaction.get(originalPostRef);
      if (!originalSnap.exists) return;
      final originalData = originalSnap.data() as Map<String, dynamic>;

      // Create the repost
      final newPostRef = postsRef.doc();
      transaction.set(newPostRef, {
        ...originalData,
        'id': newPostRef.id,
        'originalPostId': originalPostId,
        'originalUserId': originalUserId,
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'isReshare': true,
      });

      // Update analytics
      transaction.set(analyticsRef, {
        'reposts': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Track in user interactions
      final interactionRef = _userInteractionRef(currentUserId, originalPostId);
      transaction.set(interactionRef, {
        'reshared': true,
        'resharedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<List<String>> getResharedBy(String userId) {
    return firestore
        .collection('user_interactions')
        .doc(userId)
        .collection(
          isShortVideo
              ? AppConstants.shortsCollection
              : AppConstants.zapsCollection,
        )
        .where('reshared', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  Stream<int> likesStream(String id) => _analytics
      .doc(id)
      .snapshots()
      .map((s) => (s.data() as Map<String, dynamic>?)?['likes'] ?? 0);

  Future<void> _updateUserTagWeights(String userId, List<String> tags) async {
    final ref = firestore
        .collection('analytics')
        .doc('users')
        .collection('users')
        .doc(userId);
    final snap = await ref.get();
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      snap.data()?['tagsLiked'] ?? {},
    );
    for (var tag in tags) {
      data[tag] = (data[tag] ?? 0) + 1;
    }
    await ref.set({'tagsLiked': data}, SetOptions(merge: true));
  }

  Future<void> _updateUserLikingWeights(
    String userId,
    String creatorUserId, {
    int increment = 1,
  }) async {
    final ref = firestore
        .collection('analytics')
        .doc('users')
        .collection('users')
        .doc(userId);
    final snap = await ref.get();
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      snap.data()?['usersLiked'] ?? {},
    );
    final currentWeight = (data[creatorUserId] ?? 0) as int;
    final newWeight =
        (currentWeight + increment).clamp(0, double.infinity).toInt();
    if (newWeight > 0) {
      data[creatorUserId] = newWeight;
    } else {
      data.remove(creatorUserId);
    }
    await ref.set({'usersLiked': data}, SetOptions(merge: true));
  }

  Stream<List<String>> getLikedBy(String userId) {
    return firestore
        .collection('user_interactions')
        .doc(userId)
        .collection(
          isShortVideo
              ? AppConstants.shortsCollection
              : AppConstants.zapsCollection,
        )
        .where('liked', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
