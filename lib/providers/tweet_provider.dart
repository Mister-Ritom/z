import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/utils/constants.dart';
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

  ForYouFeedNotifier(this._tweetService, this.isReel) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final firstPage = await _tweetService.getForYouFeed(isReel: isReel).first;
      state = firstPage;
      _hasMore = firstPage.length == AppConstants.tweetsPerPage;
    } catch (e) {
      log("Something went wrong", error: e);
    }
    _isLoading = false;
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || state.isEmpty) return;
    _isLoading = true;

    try {
      final lastDoc = state.last.docSnapshot;
      final nextPage =
          await _tweetService
              .getForYouFeed(lastDoc: lastDoc, isReel: isReel)
              .first;
      state = [...state, ...nextPage];
      _hasMore = nextPage.length == AppConstants.tweetsPerPage;
    } catch (e) {
      log("Something went wrong", error: e);
    }
    _isLoading = false;
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
