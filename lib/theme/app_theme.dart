import 'package:flutter/material.dart';

class AppTheme {
  // Dark mode colors (curated deep slate/navy palette)
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkCard = Color(0xFF131B2E);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkAccent = Color(0xFF6366F1); // Modern Indigo
  static const Color darkSecondary = Color(0xFF10B981); // Emerald
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light mode colors (soft off-white/grey palette)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightAccent = Color(0xFF4F46E5); // Deep Indigo
  static const Color lightSecondary = Color(0xFF0D9488); // Teal
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Gradients for badges, progress rings, and headers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)], // Emerald to Teal
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)], // Rose to Dark Red
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)], // Sky Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glassmorphic Decoration Factory
  static BoxDecoration glassDecoration({
    required bool isDark,
    double radius = 16.0,
    double opacity = 0.7,
  }) {
    return BoxDecoration(
      color: isDark 
        ? darkCard.withOpacity(opacity) 
        : lightCard.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark 
          ? darkBorder.withOpacity(0.4) 
          : lightBorder.withOpacity(0.5),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark 
            ? Colors.black.withOpacity(0.25) 
            : Colors.grey.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static ThemeData getThemeData(bool isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      cardColor: isDark ? darkCard : lightCard,
      dividerColor: isDark ? darkBorder : lightBorder,
      colorScheme: ColorScheme.fromSeed(
        seedColor: isDark ? darkAccent : lightAccent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: isDark ? darkAccent : lightAccent,
        secondary: isDark ? darkSecondary : lightSecondary,
        surface: isDark ? darkCard : lightCard,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: isDark ? darkTextPrimary : lightTextPrimary,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? darkTextPrimary : lightTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: isDark ? darkTextSecondary : lightTextSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? darkTextSecondary : lightTextSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkBg.withOpacity(0.5) : Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? darkAccent : lightAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: isDark ? darkTextSecondary.withOpacity(0.7) : lightTextSecondary.withOpacity(0.7)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? darkAccent : lightAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
      ),
    );
  }
}
