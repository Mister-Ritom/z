import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/light_theme.dart';
import '../theme/dark_theme.dart';

enum AppTheme { light, dark, system }

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme');
    if (themeString != null) {
      state = AppTheme.values.firstWhere(
        (e) => e.toString() == 'AppTheme.$themeString',
        orElse: () => AppTheme.system,
      );
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme.toString().split('.').last);
  }

  ThemeData getThemeData(Brightness systemBrightness) {
    switch (state) {
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
    switch (state) {
      case AppTheme.light:
        return false;
      case AppTheme.dark:
        return true;
      case AppTheme.system:
        return systemBrightness == Brightness.dark;
    }
  }
}
