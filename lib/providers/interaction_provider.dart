import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/social/interaction_service.dart';

final interactionServiceProvider = Provider.family<InteractionService, bool>((
  ref,
  isShort,
) {
  return InteractionService(isShortVideo: isShort);
});

// ─── POST INTERACTIONS ──────────────────────────────────

final postLikedProvider =
    FutureProvider.family<bool, (String userId, String targetId, bool isShort)>(
      (ref, params) async {
        final (userId, targetId, isShort) = params;
        final service = ref.watch(interactionServiceProvider(isShort));
        return await service.isLiked(userId, targetId);
      },
    );

// ─── STORY INTERACTIONS ─────────────────────────────────

final storyLikedProvider =
    FutureProvider.family<bool, (String userId, String storyId)>((
      ref,
      params,
    ) async {
      final (userId, storyId) = params;
      final service = ref.watch(interactionServiceProvider(false));
      final data = await service.isLiked(
        userId,
        storyId,
      ); // Reuse logic if possible or separate
      return data;
    });

// ─── USER INTERACTIONS ──────────────────────────────────

final userLikedProvider =
    FutureProvider.family<bool, (String userId, String targetUserId)>((
      ref,
      params,
    ) async {
      final (userId, targetUserId) = params;
      final service = ref.watch(interactionServiceProvider(false));
      return await service.isUserLiked(userId, targetUserId);
    });

// ─── LIKED CONTENT LISTS ───────────────────────────────

final likedContentIdsProvider =
    FutureProvider.family<List<String>, (String userId, bool isShort)>((
      ref,
      params,
    ) async {
      final (userId, isShort) = params;
      final service = ref.watch(interactionServiceProvider(isShort));
      return await service.getLikedContentIds(userId);
    });

final resharedContentIdsProvider =
    FutureProvider.family<List<String>, (String userId, bool isShort)>((
      ref,
      params,
    ) async {
      final (userId, isShort) = params;
      final service = ref.watch(interactionServiceProvider(isShort));
      return await service.getResharedContentIds(userId);
    });

// ─── REALTIME STREAMS ───────────────────────────────────

final postLikedStreamProvider =
    StreamProvider.family<bool, (String userId, String targetId, bool isShort)>(
      (ref, params) {
        final (userId, targetId, isShort) = params;
        final service = ref.watch(interactionServiceProvider(isShort));
        return service.likedStream(userId, targetId);
      },
    );

final postLikesCountStreamProvider =
    StreamProvider.family<int, (String targetId, bool isShort)>((ref, params) {
      final (targetId, isShort) = params;
      final service = ref.watch(interactionServiceProvider(isShort));
      return service.likesCountStream(targetId);
    });

final postCommentsCountStreamProvider =
    StreamProvider.family<int, (String targetId, bool isShort)>((ref, params) {
      final (targetId, isShort) = params;
      final service = ref.watch(interactionServiceProvider(isShort));
      return service.commentsCountStream(targetId);
    });

final postSharesCountStreamProvider =
    StreamProvider.family<int, (String targetId, bool isShort)>((ref, params) {
      final (targetId, isShort) = params;
      final service = ref.watch(interactionServiceProvider(isShort));
      return service.sharesCountStream(targetId);
    });
