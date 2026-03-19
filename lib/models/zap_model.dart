enum Privacy {
  eveyrone,
  followers,
  unlisted;

  @override
  String toString() {
    switch (this) {
      case Privacy.eveyrone:
        return 'public';
      case Privacy.followers:
        return 'followers';
      case Privacy.unlisted:
        return 'private';
    }
  }

  static Privacy parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'everyone':
      case 'public':
        return Privacy.eveyrone;
      case 'followers':
        return Privacy.followers;
      case 'unlisted':
      case 'private':
        return Privacy.unlisted;
      default:
        return Privacy.eveyrone;
    }
  }
}

class ZapModel {
  final String id;
  final String userId;
  final String? originalUserId;
  final String? parentZapId;
  final String? quotedZapId;
  final String text;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final int likesCount;
  final int rezapsCount;
  final int repliesCount;
  final int viewsCount;
  final int sharesCount;
  final int commentsCount;
  final bool isThread;
  final bool isShort;
  final String? threadParentId;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isDeleted;
  final String? songId;
  final Privacy privacy;
  final DateTime? updatedAt;

  ZapModel({
    required this.id,
    required this.userId,
    this.originalUserId,
    this.parentZapId,
    this.quotedZapId,
    required this.text,
    this.mediaUrls = const [],
    required this.createdAt,
    this.likesCount = 0,
    this.rezapsCount = 0,
    this.repliesCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.commentsCount = 0,
    this.isThread = false,
    this.isShort = false,
    this.threadParentId,
    this.hashtags = const [],
    this.mentions = const [],
    this.isDeleted = false,
    this.songId,
    this.privacy = Privacy.eveyrone,
    this.updatedAt,
  });

  factory ZapModel.fromMap(Map<String, dynamic> map) {
    final urls = List<String>.from(map['media_urls'] ?? []);

    return ZapModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      originalUserId: map['original_user_id'],
      parentZapId: map['parent_zap_id'],
      quotedZapId: map['quoted_zap_id'],
      text: map['text'] ?? '',
      mediaUrls: urls,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
      likesCount: map['likes_count'] ?? 0,
      rezapsCount: map['rezaps_count'] ?? 0,
      repliesCount: map['replies_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      isThread: map['is_thread'] ?? false,
      isShort: map['is_short'] ?? false,
      threadParentId: map['thread_parent_id'],
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      isDeleted: map['is_deleted'] ?? false,
      songId: map['song_id'],
      privacy: Privacy.parse(map['privacy']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'original_user_id': originalUserId,
      'parent_zap_id': parentZapId,
      'quoted_zap_id': quotedZapId,
      'text': text,
      'media_urls': mediaUrls,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
      'rezaps_count': rezapsCount,
      'replies_count': repliesCount,
      'views_count': viewsCount,
      'shares_count': sharesCount,
      'comments_count': commentsCount,
      'is_thread': isThread,
      'is_short': isShort,
      'thread_parent_id': threadParentId,
      'hashtags': hashtags,
      'mentions': mentions,
      'is_deleted': isDeleted,
      'song_id': songId,
      'privacy': privacy.toString(),
    };
  }

  ZapModel copyWith({
    String? id,
    String? userId,
    String? originalUserId,
    String? parentZapId,
    String? quotedZapId,
    String? text,
    List<String>? mediaUrls,
    DateTime? createdAt,
    int? likesCount,
    int? rezapsCount,
    int? repliesCount,
    int? viewsCount,
    int? sharesCount,
    int? commentsCount,
    bool? isThread,
    bool? isShort,
    String? threadParentId,
    List<String>? hashtags,
    List<String>? mentions,
    bool? isDeleted,
    String? songId,
    Privacy? privacy,
  }) {
    return ZapModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      originalUserId: originalUserId ?? this.originalUserId,
      parentZapId: parentZapId ?? this.parentZapId,
      quotedZapId: quotedZapId ?? this.quotedZapId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      rezapsCount: rezapsCount ?? this.rezapsCount,
      repliesCount: repliesCount ?? this.repliesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isThread: isThread ?? this.isThread,
      isShort: isShort ?? this.isShort,
      threadParentId: threadParentId ?? this.threadParentId,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      isDeleted: isDeleted ?? this.isDeleted,
      songId: songId ?? this.songId,
      privacy: privacy ?? this.privacy,
    );
  }
}
