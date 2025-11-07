import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tweet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/tweet_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/tweet_composer.dart';

class TweetDetailScreen extends ConsumerWidget {
  final String tweetId;

  const TweetDetailScreen({super.key, required this.tweetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tweetAsync = ref.watch(tweetProvider(tweetId));
    final repliesAsync = ref.watch(tweetRepliesProvider(tweetId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tweet')),
      body: tweetAsync.when(
        data: (tweet) {
          if (tweet == null) {
            return const Center(child: Text('Tweet not found'));
          }

          // Get user for tweet
          final userAsync = ref.watch(userProfileProvider(tweet.userId));

          return userAsync.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('User not found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main tweet
                    TweetCard(tweet: tweet),
                    const Divider(),
                    // Reply composer button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      TweetComposer(replyToTweetId: tweet.id),
                            ),
                          );
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
                                return TweetCard(
                                  tweet: reply,
                                  showThreadLine: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => TweetDetailScreen(
                                              tweetId: reply.id,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const TweetCardShimmer(),
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
                                (context, index) => const TweetCardShimmer(),
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
