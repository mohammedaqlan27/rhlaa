// lib/l10n/app_localizations.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// مفاتيح الترجمة المركزية لتجنب الأخطاء الإملائية
class L10nKeys {
  L10nKeys._();
  static const appTitle = 'app_title';
  static const login = 'login';
  static const register = 'register';
  static const email = 'email';
  static const password = 'password';
  static const home = 'home';
  static const profile = 'profile';
  static const myBookings = 'my_bookings';
  static const notifications = 'notifications';
  static const settings = 'settings';
  static const logout = 'logout';
  static const createTrip = 'create_trip';
  static const search = 'search';
  static const noTrips = 'no_trips';
  static const confirm = 'confirm';
  static const cancel = 'cancel';
  static const error = 'error';

  // مفاتيح جديدة مطلوبة للشاشة
  static const whereTo = 'where_to';
  static const tripCategory = 'trip_category';
  static const destination = 'destination';
  static const filter = 'filter';
  static const calendar = 'calendar';
  static const support = 'support';
// أضف مفاتيح جديدة هنا عند الحاجة
}

/// AppLocalizations: مدير الترجمات البسيط مع fallback و interpolation
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// الوصول إلى الـ instance من داخل الودجتس
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// خريطة الترجمات (يمكن لاحقًا نقلها إلى ملفات ARB/JSON)
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Rhlaa',
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
      // new keys
      'where_to': 'Where do you want to go?',
      'trip_category': 'Trip category',
      'destination': 'Destination',
      'filter': 'Filter',
      'calendar': 'Calendar',
      'support': 'Support',

      "privacy": "Privacy",
        "language": "Language",
        "help_center": "Help Center"


    },
    'ar': {
      'app_title': 'تطبيق رحلة',
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
      // new keys
      'where_to': 'أين تريد الذهاب؟',
      'trip_category': 'فئة الرحلة',
      'destination': 'الوجهة',
      'filter': 'فلتر',
      'calendar': 'التقويم',
      'support': 'الدعم',
      "privacy": "الخصوصية",
      "language": "اللغة",
      "help_center": "مركز المساعدة",
    },
  };

  /// ترجمة مفتاح مع fallback إلى الإنجليزية ثم إلى المفتاح نفسه
  String translate(String key) {
    final lang = locale.languageCode;
    final map = _localizedValues[lang];
    if (map != null && map.containsKey(key)) return map[key]!;
    // fallback to English
    final fallback = _localizedValues['en']?[key];
    if (fallback != null) return fallback;
    // أثناء التطوير: طباعة تحذير عند فقدان الترجمة
    assert(() {
      debugPrint('Missing translation for "$key" in locale "$lang"');
      return true;
    }());
    return key;
  }

  /// ترجمة مع استبدال متغيرات داخل النص مثل {name}
  String translateWithArgs(String key, [Map<String, String>? args]) {
    var text = translate(key);
    if (args != null && args.isNotEmpty) {
      args.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  /// Delegate المطلوب من Flutter
  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  static void load(Locale locale) {}
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // يمكن إضافة تحميل موارد غير متزامن هنا إذا انتقلت لملفات خارجية
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// امتداد للوصول السهل داخل الودجتس: context.t(key)
extension TranslateX on BuildContext {
  String t(String key) {
    final loc = AppLocalizations.of(this);
    if (loc == null) {
      // في حال لم تُسجل الـ Localizations بعد، نعيد المفتاح كاحتياط
      return key;
    }
    return loc.translate(key);
  }

  String tArgs(String key, [Map<String, String>? args]) {
    final loc = AppLocalizations.of(this);
    if (loc == null) return key;
    return loc.translateWithArgs(key, args);
  }
}
