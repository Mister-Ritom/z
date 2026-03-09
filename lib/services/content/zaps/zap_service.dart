import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:z/utils/logger.dart';
import '../../../supabase/database.dart';
import '../../../models/zap_model.dart';
import '../../../utils/constants.dart';

/// Unified ZapService — all CRUD, queries, and comments in one file.
class ZapService {
  final bool isShort;
  final SupabaseClient _db = Database.client;

  ZapService({this.isShort = false});

  String get _table =>
      isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection;

  // ─── CRUD ──────────────────────────────────────────────

  Future<ZapModel> createZap(ZapModel zap) async {
    try {
      final id = zap.id.isEmpty ? const Uuid().v4() : zap.id;
      final data = zap.copyWith(id: id, isShort: isShort).toMap();
      await _db.from(_table).insert(data);

      // Increment user's zaps count
      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': 'profiles',
          'p_column': 'zaps_count',
          'p_id': zap.userId,
          'p_amount': 1,
        },
      );

      AppLogger.info('ZapService', 'Created zap: $id');
      return zap.copyWith(id: id);
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to create zap',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<ZapModel?> getZapById(String zapId) async {
    try {
      final data =
          await _db
              .from(_table)
              .select()
              .eq('id', zapId)
              .eq('is_deleted', false)
              .maybeSingle();
      if (data == null) return null;
      return ZapModel.fromMap(data);
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get zap',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> deleteZap(String zapId, String userId) async {
    try {
      await _db
          .from(_table)
          .update({'is_deleted': true})
          .eq('id', zapId)
          .eq('user_id', userId);
      AppLogger.info('ZapService', 'Deleted zap: $zapId');
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to delete zap',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<ZapModel>> searchZaps(String query) async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('is_deleted', false)
          .or('text.ilike.%$query%,hashtags.cs.{$query}')
          .order('created_at', ascending: false)
          .limit(AppConstants.zapsPerPage);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to search zaps',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ─── BOOKMARKS ─────────────────────────────────────────

  Future<void> bookmarkZap(String zapId, String userId) async {
    try {
      await _db.from('bookmarks').upsert({'user_id': userId, 'zap_id': zapId});
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to bookmark',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> removeBookmark(String zapId, String userId) async {
    try {
      await _db
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('zap_id', zapId);
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to remove bookmark',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isBookmarked(String zapId, String userId) async {
    try {
      final data =
          await _db
              .from('bookmarks')
              .select('id')
              .eq('user_id', userId)
              .eq('zap_id', zapId)
              .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  // ─── FEEDS & QUERIES ──────────────────────────────────

  Future<List<ZapModel>> getUserZaps(String userId) async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .isFilter('parent_zap_id', null)
          .order('created_at', ascending: false)
          .limit(50);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get user zaps',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getFollowingFeed(String userId) async {
    try {
      // Get the list of users this user follows
      final followsData = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      final followingIds =
          followsData.map<String>((d) => d['following_id'] as String).toList();

      if (followingIds.isEmpty) return [];

      final data = await _db
          .from(_table)
          .select()
          .eq('is_deleted', false)
          .isFilter('parent_zap_id', null)
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false)
          .limit(50);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get following feed',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getZapReplies(String zapId) async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('parent_zap_id', zapId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get replies',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getUserReplies(String userId) async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .not('parent_zap_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(50);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get user replies',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getUserLikedZaps(String userId) async {
    try {
      final interactions = await _db
          .from('user_interactions')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', isShort ? 'short' : 'zap')
          .eq('liked', true)
          .order('liked_at', ascending: false)
          .limit(50);

      final ids =
          interactions.map<String>((d) => d['target_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _db
          .from(_table)
          .select()
          .inFilter('id', ids)
          .eq('is_deleted', false);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get liked zaps',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getUserRezapedZaps(String userId) async {
    try {
      final interactions = await _db
          .from('user_interactions')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', isShort ? 'short' : 'zap')
          .eq('reshared', true)
          .order('reshared_at', ascending: false)
          .limit(50);

      final ids =
          interactions.map<String>((d) => d['target_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _db
          .from(_table)
          .select()
          .inFilter('id', ids)
          .eq('is_deleted', false);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get rezaped zaps',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<ZapModel>> getUserBookmarkedZaps(String userId) async {
    try {
      final bookmarks = await _db
          .from('bookmarks')
          .select('zap_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final ids = bookmarks.map<String>((d) => d['zap_id'] as String).toList();
      if (ids.isEmpty) return [];

      final data = await _db
          .from(_table)
          .select()
          .inFilter('id', ids)
          .eq('is_deleted', false);
      return data.map<ZapModel>((d) => ZapModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get bookmarked zaps',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ─── COMMENTS ──────────────────────────────────────────

  Future<void> addComment({
    required String postId,
    required String userId,
    required String text,
  }) async {
    try {
      await _db.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'text': text,
      });

      // Increment comments count on the zap
      await _db.rpc(
        'increment_counter',
        params: {
          'p_table': _table,
          'p_column': 'comments_count',
          'p_id': postId,
          'p_amount': 1,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to add comment',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getComments(
    String postId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await _db
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(data);
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Failed to get comments',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
