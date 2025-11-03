class AppConstants {
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String tweetsCollection = 'tweets';
  static const String notificationsCollection = 'notifications';
  static const String messagesCollection = 'messages';
  static const String followersCollection = 'followers';
  static const String followingCollection = 'following';
  static const String likesCollection = 'likes';
  static const String retweetsCollection = 'retweets';
  static const String bookmarksCollection = 'bookmarks';

  // Supabase Storage Buckets
  static const String profilePicturesBucket = 'profile-pictures';
  static const String coverPhotosBucket = 'cover-photos';
  static const String tweetMediaBucket = 'tweet-media';

  // User Limits
  static const int maxTweetLength = 280;
  static const int maxImagesPerTweet = 4;
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;

  // Pagination
  static const int tweetsPerPage = 20;
  static const int messagesPerPage = 30;
  static const int usersPerPage = 20;

  // Verification
  static const List<String> verifiedUserIds = [
    // Add user IDs that should have verified badges
    // Example: 'user123', 'user456'
  ];

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration cacheExpiration = Duration(hours: 1);
}
