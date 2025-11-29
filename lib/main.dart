import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:z/firebase_options.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/providers/fcm_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/services/ads/ad_manager.dart';
import 'package:z/services/analytics/firebase_analytics_service.dart';
import 'package:z/utils/logger.dart';
import 'utils/router.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Crashlytics collection in release mode
  if (kReleaseMode) {
    FirebaseAnalyticsService.setCrashlyticsCollectionEnabled(true);
  } else {
    // Disable in debug mode for faster development
    FirebaseAnalyticsService.setCrashlyticsCollectionEnabled(false);
  }

  // Initialize ad manager
  await AdManager().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  String? _previousUserId;
  ProviderSubscription<AsyncValue<User?>>? _authSubscription;
  StreamSubscription? _intentSub;

  void handleSharing(List<SharedMediaFile> value) {
    if (value.isEmpty) {
      AppLogger.warn('SharingService', 'No media shared');
      return;
    }
    final mediaPaths = value.map((e) => e.path).toList();
    AppLogger.info(
      'SharingService',
      'Sharing media',
      data: {'mediaPaths': mediaPaths},
    );
    final router = ref.read(routerProvider);
    //add a post frame callback to the router to navigate to the sharing screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/sharing', extra: mediaPaths);
    });
  }

  void initSharingIntent() {
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        handleSharing(value);
      },
      onError: (err) {
        AppLogger.error(
          'SharingService',
          'Error initializing sharing intent',
          error: err,
        );
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((value) {
          handleSharing(value);
        })
        .catchError((err) {
          AppLogger.error(
            'SharingService',
            'Error getting initial media',
            error: err,
          );
        });
  }

  @override
  void initState() {
    super.initState();
    // Initialize sharing intent
    initSharingIntent();
    // Initialize FCM service
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final fcmService = ref.read(fcmServiceProvider);
        await fcmService.initialize();
      } catch (e, st) {
        // Log error but don't crash the app
        AppLogger.error(
          'MyApp',
          'Error initializing FCM service in initState',
          error: e,
          stackTrace: st,
        );
      }
    });

    _authSubscription = ref.listenManual<AsyncValue<User?>>(
      currentUserProvider,
      (previous, next) {
        next.whenData((user) async {
          final fcmService = ref.read(fcmServiceProvider);
          if (user != null) {
            await fcmService.getTokenAndSave(user.uid);
            await FirebaseAnalyticsService.setUserId(user.uid);
            _previousUserId = user.uid;
          } else if (_previousUserId != null) {
            await fcmService.deleteToken(_previousUserId!);
            await FirebaseAnalyticsService.setUserId(null);
            _previousUserId = null;
          }
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.watch(settingsProvider.notifier);
    final theme = ref.watch(settingsProvider).theme;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Z',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.getThemeData(Brightness.light),
      darkTheme: themeNotifier.getThemeData(Brightness.dark),
      themeMode:
          theme == AppTheme.light
              ? ThemeMode.light
              : theme == AppTheme.dark
              ? ThemeMode.dark
              : ThemeMode.system,
      routerConfig: router,
    );
  }
}
