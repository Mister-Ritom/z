import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/utils/constants.dart';
import '../models/story_model.dart';

class StoryService {
  final _firestore = FirebaseFirestore.instance;
  CollectionReference get _stories =>
      _firestore.collection(AppConstants.storiesCollection);

  Stream<List<StoryModel>> getStoriesVisibleTo(String currentUserId) {
    final cutoff = DateTime.now().subtract(
      Duration(hours: AppConstants.storyExpiryHours),
    );

    return _stories
        .where('visibleTo', arrayContains: currentUserId)
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => StoryModel.fromDoc(d)).toList(),
        );
  }

  Stream<List<StoryModel>> getPublicStories() {
    final cutoff = DateTime.now().subtract(
      Duration(hours: AppConstants.storyExpiryHours),
    );

    return _stories
        .where('visibility', isEqualTo: StoryVisibility.public.name)
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => StoryModel.fromDoc(d)).toList(),
        );
  }

  Future<List<StoryModel>> getLatestPublicStories({int limit = 200}) async {
    final cutoff = DateTime.now().subtract(
      Duration(hours: AppConstants.storyExpiryHours),
    );

    final snapshot =
        await _stories
            .where('visibility', isEqualTo: StoryVisibility.public.name)
            .where('createdAt', isGreaterThanOrEqualTo: cutoff)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();

    return snapshot.docs.map((d) => StoryModel.fromDoc(d)).toList();
  }

  Stream<List<StoryModel>> getStoriesByUser(String uid) {
    final cutoff = DateTime.now().subtract(
      Duration(hours: AppConstants.storyExpiryHours),
    );

    return _stories
        .where('userId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => StoryModel.fromDoc(d)).toList(),
        );
  }

  Future<List<StoryModel>> getStoriesByIds(List<String> storyIds) async {
    if (storyIds.isEmpty) return [];

    final results = <StoryModel>[];
    final storyMap = <String, StoryModel>{};
    const batchSize = 10;

    for (var i = 0; i < storyIds.length; i += batchSize) {
      final batch = storyIds.sublist(
        i,
        i + batchSize > storyIds.length ? storyIds.length : i + batchSize,
      );

      final snapshot =
          await _stories.where(FieldPath.documentId, whereIn: batch).get();

      for (final doc in snapshot.docs) {
        storyMap[doc.id] = StoryModel.fromDoc(doc);
      }
    }

    for (final id in storyIds) {
      final story = storyMap[id];
      if (story != null) {
        results.add(story);
      }
    }

    return results;
  }

  Stream<bool> userHasStories(String uid) {
    final cutoff = DateTime.now().subtract(
      Duration(hours: AppConstants.storyExpiryHours),
    );

    return _stories
        .where('userId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> createStory({
    required String uid,
    required String caption,
    required String mediaUrl,
    required StoryVisibility visibility,
    required List<String> visibleTo,
  }) async {
    await _stories.add({
      'userId': uid,
      'caption': caption,
      'mediaUrl': mediaUrl,
      'visibility': visibility.name,
      'createdAt': FieldValue.serverTimestamp(),
      'visibleTo': visibleTo,
    });
  }
}
