// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// AppColors: ألوان التطبيق المركزية
class AppColors {
  AppColors._();

  static const Color primaryPurple = Color(0xFF6A0DAD); // بنفسجي غامق (seed)
  static const Color primaryLight = Color(0xFFB39DDB); // بنفسجي فاتح
  static const Color background = Color(0xFFF7F7FB);
  static const Color surface = Colors.white;
  static const Color lightGray = Color(0xFFD5CECE);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color errorRed = Color(0xFFC62828);
  static const Color alertYellow = Color(0xFFFFAD3B);
  static const Color textDark = Color(0xFF212121);
  static const Color muted = Color(0xFF6B6B6B);

  static Color? get darkPurple => null;
}

/// AppFonts: أسماء الخطوط المستخدمة في المشروع
class AppFonts {
  AppFonts._();

  /// تأكد من إضافة الخطوط في pubspec.yaml وملفات assets/fonts/
  static const String arabic = 'Cairo';
  static const String english = 'Roboto';

  static String? get arabicFont => null;
}

/// AppConstants: ثوابت عامة قابلة لإعادة الاستخدام
class AppConstants {
  AppConstants._();

  static const List<String> tripCategories = ['داخلية', 'خارجية'];

  static const Map<String, List<String>> destinations = {
    'داخلية': ['صنعاء', 'عدن', 'تعز', 'حضرموت', 'الحديدة', 'إب', 'مأرب', 'شبوة'],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  static const List<String> vehicleTypes = [
    'سيارة سيدان',
    'سيارة دفع رباعي',
    'سيارة فان',
  ];

  static const List<String> flexibleWindows = [
    'خلال 2–6 ساعات',
    'خلال يوم كامل',
    'بعد 42 ساعة',
  ];

  static const List<String> tripStatuses = [
    'مفعّلة',
    'في الطريق',
    'تم الوصول',
    'مكتملة',
    'ملغاة',
  ];
}

/// AppThemeFactory: دوال لإرجاع ThemeData موحّد (light / dark لاحقاً)
class AppThemeFactory {
  AppThemeFactory._();

  static ThemeData light({Color? seedColor}) {
    final seed = seedColor ?? AppColors.primaryPurple;
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryPurple,
      fontFamily: AppFonts.arabic,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),

      // ملاحظة: استخدم CardThemeData بدلاً من CardTheme لتوافق مع إصدارات Flutter الحديثة
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withOpacity(0.12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(fontFamily: AppFonts.arabic, fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
        titleMedium: TextStyle(fontFamily: AppFonts.arabic, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyLarge: TextStyle(fontFamily: AppFonts.arabic, fontSize: 16, color: AppColors.textDark),
        bodyMedium: TextStyle(fontFamily: AppFonts.arabic, fontSize: 14, color: AppColors.muted),
        bodySmall: TextStyle(fontFamily: AppFonts.arabic, fontSize: 13, color: AppColors.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: AppColors.lightGray, thickness: 1),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

// يمكنك إضافة dark() لاحقًا بنفس النمط
}
