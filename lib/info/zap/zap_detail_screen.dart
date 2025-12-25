import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/zap_provider.dart';
import '../../providers/profile_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class ZapDetailScreen extends ConsumerWidget {
  final String zapId;

  const ZapDetailScreen({super.key, required this.zapId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapAsync = ref.watch(zapProvider(zapId));
    final repliesAsync = ref.watch(zapRepliesProvider(zapId));

    return Scaffold(
      appBar: AppBar(title: const Text('Zap')),
      body: zapAsync.when(
        data: (zap) {
          if (zap == null) {
            return const Center(child: Text('Zap not found'));
          }

          // Get user for zap
          final userAsync = ref.watch(userProfileProvider(zap.userId));

          return userAsync.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('User not found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main zap
                    ZapCard(zap: zap),
                    const Divider(),
                    // Reply composer button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          /*
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ZapComposer(replyToZapId: zap.id),
                            ),
                          );
                          */
                        },
                        icon: const Icon(Icons.reply),
                        label: const Text('Reply'),
                      ),
                    ),
                    const Divider(),
                    // Replies
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Replies',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    repliesAsync.when(
                      data: (replies) {
                        if (replies.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('No replies yet')),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: replies.length,
                          itemBuilder: (context, index) {
                            final reply = replies[index];
                            final replyUserAsync = ref.watch(
                              userProfileProvider(reply.userId),
                            );

                            return replyUserAsync.when(
                              data: (replyUser) {
                                if (replyUser == null) {
                                  return Text("Something went wrong");
                                }
                                return ZapCard(zap: reply);
                              },
                              loading: () => const ZapCardShimmer(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                        );
                      },
                      loading:
                          () => ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 3,
                            itemBuilder:
                                (context, index) => const ZapCardShimmer(),
                          ),
                      error: (error, stack) {
                        log("Error: $error");
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: Text('Error: $error')),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading user')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          log("Error: $error");
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }
}
