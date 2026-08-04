// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart'; // استيراد الألوان

/// 📌 الثوابت العامة (App Constants)
class AppConstants {
  AppConstants._();

  static const double borderRadius = 16.0; // انحناء عصري موحد

  // --- تصنيفات الرحلات ---
  static const List<String> tripCategories = ['داخلية', 'خارجية'];

  // --- جميع المحافظات اليمنية (22 محافظة + الأمانة) ---
  static const List<String> yemenGovernorates = [
    'أمانة العاصمة (صنعاء)', 'محافظة صنعاء', 'عدن', 'تعز', 'حضرموت (المكلا)',
    'حضرموت (سيئون)', 'إب', 'الحديدة', 'مأرب', 'شبوة', 'الجوف', 'المهرة',
    'أبين', 'الضالع', 'لحج', 'البيضاء', 'عمران', 'ذمار', 'حجة', 'صعدة',
    'المحويت', 'ريمة', 'سقطرى'
  ];

  // --- الوجهات الخارجية (موسعة) ---
  static const Map<String, List<String>> externalDestinations = {
    'السعودية': ['الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 'الدمام', 'خميس مشيط', 'نجران', 'شرورة'],
    'الإمارات': ['دبي', 'أبوظبي', 'الشارقة', 'العين'],
    'عمان': ['مسقط', 'صلالة', 'صحار'],
    'مصر': ['القاهرة', 'الإسكندرية'],
    'الأردن': ['عمان', 'إربد'],
  };

  // --- أنواع المركبات (مفصلة) ---
  static const Map<String, List<String>> vehicleCategories = {
    'اقتصادية': ['سيدان (تويوتا كورولا، إلنترا)', 'سيدان (كامري، سوناتا)'],
    'عائلية / دفع رباعي': ['لاندكروزر (صالون)', 'برادو', 'سنتافي', 'توسان'],
    'نقل جماعي': ['باص هايس (14 راكب)', 'باص كوستر (26 راكب)', 'حافلة نقل جماعي (50 راكب)'],
    'نقل بضائع / حوض': ['هيلوكس غمارتين', 'شاص', 'دينا'],
  };

  static const List<String> tripStatuses = ['مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'];
}

/// 🛠️ إعدادات الثيم (Theme Factory)
class AppTheme {
  AppTheme._();

  // --- الثيم الفاتح (Light Theme) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.arabic,

      // داخل AppTheme في ملف constants.dart
      cardTheme: CardThemeData( // تأكد من إضافة كلمة Data
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // --- الثيم المظلم (Dark Theme) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: AppFonts.arabic,

      // داخل AppTheme في ملف constants.dart
      cardTheme: CardThemeData( // تأكد من إضافة كلمة Data
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }
}