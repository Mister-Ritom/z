import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/widgets/loading_shimmer.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tweet_provider.dart';
import '../../widgets/user_card.dart';
import '../../widgets/tweet_card.dart'; // assume you have a TweetCard widget

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchUsersAsync = ref.watch(searchUsersProvider(_searchQuery));
    final searchTweetsAsync = ref.watch(searchTweetsProvider(_searchQuery));

    final isEmptyQuery = _searchQuery.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search users or tweets',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
      body:
          isEmptyQuery
              ? const Center(
                child: Text('Search for users, tweets, or hashtags'),
              )
              : _buildCombinedResults(searchUsersAsync, searchTweetsAsync),
    );
  }

  Widget _buildCombinedResults(
    AsyncValue<List<dynamic>> usersAsync,
    AsyncValue<List<dynamic>> tweetsAsync,
  ) {
    // Combine both async values manually
    if (usersAsync.isLoading || tweetsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (usersAsync.hasError || tweetsAsync.hasError) {
      log(
        "Search Error",
        error: usersAsync.error ?? tweetsAsync.error,
        stackTrace: usersAsync.stackTrace ?? tweetsAsync.stackTrace,
      );
      return Center(
        child: Text('Error: ${usersAsync.error ?? tweetsAsync.error}'),
      );
    }

    final users = usersAsync.value ?? [];
    final tweets = tweetsAsync.value ?? [];

    if (users.isEmpty && tweets.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView(
      children: [
        if (users.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Users',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ...users.map(
            (user) => UserCard(
              user: user,
              onTap: () {
                // navigate to profile
              },
            ),
          ),
          const Divider(height: 32),
        ],
        if (tweets.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tweets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ...tweets.map((tweet) {
            final userAsync = ref.watch(userProfileProvider(tweet.userId));
            return userAsync.when(
              data: (user) {
                if (user == null) {
                  return Text("User not found");
                }
                return TweetCard(
                  tweet: tweet,
                  user: user,
                  onTap: () => context.push('/tweet/${tweet.id}'),
                  onUserTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: user.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const TweetCardShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            );
          }),
        ],
      ],
    );
  }
}
