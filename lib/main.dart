import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'package:share_handler/share_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z/utils/logger.dart';
import 'utils/router.dart';

Future<void> configureFirebaseEmulators() async {
  if (kReleaseMode) return;

  final host =
      defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';

  try {
    FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: DefaultFirebaseOptions.currentPlatform.storageBucket,
    ).useStorageEmulator(host, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);

    AppLogger.info("Main", 'Firebase emulators connected on $host');
  } catch (e, st) {
    AppLogger.error(
      "Main",
      'Failed to connect Firebase emulators',
      error: e,
      stackTrace: st,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pre-initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  //await configureFirebaseEmulators();

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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  String? _previousUserId;
  ProviderSubscription<AsyncValue<User?>>? _authSubscription;
  StreamSubscription<SharedMedia>? _sharingSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingListener();
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

  void _initSharingListener() async {
    final handler = ShareHandlerPlatform.instance;

    // Listen to shared media stream
    _sharingSubscription = handler.sharedMediaStream.listen((
      SharedMedia media,
    ) {
      _handleSharedMedia(media);
    });

    // Check for initial shared media (on app startup)
    final initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      _handleSharedMedia(initialMedia);
    }
  }

  void _handleSharedMedia(SharedMedia media) {
    final mediaPaths =
        media.attachments?.map((a) => a?.path).whereType<String>().toList() ??
        [];

    if (mediaPaths.isNotEmpty || media.content != null) {
      AppLogger.info(
        'Main',
        'Global sharing detected',
        data: {
          'mediaCount': mediaPaths.length,
          'hasText': media.content != null,
        },
      );

      // Navigate to sharing screen using GoRouter
      // We pass the list of paths and optionally the text content
      final router = ref.read(routerProvider);
      router.push(
        '/sharing',
        extra: {'paths': mediaPaths, 'text': media.content},
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _sharingSubscription?.cancel();
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
