import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class LikesTab extends ConsumerWidget {
  final String userId;

  const LikesTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(userLikedZapsProvider(userId));

    return likedAsync.when(
      data: (likedZaps) {
        if (likedZaps.isEmpty) {
          return const Center(child: Text('No liked zaps yet'));
        }
        return ListView.builder(
          itemCount: likedZaps.length,
          itemBuilder: (context, index) => ZapCard(zap: likedZaps[index]),
        );
      },
      loading:
          () => ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const ZapCardShimmer(),
          ),
      error: (error, stack) {
        log('Error: $error');
        return Center(child: Text('Error: $error'));
      },
    );
  }
}
