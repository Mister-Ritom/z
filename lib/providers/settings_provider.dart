import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/light_theme.dart';
import '../theme/dark_theme.dart';

enum AppTheme { light, dark, system }

@immutable
class AppSettings {
  const AppSettings({
    required this.enablePushNotifications,
    required this.autoplayVideos,
    required this.theme,
    required this.hasSeenOnboarding,
  });

  final bool enablePushNotifications;
  final bool autoplayVideos;
  final AppTheme theme;
  final bool hasSeenOnboarding;

  AppSettings copyWith({
    bool? enablePushNotifications,
    bool? autoplayVideos,
    bool? glassMorphismEnabled,
    AppTheme? theme,
    bool? hasSeenOnboarding,
  }) {
    return AppSettings(
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      theme: theme ?? this.theme,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  );
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs)
    : super(
        AppSettings(
          enablePushNotifications:
              _prefs.getBool('settings.push_enabled') ?? true,
          autoplayVideos: _prefs.getBool('settings.autoplay_videos') ?? true,
          theme: _loadTheme(_prefs),
          hasSeenOnboarding:
              _prefs.getBool('settings.has_seen_onboarding') ?? false,
        ),
      );

  final SharedPreferences _prefs;

  static AppTheme _loadTheme(SharedPreferences prefs) {
    final themeString = prefs.getString('settings.theme');
    return themeString != null
        ? AppTheme.values.firstWhere(
          (e) => e.toString() == 'AppTheme.$themeString',
          orElse: () => AppTheme.system,
        )
        : AppTheme.system;
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(enablePushNotifications: value);
    await _prefs.setBool('settings.push_enabled', value);
  }

  Future<void> setAutoplayVideos(bool value) async {
    state = state.copyWith(autoplayVideos: value);
    await _prefs.setBool('settings.autoplay_videos', value);
  }

  Future<void> setTheme(AppTheme theme) async {
    state = state.copyWith(theme: theme);
    await _prefs.setString('settings.theme', theme.toString().split('.').last);
  }

  Future<void> markOnboardingSeen() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await _prefs.setBool('settings.has_seen_onboarding', true);
  }

  ThemeData getThemeData(Brightness systemBrightness) {
    switch (state.theme) {
      case AppTheme.light:
        return LightTheme.theme;
      case AppTheme.dark:
        return DarkTheme.theme;
      case AppTheme.system:
        return systemBrightness == Brightness.dark
            ? DarkTheme.theme
            : LightTheme.theme;
    }
  }

  bool isDarkMode(Brightness systemBrightness) {
    switch (state.theme) {
      case AppTheme.light:
        return false;
      case AppTheme.dark:
        return true;
      case AppTheme.system:
        return systemBrightness == Brightness.dark;
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
