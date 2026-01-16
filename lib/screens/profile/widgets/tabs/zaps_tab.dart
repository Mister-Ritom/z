import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/user_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/common/loading_shimmer.dart';
import 'package:z/widgets/zap/card/zap_card.dart';

class ZapsTab extends ConsumerWidget {
  final String userId;
  final UserModel profileUser;

  const ZapsTab({super.key, required this.userId, required this.profileUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalZapsAsync = ref.watch(userZapsProvider(userId));
    final rezapsAsync = ref.watch(userRezapedZapsProvider(userId));

    return originalZapsAsync.when(
      data: (originalZaps) {
        return rezapsAsync.when(
          data: (rezapedZaps) {
            final allZaps = <ZapModel>[...originalZaps, ...rezapedZaps]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allZaps.isEmpty) {
              return const Center(child: Text('No zaps yet'));
            }

            return ListView.builder(
              itemCount: allZaps.length,
              itemBuilder: (context, index) {
                final zap = allZaps[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ZapCard(zap: zap),
                );
              },
            );
          },
          loading: () => const _ShimmerList(),
          error: (error, stack) {
            log('Error: $error', stackTrace: stack);
            return Center(child: Text('Error: $error'));
          },
        );
      },
      loading: () => const _ShimmerList(),
      error: (error, stack) {
        log('Error: $error');
        return Center(child: Text('Error: $error'));
      },
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => const ZapCardShimmer(),
    );
  }
}
