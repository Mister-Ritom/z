enum AccountType {
  public,
  private,
  verified,
  business;

  @override
  String toString() {
    switch (this) {
      case AccountType.public:
        return 'public';
      case AccountType.private:
        return 'private';
      case AccountType.verified:
        return 'verified';
      case AccountType.business:
        return 'business';
    }
  }

  static AccountType fromString(String value) {
    switch (value) {
      case 'public':
        return AccountType.public;
      case 'private':
        return AccountType.private;
      case 'verified':
        return AccountType.verified;
      case 'business':
        return AccountType.business;
      default:
        throw ArgumentError('Invalid account type: $value');
    }
  }
}

class UserModel {
  final String id;

  final String username;
  final String displayName;
  final String? bio;
  final String? profilePictureUrl;
  final String? coverPhotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int followersCount;
  final int followingCount;
  final int zapsCount;
  final AccountType accountType;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.profilePictureUrl,
    this.coverPhotoUrl,
    required this.updatedAt,
    required this.createdAt,
    this.isVerified = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.zapsCount = 0,
    this.accountType = AccountType.public,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      displayName: map['display_name'] ?? '',
      bio: map['bio'],
      profilePictureUrl: map['profile_picture_url'],
      coverPhotoUrl: map['cover_photo_url'],
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at']).toUtc()
              : DateTime.now().toUtc(),
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at']).toUtc()
              : DateTime.now().toUtc(),
      followersCount: map['followers_count'] ?? 0,
      followingCount: map['following_count'] ?? 0,
      zapsCount: map['zaps_count'] ?? 0,
      accountType: AccountType.fromString(map['account_type'] ?? 'public'),
      isVerified:
          (AccountType.fromString(map['account_type'] ?? 'public')) ==
              AccountType.verified ||
          (AccountType.fromString(map['account_type'] ?? 'public')) ==
              AccountType.business,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'profile_picture_url': profilePictureUrl,
      'cover_photo_url': coverPhotoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'followers_count': followersCount,
      'following_count': followingCount,
      'zaps_count': zapsCount,
      'account_type': accountType.toString(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? profilePictureUrl,
    String? coverPhotoUrl,
    DateTime? createdAt,
    int? followersCount,
    int? followingCount,
    int? zapsCount,
    required DateTime updatedAt,
    AccountType? accountType,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      zapsCount: zapsCount ?? this.zapsCount,
      accountType: accountType ?? this.accountType,
    );
  }

  DateTime get createdAtLocal => createdAt.toLocal();
  DateTime get updatedAtLocal => updatedAt.toLocal();
}
