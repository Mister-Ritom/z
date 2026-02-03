import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/empty_state_widget.dart';
import 'package:z/widgets/moments/moments_rail.dart';

class FollowingTab extends ConsumerWidget {
  final String userId;

  const FollowingTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapsAsync = ref.watch(followingFeedProvider(userId));
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: MomentsRail(),
          ),
        ),
        zapsAsync.when(
          data: (zaps) {
            if (zaps.isEmpty) {
              return SliverFillRemaining(
                child: EmptyStateWidget(
                  title: 'Your circle is quiet',
                  description:
                      'This feed is for your close friends. Share your profile to get started.',
                  icon: Icons.people_outline_rounded,
                  buttonText: 'Share Profile',
                  onButtonPressed: () {
                    SharePlus.instance.share(
                      ShareParams(text: 'Add me on Z! My user ID is $userId'),
                    );
                  },
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == zaps.length) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: Text('You reached the end')),
                  );
                }
                final zap = zaps[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ZapCard(zap: zap),
                );
              }, childCount: zaps.length + 1),
            );
          },
          loading:
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CoolSkeleton.card(),
                  ),
                  childCount: 10,
                ),
              ),
          error: (error, stack) {
            return SliverToBoxAdapter(
              child: Center(child: Text('Error: $error')),
            );
          },
        ),
      ],
    );
  }
}
