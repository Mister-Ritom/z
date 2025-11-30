import 'package:cloud_firestore/cloud_firestore.dart';

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
      reporterId: map['reporterId'] ?? '',
      reportType: _reportTypeFromString(map['reportType'] ?? 'post'),
      reportedPostId: map['reportedPostId'],
      reportedUserId: map['reportedUserId'],
      reportedStoryId: map['reportedStoryId'],
      category: _categoryFromString(map['category'] ?? 'other'),
      additionalDetails: map['additionalDetails'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isResolved: map['isResolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reportType': _reportTypeToString(reportType),
      'reportedPostId': reportedPostId,
      'reportedUserId': reportedUserId,
      'reportedStoryId': reportedStoryId,
      'category': _categoryToString(category),
      'additionalDetails': additionalDetails,
      'createdAt': Timestamp.fromDate(createdAt),
      'isResolved': isResolved,
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
