import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart'
    show SharePlus, ShareParams, XFile, CupertinoActivityType;
import 'package:z/info/zap/zap_detail_screen.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/bookmarking_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/helpers.dart';

import 'zap_card.dart';

class ZapActionsRow extends ConsumerWidget {
  final ZapModel zap;
  final AsyncValue<bool> isLikedStream;
  final AsyncValue<bool> isBookmarked;
  final String currentUserId;

  const ZapActionsRow({
    super.key,
    required this.zap,
    required this.isLikedStream,
    required this.isBookmarked,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return isLikedStream.when(
      data:
          (isLiked) =>
              _buildActions(context, ref, isLiked, isBookmarked.value ?? false),
      loading:
          () => _buildActions(context, ref, false, isBookmarked.value ?? false),
      error:
          (_, __) =>
              _buildActions(context, ref, false, isBookmarked.value ?? false),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isLiked,
    bool isBookmarked,
  ) {
    final isRezaping = ref.watch(rezapingProvider(zap.id));
    final isLiking = ref.watch(likingProvider(zap.id));
    final isBookmarking = ref.watch(bookmarkingProvider(zap.id));
    final postAnalytics = ref.read(postAnalyticsProvider);
    final zapService = ref.read(zapServiceProvider(false));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          count: zap.repliesCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ZapDetailScreen(zapId: zap.id),
              ),
            );
          },
        ),
        _ActionButton(
          icon: Icons.repeat,
          isLoading: isRezaping,
          onTap:
              isRezaping
                  ? null
                  : () async {
                    if (zap.userId == currentUserId) return;
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
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
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
                        creatorUserId: zap.userId,
                      );
                    } finally {
                      ref.read(likingProvider(zap.id).notifier).state = false;
                    }
                  },
        ),
        _ActionButton(
          icon: Icons.share_outlined,
          onTap: () async {
            final file =
                zap.mediaUrls.isNotEmpty
                    ? await _cachedImageToXFile(zap.mediaUrls.first)
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
        _ActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color? color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.count,
    this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4),
            Text(
              Helpers.formatNumber(count!),
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

Future<XFile?> _cachedImageToXFile(String imageUrl) async {
  final cacheManager = CachedNetworkImageProvider.defaultCacheManager;
  final fileInfo = await cacheManager.getFileFromCache(imageUrl);
  if (fileInfo != null) {
    return XFile(fileInfo.file.path);
  } else {
    final file = await cacheManager.getSingleFile(imageUrl);
    return XFile(file.path);
  }
}
