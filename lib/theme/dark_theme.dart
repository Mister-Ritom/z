import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DarkTheme {
  static ThemeData get theme {
    return ThemeData(
      extensions: [
        CoolThemeExtension(
          primaryColor: Color(0xFFFFFFFF),
          secondaryColor: Color(0xFF1DA1F2),
          themeMode: ThemeMode.dark,
        ),
      ],
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        secondary: Color(0xFF007AFF), // Premium Blue
        error: Color(0xFFFF453A), // System Red
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        outline: Color(0xFF262626),
        surfaceContainerHighest: Color(0xFF0D0D0D),
        surfaceContainerLow: Color(0xFF080808),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFFFFFFF),
        unselectedItemColor: Color(0xFF636366),
        selectedIconTheme: IconThemeData(size: 28, color: Color(0xFFFFFFFF)),
        unselectedIconTheme: IconThemeData(size: 26, color: Color(0xFF636366)),
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFFF2F2F7),
        ),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: Colors.white),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF8E8E93),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D0D0D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1C1C1E), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF000000),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0D0D0D),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1C1C1E), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1C1C1E),
        thickness: 1,
      ),
    );
  }

  static const Color textPrimary = Color(0xFFF7F9F9);
  static const Color textSecondary = Color(0xFF8B98A5);
  static const Color borderColor = Color(0xFF2F3336);
  static const Color hoverColor = Color(0xFF16181C);
  static const Color rezapColor = Color(0xFF00BA7C);
  static const Color likeColor = Color(0xFFF91880);
}
