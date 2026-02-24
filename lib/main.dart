import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/services/ads/ad_manager.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';
import 'utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Supabase
  await Database.initialize();

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

    _authSubscription = ref.listenManual<AsyncValue<User?>>(
      currentUserProvider,
      (previous, next) {
        next.whenData((user) async {
          if (user != null) {
            _previousUserId = user.id;
          } else if (_previousUserId != null) {
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
