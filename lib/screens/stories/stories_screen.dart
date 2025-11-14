import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/analytics/story_analytics_service.dart';
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/profile_picture.dart';
import 'package:z/widgets/video_player_widget.dart';
import 'story_item_screen.dart';

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUserId = currentUser.uid;
    final groupedStoriesAsync = ref.watch(
      groupedStoriesProvider(currentUserId),
    );
    final groupedPublicStoriesAsync = ref.watch(
      groupedPublicStoriesProvider(currentUserId),
    );
    final uploads = ref.watch(uploadNotifierProvider);
    final zapUploads =
        uploads.where((task) => task.type == UploadType.document).toList();
    final totalProgress =
        zapUploads.isEmpty
            ? null
            : zapUploads.map((e) => e.progress).reduce((a, b) => a + b) /
                uploads.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stories"),
        centerTitle: true,
        bottom:
            (totalProgress != null)
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(10),
                  child: LinearProgressIndicator(
                    value: totalProgress,
                    backgroundColor: Colors.grey.shade800,
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 4,
                  ),
                )
                : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupedStoriesProvider(currentUserId));
          ref.invalidate(groupedPublicStoriesProvider(currentUserId));
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            groupedStoriesAsync.when(
              data: (groupedStories) {
                if (groupedStories.isEmpty) return const SizedBox();
                return _buildSection(
                  context,
                  ref,
                  title: "Friends' Stories",
                  groupedStories: groupedStories,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                log(
                  "Error loading friend stories",
                  error: error,
                  stackTrace: stack,
                );
                return Center(child: Text('Error: $error'));
              },
            ),
            groupedPublicStoriesAsync.when(
              data: (groupedStories) {
                if (groupedStories.isEmpty) return const SizedBox();
                return _buildSection(
                  context,
                  ref,
                  title: "Public Stories",
                  groupedStories: groupedStories,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                log(
                  "Error loading public stories",
                  error: error,
                  stackTrace: stack,
                );
                return Center(child: Text('Error: $error'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Map<String, List<dynamic>> groupedStories,
  }) {
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
                return _buildStoryItem(
                  context,
                  ref,
                  user,
                  stories,
                  userIds,
                  index,
                  groupedStories,
                );
              },
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, stack) {
                log(
                  "Error loading user profile",
                  error: error,
                  stackTrace: stack,
                );
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Error loading user: $error"),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Card _buildStoryItem(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<StoryModel> stories,
    List<String> allUserIds,
    int userIndex,
    Map<String, List<dynamic>> groupedStories,
  ) {
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
                future: _sortStoriesByViewed(
                  stories,
                  analyticsService,
                  ref,
                  user.id,
                ),
                builder: (context, snapshot) {
                  final sortedStories = snapshot.data ?? stories;

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedStories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final story = sortedStories[i];
                      final isVideo = Helpers.isVideoPath(story.mediaUrl);
                      final key = GlobalKey();

                      return FutureBuilder<bool>(
                        future: analyticsService.isStoryViewed(
                          user.id,
                          story.id,
                        ),
                        builder: (context, viewedSnapshot) {
                          final isViewed = viewedSnapshot.data ?? false;

                          return GestureDetector(
                            key: key,
                            onTap: () {
                              try {
                                final renderBox =
                                    key.currentContext!.findRenderObject()
                                        as RenderBox;
                                final offset = renderBox.localToGlobal(
                                  Offset.zero,
                                );
                                final size = renderBox.size;
                                final screen = MediaQuery.of(context).size;

                                final ax =
                                    ((offset.dx + size.width / 2) /
                                            screen.width) *
                                        2 -
                                    1;
                                final ay =
                                    ((offset.dy + size.height / 2) /
                                            screen.height) *
                                        2 -
                                    1;

                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (_, __, ___) => StoryItemScreen(
                                          groupedStories: groupedStories,
                                          allUserIds: allUserIds,
                                          initialUserIndex: userIndex,
                                          initialStoryIndex: i,
                                        ),
                                    transitionDuration: const Duration(
                                      milliseconds: 400,
                                    ),
                                    reverseTransitionDuration: Duration.zero,
                                    transitionsBuilder: (
                                      context,
                                      animation,
                                      secondary,
                                      child,
                                    ) {
                                      final scale = Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
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
                                log('Error opening story viewer: $e\n$st');
                              }
                            },
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
                                        color: Colors.black45.withOpacityAlpha(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
    String userId,
  ) async {
    final futures =
        stories
            .map(
              (s) async => (
                story: s,
                viewed: await analyticsService.isStoryViewed(userId, s.id),
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
}
