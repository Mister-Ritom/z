import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:timeago/timeago.dart' as timeAgo;
import 'package:video_player/video_player.dart';
import 'package:z/models/comment_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/utils/constants.dart';
import 'package:z/widgets/profile_picture.dart';
import 'package:z/widgets/zap_card.dart';
import 'package:z/widgets/video_player_widget.dart';

// manual play state per zap id
final manualShouldPlayProvider = StateProvider.family<bool, String>(
  (ref, zapId) => true,
);

class ShortVideoWidget extends ConsumerWidget {
  final ZapModel zap;
  final bool shouldPlay;
  final void Function(VideoPlayerController controller)? onControllerChange;

  const ShortVideoWidget({
    super.key,
    required this.zap,
    required this.shouldPlay,
    this.onControllerChange,
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
    final isBookmarking = ref.watch(bookmarkingProvider(zap.id));

    return userAsync.when(
      data: (user) {
        final isBookmarked = isBookmarkedAsync.valueOrNull ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 72),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                top: -72,
                child: VideoPlayerWidget(
                  isFile: false,
                  url: zap.mediaUrls.first,
                  isPlaying: effectiveShouldPlay,
                  onControllerChange: onControllerChange,
                  disableFullscreen: true,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 80,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _actionButton(
                      isLikedStream.valueOrNull == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      null,
                      color:
                          isLikedStream.valueOrNull == true
                              ? Colors.pink
                              : Colors.white,
                      onTap: () async {
                        await analytics.toggleLike(
                          currentUser.uid,
                          zap.id,
                          zap.hashtags,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      Icons.comment_outlined,
                      commentsStream.valueOrNull,
                      onTap: () async {
                        ref
                            .read(manualShouldPlayProvider(zap.id).notifier)
                            .state = false;
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
                        ref
                            .read(manualShouldPlayProvider(zap.id).notifier)
                            .state = true;
                      },
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      Icons.share_outlined,
                      sharesStream.valueOrNull,
                      onTap: () async {
                        ref
                            .read(manualShouldPlayProvider(zap.id).notifier)
                            .state = false;
                        await analytics.share(zap.id);
                        await SharePlus.instance.share(
                          ShareParams(
                            text:
                                "Check out ${user?.displayName}'s short: ${AppConstants.appUrl}/short/${zap.id}",
                          ),
                        );
                        ref
                            .read(manualShouldPlayProvider(zap.id).notifier)
                            .state = true;
                      },
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      null,
                      color:
                          isBookmarked
                              ? Theme.of(context).colorScheme.inverseSurface
                              : Colors.grey,
                      isLoading: isBookmarking,
                      onTap:
                          isBookmarking
                              ? null
                              : () async {
                                final zapService = ref.read(
                                  zapServiceProvider(true),
                                );
                                ref
                                    .read(bookmarkingProvider(zap.id).notifier)
                                    .state = true;
                                try {
                                  if (isBookmarked) {
                                    await zapService.removeBookmark(
                                      zap.id,
                                      currentUser.uid,
                                    );
                                  } else {
                                    await zapService.bookmarkZap(
                                      zap.id,
                                      currentUser.uid,
                                    );
                                  }
                                  ref.invalidate(
                                    isBookmarkedProvider((
                                      zapId: zap.id,
                                      userId: currentUser.uid,
                                    )),
                                  );
                                } finally {
                                  ref
                                      .read(
                                        bookmarkingProvider(zap.id).notifier,
                                      )
                                      .state = false;
                                }
                              },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            ref
                                .read(manualShouldPlayProvider(zap.id).notifier)
                                .state = false;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ProfileScreen(userId: zap.userId),
                              ),
                            );
                            ref
                                .read(manualShouldPlayProvider(zap.id).notifier)
                                .state = true;
                          },
                          child: ProfilePicture(
                            pfp: user?.profilePictureUrl,
                            name: user?.displayName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user?.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                if (user?.isVerified ?? false) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '@${user?.username}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 8),
                        if (user != null && currentUser.uid != user.id)
                          SizedBox(
                            width: 90,
                            child: _followButton(currentUser.uid, user.id, ref),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    ExpandableZapText(text: zap.text, createdAt: zap.createdAt),
                  ],
                ),
              ),
              const Positioned(
                right: 16,
                bottom: 16,
                child: Icon(Icons.music_note, color: Colors.white, size: 30),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _followButton(String currentUserId, String userId, WidgetRef ref) {
    final profileService = ref.read(profileServiceProvider);

    return FutureBuilder<bool>(
      future: profileService.isFollowing(currentUserId, userId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        if (!isFollowing) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  isLoading
                      ? null
                      : () async {
                        await profileService.followUser(currentUserId, userId);

                        // Trigger rebuild after following/unfollowing
                        (context as Element).markNeedsBuild();
                      },
              child:
                  isLoading
                      ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        'Follow',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white),
                      ),
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  Widget _actionButton(
    IconData icon,
    int? count, {
    Color color = Colors.white,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child:
              isLoading
                  ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                  : Icon(icon, color: color, size: 28),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(height: 4),
          Text(count.toString(), style: TextStyle(color: color, fontSize: 12)),
        ],
      ],
    );
  }
}

class ExpandableZapText extends StatefulWidget {
  final String text;
  final DateTime createdAt;

  const ExpandableZapText({
    super.key,
    required this.text,
    required this.createdAt,
  });

  @override
  State<ExpandableZapText> createState() => _ExpandableZapTextState();
}

class _ExpandableZapTextState extends State<ExpandableZapText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final timeAgoText = timeAgo.format(widget.createdAt);

    return GestureDetector(
      onTap: () => setState(() => expanded = !expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: expanded ? null : 1,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            timeAgoText,
            style: TextStyle(
              color: Colors.white.withOpacityAlpha(0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentSheet extends ConsumerStatefulWidget {
  final String zapId;
  final String currentUserId;
  const CommentSheet({
    super.key,
    required this.zapId,
    required this.currentUserId,
  });

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final zapService = ref.read(zapServiceProvider(true));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: zapService.streamCommentsForPostPaginated(
                    widget.zapId,
                    50,
                  ),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    return ListView.builder(
                      controller: controller,
                      itemCount: comments.length,
                      itemBuilder: (_, index) {
                        final comment = comments[index];
                        return ListTile(
                          title: Text(comment.text),
                          subtitle: Text(comment.userId),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      final comment = CommentModel(
                        id: const Uuid().v4(),
                        postId: widget.zapId,
                        userId: widget.currentUserId,
                        text: text,
                        createdAt: DateTime.now(),
                      );
                      await zapService.addComment(comment);
                      _controller.clear();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
