class AppConstants {
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String zapsCollection = 'zaps';
  static const String shortsCollection = 'shorts';
  static const String notificationsCollection = 'notifications';
  static const String messagesCollection = 'messages';
  static const String followersCollection = 'followers';
  static const String followingCollection = 'following';
  static const String likesCollection = 'likes';
  static const String bookmarksCollection = 'bookmarks';
  static const String storiesCollection = 'stories';

  // Supabase Storage Buckets
  static const String profilePicturesBucket = 'profile-pictures';
  static const String coverPhotosBucket = 'cover-photos';
  static const String zapMediaBucket = 'zap-media';
  static const String storyMediaBucket = 'stories';
  static const String shortsVideoBucket = 'shorts';
  static const String documentsBucket = 'documents';

  // User Limits
  static const int maxZapLength = 280;
  static const int maxImagesPerZap = 10;
  static const int maxVideosPerZap = 4;
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;

  // Pagination
  static const int zapsPerPage = 20;
  static const int messagesPerPage = 30;
  static const int usersPerPage = 20;

  //Icons
  static const String darkModeIcon = "assets/icons/icon_white.png";
  static const String lightModeIcon = "assets/icons/icon_black.png";

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration cacheExpiration = Duration(hours: 1);

  //Web
  static const String appUrl = "https://zananta.vercel.app";

  //stories
  static const int storyExpiryHours = 24;
}
