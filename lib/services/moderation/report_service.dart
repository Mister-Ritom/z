import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/report_model.dart';
import 'package:z/utils/logger.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Report a post, user, or story
  Future<void> reportContent({
    required String reporterId,
    required ReportType reportType,
    String? postId,
    String? userId,
    String? storyId,
    required ReportCategory category,
    String? additionalDetails,
  }) async {
    try {
      // Validate that the correct ID is provided based on report type
      if (reportType == ReportType.post && postId == null) {
        throw Exception('Post ID is required for post reports');
      }
      if (reportType == ReportType.user && userId == null) {
        throw Exception('User ID is required for user reports');
      }
      if (reportType == ReportType.story && storyId == null) {
        throw Exception('Story ID is required for story reports');
      }

      final report = ReportModel(
        id: _firestore.collection('reports').doc().id,
        reporterId: reporterId,
        reportType: reportType,
        reportedPostId: postId,
        reportedUserId: userId,
        reportedStoryId: storyId,
        category: category,
        additionalDetails: additionalDetails,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('reports')
          .doc(report.id)
          .set(report.toMap());

      AppLogger.info(
        'ReportService',
        'Content reported successfully',
        data: {
          'reportId': report.id,
          'reportType': reportType.toString(),
          'category': category.toString(),
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'ReportService',
        'Error reporting content',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to report content: $e');
    }
  }

  /// Check if user has already reported this content
  Future<bool> hasReported({
    required String reporterId,
    required ReportType reportType,
    String? postId,
    String? userId,
    String? storyId,
  }) async {
    try {
      Query query = _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportType', isEqualTo: reportType.toString().split('.').last);

      if (reportType == ReportType.post && postId != null) {
        query = query.where('reportedPostId', isEqualTo: postId);
      } else if (reportType == ReportType.user && userId != null) {
        query = query.where('reportedUserId', isEqualTo: userId);
      } else if (reportType == ReportType.story && storyId != null) {
        query = query.where('reportedStoryId', isEqualTo: storyId);
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      AppLogger.error(
        'ReportService',
        'Error checking if content is reported',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}

