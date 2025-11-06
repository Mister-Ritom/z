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
    required this.glassMorphismEnabled,
    required this.theme,
  });

  final bool enablePushNotifications;
  final bool autoplayVideos;
  final bool glassMorphismEnabled;
  final AppTheme theme;

  AppSettings copyWith({
    bool? enablePushNotifications,
    bool? autoplayVideos,
    bool? glassMorphismEnabled,
    AppTheme? theme,
  }) {
    return AppSettings(
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      glassMorphismEnabled: glassMorphismEnabled ?? this.glassMorphismEnabled,
      theme: theme ?? this.theme,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
    : super(
        const AppSettings(
          enablePushNotifications: true,
          autoplayVideos: true,
          glassMorphismEnabled: true,
          theme: AppTheme.system,
        ),
      ) {
    _loadSettings();
  }

  late SharedPreferences _prefs;

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final push = _prefs.getBool('settings.push_enabled') ?? true;
    final autoplay = _prefs.getBool('settings.autoplay_videos') ?? true;
    final glass = _prefs.getBool('settings.glass_enabled') ?? false;
    final themeString = _prefs.getString('settings.theme');
    final theme =
        themeString != null
            ? AppTheme.values.firstWhere(
              (e) => e.toString() == 'AppTheme.$themeString',
              orElse: () => AppTheme.system,
            )
            : AppTheme.system;

    state = AppSettings(
      enablePushNotifications: push,
      autoplayVideos: autoplay,
      glassMorphismEnabled: glass,
      theme: theme,
    );
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(enablePushNotifications: value);
    await _prefs.setBool('settings.push_enabled', value);
  }

  Future<void> setAutoplayVideos(bool value) async {
    state = state.copyWith(autoplayVideos: value);
    await _prefs.setBool('settings.autoplay_videos', value);
  }

  Future<void> setGlassMorphismEnabled(bool value) async {
    state = state.copyWith(glassMorphismEnabled: value);
    await _prefs.setBool('settings.glass_enabled', value);
  }

  Future<void> setTheme(AppTheme theme) async {
    state = state.copyWith(theme: theme);
    await _prefs.setString('settings.theme', theme.toString().split('.').last);
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
  return SettingsNotifier();
});
