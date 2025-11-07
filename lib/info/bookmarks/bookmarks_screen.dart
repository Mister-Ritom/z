import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/tweet_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/widgets/tweet_card.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bookmarkedTweets = ref.watch(
      userBookmarkedTweetsProvider(currentUser.id),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: bookmarkedTweets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          log("Error", error: e, stackTrace: st);
          return Center(child: Text('Error: $e'));
        },
        data: (tweets) {
          if (tweets.isEmpty) {
            return const Center(child: Text('No bookmarks yet'));
          }
          return ListView.separated(
            itemCount: tweets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tweet = tweets[index];
              final user =
                  ref.watch(userProfileProvider(tweet.userId)).valueOrNull;
              if (user == null) {
                return Text("Something went wrong");
              }
              return TweetCard(tweet: tweet, user: user);
            },
          );
        },
      ),
    );
  }
}
