import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:z/firebase_options.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/providers/fcm_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/services/firebase_analytics_service.dart';
import 'package:z/widgets/sharing_listener.dart';
import 'utils/router.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize FCM service
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final fcmService = ref.read(fcmServiceProvider);
        await fcmService.initialize();
      } catch (e) {
        // Handle error silently
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.watch(settingsProvider.notifier);
    final theme = ref.watch(settingsProvider).theme;
    final router = ref.watch(routerProvider);

    // Handle FCM token when auth state changes
    ref.listen(currentUserProvider, (previous, next) {
      next.whenData((user) async {
        final fcmService = ref.read(fcmServiceProvider);
        if (user != null) {
          // User logged in, save FCM token
          await fcmService.getTokenAndSave(user.uid);
          // Set user ID for analytics
          await FirebaseAnalyticsService.setUserId(user.uid);
          _previousUserId = user.uid;
        } else if (_previousUserId != null) {
          // User logged out, delete FCM token
          await fcmService.deleteToken(_previousUserId!);
          // Clear user ID from analytics
          await FirebaseAnalyticsService.setUserId(null);
          _previousUserId = null;
        }
      });
    });

    return SharingListener(
      child: MaterialApp.router(
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
      ),
    );
  }
}
