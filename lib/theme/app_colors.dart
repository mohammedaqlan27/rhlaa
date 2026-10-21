import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- ألوان الهوية ---
  static const Color logoBlue = Color(0xFF1E70B8);
  static const Color logoTeal = Color(0xFF17A5A3);
  static const Color logoGreen = Color(0xFF4EBF64);

  // --- ألوان وظيفية ---
  static const Color primary = logoBlue;
  static const Color secondary = logoTeal;
  static const Color success = logoGreen;
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFFFAD3B);

  // --- الخلفيات ---
  static const Color background = Color(0xFFF8F9FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // --- درجات رمادية (مطلوبة في الكود) ---
  static const Color gray50  = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF7F7F7);
  static const Color gray200 = Color(0xFFEDEDED);
  static const Color gray300 = Color(0xFFD5CECE);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray700 = Color(0xFF6B6B6B);
  static const Color gray900 = Color(0xFF212121);

  // --- النصوص ---
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF525F69);
  static const Color textMuted = gray700;

  // --- الوضع المظلم ---
  static const Color backgroundDark = Color(0xFF0F1720);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF0B1220);

  // --- ألوان لوحة التحكم للويب (Dark Dashboard) ---
  static const Color webBackground = Color(0xFF0F1217);
  static const Color webSidebarBackground = Color(0xFF181B20);
  static const Color webCardBackground = Color(0xFF1E222A);
  static const Color webHeaderBackground = Color(0xFF181B20);
  static const Color webBorder = Color(0xFF262A33);

  static get surfaceLight => null;

  static get backgroundLight => null;


  // --- أدوات مساعدة ---
  static MaterialColor createMaterialColor(Color color) {
    final strengths = <double>[.05];
    final swatch = <int, Color>{};
    final r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) strengths.add(0.1 * i);

    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      final int newR = r + ((ds < 0 ? r : (255 - r)) * ds).round();
      final int newG = g + ((ds < 0 ? g : (255 - g)) * ds).round();
      final int newB = b + ((ds < 0 ? b : (255 - b)) * ds).round();
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        newR.clamp(0, 255), newG.clamp(0, 255), newB.clamp(0, 255), 1,
      );
    }

    return MaterialColor(color.value, swatch);
  }

  static Color contrastText(Color backgroundColor, {Color dark = Colors.black, Color light = Colors.white}) {
    return backgroundColor.computeLuminance() < 0.5 ? light : dark;
  }

  static Color fromHex(String hexString, {String fallback = '#000000'}) {
    final hex = (hexString.isEmpty ? fallback : hexString).replaceAll('#', '');
    final buffer = StringBuffer();
    if (hex.length == 6) buffer.write('ff');
    buffer.write(hex);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String sanitizeKey(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_').toLowerCase();
  }
}

class AppFonts {
  AppFonts._();
  static const String arabic = 'Cairo';
  static const String english = 'Roboto';
}
