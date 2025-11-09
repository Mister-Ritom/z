import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryVisibility {
  public,
  followers,
  mutual;

  String get name {
    switch (this) {
      case StoryVisibility.public:
        return 'public';
      case StoryVisibility.followers:
        return 'followers';
      case StoryVisibility.mutual:
        return 'mutual';
    }
  }

  static StoryVisibility fromString(String str) {
    switch (str) {
      case 'followers':
        return StoryVisibility.followers;
      case 'mutual':
        return StoryVisibility.mutual;
      case 'public':
      default:
        return StoryVisibility.public;
    }
  }
}

class StoryModel {
  final String id;
  final String userId;
  final String caption;
  final String mediaUrl;
  final Duration duration = Duration(seconds: 15);
  final StoryVisibility visibility;
  final DateTime createdAt;
  final List<String> visibleTo;

  StoryModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.mediaUrl,
    required this.visibility,
    required this.createdAt,
    required this.visibleTo,
  });

  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      id: doc.id,
      userId: data['userId'],
      caption: data['caption'],
      mediaUrl: data['mediaUrl'],
      visibility: StoryVisibility.fromString(data['visibility'] ?? 'public'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      visibleTo: List<String>.from(data['visibleTo'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caption': caption,
      'mediaUrl': mediaUrl,
      'visibility': visibility.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'visibleTo': visibleTo,
    };
  }
}
