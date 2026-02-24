import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/constants.dart';
import 'package:z/models/story_model.dart';
import 'package:z/utils/logger.dart';

/// StoryService — Supabase-backed stories.
class StoryService {
  final SupabaseClient _db = Database.client;

  Future<List<StoryModel>> getStoriesVisibleTo(String currentUserId) async {
    try {
      final cutoff =
          DateTime.now()
              .subtract(Duration(hours: AppConstants.storyExpiryHours))
              .toIso8601String();

      final data = await _db
          .from('stories')
          .select()
          .eq('is_deleted', false)
          .gte('created_at', cutoff)
          .or(
            'visibility.eq.public,user_id.eq.$currentUserId,visible_to.cs.{$currentUserId}',
          )
          .order('created_at', ascending: false);

      return data.map<StoryModel>((d) => StoryModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to get visible stories',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<StoryModel>> getLatestPublicStories({int limit = 200}) async {
    try {
      final cutoff =
          DateTime.now()
              .subtract(Duration(hours: AppConstants.storyExpiryHours))
              .toIso8601String();

      final data = await _db
          .from('stories')
          .select()
          .eq('visibility', 'public')
          .eq('is_deleted', false)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(limit);

      return data.map<StoryModel>((d) => StoryModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to get public stories',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<StoryModel>> getStoriesByUser(String uid) async {
    try {
      final cutoff =
          DateTime.now()
              .subtract(Duration(hours: AppConstants.storyExpiryHours))
              .toIso8601String();

      final data = await _db
          .from('stories')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false);

      return data.map<StoryModel>((d) => StoryModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to get user stories',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<StoryModel>> getStoriesByIds(List<String> storyIds) async {
    if (storyIds.isEmpty) return [];
    try {
      final data = await _db
          .from('stories')
          .select()
          .inFilter('id', storyIds)
          .eq('is_deleted', false);
      return data.map<StoryModel>((d) => StoryModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to get stories by IDs',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<bool> userHasStories(String uid) async {
    try {
      final cutoff =
          DateTime.now()
              .subtract(Duration(hours: AppConstants.storyExpiryHours))
              .toIso8601String();

      final data =
          await _db
              .from('stories')
              .select('id')
              .eq('user_id', uid)
              .eq('is_deleted', false)
              .gte('created_at', cutoff)
              .limit(1)
              .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> createStory({
    required String uid,
    required String caption,
    required String mediaUrl,
    required StoryVisibility visibility,
    required List<String> visibleTo,
  }) async {
    try {
      await _db.from('stories').insert({
        'user_id': uid,
        'caption': caption,
        'media_url': mediaUrl,
        'visibility': visibility.name,
        'visible_to': visibleTo,
        'is_deleted': false,
      });
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to create story',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deleteStory({
    required String storyId,
    required String userId,
  }) async {
    try {
      await _db
          .from('stories')
          .update({'is_deleted': true})
          .eq('id', storyId)
          .eq('user_id', userId);
    } catch (e, st) {
      AppLogger.error(
        'StoryService',
        'Failed to delete story',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
