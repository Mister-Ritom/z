import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/firebase_options.dart';
import 'package:z/providers/settings_provider.dart';
import 'utils/supabase_config.dart';
import 'utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
    debugPrint('Please configure Supabase in supabase_config.dart');
  }

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
