import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String text;
  final String userId;
  final String postId;
  final DateTime createdAt;
  final String? parentCommentId;
  final int likesCount;
  final bool isEdited;

  CommentModel({
    required this.id,
    required this.text,
    required this.userId,
    required this.postId,
    required this.createdAt,
    this.parentCommentId,
    this.likesCount = 0,
    this.isEdited = false,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    return CommentModel(
      id: id,
      text: map['text'] ?? '',
      userId: map['userId'] ?? '',
      postId: map['postId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      parentCommentId: map['parentCommentId'],
      likesCount: map['likesCount'] ?? 0,
      isEdited: map['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'userId': userId,
      'postId': postId,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'isEdited': isEdited,
    };
  }
}
