import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/analytics/post_analytics_service.dart';
import 'package:z/analytics/story_analytics_service.dart';
import 'package:z/analytics/user_analytics_service.dart';

final postAnalyticsProvider = Provider((ref) => PostAnalyticsService());
final storyAnalyticsProvider = Provider((ref) => StoryAnalyticsService());
final shortVideoAnalyticsProvider = Provider(
  (ref) => PostAnalyticsService(isShortVideo: true),
);
final userAnalyticsProvider = Provider((ref) => UserAnalyticsService());

// ------------------------------------------------------------
// 🧩 POST ANALYTICS STREAMS
// ------------------------------------------------------------

final postLikedStreamProvider =
    StreamProvider.family<bool, (String userId, String postId)>((ref, params) {
      final (userId, postId) = params;
      final service = ref.watch(postAnalyticsProvider);
      return service.isLikedStream(userId, postId);
    });

final postViewsStreamProvider = StreamProvider.family<int, String>((
  ref,
  postId,
) {
  final service = ref.watch(postAnalyticsProvider);
  return service.viewsStream(postId);
});

final postCommentsCountStreamProvider = StreamProvider.family<int, String>((
  ref,
  postId,
) {
  final service = ref.watch(postAnalyticsProvider);
  return service.commentsCountStream(postId);
});

final postSharesStreamProvider = StreamProvider.family<int, String>((
  ref,
  postId,
) {
  final service = ref.watch(postAnalyticsProvider);
  return service.sharesStream(postId);
});

// ------------------------------------------------------------
// 🧩 STORY ANALYTICS STREAMS
// ------------------------------------------------------------

final storyLikedStreamProvider =
    StreamProvider.family<bool, (String userId, String storyId)>((ref, params) {
      final (userId, storyId) = params;
      final service = ref.watch(storyAnalyticsProvider);
      return service.isStoryLikedStream(userId, storyId);
    });

final storyViewsStreamProvider = StreamProvider.family<int, String>((
  ref,
  storyId,
) {
  final service = ref.watch(storyAnalyticsProvider);
  return service.storyViewsStream(storyId);
});

final storySharesStreamProvider = StreamProvider.family<int, String>((
  ref,
  storyId,
) {
  final service = ref.watch(storyAnalyticsProvider);
  return service.storySharesStream(storyId);
});

// ------------------------------------------------------------
// 🧩 SHORT VIDEO ANALYTICS STREAMS
// ------------------------------------------------------------

final videoLikedStreamProvider =
    StreamProvider.family<bool, (String userId, String videoId)>((ref, params) {
      final (userId, videoId) = params;
      final service = ref.watch(shortVideoAnalyticsProvider);
      return service.isLikedStream(userId, videoId);
    });

final videoViewsStreamProvider = StreamProvider.family<int, String>((
  ref,
  videoId,
) {
  final service = ref.watch(shortVideoAnalyticsProvider);
  return service.viewsStream(videoId);
});

final videoCommentsCountStreamProvider = StreamProvider.family<int, String>((
  ref,
  videoId,
) {
  final service = ref.watch(shortVideoAnalyticsProvider);
  return service.commentsCountStream(videoId);
});

final videoSharesStreamProvider = StreamProvider.family<int, String>((
  ref,
  videoId,
) {
  final service = ref.watch(shortVideoAnalyticsProvider);
  return service.sharesStream(videoId);
});

// ------------------------------------------------------------
// 🧩 USER ANALYTICS STREAMS
// ------------------------------------------------------------

final userLikedStreamProvider =
    StreamProvider.family<bool, (String userId, String targetUserId)>((
      ref,
      params,
    ) {
      final (userId, targetUserId) = params;
      final service = ref.watch(userAnalyticsProvider);
      return service.isUserLikedStream(userId, targetUserId);
    });

final userTotalLikesStreamProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  final service = ref.watch(userAnalyticsProvider);
  return service.userTotalLikesStream(userId);
});
