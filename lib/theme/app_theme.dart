// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 🛠️ AppTheme: مصنع الثيمات الموحد للويب والموبايل
class AppTheme {
  AppTheme._();

  /// الثيم الفاتح (Light Theme - للركاب والموبايل)
  static ThemeData light({Color? seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.error,
    );
    return _buildTheme(colorScheme, isDark: false);
  }

  /// الثيم المظلم (Dark Theme - للويب ولوحات التحكم)
  static ThemeData dark({Color? seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppColors.logoBlue,
      brightness: Brightness.dark,
      surface: AppColors.webCardBackground,
      error: AppColors.error,
    );
    return _buildTheme(colorScheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, {required bool isDark}) {
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.gray400 : AppColors.textSecondary;
    final scaffoldBg = isDark ? AppColors.webBackground : AppColors.background;
    final cardBg = isDark ? AppColors.webCardBackground : AppColors.card;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppFonts.arabic,
      scaffoldBackgroundColor: scaffoldBg,

      // --- النصوص ---
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: primaryTextColor, fontFamily: AppFonts.arabic),
        bodyMedium: TextStyle(color: primaryTextColor, fontFamily: AppFonts.arabic),
        bodySmall: TextStyle(color: secondaryTextColor, fontFamily: AppFonts.arabic),
        titleMedium: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontFamily: AppFonts.arabic),
        titleLarge: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontFamily: AppFonts.arabic),
      ),

      // --- شريط التطبيق العلوي (AppBarTheme الموحد) ---
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.webHeaderBackground : colorScheme.primary,
        foregroundColor: isDark ? Colors.white : colorScheme.onPrimary,
        centerTitle: true,
        elevation: 0,
      ),

      // --- البطاقات (CardTheme) ---
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark
              ? const BorderSide(color: AppColors.webBorder, width: 1.0)
              : const BorderSide(color: Colors.transparent, width: 0.0),
        ),
      ),

      // --- مدخلات النصوص (Text Fields) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
        labelStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.webBorder : AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.webBorder : AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),

      // --- الأزرار ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}