import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        secondary: Color(0xFF1DA1F2),
        error: Color(0xFFEF4444),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        outline: Color(0xFFE5E5E5),
        surfaceContainerHighest: Color(0xFFF7F9F9),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF9F9F9),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF000000),
        unselectedItemColor: Color(0xFF8B98A5),
        selectedIconTheme: IconThemeData(size: 28, color: Color(0xFF000000)),
        unselectedIconTheme: IconThemeData(size: 26, color: Color(0xFF8B98A5)),
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),

      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF000000)),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF000000),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF000000),
        ),
        displayMedium: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF000000),
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 15,
          color: const Color(0xFF0F1419),
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 15,
          color: const Color(0xFF536471),
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 13,
          color: const Color(0xFF536471),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9F9),
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
          backgroundColor: const Color(0xFF000000),
          foregroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEFF3F4),
        thickness: 0.5,
      ),
    );
  }

  static const Color textPrimary = Color(0xFF0F1419);
  static const Color textSecondary = Color(0xFF536471);
  static const Color borderColor = Color(0xFFEFF3F4);
  static const Color hoverColor = Color(0xFFF7F9F9);
  static const Color retweetColor = Color(0xFF00BA7C);
  static const Color likeColor = Color(0xFFF91880);
}
