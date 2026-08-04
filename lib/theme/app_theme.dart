// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ThemeExtension مخصص للألوان التطبيقية
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color brandAccent;
  final Color success;
  final Color danger;
  final Color warning;

  const AppColorsExtension({
    required this.brandAccent,
    required this.success,
    required this.danger,
    required this.warning,
  });

  @override
  AppColorsExtension copyWith({Color? brandAccent, Color? success, Color? danger, Color? warning}) {
    return AppColorsExtension(
      brandAccent: brandAccent ?? this.brandAccent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// AppTheme: مصنع ثيمات التطبيق مع دعم Light / Dark / High Contrast
class AppTheme {
  AppTheme._();

  static const double _borderRadius = 12.0;

  // مشغلات الثيم السريعة
  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();

  /// إرجاع ThemeData للثيم الفاتح
  static ThemeData light({
    Color? seedColor,
    bool highContrast = false,
    String fontFamily = AppFonts.arabic,
  }) {
    final seed = seedColor ?? AppColors.primary;
    final primarySwatch = AppColors.createMaterialColor(seed);
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surface,
      background: AppColors.background,
    );

    return _buildTheme(colorScheme, fontFamily, highContrast, primarySwatch);
  }

  /// إرجاع ThemeData للثيم المظلم
  static ThemeData dark({
    Color? seedColor,
    bool highContrast = false,
    String fontFamily = AppFonts.arabic,
  }) {
    final seed = seedColor ?? AppColors.primary;
    final primarySwatch = AppColors.createMaterialColor(seed);
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
      secondary: AppColors.secondary,
      surface: AppColors.surfaceDark,
      background: AppColors.backgroundDark,
      error: AppColors.error,
    );

    return _buildTheme(colorScheme, fontFamily, highContrast, primarySwatch);
  }

  /// دالة مركزية لبناء الثيم لضمان التناسق التام
  static ThemeData _buildTheme(ColorScheme colorScheme, String fontFamily, bool highContrast, MaterialColor primarySwatch) {
    final isDark = colorScheme.brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primarySwatch: primarySwatch,
      scaffoldBackgroundColor: isDark ? colorScheme.background : AppColors.background,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final appColorsExt = AppColorsExtension(
      brandAccent: colorScheme.primary,
      success: AppColors.success,
      danger: AppColors.error,
      warning: AppColors.warning,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[appColorsExt],
      textTheme: _buildTextTheme(fontFamily, highContrast, isDark, colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme, fontFamily),
      cardTheme: _buildCardTheme(isDark, colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme, highContrast, fontFamily),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buildElevatedButtonStyle(colorScheme, highContrast, fontFamily)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buildOutlinedButtonStyle(colorScheme, highContrast, fontFamily)),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? colorScheme.surface : AppColors.textPrimary,
        contentTextStyle: TextStyle(color: isDark ? colorScheme.onSurface : Colors.white, fontFamily: fontFamily),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius + 4)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        indicatorColor: colorScheme.primary.withOpacity(0.08),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : AppColors.gray300,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: colorScheme.onSurface, fontSize: 16),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, color: colorScheme.onSurface.withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: _buildDialogTheme(isDark, colorScheme, fontFamily),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.selected)) return colorScheme.primary;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      iconTheme: IconThemeData(color: colorScheme.primary, size: 24),
    );
  }

  // --- مساعدات بناء المكونات (Component Helpers) ---

  static TextTheme _buildTextTheme(String fontFamily, bool highContrast, bool isDark, ColorScheme colorScheme) {
    final Color textColor = isDark ? colorScheme.onSurface : AppColors.textPrimary;
    final Color secondaryColor = isDark ? colorScheme.onSurface.withOpacity(0.9) : AppColors.textSecondary;

    return TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 32 : 28, fontWeight: FontWeight.bold, color: textColor),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 22 : 20, fontWeight: FontWeight.bold, color: textColor),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 18 : 16, fontWeight: FontWeight.w600, color: textColor),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 17 : 15, color: textColor, height: 1.5),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 15 : 14, color: secondaryColor),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: highContrast ? 13 : 12, color: secondaryColor),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme colorScheme, String fontFamily) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: isDark ? colorScheme.surface : colorScheme.primary,
      foregroundColor: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
      ),
      iconTheme: IconThemeData(color: isDark ? colorScheme.onSurface : colorScheme.onPrimary),
    );
  }

  // إرجاع CardThemeData متوافق مع توقيع ThemeData
  static CardThemeData _buildCardTheme(bool isDark, ColorScheme colorScheme) {
    return CardThemeData(
      color: isDark ? const Color(0xFF1E1E1E) : AppColors.card,
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        side: isDark
            ? BorderSide(color: Colors.white.withOpacity(0.05))
            : BorderSide(color: AppColors.gray200.withOpacity(0.5)),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(ColorScheme colorScheme, bool highContrast, String fontFamily) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? colorScheme.surface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: TextStyle(fontFamily: fontFamily, color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
      labelStyle: TextStyle(fontFamily: fontFamily, color: colorScheme.onSurface.withOpacity(0.8), fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_borderRadius), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
    );
  }

  static ButtonStyle _buildElevatedButtonStyle(ColorScheme colorScheme, bool highContrast, String fontFamily) {
    return ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: highContrast ? 4 : 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
      textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  static ButtonStyle _buildOutlinedButtonStyle(ColorScheme colorScheme, bool highContrast, String fontFamily) {
    return OutlinedButton.styleFrom(
      foregroundColor: colorScheme.primary,
      side: BorderSide(color: colorScheme.primary, width: highContrast ? 2 : 1.2),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
      textStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  // DialogThemeData متوافق مع توقيع ThemeData
  static DialogThemeData _buildDialogTheme(bool isDark, ColorScheme colorScheme, String fontFamily) {
    return DialogThemeData(
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius + 4)),
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
      contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: colorScheme.onSurface),
    );
  }

  /// إرجاع ThemeData بناءً على ThemeMode
  static ThemeData themeForMode({
    required ThemeMode mode,
    Color? seedColor,
    bool highContrast = false,
    String fontFamily = AppFonts.arabic,
  }) {
    switch (mode) {
      case ThemeMode.dark:
        return dark(seedColor: seedColor, highContrast: highContrast, fontFamily: fontFamily);
      case ThemeMode.light:
        return light(seedColor: seedColor, highContrast: highContrast, fontFamily: fontFamily);
      default:
        return light(seedColor: seedColor, highContrast: highContrast, fontFamily: fontFamily);
    }
  }
}
