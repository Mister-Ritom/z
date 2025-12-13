import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:z/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:z/utils/constants.dart';
import 'package:z/firebase_options.dart';

/// Top-level function for handling background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  AppLogger.info(
    'FCMService',
    'Handling background message',
    data: {'messageId': message.messageId},
  );
  // Background messages are handled here
  // FCM will automatically show notifications when app is in background
  // This handler is for processing data if needed
}

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _isInitialized = false;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if FCM should be enabled for this platform
      final shouldEnable =
          defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              AppConstants.iosNotificationAvailable) ||
          (defaultTargetPlatform == TargetPlatform.macOS &&
              AppConstants.iosNotificationAvailable);

      if (!shouldEnable) {
        AppLogger.warn(
          'FCMService',
          'FCM disabled for this platform (iOS/macOS notifications not available)',
          data: {'platform': defaultTargetPlatform.name},
        );
        return;
      }

      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('FCMService', 'User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        AppLogger.info(
          'FCMService',
          'User granted provisional notification permission',
        );
      } else {
        AppLogger.warn(
          'FCMService',
          'User declined or has not accepted notification permission',
        );
        return;
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages (only show when app is in background)
      _messageSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        AppLogger.info(
          'FCMService',
          'Received foreground message',
          data: {'messageId': message.messageId},
        );
        // Don't show notifications when app is in foreground
        // They will be handled by the app's notification system
      });

      // Handle notification taps when app is opened from terminated state
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          AppLogger.info(
            'FCMService',
            'App opened from terminated state via notification',
            data: {'messageId': message.messageId},
          );
          _handleNotificationTap(message);
        }
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info(
          'FCMService',
          'App opened from background via notification',
          data: {'messageId': message.messageId},
        );
        _handleNotificationTap(message);
      });

      _isInitialized = true;
      AppLogger.info('FCMService', 'FCM Service initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error(
        'FCMService',
        'Error initializing FCM Service',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get FCM token and save it to Firestore
  Future<String?> getTokenAndSave(String userId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Only get token on Android or if iOS notifications are enabled
      if (defaultTargetPlatform != TargetPlatform.android &&
          !(defaultTargetPlatform == TargetPlatform.iOS &&
              AppConstants.iosNotificationAvailable) &&
          !(defaultTargetPlatform == TargetPlatform.macOS &&
              AppConstants.iosNotificationAvailable)) {
        return null;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(userId, token);
        AppLogger.info(
          'FCMService',
          'FCM token saved for user',
          data: {'userId': userId},
        );
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(userId, newToken);
        AppLogger.info(
          'FCMService',
          'FCM token refreshed for user',
          data: {'userId': userId},
        );
      });

      return token;
    } catch (e, stackTrace) {
      AppLogger.error(
        'FCMService',
        'Error getting FCM token',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      final tokenRef = _firestore
          .collection(AppConstants.fcmTokensCollection)
          .doc(userId);

      // Get existing tokens
      final doc = await tokenRef.get();
      List<String> tokens = [];

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['tokens'] != null) {
          tokens = List<String>.from(data['tokens'] as List);
        }
      }

      // Add new token if not already present
      if (!tokens.contains(token)) {
        tokens.add(token);
      }

      // Update Firestore
      await tokenRef.set({
        'tokens': tokens,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogger.info(
        'FCMService',
        'FCM token saved to Firestore',
        data: {'userId': userId},
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'FCMService',
        'Error saving FCM token to Firestore',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
    }
  }

  /// Delete FCM token from Firestore
  Future<void> deleteToken(String userId) async {
    // Check if FCM should be enabled for this platform
    final shouldEnable =
        defaultTargetPlatform == TargetPlatform.android ||
        (defaultTargetPlatform == TargetPlatform.iOS &&
            AppConstants.iosNotificationAvailable) ||
        (defaultTargetPlatform == TargetPlatform.macOS &&
            AppConstants.iosNotificationAvailable);
    if (!shouldEnable) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final tokenRef = _firestore
          .collection(AppConstants.fcmTokensCollection)
          .doc(userId);

      final doc = await tokenRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['tokens'] != null) {
          List<String> tokens = List<String>.from(data['tokens'] as List);
          tokens.remove(token);

          if (tokens.isEmpty) {
            await tokenRef.delete();
          } else {
            await tokenRef.update({
              'tokens': tokens,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      AppLogger.info(
        'FCMService',
        'FCM token deleted from Firestore',
        data: {'userId': userId},
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'FCMService',
        'Error deleting FCM token',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
    }
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final notificationType = data['type'] as String?;

    // If it's a chat message, navigate to chat screen
    if (notificationType == 'message') {
      final senderId = data['senderId'] as String?;
      if (senderId != null) {
        // Use a global navigator key or event bus to navigate
        // We'll set this up in main.dart
        FCMNavigationHandler.navigateToChat?.call(senderId);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _isInitialized = false;
  }
}

/// Global navigation handler for FCM notifications
class FCMNavigationHandler {
  static Function(String senderId)? navigateToChat;
}
