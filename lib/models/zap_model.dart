import 'package:cloud_firestore/cloud_firestore.dart';

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
  final bool isThread;
  final bool isShort;
  final String? threadParentId;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isDeleted;
  final String? songId;
  final DocumentSnapshot? docSnapshot;

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
    this.isThread = false,
    this.threadParentId,
    this.hashtags = const [],
    this.mentions = const [],
    this.isDeleted = false,
    this.songId, // 👈 NEW
    this.isShort = false,
    this.docSnapshot,
  });

  factory ZapModel.fromMap(
    Map<String, dynamic> map, {
    DocumentSnapshot? snapshot,
  }) {
    final urls = List<String>.from((map['mediaUrls'] ?? []));
    if (map.containsKey("mediaUrl")) urls.add(map["mediaUrl"]);
    return ZapModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      originalUserId: map['originalUserId'],
      parentZapId: map['parentZapId'],
      quotedZapId: map['quotedZapId'],
      text: map['text'] ?? '',
      mediaUrls: urls,
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      rezapsCount: map['rezapsCount'] ?? 0,
      repliesCount: map['repliesCount'] ?? 0,
      isThread: map['isThread'] ?? false,
      isShort: map['isShort'] ?? false,
      threadParentId: map['threadParentId'],
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      isDeleted: map['isDeleted'] ?? false,
      songId: map['songId'], // 👈 NEW
      docSnapshot: snapshot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'originalUserId': originalUserId,
      'parentZapId': parentZapId,
      'quotedZapId': quotedZapId,
      'text': text,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'rezapsCount': rezapsCount,
      'repliesCount': repliesCount,
      'isThread': isThread,
      'threadParentId': threadParentId,
      'hashtags': hashtags,
      'mentions': mentions,
      'isShort': isShort,
      'isDeleted': isDeleted,
      'songId': songId,
    };
  }

  ZapModel copyWith({
    String? id,
    String? userId,
    String? parentZapId,
    String? quotedZapId,
    String? text,
    List<String>? mediaUrls,
    DateTime? createdAt,
    int? likesCount,
    int? rezapsCount,
    int? repliesCount,
    bool? isThread,
    bool? isShort,
    String? threadParentId,
    List<String>? hashtags,
    List<String>? mentions,
    bool? isDeleted,
    String? songId, // 👈 NEW
  }) {
    return ZapModel(
      id: id ?? this.id,
      docSnapshot: docSnapshot,
      userId: userId ?? this.userId,
      parentZapId: parentZapId ?? this.parentZapId,
      quotedZapId: quotedZapId ?? this.quotedZapId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      rezapsCount: rezapsCount ?? this.rezapsCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isThread: isThread ?? this.isThread,
      isShort: isShort ?? this.isShort,
      threadParentId: threadParentId ?? this.threadParentId,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      isDeleted: isDeleted ?? this.isDeleted,
      songId: songId ?? this.songId, // 👈 NEW
    );
  }
}
