import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class RepliesTab extends ConsumerWidget {
  final String userId;

  const RepliesTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(userRepliesProvider(userId));

    return repliesAsync.when(
      data: (replies) {
        if (replies.isEmpty) {
          return const Center(child: Text('No replies yet'));
        }
        return ListView.builder(
          itemCount: replies.length,
          itemBuilder: (context, index) => ZapCard(zap: replies[index]),
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
