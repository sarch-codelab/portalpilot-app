import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeNotifier extends ValueNotifier<ThemeMode> {
  AppThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final hasTheme = prefs.containsKey('theme_is_dark');
    final isDark = hasTheme ? (prefs.getBool('theme_is_dark') ?? true) : true;
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final nextMode = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    value = nextMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', nextMode == ThemeMode.dark);
  }

  bool get isDark => value == ThemeMode.dark;
}

final appThemeNotifier = AppThemeNotifier();

class ThemePalette {
  final bool isDark;

  ThemePalette({required this.isDark});

  Color get bgPrimary => isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA);
  Color get bgSecondary => isDark ? const Color(0xFF080808) : const Color(0xFFE9ECEF);
  Color get bgTertiary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFDEE2E6);
  Color get cardColor => isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  Color get borderLight => isDark ? const Color(0x29FFFFFF) : const Color(0x1A000000);
  Color get appBarColor => isDark ? const Color(0xFF080808) : const Color(0xFFFFFFFF);

  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);
  Color get accentPurpleLight => const Color(0xFFA78BFA);
  Color get accentPurpleDeep => const Color(0xFF5B21B6);

  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF212529);
  Color get textMuted => isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6C757D);
  Color get textDark => isDark ? const Color(0xFF525252) : const Color(0xFF495057);

  Color get successGreen => const Color(0xFF10B981);
  Color get warningAmber => const Color(0xFFF59E0B);
  Color get infoBlue => const Color(0xFF3B82F6);
  Color get errorRed => const Color(0xFFEF4444);
}
