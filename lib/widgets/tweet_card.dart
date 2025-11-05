import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/utils/constants.dart';
import 'package:z/widgets/media_carousel.dart';
import '../models/tweet_model.dart';
import '../models/user_model.dart';
import '../providers/tweet_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/helpers.dart';
import '../screens/tweet/tweet_detail_screen.dart';

final retweetingProvider = StateProvider.family<bool, String>(
  (ref, tweetId) => false,
);
final likingProvider = StateProvider.family<bool, String>(
  (ref, tweetId) => false,
);
final bookmarkingProvider = StateProvider.family<bool, String>(
  (ref, tweetId) => false,
);

class TweetCard extends ConsumerWidget {
  final TweetModel tweet;
  final UserModel? user;
  final bool showThreadLine;
  final Function()? onTap;
  final Function()? onUserTap;

  const TweetCard({
    super.key,
    required this.tweet,
    this.user,
    this.showThreadLine = false,
    this.onTap,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    final isLiked = tweet.likedBy.contains(currentUser.id);
    final isBookmarked = ref.watch(
      isBookmarkedProvider((tweetId: tweet.id, userId: currentUser.id)),
    );
    final isRetweeted = tweet.retweetedBy.contains(currentUser.id);

    final mediaUrls = tweet.mediaUrls;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onUserTap,
              child: CircleAvatar(
                radius: 24,
                backgroundImage:
                    user?.profilePictureUrl != null
                        ? CachedNetworkImageProvider(user!.profilePictureUrl!)
                        : null,
                child:
                    user?.profilePictureUrl == null
                        ? Text(user?.displayName[0].toUpperCase() ?? 'U')
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onUserTap,
                        child: Text(
                          user?.displayName ?? 'User',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (user?.isVerified ?? false) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 18,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                      const SizedBox(width: 4),
                      Text(
                        '@${user?.username ?? 'user'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      Text('·', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(tweet.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tweet.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  MediaCarousel(
                    mediaUrls: mediaUrls,
                    isVideo: (s) => s.endsWith(".mp4") || s.endsWith(".mov"),
                  ),

                  const SizedBox(height: 12),
                  _buildActions(
                    context,
                    ref,
                    isLiked,
                    isRetweeted,
                    isBookmarked.value ?? false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isLiked,
    bool isRetweeted,
    bool isBookmarked,
  ) {
    final isRetweeting = ref.watch(retweetingProvider(tweet.id));
    final isLiking = ref.watch(likingProvider(tweet.id));
    final isBookmarking = ref.watch(bookmarkingProvider(tweet.id));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          context,
          Icons.chat_bubble_outline,
          tweet.repliesCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TweetDetailScreen(tweetId: tweet.id),
              ),
            );
          },
        ),
        _buildActionButton(
          context,
          Icons.repeat,
          tweet.retweetsCount,
          color: isRetweeted ? const Color(0xFF00BA7C) : null,
          isLoading: isRetweeting,
          onTap:
              isRetweeting
                  ? null
                  : () async {
                    final currentUser =
                        ref.read(currentUserModelProvider).valueOrNull;
                    if (currentUser != null) {
                      final tweetService = ref.read(tweetServiceProvider);
                      ref.read(retweetingProvider(tweet.id).notifier).state =
                          true;
                      try {
                        await tweetService.retweet(tweet.id, currentUser.id);
                      } finally {
                        ref.read(retweetingProvider(tweet.id).notifier).state =
                            false;
                      }
                    }
                  },
        ),
        _buildActionButton(
          context,
          isLiked ? Icons.favorite : Icons.favorite_border,
          tweet.likesCount,
          color: isLiked ? const Color(0xFFF91880) : null,
          isLoading: isLiking,
          onTap:
              isLiking
                  ? null
                  : () async {
                    final currentUser =
                        ref.read(currentUserModelProvider).valueOrNull;
                    if (currentUser != null) {
                      final tweetService = ref.read(tweetServiceProvider);
                      ref.read(likingProvider(tweet.id).notifier).state = true;
                      try {
                        await tweetService.likeTweet(tweet.id, currentUser.id);
                      } finally {
                        ref.read(likingProvider(tweet.id).notifier).state =
                            false;
                      }
                    }
                  },
        ),
        _buildActionButton(
          context,
          Icons.share_outlined,
          null,
          onTap: () async {
            final file =
                tweet.mediaUrls.isNotEmpty
                    ? await cachedImageToXFile(tweet.mediaUrls[0])
                    : null;
            await SharePlus.instance.share(
              ShareParams(
                title: "Share ${user?.displayName ?? user?.username}'s post",
                text:
                    "Take a look at ${user?.displayName ?? user?.username}'s post ${AppConstants.appUrl}/tweet/${tweet.id}",
                previewThumbnail: file,
                excludedCupertinoActivities: [
                  CupertinoActivityType.addToHomeScreen,
                  CupertinoActivityType.sharePlay,
                  CupertinoActivityType.assignToContact,
                  CupertinoActivityType.openInIBooks,
                ],
              ),
            );
          },
        ),
        _buildActionButton(
          context,
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
                    final currentUser =
                        ref.read(currentUserModelProvider).valueOrNull;
                    if (currentUser != null) {
                      final tweetService = ref.read(tweetServiceProvider);
                      ref.read(bookmarkingProvider(tweet.id).notifier).state =
                          true;
                      try {
                        if (isBookmarked) {
                          await tweetService.removeBookmark(
                            tweet.id,
                            currentUser.id,
                          );
                        } else {
                          await tweetService.bookmarkTweet(
                            tweet.id,
                            currentUser.id,
                          );
                        }
                        ref.invalidate(
                          isBookmarkedProvider((
                            tweetId: tweet.id,
                            userId: currentUser.id,
                          )),
                        );
                      } finally {
                        ref.read(bookmarkingProvider(tweet.id).notifier).state =
                            false;
                      }
                    }
                  },
        ),
      ],
    );
  }

  Future<XFile?> cachedImageToXFile(String imageUrl) async {
    final cacheManager = CachedNetworkImageProvider.defaultCacheManager;
    final fileInfo = await cacheManager.getFileFromCache(imageUrl);
    if (fileInfo != null) {
      return XFile(fileInfo.file.path);
    } else {
      final file = await cacheManager.getSingleFile(imageUrl);
      return XFile(file.path);
    }
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    int? count, {
    Color? color,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              icon,
              size: 20,
              color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
            ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Text(
              Helpers.formatNumber(count),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
