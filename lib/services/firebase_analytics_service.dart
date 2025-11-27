import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class FirebaseAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Log a screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  /// Log a custom event
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  /// Log user login
  static Future<void> logLogin({String? loginMethod}) async {
    await _analytics.logLogin(loginMethod: loginMethod);
  }

  /// Log user signup
  static Future<void> logSignUp({String? signUpMethod}) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod ?? 'unknown');
  }

  /// Log when user creates a post/zap
  static Future<void> logPostCreated({
    String? contentType,
    bool isShort = false,
  }) async {
    await logEvent(
      name: 'post_created',
      parameters: {'content_type': contentType ?? 'text', 'is_short': isShort},
    );
  }

  /// Log when user likes a post
  static Future<void> logPostLiked({bool isShort = false}) async {
    await logEvent(name: 'post_liked', parameters: {'is_short': isShort});
  }

  /// Log when user comments on a post
  static Future<void> logPostCommented({bool isShort = false}) async {
    await logEvent(name: 'post_commented', parameters: {'is_short': isShort});
  }

  /// Log when user shares a post
  static Future<void> logPostShared({bool isShort = false}) async {
    await logEvent(name: 'post_shared', parameters: {'is_short': isShort});
  }

  /// Log when user views a story
  static Future<void> logStoryViewed() async {
    await logEvent(name: 'story_viewed');
  }

  /// Log when user creates a story
  static Future<void> logStoryCreated() async {
    await logEvent(name: 'story_created');
  }

  /// Log when user sends a message
  static Future<void> logMessageSent() async {
    await logEvent(name: 'message_sent');
  }

  /// Log when user follows another user
  static Future<void> logUserFollowed() async {
    await logEvent(name: 'user_followed');
  }

  /// Log when user unfollows another user
  static Future<void> logUserUnfollowed() async {
    await logEvent(name: 'user_unfollowed');
  }

  /// Set user ID for analytics
  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
    if (userId != null) {
      await _crashlytics.setUserIdentifier(userId);
    }
  }

  /// Set user properties
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  /// Report a non-fatal error to Crashlytics
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Log a message to Crashlytics
  static Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  /// Set custom key-value pairs for Crashlytics
  static Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  /// Enable/disable Crashlytics collection
  static void setCrashlyticsCollectionEnabled(bool enabled) {
    _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }
}
