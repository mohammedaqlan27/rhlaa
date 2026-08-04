// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class ThemeProvider with ChangeNotifier {
  static const _kThemeModeKey = 'theme_mode';
  static const _kHighContrastKey = 'high_contrast';
  static const _kSeedColorKey = 'seed_color_hex';

  ThemeMode _mode;
  bool _highContrast;
  Color? _seedColor;

  ThemeProvider({
    ThemeMode initialMode = ThemeMode.system,
    bool initialHighContrast = false,
    Color? initialSeedColor,
  })  : _mode = initialMode,
        _highContrast = initialHighContrast,
        _seedColor = initialSeedColor;

  ThemeMode get mode => _mode;
  bool get highContrast => _highContrast;
  Color? get seedColor => _seedColor;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _modeToString(mode));
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrastKey, value);
  }

  Future<void> setSeedColor(Color? color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_kSeedColorKey);
    } else {
      await prefs.setString(_kSeedColorKey, '#${color.value.toRadixString(16).padLeft(8, '0')}');
    }
  }

  Future<void> toggleDarkLight() async {
    if (_mode == ThemeMode.dark) {
      await setMode(ThemeMode.light);
    } else {
      await setMode(ThemeMode.dark);
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  static ThemeMode _stringToMode(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static Color? _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      final cleaned = hexString.replaceFirst('#', '');
      if (cleaned.length == 6) buffer.write('ff');
      buffer.write(cleaned);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// تحميل التفضيلات من SharedPreferences عند تشغيل التطبيق
  static Future<ThemeProvider> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kThemeModeKey) ?? 'system';
    final highContrast = prefs.getBool(_kHighContrastKey) ?? false;
    final seedHex = prefs.getString(_kSeedColorKey);

    return ThemeProvider(
      initialMode: _stringToMode(modeStr),
      initialHighContrast: highContrast,
      initialSeedColor: _parseHexColor(seedHex),
    );
  }
}
