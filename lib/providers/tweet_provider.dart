import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tweet_service.dart';
import '../models/tweet_model.dart';

final tweetServiceProvider = Provider<TweetService>((ref) {
  return TweetService();
});

final forYouFeedProvider = StreamProvider<List<TweetModel>>((ref) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getForYouFeed();
});

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

final userLikedTweetsProvider = StreamProvider.family<List<TweetModel>, String>((
  ref,
  userId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getUserLikedTweets(userId);
});

final userRetweetedTweetsProvider =
    StreamProvider.family<List<TweetModel>, String>((
  ref,
  userId,
) {
  final tweetService = ref.watch(tweetServiceProvider);
  return tweetService.getUserRetweetedTweets(userId);
});

final tweetProvider = FutureProvider.family<TweetModel?, String>((
  ref,
  tweetId,
) async {
  final tweetService = ref.watch(tweetServiceProvider);
  return await tweetService.getTweetById(tweetId);
});
