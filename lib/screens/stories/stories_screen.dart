import 'package:flutter/material.dart';
import 'package:z/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/screens/stories/widgets/stories_section.dart';

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
              data:
                  (groupedStories) =>
                      groupedStories.isEmpty
                          ? const SizedBox()
                          : StoriesSection(
                            title: "Friends' Stories",
                            groupedStories: groupedStories,
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                AppLogger.error(
                  'StoriesScreen',
                  'Error loading friend stories',
                  error: error,
                  stackTrace: stack,
                );
                return Center(child: Text('Error: $error'));
              },
            ),
            groupedPublicStoriesAsync.when(
              data:
                  (groupedStories) =>
                      groupedStories.isEmpty
                          ? const SizedBox()
                          : StoriesSection(
                            title: "Public Stories",
                            groupedStories: groupedStories,
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                AppLogger.error(
                  'StoriesScreen',
                  'Error loading public stories',
                  error: error,
                  stackTrace: stack,
                );
                return SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
