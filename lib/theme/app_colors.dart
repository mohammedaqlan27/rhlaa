// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// AppColors: ألوان التطبيق المركزية (متوافقة مع ألوان الهوية الثلاثة)
class AppColors {
  AppColors._();

  // ألوان الشعار الأساسية
  static const Color logoBlue = Color(0xFF1E70B8);
  static const Color logoTeal = Color(0xFF17A5A3);
  static const Color logoGreen = Color(0xFF4EBF64);

  // الألوان الوظيفية للتطبيق
  static const Color primaryBlue = logoBlue;
  static const Color secondaryTeal = logoTeal;
  static const Color background = Color(0xFFF7F7FB);
  static const Color surface = Colors.white;
  static const Color lightGray = Color(0xFFD5CECE);
  static const Color successGreen = logoGreen;
  static const Color errorRed = Color(0xFFC62828);
  static const Color alertYellow = Color(0xFFFFAD3B);
  static const Color textDark = Color(0xFF212121);
  static const Color muted = Color(0xFF6B6B6B);
}

/// AppFonts: أسماء الخطوط المستخدمة في المشروع
class AppFonts {
  AppFonts._();

  static const String arabic = 'Cairo';
  static const String english = 'Roboto';
}

/// AppConstants: ثوابت عامة وهياكل البيانات المركزية للتطبيق
class AppConstants {
  AppConstants._();

  // تصنيفات الرحلات الرئيسية
  static const List<String> tripCategories = ['داخلية', 'خارجية'];

  // 1. الوجهات الداخلية: تشمل جميع محافظات الجمهورية اليمنية الـ 22
  static const List<String> internalDestinations = [
    'أمانة العاصمة (صنعاء)',
    'محافظة صنعاء',
    'عدن',
    'تعز',
    'حضرموت',
    'إب',
    'الحديدة',
    'مأرب',
    'شبوة',
    'ذمار',
    'حجة',
    'عمران',
    'صعدة',
    'الجوف',
    'البيضاء',
    'الضالع',
    'لحج',
    'أبين',
    'المهرة',
    'المحويت',
    'ريمة',
    'سقطرى',
  ];

  // 2. الوجهات الخارجية: الدول والمدن الأكثر حركية وسفراً لليمنيين للعمل والعبور
  static const Map<String, List<String>> externalDestinations = {
    'المملكة العربية السعودية': [
      'الرياض',
      'جدة',
      'مكة المكرمة',
      'المدينة المنورة',
      'الدمام',
      'خميس مشيط',
      'جازان',
    ],
    'دولة الإمارات العربية المتحدة': [
      'دبي',
      'أبوظبي',
      'الشارقة',
    ],
    'سلطنة عمان': [
      'مسقط',
      'صلالة',
      'صحار',
      'نزوى',
    ],
  };

  // 3. هيكلة المركبات: الشركات والموديلات الأكثر استخداماً واعتمادية في الخطوط الطويلة بمصر واليمن
  static const Map<String, List<String>> vehiclesByCompany = {
    'تويوتا (Toyota)': [
      'هيلوكس (Hilux) - حوض شاص',
      'لاندكروزر (صالون) - دفع رباعي',
      'إنوفا (Innova) - عائلي 7 ركاب',
      'كورولا (Corolla) - سيدان',
      'هايس (HiAce) - باص صغير 14 راكب',
    ],
    'هيونداي (Hyundai)': [
      'سنتافي (Santa Fe) - عائلي خطوط',
      'توسان (Tucson) - عائلي صغير',
      'إلنترا (Elantra) - سيدان',
      'إتش 1 (H1) - فان مريح',
    ],
    'شركات الباصات المتوسطة': [
      'تويوتا كوستر (Coaster)',
      'هيونداي كونتي (County)',
      'ميتسوبيشي روزا (Rosa)',
    ],
    'جي إم سي (GMC)': [
      'سوبربان (Suburban) - صالون مغتربين عريض',
      'يوكن (Yukon) - دفع رباعي طويل',
    ],
    'كيا (Kia)': [
      'سورينتو (Sorento) - دفع رباعي',
      'كارنفال (Carnival) - فان عائلي واسع',
      'سبورتج (Sportage)',
    ],
    'نيسان (Nissan)': [
      'باترول (Patrol) - بطل الدروب سفري',
      'أورفان (Urvan) - باص ميكرو لنقل الركاب',
    ],
  };

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

/// AppThemeFactory: دوال لإرجاع ThemeData موحّد مبني على الألوان الجديدة
class AppThemeFactory {
  AppThemeFactory._();

  static ThemeData light({Color? seedColor}) {
    final seed = seedColor ?? AppColors.primaryBlue;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      secondary: AppColors.secondaryTeal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryBlue,
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
      dividerTheme: const DividerThemeData(color: AppColors.lightGray, thickness: 1),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}