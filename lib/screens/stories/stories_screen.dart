import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/video_player_widget.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text("Stories"), centerTitle: true),
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
                if (groupedStories.isEmpty) {
                  return const SizedBox();
                }
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
                if (groupedStories.isEmpty) {
                  return const SizedBox();
                }
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
            final userId = groupedStories.keys.elementAt(index);
            final stories = groupedStories[userId] as List<StoryModel>;
            final userAsync = ref.watch(userProfileProvider(userId));

            return userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox();

                return _buildStoryItem(user, stories);
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

  Card _buildStoryItem(UserModel user, List<StoryModel> stories) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(user.profilePictureUrl ?? ''),
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
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final story = stories[i];
                  final isVideo = Helpers.isVideoPath(story.mediaUrl);

                  return GestureDetector(
                    onTap: () {
                      // TODO: Navigate to story viewer
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 100,
                        child:
                            isVideo
                                ? VideoPlayerWidget(
                                  url: story.mediaUrl,
                                  isFile: false,
                                )
                                : AppImage.network(
                                  story.mediaUrl,
                                  fit: BoxFit.cover,
                                ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
