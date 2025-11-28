import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class MediaTab extends ConsumerWidget {
  final String userId;

  const MediaTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapsAsync = ref.watch(userZapsProvider(userId));
    return zapsAsync.when(
      data: (zaps) {
        final mediaZaps =
            zaps.where((zap) => zap.mediaUrls.isNotEmpty).toList();
        if (mediaZaps.isEmpty) {
          return const Center(child: Text('No media yet'));
        }
        return ListView.builder(
          itemCount: mediaZaps.length,
          itemBuilder: (context, index) => ZapCard(zap: mediaZaps[index]),
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
