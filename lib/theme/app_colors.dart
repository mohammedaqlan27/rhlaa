// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// AppColors: ألوان التطبيق المركزية مع أدوات مساعدة للوصولية والتوافق
class AppColors {
  AppColors._();

  // --- ألوان الهوية الأساسية ---
  static const Color logoBlue = Color(0xFF1E70B8);
  static const Color logoTeal = Color(0xFF17A5A3);
  static const Color logoGreen = Color(0xFF4EBF64);

  // --- ألوان وظيفية رئيسية (استخدمها في الواجهات) ---
  static const Color primary = logoBlue;
  static const Color secondary = logoTeal;
  static const Color success = logoGreen;
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFFFAD3B);

  // --- خلفيات وأسقف (surface) ---
  static const Color background = Color(0xFFF8F9FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // --- درجات رمادية معيارية ---
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF7F7F7);
  static const Color gray200 = Color(0xFFEDEDED);
  static const Color gray300 = Color(0xFFD5CECE);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray700 = Color(0xFF6B6B6B);
  static const Color gray900 = Color(0xFF212121);

  // --- نصوص ---
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF525F69);
  static const Color textMuted = gray700;

  // --- ألوان للوضع المظلم ---
  static const Color backgroundDark = Color(0xFF0F1720);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF0B1220);

  // Alias آمن للون الأساسي
  static Color get primaryBlue => primary;

  // -------------------------
  // أدوات مساعدة
  // -------------------------

  /// توليد MaterialColor من لون مفرد (مفيد لاستخدام primarySwatch)
  static MaterialColor createMaterialColor(Color color) {
    final strengths = <double>[.05];
    final swatch = <int, Color>{};
    final r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) strengths.add(0.1 * i);

    for (var strength in strengths) {
      final ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.value, {
      50: swatch[50] ?? color.withOpacity(0.1),
      100: swatch[100] ?? color.withOpacity(0.2),
      200: swatch[200] ?? color.withOpacity(0.3),
      300: swatch[300] ?? color.withOpacity(0.4),
      400: swatch[400] ?? color.withOpacity(0.5),
      500: swatch[500] ?? color,
      600: swatch[600] ?? color.withOpacity(0.7),
      700: swatch[700] ?? color.withOpacity(0.8),
      800: swatch[800] ?? color.withOpacity(0.9),
      900: swatch[900] ?? color.withOpacity(1.0),
    });
  }

  /// اختيار لون نص متباين (أسود أو أبيض) بناءً على luminance
  static Color contrastText(Color backgroundColor, {Color dark = Colors.black, Color light = Colors.white}) {
    return backgroundColor.computeLuminance() < 0.5 ? light : dark;
  }

  /// تحويل HEX string إلى Color بأمان (يدعم #RRGGBB و RRGGBB)
  static Color fromHex(String hexString, {String fallback = '#000000'}) {
    final hex = (hexString.isEmpty ? fallback : hexString).replaceAll('#', '');
    final buffer = StringBuffer();
    if (hex.length == 6) buffer.write('ff');
    buffer.write(hex);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// تنظيف مفتاح/اسم لاستخدامه في مسارات التخزين أو أسماء الحقول
  static String sanitizeKey(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_').toLowerCase();
  }
}

/// AppFonts: أسماء الخطوط المستخدمة في المشروع
class AppFonts {
  AppFonts._();
  static const String arabic = 'Cairo';
  static const String english = 'Roboto';
}

/// AppConstants: ثوابت عامة مركزة (قابلة للتوسيع لاحقاً)
class AppConstants {
  AppConstants._();

  static const List<String> tripCategories = ['داخلية', 'خارجية'];

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

  static const Map<String, List<String>> externalDestinations = {
    'المملكة العربية السعودية': ['الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 'الدمام', 'خميس مشيط', 'جازان'],
    'دولة الإمارات العربية المتحدة': ['دبي', 'أبوظبي', 'الشارقة'],
    'سلطنة عمان': ['مسقط', 'صلالة', 'صحار', 'نزوى'],
  };

  static const Map<String, List<String>> vehiclesByCompany = {
    'تويوتا (Toyota)': [
      'هيلوكس (Hilux) - حوض شاص',
      'لاندكروزر (صالون) - دفع رباعي',
      'إنوفا (Innova) - عائلي 7 ركاب',
      'كورولا (Corolla) - سيدان',
      'هايس (HiAce) - باص صغير 14 راكب',
    ],
    'هيونداي (Hyundai)': ['سنتافي (Santa Fe)', 'توسان (Tucson)', 'إلنترا (Elantra)', 'إتش 1 (H1)'],
    'شركات الباصات المتوسطة': ['تويوتا كوستر (Coaster)', 'هيونداي كونتي (County)', 'ميتسوبيشي روزا (Rosa)'],
    'جي إم سي (GMC)': ['سوبربان (Suburban)', 'يوكن (Yukon)'],
    'كيا (Kia)': ['سورينتو (Sorento)', 'كارنفال (Carnival)', 'سبورتج (Sportage)'],
    'نيسان (Nissan)': ['باترول (Patrol)', 'أورفان (Urvan)'],
  };

  static const List<String> flexibleWindows = ['خلال 2–6 ساعات', 'خلال يوم كامل', 'بعد 42 ساعة'];

  static const List<String> tripStatuses = ['مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'];
}
