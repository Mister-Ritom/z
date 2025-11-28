import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class FollowingTab extends ConsumerWidget {
  final String userId;

  const FollowingTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapsAsync = ref.watch(followingFeedProvider(userId));
    return zapsAsync.when(
      data: (zaps) {
        if (zaps.isEmpty) {
          return const Center(
            child: Text('Follow users to see their zaps here'),
          );
        }
        return ListView.builder(
          itemCount: zaps.length + 1,
          itemBuilder: (context, index) {
            if (index == zaps.length) {
              return const SizedBox(
                height: 160,
                child: Center(child: Text('You reached the end')),
              );
            }
            final zap = zaps[index];
            return ZapCard(zap: zap);
          },
        );
      },
      loading:
          () => ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => const ZapCardShimmer(),
          ),
      error: (error, stack) {
        return Center(child: Text('Error: $error'));
      },
    );
  }
}
