import 'package:cloud_firestore/cloud_firestore.dart';

class TweetModel {
  final String id;
  final String userId;
  final String? originalUserId;
  final String? parentTweetId; // For replies
  final String? quotedTweetId; // For quote tweets
  final String text;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final int likesCount;
  final int retweetsCount;
  final int repliesCount;
  final bool isThread;
  final bool isReel;
  final String? threadParentId;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isDeleted;
  final DocumentSnapshot? docSnapshot;

  TweetModel({
    required this.id,
    required this.userId,
    this.originalUserId,
    this.isReel = false,
    this.docSnapshot,
    this.parentTweetId,
    this.quotedTweetId,
    required this.text,
    this.mediaUrls = const [],
    required this.createdAt,
    this.likesCount = 0,
    this.retweetsCount = 0,
    this.repliesCount = 0,
    this.isThread = false,
    this.threadParentId,
    this.hashtags = const [],
    this.mentions = const [],
    this.isDeleted = false,
  });

  factory TweetModel.fromMap(
    Map<String, dynamic> map, {
    DocumentSnapshot? snapshot,
  }) {
    return TweetModel(
      id: map['id'] ?? '',
      isReel: map['isReel'] ?? false,
      originalUserId: map['originalUserId'],
      docSnapshot: snapshot,
      userId: map['userId'] ?? '',
      parentTweetId: map['parentTweetId'],
      quotedTweetId: map['quotedTweetId'],
      text: map['text'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      retweetsCount: map['retweetsCount'] ?? 0,
      repliesCount: map['repliesCount'] ?? 0,
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
      'isReel': isReel,
      'parentTweetId': parentTweetId,
      'quotedTweetId': quotedTweetId,
      'text': text,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'retweetsCount': retweetsCount,
      'repliesCount': repliesCount,
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
    List<String>? mediaUrls,
    DateTime? createdAt,
    int? likesCount,
    int? retweetsCount,
    int? repliesCount,
    bool? isThread,
    bool? isReel,
    String? threadParentId,
    List<String>? hashtags,
    List<String>? mentions,
    bool? isDeleted,
  }) {
    return TweetModel(
      id: id ?? this.id,
      docSnapshot: docSnapshot,
      userId: userId ?? this.userId,
      parentTweetId: parentTweetId ?? this.parentTweetId,
      quotedTweetId: quotedTweetId ?? this.quotedTweetId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      retweetsCount: retweetsCount ?? this.retweetsCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isThread: isThread ?? this.isThread,
      isReel: isReel ?? this.isReel,
      threadParentId: threadParentId ?? this.threadParentId,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
