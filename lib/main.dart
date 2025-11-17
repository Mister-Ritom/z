import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:z/firebase_options.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/services/ad_manager.dart';
import 'utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize ad manager
  await AdManager().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
