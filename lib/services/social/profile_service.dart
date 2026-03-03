import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/models/user_model.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';
import '../analytics/analytics_service.dart';

/// ProfileService — fully Supabase-backed.
/// Handles CRUD, follow/unfollow, search, and blocking.
class ProfileService {
  final SupabaseClient _db = Database.client;
  final AnalyticsService? analytics;

  ProfileService({this.analytics});

  // ─── PROFILE CRUD ──────────────────────────────────────

  Future<void> createProfile(UserModel user) async {
    try {
      await _db.from('profiles').insert(user.toMap());
      AppLogger.info('ProfileService', 'Profile created: ${user.id}');
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to create profile',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<UserModel?> getProfileByUserId(String userId) async {
    try {
      final data =
          await _db.from('profiles').select().eq('id', userId).maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to get profile',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final data =
          await _db
              .from('profiles')
              .select()
              .eq('username', username)
              .maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to get user by username',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> updateProfile(
    String userId, {
    String? displayName,
    String? bio,
    String? profilePictureUrl,
    String? coverPhotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (profilePictureUrl != null) {
        updates['profile_picture_url'] = profilePictureUrl;
      }
      if (coverPhotoUrl != null) updates['cover_photo_url'] = coverPhotoUrl;

      await _db.from('profiles').update(updates).eq('id', userId);
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to update profile',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final data =
          await _db
              .from('profiles')
              .select('id')
              .eq('username', username)
              .maybeSingle();
      return data == null;
    } catch (e) {
      return false;
    }
  }

  Future<String> getAvailableUsername(String base) async {
    String username = base;
    int counter = 1;
    while (!(await isUsernameAvailable(username))) {
      username = '$base$counter';
      counter++;
    }
    return username;
  }

  // ─── FOLLOW / UNFOLLOW ─────────────────────────────────

  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _db.rpc(
        'follow_user',
        params: {'p_follower_id': followerId, 'p_following_id': followingId},
      );

      analytics?.capture(
        eventName: 'user_followed',
        properties: {'follower_id': followerId, 'following_id': followingId},
      );
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to follow user',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _db.rpc(
        'unfollow_user',
        params: {'p_follower_id': followerId, 'p_following_id': followingId},
      );

      analytics?.capture(
        eventName: 'user_unfollowed',
        properties: {'follower_id': followerId, 'following_id': followingId},
      );
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to unfollow user',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final data =
          await _db
              .from('follows')
              .select('id')
              .eq('follower_id', followerId)
              .eq('following_id', followingId)
              .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getUserFollowers(String userId) async {
    try {
      final data = await _db
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);
      return data.map<String>((d) => d['follower_id'] as String).toList();
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to get followers',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<String>> getUserFollowing(String userId) async {
    try {
      final data = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      return data.map<String>((d) => d['following_id'] as String).toList();
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to get following',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ─── SEARCH ────────────────────────────────────────────

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      final data = await _db
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);
      return data.map<UserModel>((d) => UserModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'ProfileService',
        'Failed to search users',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
