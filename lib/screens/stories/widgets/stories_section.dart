import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/analytics/story_analytics_service.dart';
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/screens/stories/story_item_screen.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/widgets/media/video_player_widget.dart';

class StoriesSection extends ConsumerWidget {
  final String title;
  final Map<String, List<dynamic>> groupedStories;

  const StoriesSection({
    super.key,
    required this.title,
    required this.groupedStories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userIds = groupedStories.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          itemCount: groupedStories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final userId = userIds[index];
            final stories = groupedStories[userId] as List<StoryModel>;
            final userAsync = ref.watch(userProfileProvider(userId));

            return userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox();
                return StoryItemCard(
                  user: user,
                  stories: stories,
                  allUserIds: userIds,
                  userIndex: index,
                  groupedStories: groupedStories,
                );
              },
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, stack) {
                AppLogger.error(
                  'StoriesScreen',
                  'Error loading user profile',
                  error: error,
                  stackTrace: stack,
                );
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading user: $error'),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class StoryItemCard extends ConsumerWidget {
  final UserModel user;
  final List<StoryModel> stories;
  final List<String> allUserIds;
  final int userIndex;
  final Map<String, List<dynamic>> groupedStories;

  const StoryItemCard({
    super.key,
    required this.user,
    required this.stories,
    required this.allUserIds,
    required this.userIndex,
    required this.groupedStories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsService = ref.read(storyAnalyticsProvider);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: user.id),
                  ),
                );
              },
              child: Row(
                children: [
                  ProfilePicture(
                    name: user.displayName,
                    pfp: user.profilePictureUrl,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: FutureBuilder<List<StoryModel>>(
                future: _sortStoriesByViewed(stories, analyticsService, ref),
                builder: (context, snapshot) {
                  final sortedStories = snapshot.data ?? stories;

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedStories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final story = sortedStories[index];
                      return _StoryThumbnail(
                        story: story,
                        analyticsService: analyticsService,
                        onTap:
                            (key) =>
                                _openStory(context, key, storyIndex: index),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<StoryModel>> _sortStoriesByViewed(
    List<StoryModel> stories,
    StoryAnalyticsService analyticsService,
    WidgetRef ref,
  ) async {
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.uid;
    if (currentUserId == null) return stories;

    final futures =
        stories
            .map(
              (story) async => (
                story: story,
                viewed:
                    await analyticsService
                        .isStoryViewedStream(currentUserId, story.id)
                        .first,
              ),
            )
            .toList();

    final results = await Future.wait(futures);
    results.sort((a, b) {
      if (a.viewed && !b.viewed) return 1;
      if (!a.viewed && b.viewed) return -1;
      return 0;
    });
    return results.map((e) => e.story).toList();
  }

  void _openStory(
    BuildContext context,
    GlobalKey key, {
    required int storyIndex,
  }) {
    try {
      final renderBox = key.currentContext!.findRenderObject() as RenderBox;
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final screen = MediaQuery.of(context).size;

      final ax = ((offset.dx + size.width / 2) / screen.width) * 2 - 1;
      final ay = ((offset.dy + size.height / 2) / screen.height) * 2 - 1;

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => StoryItemScreen(
                groupedStories: groupedStories,
                allUserIds: allUserIds,
                initialUserIndex: userIndex,
                initialStoryIndex: storyIndex,
              ),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scale = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return Transform.scale(
              scale: scale.value,
              alignment: Alignment(ax, ay),
              child: child,
            );
          },
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'StoriesScreen',
        'Error opening story viewer',
        error: e,
        stackTrace: st,
      );
    }
  }
}

class _StoryThumbnail extends ConsumerWidget {
  final StoryModel story;
  final StoryAnalyticsService analyticsService;
  final void Function(GlobalKey key) onTap;

  const _StoryThumbnail({
    required this.story,
    required this.analyticsService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = Helpers.isVideoPath(story.mediaUrl);
    final key = GlobalKey();
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    return StreamBuilder<bool>(
      stream:
          currentUser != null
              ? analyticsService.isStoryViewedStream(currentUser.uid, story.id)
              : Stream.value(false),
      initialData: false,
      builder: (context, snapshot) {
        final isViewed = snapshot.data ?? false;

        return GestureDetector(
          key: key,
          onTap: () => onTap(key),
          child: Stack(
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    child:
                        isVideo
                            ? VideoPlayerWidget(
                              url: story.mediaUrl,
                              isFile: false,
                              disableFullscreen: true,
                              isPlaying: false,
                              thumbnailOnly: true,
                            )
                            : AppImage.network(
                              story.mediaUrl,
                              fit: BoxFit.cover,
                            ),
                  ),
                ),
              ),
              if (isViewed)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      color: Colors.black45.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
