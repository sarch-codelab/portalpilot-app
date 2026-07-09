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
