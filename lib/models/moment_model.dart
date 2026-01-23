import 'package:cloud_firestore/cloud_firestore.dart';

enum MomentCategory {
  life,
  habit,
  mood,
  presence,
  reflection;

  String get label {
    switch (this) {
      case MomentCategory.life:
        return 'Life';
      case MomentCategory.habit:
        return 'Habit';
      case MomentCategory.mood:
        return 'Mood';
      case MomentCategory.presence:
        return 'Presence';
      case MomentCategory.reflection:
        return 'Reflection';
    }
  }

  static MomentCategory parse(String value) {
    return MomentCategory.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MomentCategory.presence,
    );
  }
}

enum MomentVisibility {
  public,
  circle, // Friends/Followers only
  private;

  static MomentVisibility parse(String value) {
    return MomentVisibility.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MomentVisibility.circle,
    );
  }
}

class MomentModel {
  final String id;
  final String userId;
  final String text;
  final MomentCategory category;
  final MomentVisibility visibility;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isExpired;

  const MomentModel({
    required this.id,
    required this.userId,
    required this.text,
    this.category = MomentCategory.presence,
    this.visibility = MomentVisibility.circle,
    required this.createdAt,
    this.expiresAt,
    this.isExpired = false,
  });

  factory MomentModel.fromMap(Map<String, dynamic> map, String id) {
    return MomentModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      category: MomentCategory.parse(map['category'] ?? 'presence'),
      visibility: MomentVisibility.parse(map['visibility'] ?? 'circle'),
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      expiresAt:
          map['expiresAt'] is Timestamp
              ? (map['expiresAt'] as Timestamp).toDate()
              : null,
      isExpired: map['isExpired'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'category': category.name,
      'visibility': visibility.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isExpired': isExpired,
    };
  }

  MomentModel copyWith({
    String? id,
    String? userId,
    String? text,
    MomentCategory? category,
    MomentVisibility? visibility,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isExpired,
  }) {
    return MomentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpired: isExpired ?? this.isExpired,
    );
  }
}
