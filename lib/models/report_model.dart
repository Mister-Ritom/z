enum ReportType { post, user, story }

enum ReportCategory {
  spam,
  harassment,
  hateSpeech,
  inappropriateContent,
  misinformation,
  violence,
  selfHarm,
  copyright,
  other,
}

class ReportModel {
  final String id;
  final String reporterId;
  final ReportType reportType;
  final String? reportedPostId;
  final String? reportedUserId;
  final String? reportedStoryId;
  final ReportCategory category;
  final String? additionalDetails;
  final DateTime createdAt;
  final bool isResolved;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportType,
    this.reportedPostId,
    this.reportedUserId,
    this.reportedStoryId,
    required this.category,
    this.additionalDetails,
    required this.createdAt,
    this.isResolved = false,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      reporterId: map['reporter_id'] ?? map['reporterId'] ?? '',
      reportType: _reportTypeFromString(
        map['report_type'] ?? map['reportType'] ?? 'post',
      ),
      reportedPostId: map['reported_post_id'] ?? map['reportedPostId'],
      reportedUserId: map['reported_user_id'] ?? map['reportedUserId'],
      reportedStoryId: map['reported_story_id'] ?? map['reportedStoryId'],
      category: _categoryFromString(map['category'] ?? 'other'),
      additionalDetails: map['additional_details'] ?? map['additionalDetails'],
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : (map['createdAt'] != null
                  ? DateTime.parse(map['createdAt'])
                  : DateTime.now()),
      isResolved: map['is_resolved'] ?? map['isResolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'report_type': _reportTypeToString(reportType),
      'reported_post_id': reportedPostId,
      'reported_user_id': reportedUserId,
      'reported_story_id': reportedStoryId,
      'category': _categoryToString(category),
      'additional_details': additionalDetails,
      'created_at': createdAt.toIso8601String(),
      'is_resolved': isResolved,
    };
  }

  static ReportType _reportTypeFromString(String str) {
    switch (str) {
      case 'user':
        return ReportType.user;
      case 'story':
        return ReportType.story;
      case 'post':
        return ReportType.post;
      default:
        return ReportType.post;
    }
  }

  static String _reportTypeToString(ReportType type) {
    switch (type) {
      case ReportType.user:
        return 'user';
      case ReportType.story:
        return 'story';
      case ReportType.post:
        return 'post';
    }
  }

  static ReportCategory _categoryFromString(String str) {
    switch (str) {
      case 'spam':
        return ReportCategory.spam;
      case 'harassment':
        return ReportCategory.harassment;
      case 'hateSpeech':
        return ReportCategory.hateSpeech;
      case 'inappropriateContent':
        return ReportCategory.inappropriateContent;
      case 'misinformation':
        return ReportCategory.misinformation;
      case 'violence':
        return ReportCategory.violence;
      case 'selfHarm':
        return ReportCategory.selfHarm;
      case 'copyright':
        return ReportCategory.copyright;
      case 'other':
        return ReportCategory.other;
      default:
        return ReportCategory.other;
    }
  }

  static String _categoryToString(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return 'spam';
      case ReportCategory.harassment:
        return 'harassment';
      case ReportCategory.hateSpeech:
        return 'hateSpeech';
      case ReportCategory.inappropriateContent:
        return 'inappropriateContent';
      case ReportCategory.misinformation:
        return 'misinformation';
      case ReportCategory.violence:
        return 'violence';
      case ReportCategory.selfHarm:
        return 'selfHarm';
      case ReportCategory.copyright:
        return 'copyright';
      case ReportCategory.other:
        return 'other';
    }
  }
}
