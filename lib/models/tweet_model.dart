class TweetModel {
  final String id;
  final String userId;
  final String? parentTweetId; // For replies
  final String? quotedTweetId; // For quote tweets
  final String text;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final DateTime createdAt;
  final int likesCount;
  final int retweetsCount;
  final int repliesCount;
  final List<String> likedBy;
  final List<String> retweetedBy;
  final bool isThread;
  final String? threadParentId;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isDeleted;

  TweetModel({
    required this.id,
    required this.userId,
    this.parentTweetId,
    this.quotedTweetId,
    required this.text,
    this.imageUrls = const [],
    this.videoUrls = const [],
    required this.createdAt,
    this.likesCount = 0,
    this.retweetsCount = 0,
    this.repliesCount = 0,
    this.likedBy = const [],
    this.retweetedBy = const [],
    this.isThread = false,
    this.threadParentId,
    this.hashtags = const [],
    this.mentions = const [],
    this.isDeleted = false,
  });

  factory TweetModel.fromMap(Map<String, dynamic> map) {
    return TweetModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      parentTweetId: map['parentTweetId'],
      quotedTweetId: map['quotedTweetId'],
      text: map['text'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      videoUrls: List<String>.from(map['videoUrls'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      retweetsCount: map['retweetsCount'] ?? 0,
      repliesCount: map['repliesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      retweetedBy: List<String>.from(map['retweetedBy'] ?? []),
      isThread: map['isThread'] ?? false,
      threadParentId: map['threadParentId'],
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'parentTweetId': parentTweetId,
      'quotedTweetId': quotedTweetId,
      'text': text,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'retweetsCount': retweetsCount,
      'repliesCount': repliesCount,
      'likedBy': likedBy,
      'retweetedBy': retweetedBy,
      'isThread': isThread,
      'threadParentId': threadParentId,
      'hashtags': hashtags,
      'mentions': mentions,
      'isDeleted': isDeleted,
    };
  }

  TweetModel copyWith({
    String? id,
    String? userId,
    String? parentTweetId,
    String? quotedTweetId,
    String? text,
    List<String>? imageUrls,
    List<String>? videoUrls,
    DateTime? createdAt,
    int? likesCount,
    int? retweetsCount,
    int? repliesCount,
    List<String>? likedBy,
    List<String>? retweetedBy,
    bool? isThread,
    String? threadParentId,
    List<String>? hashtags,
    List<String>? mentions,
    bool? isDeleted,
  }) {
    return TweetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parentTweetId: parentTweetId ?? this.parentTweetId,
      quotedTweetId: quotedTweetId ?? this.quotedTweetId,
      text: text ?? this.text,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      retweetsCount: retweetsCount ?? this.retweetsCount,
      repliesCount: repliesCount ?? this.repliesCount,
      likedBy: likedBy ?? this.likedBy,
      retweetedBy: retweetedBy ?? this.retweetedBy,
      isThread: isThread ?? this.isThread,
      threadParentId: threadParentId ?? this.threadParentId,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
