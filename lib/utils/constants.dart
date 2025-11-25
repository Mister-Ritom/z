import 'package:flutter/foundation.dart';

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

  //Ads
  static String postAdUnitIos = "ca-app-pub-2032620092700178/6520501886";
  static String postAdUnitAndroid = "ca-app-pub-2032620092700178/5833557432";

  static String interAdUnitIos = "ca-app-pub-2032620092700178/9196450896";
  static String interAdUnitAndroid = "ca-app-pub-2032620092700178/7722876685";

  // Ad Frequency Constants - Balanced & User-Friendly
  static const int minContentGap =
      3; // Show ads only after enough content spacing
  static const int zapAdMin = 6; // Minimum zaps before showing an ad
  static const int zapAdMax = 12; // Maximum zaps before forcing an ad

  static const double storyAdChance = 0.15; // 15% chance per story
  static const double shortsAdChance = 0.12; // 12% chance per short
  static const double zapPageAdChance = 0.10; // 10% chance per zap page

  // Only sometimes show interstitials
  static const double interstitialAdChance = 0.07; // 7% chance

  // Use test IDs in debug, real post/inter IDs in release
  static String nativeAdUnitIdIos =
      kReleaseMode ? postAdUnitIos : "ca-app-pub-3940256099942544/3986624511";

  static String nativeAdUnitIdAndroid =
      kReleaseMode
          ? postAdUnitAndroid
          : "ca-app-pub-3940256099942544/2247696110";

  static String interstitialAdUnitIdIos =
      kReleaseMode ? interAdUnitIos : "ca-app-pub-3940256099942544/4411468910";

  static String interstitialAdUnitIdAndroid =
      kReleaseMode
          ? interAdUnitAndroid
          : "ca-app-pub-3940256099942544/1033173712";

  // Ad Preloading
  static const int maxPreloadedAds = 5; // Maximum number of preloaded ads
  static const Duration adPreloadTimeout = Duration(
    seconds: 10,
  ); // Timeout for ad loading

  // FCM Tokens Collection
  static const String fcmTokensCollection = 'fcm_tokens';

  // iOS Notification Support
  static const bool iosNotificationAvailable = false;
}
