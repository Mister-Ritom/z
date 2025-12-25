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
  });

  final bool enablePushNotifications;
  final bool autoplayVideos;
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
      theme: theme ?? this.theme,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier({SharedPreferences? preferences})
    : _prefs = preferences,
      super(
        const AppSettings(
          enablePushNotifications: true,
          autoplayVideos: true,
          theme: AppTheme.system,
        ),
      ) {
    _initialization = _loadSettings();
  }

  SharedPreferences? _prefs;
  late final Future<void> _initialization;

  Future<void> get initialized => _initialization;

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _loadSettings() async {
    final prefs = await _ensurePrefs();
    final push = prefs.getBool('settings.push_enabled') ?? true;
    final autoplay = prefs.getBool('settings.autoplay_videos') ?? true;
    final themeString = prefs.getString('settings.theme');
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
      theme: theme,
    );
  }

  Future<void> setPushNotifications(bool value) async {
    final prefs = await _ensurePrefs();
    state = state.copyWith(enablePushNotifications: value);
    await prefs.setBool('settings.push_enabled', value);
  }

  Future<void> setAutoplayVideos(bool value) async {
    final prefs = await _ensurePrefs();
    state = state.copyWith(autoplayVideos: value);
    await prefs.setBool('settings.autoplay_videos', value);
  }

  Future<void> setTheme(AppTheme theme) async {
    final prefs = await _ensurePrefs();
    state = state.copyWith(theme: theme);
    await prefs.setString('settings.theme', theme.toString().split('.').last);
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
