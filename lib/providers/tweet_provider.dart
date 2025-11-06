import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tweet_service.dart';
import '../models/tweet_model.dart';

final tweetServiceProvider = Provider<TweetService>((ref) {
  return TweetService();
});

final forYouFeedProvider =
    StateNotifierProvider.family<ForYouFeedNotifier, List<TweetModel>, bool>((
      ref,
      isReel,
    ) {
      final tweetService = ref.watch(tweetServiceProvider);
      return ForYouFeedNotifier(tweetService, isReel);
    });

class ForYouFeedNotifier extends StateNotifier<List<TweetModel>> {
  final TweetService _tweetService;
  final bool isReel;
  bool _isLoading = false;
  bool _hasMore = true;

  final List<StreamSubscription<List<TweetModel>>> _pageSubs = [];

  ForYouFeedNotifier(this._tweetService, this.isReel) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    if (_isLoading) return;
    _isLoading = true;

    final firstPageStream = _tweetService.getForYouFeed(isReel: isReel);
    _subscribeToPage(firstPageStream);

    _isLoading = false;
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || state.isEmpty) return;
    _isLoading = true;

    final lastDoc = state.last.docSnapshot;
    final nextPageStream = _tweetService.getForYouFeed(
      lastDoc: lastDoc,
      isReel: isReel,
    );
    _subscribeToPage(nextPageStream);

    _isLoading = false;
  }

  void _subscribeToPage(Stream<List<TweetModel>> pageStream) {
    final sub = pageStream.listen((tweets) {
      if (tweets.isEmpty) {
        _hasMore = false;
      } else {
        // Create a map of current tweets by ID
        final currentMap = {for (var t in state) t.id: t};

        // Merge or update tweets from server
        for (var tweet in tweets) {
          currentMap[tweet.id] = tweet; // This will replace if already exists
        }

        state = currentMap.values.toList();
      }
    });
    _pageSubs.add(sub);
  }

  @override
  void dispose() {
    for (var sub in _pageSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}

final followingFeedProvider = StreamProvider.family<List<TweetModel>, String>((
  ref,
  userId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getFollowingFeed(userId);
});

final userTweetsProvider = StreamProvider.family<List<TweetModel>, String>((
  ref,
  userId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getUserTweets(userId);
});
final searchTweetsProvider = FutureProvider.family<List<TweetModel>, String>((
  ref,
  query,
) async {
  final tweetService = ref.watch(tweetServiceProvider);
  return await tweetService.searchTweets(query);
});

final tweetRepliesProvider = StreamProvider.family<List<TweetModel>, String>((
  ref,
  tweetId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getTweetReplies(tweetId);
});

final userRepliesProvider = StreamProvider.family<List<TweetModel>, String>((
  ref,
  userId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getUserReplies(userId);
});

final userLikedTweetsProvider = StreamProvider.family<List<TweetModel>, String>(
  (ref, userId) {
    final tweetService = ref.watch(tweetServiceProvider);
    return tweetService.getUserLikedTweets(userId);
  },
);

final userRetweetedTweetsProvider =
    StreamProvider.family<List<TweetModel>, String>((ref, userId) {
      final tweetService = ref.watch(tweetServiceProvider);
      return tweetService.getUserRetweetedTweets(userId);
    });

final userBookmarkedTweetsProvider =
    StreamProvider.family<List<TweetModel>, String>((ref, userId) {
      final tweetService = ref.watch(tweetServiceProvider);
      return tweetService.getUserBookmarkedTweets(userId);
    });

final tweetProvider = FutureProvider.family<TweetModel?, String>((
  ref,
  tweetId,
) async {
  final tweetService = ref.watch(tweetServiceProvider);
  return await tweetService.getTweetById(tweetId);
});
final isBookmarkedProvider =
    FutureProvider.family<bool, ({String tweetId, String userId})>((
      ref,
      args,
    ) async {
      final tweetService = ref.watch(tweetServiceProvider);
      return await tweetService.isBookmarked(args.tweetId, args.userId);
    });
