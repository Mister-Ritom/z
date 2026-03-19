import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story_model.dart';
import '../services/content/stories/story_service.dart';
import 'recommendation_provider.dart';

final storyServiceProvider = Provider((ref) => StoryService());

final storiesVisibleProvider = FutureProvider.family<List<StoryModel>, String>((
  ref,
  currentUserId,
) async {
  final service = ref.watch(storyServiceProvider);
  return await service.getStoriesVisibleTo(currentUserId);
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
final storiesPublicProvider = FutureProvider.family<List<StoryModel>, String>((
  ref,
  currentUserId,
) async {
  final storyService = ref.watch(storyServiceProvider);
  final recommendationService = ref.watch(recommendationServiceProvider);

  final storyIds = await recommendationService.getStoryRecommendations(
    limit: 200,
  );

  if (storyIds.isEmpty) {
    return storyService.getLatestPublicStories(limit: 200);
  }

  return storyService.getStoriesByIds(storyIds);
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

final userStoriesProvider = FutureProvider.family<List<StoryModel>, String>((
  ref,
  uid,
) async {
  final service = ref.watch(storyServiceProvider);
  return await service.getStoriesByUser(uid);
});

final userHasStoriesProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  final service = ref.watch(storyServiceProvider);
  return await service.userHasStories(uid);
});
