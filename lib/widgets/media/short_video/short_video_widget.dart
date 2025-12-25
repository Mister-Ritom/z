import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/media/video_player_widget.dart';
import 'package:z/widgets/media/short_video/comment_sheet.dart';
import 'package:z/widgets/media/short_video/short_video_actions.dart';
import 'package:z/widgets/media/short_video/short_video_overlay.dart';
import 'package:z/widgets/media/short_video/short_video_options_sheet.dart';

// manual play state per zap id
final manualShouldPlayProvider = StateProvider.family<bool, String>(
  (ref, zapId) => true,
);

class ShortVideoWidget extends ConsumerWidget {
  final ZapModel zap;
  final bool shouldPlay;

  const ShortVideoWidget({
    super.key,
    required this.zap,
    required this.shouldPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (zap.mediaUrls.isEmpty) {
      log("No media found, skipping zap ${zap.id}");
      return const SizedBox.shrink();
    }

    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      context.go("login");
      return const Text("Sign in");
    }

    final manualShouldPlay = ref.watch(manualShouldPlayProvider(zap.id));
    final effectiveShouldPlay = shouldPlay && manualShouldPlay;

    final userAsync = ref.watch(userProfileProvider(zap.userId));
    final isLikedStream = ref.watch(
      videoLikedStreamProvider((currentUser.uid, zap.id)),
    );
    final commentsStream = ref.watch(videoCommentsCountStreamProvider(zap.id));
    final sharesStream = ref.watch(videoSharesStreamProvider(zap.id));
    final analytics = ref.read(shortVideoAnalyticsProvider);

    final isBookmarkedAsync = ref.watch(
      isBookmarkedProvider((zapId: zap.id, userId: currentUser.uid)),
    );

    return userAsync.when(
      data: (user) {
        if (user == null) {
          AppLogger.error("UserFounder", "User not found for zap ${zap.id}");
          return const SizedBox.shrink();
        }
        final isBookmarked = isBookmarkedAsync.valueOrNull ?? false;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: VideoPlayerWidget(
                isFile: false,
                url: zap.mediaUrls.first,
                isPlaying: effectiveShouldPlay,
                disableFullscreen: true,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 80,
              child: ShortVideoActions(
                isLiked: isLikedStream.valueOrNull == true,
                commentsCount: commentsStream.valueOrNull,
                sharesCount: sharesStream.valueOrNull,
                onLike: () async {
                  await analytics.toggleLike(
                    currentUser.uid,
                    zap.id,
                    zap.hashtags,
                    creatorUserId: zap.userId,
                  );
                },
                onComment: () async {
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      false;
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (_) => CommentSheet(
                          zapId: zap.id,
                          currentUserId: currentUser.uid,
                        ),
                  );
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      true;
                },
                onShare: () async {
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      false;
                  await analytics.share(zap.id);
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          "Check out ${user.displayName}'s short: ${AppConstants.appUrl}/short/${zap.id}",
                    ),
                  );
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      true;
                },
                onMoreOptions: () async {
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      false;
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder:
                        (_) => ShortVideoOptionsSheet(
                          zapId: zap.id,
                          zapUserId: zap.userId,
                          currentUserId: currentUser.uid,
                          isBookmarked: isBookmarked,
                        ),
                  );
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      true;
                },
              ),
            ),
            Positioned(
              left: 16,
              bottom: 0,
              right: 72,
              child: ShortVideoOverlay(
                user: user,
                currentUserId: currentUser.uid,
                zapUserId: zap.userId,
                zapText: zap.text,
                createdAt: zap.createdAt,
                onProfileTap: () async {
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      false;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: zap.userId),
                    ),
                  );
                  ref.read(manualShouldPlayProvider(zap.id).notifier).state =
                      true;
                },
              ),
            ),
            const Positioned(
              right: 16,
              bottom: 0,
              child: Icon(Icons.music_note, color: Colors.white, size: 30),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
