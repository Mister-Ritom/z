import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';

/// BlockService — unified blocking for users, posts, and messaging.
/// Uses a single `blocks` table with a `block_type` column.
class BlockService {
  final SupabaseClient _db = Database.client;

  // ─── USER BLOCKS ───────────────────────────────────────

  Future<void> blockUser(String blockerId, String blockedUserId) async {
    try {
      await _db.from('blocks').upsert({
        'blocker_id': blockerId,
        'block_type': 'user',
        'blocked_user_id': blockedUserId,
      });
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to block user',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> unblockUser(String blockerId, String blockedUserId) async {
    try {
      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('block_type', 'user')
          .eq('blocked_user_id', blockedUserId);
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to unblock user',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isUserBlocked(String blockerId, String blockedUserId) async {
    try {
      final data =
          await _db
              .from('blocks')
              .select('id')
              .eq('blocker_id', blockerId)
              .eq('block_type', 'user')
              .eq('blocked_user_id', blockedUserId)
              .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getBlockedUserIds(String userId) async {
    try {
      final data = await _db
          .from('blocks')
          .select('blocked_user_id')
          .eq('blocker_id', userId)
          .eq('block_type', 'user');
      return data.map<String>((d) => d['blocked_user_id'] as String).toList();
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to get blocked users',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ─── POST BLOCKS ───────────────────────────────────────

  Future<void> blockPost(String blockerId, String postId) async {
    try {
      await _db.from('blocks').upsert({
        'blocker_id': blockerId,
        'block_type': 'post',
        'blocked_post_id': postId,
      });
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to block post',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isPostBlocked(String blockerId, String postId) async {
    try {
      final data =
          await _db
              .from('blocks')
              .select('id')
              .eq('blocker_id', blockerId)
              .eq('block_type', 'post')
              .eq('blocked_post_id', postId)
              .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  // ─── MESSAGING BLOCKS ─────────────────────────────────

  Future<void> blockMessaging(String blockerId, String blockedUserId) async {
    try {
      await _db.from('blocks').upsert({
        'blocker_id': blockerId,
        'block_type': 'messaging',
        'blocked_user_id': blockedUserId,
      });
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to block messaging',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> unblockMessaging(String blockerId, String blockedUserId) async {
    try {
      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('block_type', 'messaging')
          .eq('blocked_user_id', blockedUserId);
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Failed to unblock messaging',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isMessagingBlocked(String userId1, String userId2) async {
    try {
      final data =
          await _db
              .from('blocks')
              .select('id')
              .eq('block_type', 'messaging')
              .or('blocker_id.eq.$userId1,blocker_id.eq.$userId2')
              .or('blocked_user_id.eq.$userId1,blocked_user_id.eq.$userId2')
              .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }
}
