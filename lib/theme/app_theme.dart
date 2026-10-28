import 'package:flutter/material.dart';

class AppTheme {
  // Exact Colors Extracted from GHEEDOSA Menu Website
  static const Color primary = Color(0xFFF57C00);       // Brand Primary Orange
  static const Color primaryDark = Color(0xFFEF6C00);   // Dark Orange
  static const Color secondary = Color(0xFF043A63);     // Accent Navy Blue
  static const Color primarySoft = Color(0xFFFFF3E0);   // Soft Light Orange Highlight

  static const Color surface = Color(0xFFFFFFFF);       // Card Background
  static const Color background = Color(0xFFF5F5F9);    // Page Background

  static const Color textDark = Color(0xFF22303E);      // Heading Text
  static const Color textMuted = Color(0xFF757575);     // Muted Text

  static const Color chipSelected = Color(0xFFF57C00);  // Chip Selected
  static const Color chipUnselected = Color(0xFFEEEEEE);// Chip Unselected

  static const Color openGreen = Color(0xFF2ECC71);     // Open Tag Green
  static const Color closedRed = Color(0xFFE74C3C);     // Closed Tag Red
  static const Color ratingGold = Color(0xFFF1C40F);    // Star Rating Gold

  static const double cardCornerRadius = 16.0;
  static const double controlCornerRadius = 12.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlCornerRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlCornerRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipUnselected,
        disabledColor: Colors.grey.shade200,
        selectedColor: chipSelected,
        secondarySelectedColor: primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
    );
  }
}
