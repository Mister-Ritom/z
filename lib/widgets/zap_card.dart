import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/utils/constants.dart';
import 'package:z/widgets/loading_shimmer.dart';
import 'package:z/widgets/media_carousel.dart';
import 'package:z/widgets/profile_picture.dart';
import '../models/zap_model.dart';
import '../models/user_model.dart';
import '../providers/zap_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/helpers.dart';
import '../info/zap/zap_detail_screen.dart';

final rezapingProvider = StateProvider.family<bool, String>(
  (ref, zapId) => false,
);
final likingProvider = StateProvider.family<bool, String>(
  (ref, zapId) => false,
);
final bookmarkingProvider = StateProvider.family<bool, String>(
  (ref, zapId) => false,
);

class ZapCard extends ConsumerWidget {
  final ZapModel zap;
  final bool showThreadLine;
  final Function()? onTap;

  const ZapCard({
    super.key,
    required this.zap,
    this.showThreadLine = false,
    this.onTap,
  });

  void onUserTap(BuildContext context, UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.id)),
    );
  }

  Widget _userWidget(
    AsyncValue<UserModel?> userAsync,
    AsyncValue<UserModel?> originalUserAsync,
    BuildContext context,
  ) {
    return originalUserAsync.when(
      data: (user) {
        if (user == null) return const Text("Something went wrong");
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () {
            onUserTap(context, user);
          },
          leading: ProfilePicture(
            name: user.displayName,
            pfp: user.profilePictureUrl,
          ),
          title: Row(
            children: [
              Text(
                user.displayName,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 18,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '·',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(color: Colors.blueGrey),
              ),
              const SizedBox(width: 4),
              Text(
                timeago.format(zap.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.blueGrey),
              ),
            ],
          ),
          subtitle: Text('@${user.username}'),
          subtitleTextStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        );
      },
      loading: () => const ZapCardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      context.go("/login");
      return const Text("Sign in");
    }

    final userAsync = ref.watch(userProfileProvider(zap.userId));
    final originalUserAsync =
        zap.originalUserId != null
            ? ref.watch(userProfileProvider(zap.originalUserId!))
            : userAsync;
    final isBookmarked = ref.watch(
      isBookmarkedProvider((zapId: zap.id, userId: currentUser.uid)),
    );
    final isLikedStream = ref.watch(
      postLikedStreamProvider((currentUser.uid, zap.id)),
    );

    final mediaUrls = zap.mediaUrls;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (originalUserAsync.valueOrNull?.id != userAsync.valueOrNull?.id)
              RichText(
                text: TextSpan(
                  text: "Reposted by ",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: userAsync.valueOrNull!.username,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              onUserTap(context, userAsync.valueOrNull!);
                            },
                    ),
                  ],
                ),
              ),
            _userWidget(userAsync, originalUserAsync, context),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                zap.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            MediaCarousel(mediaUrls: mediaUrls),
            const SizedBox(height: 12),
            isLikedStream.when(
              data:
                  (isLiked) => _buildActions(
                    context,
                    ref,
                    isLiked,
                    isBookmarked.value ?? false,
                    currentUser.uid,
                  ),
              loading:
                  () => _buildActions(
                    context,
                    ref,
                    false,
                    isBookmarked.value ?? false,
                    currentUser.uid,
                  ),
              error:
                  (_, __) => _buildActions(
                    context,
                    ref,
                    false,
                    isBookmarked.value ?? false,
                    currentUser.uid,
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
    bool isBookmarked,
    String currentUserId,
  ) {
    final isRezaping = ref.watch(rezapingProvider(zap.id));
    final isLiking = ref.watch(likingProvider(zap.id));
    final isBookmarking = ref.watch(bookmarkingProvider(zap.id));

    final postAnalytics = ref.read(postAnalyticsProvider);
    final zapService = ref.read(zapServiceProvider(false));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          context,
          Icons.chat_bubble_outline,
          zap.repliesCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ZapDetailScreen(zapId: zap.id),
              ),
            );
          },
        ),
        _buildActionButton(
          context,
          Icons.repeat,
          null,
          isLoading: isRezaping,
          onTap:
              isRezaping
                  ? null
                  : () async {
                    if (zap.userId == currentUserId) {
                      return;
                    }
                    ref.read(rezapingProvider(zap.id).notifier).state = true;
                    try {
                      await postAnalytics.repostPost(
                        originalPostId: zap.id,
                        currentUserId: currentUserId,
                        originalUserId: zap.userId,
                      );
                    } finally {
                      ref.read(rezapingProvider(zap.id).notifier).state = false;
                    }
                  },
        ),
        _buildActionButton(
          context,
          isLiked ? Icons.favorite : Icons.favorite_border,
          null,
          color: isLiked ? const Color(0xFFF91880) : null,
          isLoading: isLiking,
          onTap:
              isLiking
                  ? null
                  : () async {
                    ref.read(likingProvider(zap.id).notifier).state = true;
                    try {
                      await postAnalytics.toggleLike(
                        currentUserId,
                        zap.id,
                        zap.hashtags,
                      );
                    } finally {
                      ref.read(likingProvider(zap.id).notifier).state = false;
                    }
                  },
        ),
        _buildActionButton(
          context,
          Icons.share_outlined,
          null,
          onTap: () async {
            final file =
                zap.mediaUrls.isNotEmpty
                    ? await cachedImageToXFile(zap.mediaUrls[0])
                    : null;

            await postAnalytics.share(zap.id);

            final user = ref.read(userProfileProvider(zap.userId)).valueOrNull;
            await SharePlus.instance.share(
              ShareParams(
                title:
                    user != null
                        ? "Share ${user.displayName}'s post"
                        : "Share Post",
                text:
                    "Check out this post: ${AppConstants.appUrl}/zap/${zap.id}",
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
                    ref.read(bookmarkingProvider(zap.id).notifier).state = true;
                    try {
                      if (isBookmarked) {
                        await zapService.removeBookmark(zap.id, currentUserId);
                      } else {
                        await zapService.bookmarkZap(zap.id, currentUserId);
                      }
                      ref.invalidate(
                        isBookmarkedProvider((
                          zapId: zap.id,
                          userId: currentUserId,
                        )),
                      );
                    } finally {
                      ref.read(bookmarkingProvider(zap.id).notifier).state =
                          false;
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
