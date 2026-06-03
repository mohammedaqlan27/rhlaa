import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // دالة مساعدة للوصول إلى الكلاس من داخل الـ Widgets
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // خريطة النصوص المترجمة
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Trips App',
      'login': 'Login',
      'register': 'Register',
      'email': 'Email Address',
      'password': 'Password',
      'home': 'Home',
      'profile': 'Profile',
      'my_bookings': 'My Bookings',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'logout': 'Logout',
      'create_trip': 'Create New Trip',
      'search': 'Search for trips...',
      'no_trips': 'No trips found',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'error': 'Something went wrong',
    },
    'ar': {
      'app_title': 'تطبيق الرحلات',
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'home': 'الرئيسية',
      'profile': 'الملف الشخصي',
      'my_bookings': 'حجوزاتي',
      'notifications': 'التنبيهات',
      'settings': 'الإعدادات',
      'logout': 'تسجيل الخروج',
      'create_trip': 'إنشاء رحلة جديدة',
      'search': 'البحث عن رحلات...',
      'no_trips': 'لا توجد رحلات متاحة',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'error': 'حدث خطأ ما',
    },
  };

  // دالة لجلب النص بناءً على المفتاح واللغة الحالية
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Delegate المسؤول عن تحميل ملفات اللغة
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

// كلاس الـ Delegate المطلوب من Flutter
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}