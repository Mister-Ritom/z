import 'dart:async';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../firebase_options.dart';

/// Top-level function for handling background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  log('Handling background message: ${message.messageId}');
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
        log(
          'FCM disabled for this platform (iOS/macOS notifications not available)',
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
        log('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        log('User granted provisional notification permission');
      } else {
        log('User declined or has not accepted notification permission');
        return;
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages (only show when app is in background)
      _messageSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        log('Received foreground message: ${message.messageId}');
        // Don't show notifications when app is in foreground
        // They will be handled by the app's notification system
      });

      // Handle notification taps when app is opened from terminated state
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          log('App opened from terminated state via notification');
          _handleNotificationTap(message);
        }
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log('App opened from background via notification');
        _handleNotificationTap(message);
      });

      _isInitialized = true;
      log('FCM Service initialized successfully');
    } catch (e, stackTrace) {
      log('Error initializing FCM Service: $e', stackTrace: stackTrace);
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
        log('FCM token saved for user: $userId');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(userId, newToken);
        log('FCM token refreshed for user: $userId');
      });

      return token;
    } catch (e, stackTrace) {
      log('Error getting FCM token: $e', stackTrace: stackTrace);
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
    } catch (e, stackTrace) {
      log('Error saving FCM token to Firestore: $e', stackTrace: stackTrace);
    }
  }

  /// Delete FCM token from Firestore
  Future<void> deleteToken(String userId) async {
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
    } catch (e, stackTrace) {
      log('Error deleting FCM token: $e', stackTrace: stackTrace);
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
