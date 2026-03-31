import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF7F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7EAF3);
  static const borderStrong = Color(0xFFD7DDED);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const accent = Color(0xFF2F426F);
  static const success = Color(0xFF22C55E);

  static const darkBackground = Color(0xFF0D1117);
  static const darkSurface = Color(0xFF161B22);
  static const darkBorder = Color(0xFF2D333B);
  static const darkBorderStrong = Color(0xFF444C56);
  static const darkTextPrimary = Color(0xFFE6EDF3);
  static const darkTextSecondary = Color(0xFF8B949E);
  static const darkAccent = Color(0xFF4A6FBF);
}

class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0.4,
        shadowColor: Color(0x12000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: GoogleFonts.manropeTextTheme(
        const TextTheme(
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0.8,
          shadowColor: const Color(0x22000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: const Color(0xFFF8FAFC),
        selectedColor: AppColors.accent.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.darkAccent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.darkBorder),
        ),
      ),
      textTheme: GoogleFonts.manropeTextTheme(
        const TextTheme(
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextPrimary,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.darkTextSecondary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkAccent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          side: const BorderSide(color: AppColors.darkAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.darkBorder),
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.darkAccent.withValues(alpha: 0.25),
        labelStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
