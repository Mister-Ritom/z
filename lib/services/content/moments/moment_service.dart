import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';

/// MomentService — Supabase-backed ephemeral moments.
class MomentService {
  final SupabaseClient _db = Database.client;

  Future<void> createMoment(MomentModel moment) async {
    try {
      await _db.from('moments').insert(moment.toMap());
      AppLogger.info('MomentService', 'Created moment');
    } catch (e, st) {
      AppLogger.error(
        'MomentService',
        'Failed to create moment',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<MomentModel>> getUserMoments(String userId) async {
    try {
      final data = await _db
          .from('moments')
          .select()
          .eq('user_id', userId)
          .eq('is_expired', false)
          .order('created_at', ascending: false)
          .limit(20);
      return data.map<MomentModel>((d) => MomentModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'MomentService',
        'Failed to get user moments',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<List<MomentModel>> getMomentsFeed({
    required List<String> followingIds,
    required String currentUserId,
  }) async {
    if (followingIds.isEmpty) return [];

    try {
      final yesterday =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final allIds = [...followingIds, currentUserId];

      final data = await _db
          .from('moments')
          .select()
          .inFilter('user_id', allIds)
          .eq('is_expired', false)
          .neq('visibility', 'private')
          .gte('created_at', yesterday)
          .order('created_at', ascending: false)
          .limit(10);

      return data.map<MomentModel>((d) => MomentModel.fromMap(d)).toList();
    } catch (e, st) {
      AppLogger.error(
        'MomentService',
        'Failed to get moments feed',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
