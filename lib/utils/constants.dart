import 'package:flutter/material.dart';

/// 🎨 ألوان التطبيق (App Colors)
class AppColors {
  static const Color primaryPurple = Color(0xFFB39DDB); // بنفسجي فاتح
  static const Color darkPurple = Color(0xFF6A0DAD);    // بنفسجي غامق
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color lightGray = Color.fromARGB(255, 213, 206, 206);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color alertYellow = Color.fromARGB(255, 255, 173, 59);

  // السطر المصحح (تم حذف الرموز الغريبة وتصحيح القيمة)
  static const Color textDark = Color(0xFF212121);
}

/// ✒️ الخطوط المستخدمة (App Fonts)
class AppFonts {
  static const String arabicFont = 'Cairo';
  static const String englishFont = 'Roboto';
}

/// 📌 ثوابت عامة (App Constants)
class AppConstants {
  static const List<String> tripCategories = ['داخلية', 'خارجية'];

  static const Map<String, List<String>> destinations = {
    'داخلية': ['صنعاء', 'عدن', 'تعز', 'حضرموت'],
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

/// 🛠️ إعدادات الثيم
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primaryPurple,
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      fontFamily: AppFonts.arabicFont,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryPurple,
        primary: AppColors.primaryPurple,
        error: AppColors.errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryPurple,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.arabicFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}