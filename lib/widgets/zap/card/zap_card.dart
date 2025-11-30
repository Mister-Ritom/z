import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/widgets/common/loading_shimmer.dart';
import 'package:z/widgets/media/media_carousel.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/widgets/zap/card/zap_user_header.dart';
import 'package:z/widgets/zap/card/zap_repost_banner.dart';
import 'package:z/widgets/zap/card/zap_actions_row.dart';
import 'package:z/widgets/zap/card/zap_options_sheet.dart';

final rezapingProvider = StateProvider.family<bool, String>(
  (ref, zapId) => false,
);
final likingProvider = StateProvider.family<bool, String>(
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

    final shouldShowRepost =
        originalUserAsync.valueOrNull?.id != userAsync.valueOrNull?.id;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shouldShowRepost && userAsync.valueOrNull != null)
              ZapRepostBanner(
                username: userAsync.valueOrNull!.username,
                onTap: () {
                  final user = userAsync.valueOrNull;
                  if (user != null) {
                    onUserTap(context, user);
                  }
                },
              ),
            originalUserAsync.when(
              data:
                  (user) =>
                      user == null
                          ? const SizedBox.shrink()
                          : ZapUserHeader(
                            user: user,
                            createdAt: zap.createdAt,
                            onTap: () => onUserTap(context, user),
                            onMoreOptions: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ZapOptionsSheet(
                                  zap: zap,
                                  currentUserId: currentUser.uid,
                                  isBookmarked: isBookmarked.value ?? false,
                                ),
                              );
                            },
                          ),
              loading: () => const ZapCardShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                zap.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            MediaCarousel(mediaUrls: mediaUrls),
            const SizedBox(height: 12),
            ZapActionsRow(
              zap: zap,
              isLikedStream: isLikedStream,
              isBookmarked: isBookmarked,
              currentUserId: currentUser.uid,
            ),
          ],
        ),
      ),
    );
  }
}
