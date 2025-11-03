import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/video_player_widget.dart';
import '../models/tweet_model.dart';
import '../models/user_model.dart';
import '../providers/tweet_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/helpers.dart';
import '../screens/tweet/tweet_detail_screen.dart';

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
    final isLiked = tweet.likedBy.contains(currentUser?.id);
    final isRetweeted = tweet.retweetedBy.contains(currentUser?.id);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
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
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
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
                  // Tweet text
                  Text(
                    tweet.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  // Images
                  if (tweet.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildImageGrid(context, tweet.imageUrls),
                  ],
                  // Video
                  if (tweet.videoUrl != null) ...[
                    const SizedBox(height: 8),
                    _buildVideoPreview(context, tweet.videoUrl!),
                  ],
                  // Actions
                  const SizedBox(height: 12),
                  _buildActions(context, ref, isLiked, isRetweeted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrls.first,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    // Grid for multiple images
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: imageUrls.length > 4 ? 4 : imageUrls.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppImage.network(
            imageUrl: imageUrls[index],
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _buildVideoPreview(BuildContext context, String videoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        child: VideoPlayerWidget(isFile: false, url: videoUrl),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isLiked,
    bool isRetweeted,
  ) {
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
          isRetweeted ? Icons.repeat : Icons.repeat,
          tweet.retweetsCount,
          color: isRetweeted ? const Color(0xFF00BA7C) : null,
          onTap: () async {
            final currentUser = ref.read(currentUserModelProvider).valueOrNull;
            if (currentUser != null) {
              final tweetService = ref.read(tweetServiceProvider);
              await tweetService.retweet(tweet.id, currentUser.id);
            }
          },
        ),
        _buildActionButton(
          context,
          isLiked ? Icons.favorite : Icons.favorite_border,
          tweet.likesCount,
          color: isLiked ? const Color(0xFFF91880) : null,
          onTap: () async {
            final currentUser = ref.read(currentUserModelProvider).valueOrNull;
            if (currentUser != null) {
              final tweetService = ref.read(tweetServiceProvider);
              await tweetService.likeTweet(tweet.id, currentUser.id);
            }
          },
        ),
        _buildActionButton(
          context,
          Icons.share_outlined,
          null,
          onTap: () {
            // Share functionality
          },
        ),
        _buildActionButton(
          context,
          Icons.bookmark_border,
          null,
          onTap: () {
            // Bookmark functionality
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    int? count, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
