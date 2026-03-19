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
        return 'close_friends';
    }
  }

  static StoryVisibility fromString(String str) {
    switch (str) {
      case 'followers':
        return StoryVisibility.followers;
      case 'mutual':
      case 'close_friends':
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
  final Duration duration = const Duration(seconds: 15);
  final StoryVisibility visibility;
  final DateTime createdAt;
  final List<String> visibleTo;
  final bool isDeleted;
  final int likesCount;
  final int viewsCount;
  final int sharesCount;

  StoryModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.mediaUrl,
    required this.visibility,
    required this.createdAt,
    required this.visibleTo,
    this.isDeleted = false,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      caption: map['caption'] ?? '',
      mediaUrl: map['media_url'] ?? '',
      visibility: StoryVisibility.fromString(map['visibility'] ?? 'public'),
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'].toString())
              : DateTime.now(),
      visibleTo: List<String>.from(map['visible_to'] ?? []),
      isDeleted: map['is_deleted'] ?? false,
      likesCount: map['likes_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'caption': caption,
      'media_url': mediaUrl,
      'visibility': visibility.name,
      'visible_to': visibleTo,
      'is_deleted': isDeleted,
    };
  }
}
