import 'package:cloud_firestore/cloud_firestore.dart';

class ZapModel {
  final String id;
  final String userId;
  final String? originalUserId;
  final String? parentZapId; // For replies
  final String? quotedZapId; // For quote zaps
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
  final DocumentSnapshot? docSnapshot;

  ZapModel({
    required this.id,
    required this.userId,
    this.originalUserId,
    this.isShort = false,
    this.docSnapshot,
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
  });

  factory ZapModel.fromMap(
    Map<String, dynamic> map, {
    DocumentSnapshot? snapshot,
  }) {
    return ZapModel(
      id: map['id'] ?? '',
      isShort: map['isShort'] ?? false,
      originalUserId: map['originalUserId'],
      docSnapshot: snapshot,
      userId: map['userId'] ?? '',
      parentZapId: map['parentZapId'],
      quotedZapId: map['quotedZapId'],
      text: map['text'] ?? '',
      mediaUrls: List<String>.from(
        (map['mediaUrls'] != null && (map['mediaUrls'] as List).isNotEmpty)
            ? map['mediaUrls']
            : (map['mediaUrl'] != null ? [map['mediaUrl']] : []),
      ),

      createdAt: () {
        final value = map['createdAt'];

        if (value == null) return DateTime.now();

        // Firestore Timestamp
        if (value is Timestamp) return value.toDate();

        // int milliseconds (or seconds)
        if (value is int) {
          // If it's too small (e.g., 10-digit seconds), convert to ms
          if (value < 1000000000000) {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
          return DateTime.fromMillisecondsSinceEpoch(value);
        }

        // Fallback
        return DateTime.now();
      }(),

      likesCount: map['likesCount'] ?? 0,
      rezapsCount: map['rezapsCount'] ?? 0,
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
      'isShort': isShort,
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
      'isDeleted': isDeleted,
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
    );
  }
}
