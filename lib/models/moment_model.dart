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
  circle,
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

  factory MomentModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return MomentModel(
      id: id ?? map['id'] ?? '',
      userId: map['user_id'] ?? '',
      text: map['text'] ?? '',
      category: MomentCategory.parse(map['category'] ?? 'presence'),
      visibility: MomentVisibility.parse(map['visibility'] ?? 'circle'),
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'].toString())
              : DateTime.now(),
      expiresAt:
          map['expires_at'] != null
              ? DateTime.parse(map['expires_at'].toString())
              : null,
      isExpired: map['is_expired'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'text': text,
      'category': category.name,
      'visibility': visibility.name,
      'is_expired': isExpired,
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
