class UserModel {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? bio;
  final String? profilePictureUrl;
  final String? coverPhotoUrl;
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;
  final int zapsCount;
  final bool isVerified;
  final bool isPrivate;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.bio,
    this.profilePictureUrl,
    this.coverPhotoUrl,
    required this.createdAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.zapsCount = 0,
    this.isVerified = false,
    this.isPrivate = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      bio: map['bio'],
      profilePictureUrl: map['profilePictureUrl'],
      coverPhotoUrl: map['coverPhotoUrl'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      zapsCount: map['zapsCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      isPrivate: map['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'profilePictureUrl': profilePictureUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'createdAt': createdAt,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'zapsCount': zapsCount,
      'isVerified': isVerified,
      'isPrivate': isPrivate,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? bio,
    String? profilePictureUrl,
    String? coverPhotoUrl,
    DateTime? createdAt,
    int? followersCount,
    int? followingCount,
    int? zapsCount,
    bool? isVerified,
    bool? isPrivate,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      zapsCount: zapsCount ?? this.zapsCount,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
