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

  factory CommentModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return CommentModel(
      id: id ?? map['id'] ?? '',
      text: map['text'] ?? '',
      userId: map['user_id'] ?? '',
      postId: map['post_id'] ?? '',
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
      parentCommentId: map['parent_comment_id'],
      likesCount: map['likes_count'] ?? 0,
      isEdited: map['is_edited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'user_id': userId,
      'post_id': postId,
      'created_at': createdAt.toIso8601String(),
      'parent_comment_id': parentCommentId,
      'likes_count': likesCount,
      'is_edited': isEdited,
    };
  }
}
