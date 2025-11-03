import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DarkTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        secondary: Color(0xFF1DA1F2),
        error: Color(0xFFEF4444),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        outline: Color(0xFF2F3336),
        surfaceContainerHighest: Color(0xFF16181C),
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
        displayMedium: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 15,
          color: const Color(0xFFF7F9F9),
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 15,
          color: const Color(0xFF8B98A5),
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 13,
          color: const Color(0xFF8B98A5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF16181C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF1DA1F2), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF16181C),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2F3336),
        thickness: 0.5,
      ),
    );
  }

  static const Color textPrimary = Color(0xFFF7F9F9);
  static const Color textSecondary = Color(0xFF8B98A5);
  static const Color borderColor = Color(0xFF2F3336);
  static const Color hoverColor = Color(0xFF16181C);
  static const Color retweetColor = Color(0xFF00BA7C);
  static const Color likeColor = Color(0xFFF91880);
}
