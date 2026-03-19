import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';

/// ReportService — content reporting via Supabase.
class ReportService {
  final SupabaseClient _db = Database.client;

  Future<void> reportContent({
    required String reporterId,
    required String reportType,
    required String category,
    String? postId,
    String? userId,
    String? storyId,
    String? additionalDetails,
  }) async {
    try {
      await _db.from('reports').insert({
        'reporter_id': reporterId,
        'report_type': reportType,
        'category': category,
        'reported_post_id': postId,
        'reported_user_id': userId,
        'reported_story_id': storyId,
        'additional_details': additionalDetails,
      });
      AppLogger.info('ReportService', 'Report submitted: $reportType');
    } catch (e, st) {
      AppLogger.error(
        'ReportService',
        'Failed to report',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<bool> hasReported({
    required String reporterId,
    String? postId,
    String? userId,
    String? storyId,
  }) async {
    try {
      var query = _db
          .from('reports')
          .select('id')
          .eq('reporter_id', reporterId);

      if (postId != null) query = query.eq('reported_post_id', postId);
      if (userId != null) query = query.eq('reported_user_id', userId);
      if (storyId != null) query = query.eq('reported_story_id', storyId);

      final data = await query.maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }
}
