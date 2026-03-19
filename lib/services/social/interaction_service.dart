import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';
import '../analytics/analytics_service.dart';

/// InteractionService — unified service for likes, views, shares, and reposts.
/// Replaces PostAnalyticsService, StoryAnalyticsService, and UserAnalyticsService.
/// Uses `user_interactions` table + counter columns on content tables.
class InteractionService {
  final SupabaseClient _db = Database.client;
  final bool isShortVideo;
  final AnalyticsService? analytics;

  InteractionService({this.isShortVideo = false, this.analytics});

  String get _contentType => isShortVideo ? 'short' : 'zap';
  String get _contentTable => isShortVideo ? 'shorts' : 'zaps';

  // ─── STREAMS ───────────────────────────────────────────

  Stream<bool> likedStream(String userId, String targetId) {
    return _db
        .from('user_interactions')
        .stream(primaryKey: ['user_id', 'target_id', 'target_type'])
        .map((data) {
          final interaction = data.where(
            (d) =>
                d['user_id'] == userId &&
                d['target_id'] == targetId &&
                d['target_type'] == _contentType,
          );
          return interaction.isNotEmpty && interaction.first['liked'] == true;
        });
  }

  Stream<int> likesCountStream(String targetId) {
    return _db.from(_contentTable).stream(primaryKey: ['id']).map((data) {
      final content = data.where((d) => d['id'] == targetId);
      return content.isNotEmpty
          ? (content.first['likes_count'] as int? ?? 0)
          : 0;
    });
  }

  Stream<int> sharesCountStream(String targetId) {
    return _db.from(_contentTable).stream(primaryKey: ['id']).map((data) {
      final content = data.where((d) => d['id'] == targetId);
      return content.isNotEmpty
          ? (content.first['shares_count'] as int? ?? 0)
          : 0;
    });
  }

  Stream<int> commentsCountStream(String targetId) {
    return _db.from(_contentTable).stream(primaryKey: ['id']).map((data) {
      final content = data.where((d) => d['id'] == targetId);
      return content.isNotEmpty
          ? (content.first['comments_count'] as int? ?? 0)
          : 0;
    });
  }

  Stream<bool> storyViewedStream(String userId, String storyId) {
    return _db
        .from('user_interactions')
        .stream(primaryKey: ['user_id', 'target_id', 'target_type'])
        .map((data) {
          final interaction = data.where(
            (d) =>
                d['user_id'] == userId &&
                d['target_id'] == storyId &&
                d['target_type'] == 'story',
          );
          return interaction.isNotEmpty && interaction.first['viewed'] == true;
        });
  }

  Stream<bool> storyLikedStream(String userId, String storyId) {
    return _db
        .from('user_interactions')
        .stream(primaryKey: ['user_id', 'target_id', 'target_type'])
        .map((data) {
          final interaction = data.where(
            (d) =>
                d['user_id'] == userId &&
                d['target_id'] == storyId &&
                d['target_type'] == 'story',
          );
          return interaction.isNotEmpty && interaction.first['liked'] == true;
        });
  }

  // ─── LIKES ─────────────────────────────────────────────

