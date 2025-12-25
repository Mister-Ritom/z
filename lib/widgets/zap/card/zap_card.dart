import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:z/info/zap/zap_detail_screen.dart';
import 'package:z/models/user_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/bookmarking_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/widgets/media/media_carousel.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/widgets/zap/card/overlay_widget.dart';

class ZapPost {
  final String id;
  final UserModel user;
  final String text;
  final List<String> mediaUrls;
  final String createdAt;
  final int likesCount;
  final int repliesCount;
  final bool isLiked;
  final String? songId;
  final bool isVerified;
  final bool isThread;
  final Privacy privacy;

  ZapPost({
    required this.id,
    required this.user,
    required this.text,
    required this.mediaUrls,
    required this.createdAt,
    required this.likesCount,
    required this.repliesCount,
    required this.isLiked,
    this.songId,
    this.isVerified = false,
    this.isThread = false,
    this.privacy = Privacy.eveyrone,
  });
}

class ZapCard extends ConsumerWidget {
  final ZapModel zap;

  const ZapCard({super.key, required this.zap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider).value?.uid ?? '';

    final userAsync = ref.watch(userProfileProvider(zap.userId));
    final isLikedAsync = ref.watch(
      postLikedStreamProvider((currentUserId, zap.id)),
    );
    final likesCountAsync = ref.watch(postLikesStreamProvider(zap.id));
    final repliesCountAsync = ref.watch(
      postCommentsCountStreamProvider(zap.id),
    );

    return userAsync.when(
      loading:
          () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
      error: (err, stack) => Text('Error loading user: $err'),
      data: (userModel) {
        if (userModel == null) return const SizedBox.shrink();

        final zapPost = ZapPost(
          id: zap.id,
          user: userModel,
          text: zap.text,
          mediaUrls: zap.mediaUrls,
          createdAt: _formatDate(zap.createdAt),
          likesCount: likesCountAsync.value ?? zap.likesCount,
          repliesCount: repliesCountAsync.value ?? zap.repliesCount,
          isLiked: isLikedAsync.value ?? false, // Stream-driven
          songId: zap.songId,
          isVerified: userModel.isVerified,
          isThread: zap.isThread,
          privacy: zap.privacy,
        );

        return ZapPostCard(
          post: zapPost,
          onLikeToggle:
              () => ref
                  .read(postAnalyticsProvider)
                  .toggleLike(
                    currentUserId,
                    zap.id,
                    zap.hashtags,
                    creatorUserId: zap.userId,
                  ),
          onBoostTap: () {
            if (currentUserId == zap.userId) return;
            ref
                .read(postAnalyticsProvider)
                .repostPost(
                  originalPostId: zap.id,
                  currentUserId: currentUserId,
                  originalUserId: zap.userId,
                );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    // Simple implementation - you can use the 'timeago' package for better results
    return timeago.format(date);
  }
}

// -----------------------------------------------------------------------------
// MAIN COMPONENT: ZAP POST CARD
// -----------------------------------------------------------------------------

class ZapPostCard extends ConsumerWidget {
  final ZapPost post;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onBoostTap;

  const ZapPostCard({
    super.key,
    required this.post,
    this.onLikeToggle,
    this.onBoostTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasMedia = post.mediaUrls.isNotEmpty;
    final bool hasText = post.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          ZapHeader(
            user: post.user,
            createdAt: post.createdAt,
            privacy: post.privacy,
            isThread: post.isThread,
            postId: post.id,
          ),

          // 2. Content Body
          if (hasMedia) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    // Media Component
                    MediaCarousel(
                      mediaUrls: post.mediaUrls,
                      maxHeight: 400, // Aspect ratio approximation
                    ),

                    // Music Badge Overlay
                    if (post.songId != null)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: _MusicBadge(songId: post.songId!),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Text Only Layout (Big Colorful Block)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDark
                          ? [const Color(0xFF0F172A), Colors.black]
                          : [const Color(0xFFEFF6FF), const Color(0xFFEEF2FF)],
                ),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
                  ),
                  bottom: BorderSide(
                    color:
                        isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
                  ),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    CoolIcon(icon: LucideIcons.zap, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      '"${post.text}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color:
                            isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 3. Caption (If Media + Text exist)
          if (hasMedia && hasText)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ZapText(text: post.text),
            ),

          // 4. Actions
          Padding(
            padding: EdgeInsets.only(
              top: (hasMedia && hasText) ? 12 : 16,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            child: // Inside ZapPostCard build method:
                ZapActions(
              likesCount: post.likesCount,
              repliesCount: post.repliesCount,
              isVerified: post.isVerified,
              isLiked: post.isLiked,
              onLikeToggle: onLikeToggle, // Passed from ZapCard
              onReplyTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZapDetailScreen(zapId: post.id),
                    ),
                  ),
              onBoostTap: onBoostTap, // Passed from ZapCard
              onShareTap: () async {
                await ref.read(postAnalyticsProvider).share(post.id);
                await SharePlus.instance.share(
                  ShareParams(
                    text:
                        "Check this out: ${AppConstants.appUrl}/zap/${post.id} on Z!",
                  ),
                );
              },
              onBookmarkTap: () async {
                final currentUser = ref.read(currentUserProvider).value;
                if (currentUser == null) return;

                final zapService = ref.read(zapServiceProvider(false));
                final bookmarked =
                    ref
                        .read(
                          isBookmarkedProvider((
                            zapId: post.id,
                            userId: currentUser.uid,
                          )),
                        )
                        .value ??
                    false;

                if (bookmarked) {
                  await zapService.removeBookmark(post.id, currentUser.uid);
                } else {
                  await zapService.bookmarkZap(post.id, currentUser.uid);
                }
                ref.invalidate(isBookmarkedProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENT: HEADER
// -----------------------------------------------------------------------------

class ZapHeader extends StatelessWidget {
  final UserModel user;
  final String createdAt;
  final Privacy privacy;
  final bool isThread;
  final String postId;

  const ZapHeader({
    super.key,
    required this.user,
    required this.createdAt,
    required this.privacy,
    required this.isThread,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Avatar
              SizedBox(
                width: 44,
                height: 44,
                child: ProfilePicture(
                  pfp: user.profilePictureUrl,
                  name: user.displayName,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (user.isVerified) ...[
                        const Icon(
                          LucideIcons.shieldCheck,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        "/ $createdAt",
                        style: TextStyle(
                          color:
                              isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        user.username,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color:
                              isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                        ),
                      ),
                      if (isThread) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.hash,
                          size: 10,
                          color: Colors.blue,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder:
                    (context) =>
                        ZapMenuSheet(postId: postId, username: user.username),
              );
            },
            icon: Icon(
              LucideIcons.ellipsis,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENT: ADVANCED TEXT (Mentions/Hashtags)
// -----------------------------------------------------------------------------

class ZapText extends StatelessWidget {
  final String text;

  const ZapText({super.key, required this.text});

  void _showTagPopup(
    BuildContext context,
    String matchText,
    TapDownDetails details,
  ) {
    final overlayController = AnchoredOverlayController();
    final box = context.findRenderObject() as RenderBox;

    final rect = Rect.fromLTWH(
      details.globalPosition.dx - 4,
      details.globalPosition.dy - 18,
      8,
      22,
    );

    overlayController.show(
      context: context,
      anchorRect: rect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(matchText, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Profile preview info'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    List<TextSpan> spans = [];

    // Simple regex based parsing for @ and #
    RegExp linkRegExp = RegExp(r"(@[\w_]+|#[\w_]+)");

    text.splitMapJoin(
      linkRegExp,
      onMatch: (Match match) {
        String matchText = match[0]!;
        final isMention = matchText.startsWith('@');

        spans.add(
          TextSpan(
            text: matchText,
            style: TextStyle(
              color:
                  isMention
                      ? (isDark
                          ? const Color(0xFF6DB6FF)
                          : const Color(0xFF1A73E8))
                      : (isDark
                          ? const Color(0xFF9AA0A6)
                          : const Color(0xFF5F6368)),
              fontWeight: isMention ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: isMention ? 0.0 : 0.4,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTapDown = (details) {
                    _showTagPopup(context, matchText, details);
                  },
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(
          TextSpan(
            text: nonMatch,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        );
        return '';
      },
    );

    return RichText(
      text: TextSpan(style: const TextStyle(fontSize: 15), children: spans),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENT: ACTIONS (Likes, Share, etc)
// -----------------------------------------------------------------------------
class ZapActions extends StatelessWidget {
  final int likesCount;
  final int repliesCount;
  final bool isVerified;
  final bool isLiked;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onReplyTap;
  final VoidCallback? onBoostTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onBookmarkTap;

  const ZapActions({
    super.key,
    required this.likesCount,
    required this.repliesCount,
    required this.isVerified,
    required this.isLiked,
    this.onReplyTap,
    this.onLikeToggle,
    this.onBoostTap,
    this.onShareTap,
    this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _ActionButton(
              icon: LucideIcons.heart,
              label:
                  likesCount > 999
                      ? "${(likesCount / 1000).toStringAsFixed(1)}K"
                      : "$likesCount",
              isActive: isLiked,
              activeColor:
                  Colors.redAccent, // Changed to Red for standard 'liked' feel
              onTap: onLikeToggle ?? () {},
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: LucideIcons.messageCircle,
              label: "$repliesCount",
              onTap: onReplyTap ?? () {},
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: LucideIcons.repeat2,
              label: "Boost",
              isTextLabel: true,
              onTap: onBoostTap ?? () {},
            ),
          ],
        ),
        Row(
          children: [
            if (isVerified)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  LucideIcons.badgeCheck,
                  size: 20,
                  color: Colors.blueAccent.withOpacity(0.6),
                ),
              ),
            CoolIconButton(
              icon: LucideIcons.share2,
              onPressed: onShareTap,
              iconColor: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            CoolIconButton(
              icon: LucideIcons.bookmark,
              onPressed: onBookmarkTap,
              iconColor: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final bool isTextLabel;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.isTextLabel = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final contentColor =
        isActive
            ? Colors.white
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade500);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: contentColor),
            if (!isTextLabel || MediaQuery.of(context).size.width > 350) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: contentColor,
                  letterSpacing: isTextLabel ? 0.5 : 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENT: MENU ACTION SHEET
// -----------------------------------------------------------------------------

class ZapMenuSheet extends StatelessWidget {
  final String postId;
  final String username;

  const ZapMenuSheet({super.key, required this.postId, required this.username});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF09090B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(40),
          bottom: Radius.circular(24),
        ),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      LucideIcons.zap,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ZAP MANAGEMENT",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "NODE_REF: $postId",
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Courier',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Options
          _MenuOption(icon: LucideIcons.link2, label: "Copy Direct Link"),
          _MenuOption(icon: LucideIcons.bookmark, label: "Archive to Vault"),
          _MenuOption(icon: LucideIcons.chartArea, label: "View Insights"),
          Divider(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            height: 32,
          ),
          _MenuOption(icon: LucideIcons.eyeOff, label: "Limit Visibility"),
          _MenuOption(
            icon: LucideIcons.userMinus,
            label: "Restrict @$username",
          ),
          _MenuOption(
            icon: LucideIcons.flag,
            label: "Report Violation",
            isDanger: true,
          ),
        ],
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDanger;

  const _MenuOption({
    required this.icon,
    required this.label,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDanger ? Colors.redAccent : (isDark ? Colors.white : Colors.black87);
    final bgHover =
        isDanger
            ? Colors.redAccent.withOpacity(0.1)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgHover,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENT: MUSIC BADGE
// -----------------------------------------------------------------------------

class _MusicBadge extends StatelessWidget {
  final String songId;

  const _MusicBadge({required this.songId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.music2,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              songId,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
