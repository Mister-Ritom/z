import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightTheme {
  static ThemeData get theme {
    return ThemeData(
      extensions: [
        CoolThemeExtension(
          primaryColor: Color(0xFF000000),
          secondaryColor: Color(0xFF1DA1F2),
          themeMode: ThemeMode.light,
        ),
      ],
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        secondary: Color(0xFF007AFF), // Premium Blue
        error: Color(0xFFFF3B30), // System Red
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        outline: Color(0xFFE5E5EA),
        surfaceContainerHighest: Color(0xFFF2F2F7),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF000000),
        unselectedItemColor: Color(0xFF8E8E93),
        selectedIconTheme: IconThemeData(size: 28, color: Color(0xFF000000)),
        unselectedIconTheme: IconThemeData(size: 26, color: Color(0xFF8E8E93)),
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),

      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF000000)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF000000),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF000000),
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF000000),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF000000),
        ),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: Colors.black),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF3A3A3C),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          foregroundColor: const Color(0xFFFFFFFF),
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
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5EA),
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: const Color(0xFF000000)),
    );
  }

  static const Color textPrimary = Color(0xFF0F1419);
  static const Color textSecondary = Color(0xFF536471);
  static const Color borderColor = Color(0xFFEFF3F4);
  static const Color hoverColor = Color(0xFFF7F9F9);
  static const Color rezapColor = Color(0xFF00BA7C);
  static const Color likeColor = Color(0xFFF91880);
}
