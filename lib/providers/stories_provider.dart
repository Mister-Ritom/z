import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';

final storyServiceProvider = Provider((ref) => StoryService());

final storiesVisibleProvider = StreamProvider.family<List<StoryModel>, String>((
  ref,
  currentUserId,
) {
  final service = ref.watch(storyServiceProvider);
  return service.getStoriesVisibleTo(currentUserId);
});

final groupedStoriesProvider =
    Provider.family<AsyncValue<Map<String, List<StoryModel>>>, String>((
      ref,
      currentUserId,
    ) {
      final storiesAsync = ref.watch(storiesVisibleProvider(currentUserId));

      return storiesAsync.whenData((stories) {
        final grouped = <String, List<StoryModel>>{};
        for (final story in stories) {
          grouped.putIfAbsent(story.userId, () => []).add(story);
        }
        return grouped;
      });
    });
final storiesPublicProvider = StreamProvider.family<List<StoryModel>, String>((
  ref,
  currentUserId,
) {
  final service = ref.watch(storyServiceProvider);
  return service.getPublicStories();
});

final groupedPublicStoriesProvider =
    Provider.family<AsyncValue<Map<String, List<StoryModel>>>, String>((
      ref,
      currentUserId,
    ) {
      final storiesAsync = ref.watch(storiesPublicProvider(currentUserId));

      return storiesAsync.whenData((stories) {
        final grouped = <String, List<StoryModel>>{};
        for (final story in stories) {
          grouped.putIfAbsent(story.userId, () => []).add(story);
        }
        return grouped;
      });
    });

final userStoriesProvider = StreamProvider.family<List<StoryModel>, String>((
  ref,
  uid,
) {
  final service = ref.watch(storyServiceProvider);
  return service.getStoriesByUser(uid);
});

final userHasStoriesProvider = StreamProvider.family<bool, String>((ref, uid) {
  final service = ref.watch(storyServiceProvider);
  return service.userHasStories(uid);
});