  Future<bool> isLiked(String userId, String targetId) async {
    try {
      final data =
          await _db
              .from('user_interactions')
              .select('liked')
              .eq('user_id', userId)
              .eq('target_id', targetId)
              .eq('target_type', _contentType)
              .maybeSingle();
      return data?['liked'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleLike(String userId, String targetId) async {
    try {
      final liked = await isLiked(userId, targetId);
      final now = DateTime.now().toIso8601String();

      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': targetId,
        'target_type': _contentType,
        'liked': !liked,
        'liked_at': !liked ? now : null,
      });

      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': _contentTable,
          'p_column': 'likes_count',
          'p_id': targetId,
          'p_amount': liked ? -1 : 1,
        },
      );

      analytics?.capture(
        eventName: 'content_liked',
        properties: {
          'target_id': targetId,
          'target_type': _contentType,
          'is_liked': !liked,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to toggle like',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ─── VIEWS DEBOUNCING ──────────────────────────────────
  static final Map<String, Set<String>> _viewBuffer = {};
  static DateTime _lastFlush = DateTime.now();
  static bool _isFlushing = false;

  Future<void> view(String userId, String targetId) async {
    try {
      _viewBuffer.putIfAbsent(_contentType, () => {}).add(targetId);

      final shouldFlush =
          DateTime.now().difference(_lastFlush).inSeconds > 10 ||
          (_viewBuffer[_contentType]?.length ?? 0) >= 20;

      if (shouldFlush && !_isFlushing) {
        _flushViews(userId); // Non-blocking flush
      }
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to buffer view',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _flushViews(String userId) async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final targets = _viewBuffer[_contentType]?.toList() ?? [];
      if (targets.isEmpty) return;

      _viewBuffer[_contentType]?.clear();
      _lastFlush = DateTime.now();

      for (final id in targets) {
        await _db.from('user_interactions').upsert({
          'user_id': userId,
          'target_id': id,
          'target_type': _contentType,
          'viewed': true,
          'viewed_at': DateTime.now().toIso8601String(),
        });

        await _db.rpc(
          'increment_counter',
          params: {
            'p_table': _contentTable,
            'p_column': 'views_count',
            'p_id': id,
            'p_amount': 1,
          },
        );

        analytics?.capture(
          eventName: 'content_viewed',
          properties: {'target_id': id, 'target_type': _contentType},
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Flush failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isFlushing = false;
    }
  }

  // ─── SHARES ────────────────────────────────────────────

  Future<void> share(String targetId) async {
    try {
      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': _contentTable,
          'p_column': 'shares_count',
          'p_id': targetId,
          'p_amount': 1,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to record share',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ─── REPOSTS ───────────────────────────────────────────

  Future<void> toggleRepost(String userId, String targetId) async {
    try {
      final existing =
          await _db
              .from('user_interactions')
              .select('reshared')
              .eq('user_id', userId)
              .eq('target_id', targetId)
              .eq('target_type', _contentType)
              .maybeSingle();

      final isReshared = existing?['reshared'] == true;

      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': targetId,
        'target_type': _contentType,
        'reshared': !isReshared,
        'reshared_at': !isReshared ? DateTime.now().toIso8601String() : null,
      });

      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': _contentTable,
          'p_column': 'rezaps_count',
          'p_id': targetId,
          'p_amount': isReshared ? -1 : 1,
        },
      );

      analytics?.capture(
        eventName: 'content_reshared',
        properties: {
          'target_id': targetId,
          'target_type': _contentType,
          'is_reshared': !isReshared,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to toggle repost',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ─── SKIP ──────────────────────────────────────────────

  Future<void> skip(String userId, String targetId) async {
    try {
      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': targetId,
        'target_type': _contentType,
        'skipped': true,
      });

      analytics?.capture(
        eventName: 'content_skipped',
        properties: {'target_id': targetId, 'target_type': _contentType},
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to record skip',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ─── STORY INTERACTIONS ────────────────────────────────

  Future<void> toggleStoryLike(String userId, String storyId) async {
    try {
      final existing =
          await _db
              .from('user_interactions')
              .select('liked')
              .eq('user_id', userId)
              .eq('target_id', storyId)
              .eq('target_type', 'story')
              .maybeSingle();

      final isLiked = existing?['liked'] == true;

      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': storyId,
        'target_type': 'story',
        'liked': !isLiked,
        'liked_at': !isLiked ? DateTime.now().toIso8601String() : null,
      });

      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': 'stories',
          'p_column': 'likes_count',
          'p_id': storyId,
          'p_amount': isLiked ? -1 : 1,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to toggle story like',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> viewStory(String userId, String storyId) async {
    try {
      final existing =
          await _db
              .from('user_interactions')
              .select('viewed')
              .eq('user_id', userId)
              .eq('target_id', storyId)
              .eq('target_type', 'story')
              .maybeSingle();

      if (existing?['viewed'] == true) return;

      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': storyId,
        'target_type': 'story',
        'viewed': true,
        'viewed_at': DateTime.now().toIso8601String(),
      });

      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': 'stories',
          'p_column': 'views_count',
          'p_id': storyId,
          'p_amount': 1,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to view story',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ─── USER LIKES ────────────────────────────────────────

  Future<void> toggleUserLike(String userId, String targetUserId) async {
    try {
      final existing =
          await _db
              .from('user_interactions')
              .select('liked')
              .eq('user_id', userId)
              .eq('target_id', targetUserId)
              .eq('target_type', 'user')
              .maybeSingle();

      final isLiked = existing?['liked'] == true;

      await _db.from('user_interactions').upsert({
        'user_id': userId,
        'target_id': targetUserId,
        'target_type': 'user',
        'liked': !isLiked,
        'liked_at': !isLiked ? DateTime.now().toIso8601String() : null,
      });
    } catch (e, st) {
      AppLogger.error(
        'InteractionService',
        'Failed to toggle user like',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> isUserLiked(String userId, String targetUserId) async {
    try {
      final data =
          await _db
              .from('user_interactions')
              .select('liked')
              .eq('user_id', userId)
              .eq('target_id', targetUserId)
              .eq('target_type', 'user')
              .maybeSingle();
      return data?['liked'] == true;
    } catch (e) {
      return false;
    }
  }

  // ─── QUERIES ───────────────────────────────────────────

  Future<List<String>> getLikedContentIds(String userId) async {
    try {
      final data = await _db
          .from('user_interactions')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', _contentType)
          .eq('liked', true);
      return data.map<String>((d) => d['target_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getResharedContentIds(String userId) async {
    try {
      final data = await _db
          .from('user_interactions')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', _contentType)
          .eq('reshared', true);
      return data.map<String>((d) => d['target_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}
