import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppWindowManager {
  AppWindowManager._();
  static final instance = AppWindowManager._();

  final WindowManager _wm = WindowManager.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _wm.ensureInitialized();
    await _wm.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  Future<void> restoreWindow() async {
    try {
      await initialize();
      await Future.delayed(const Duration(milliseconds: 500));
      await _wm.setMinimumSize(const Size(720, 560));

      final prefs = await SharedPreferences.getInstance();
      final left = prefs.getInt('win_x');
      final top = prefs.getInt('win_y');
      final width = prefs.getInt('win_w');
      final height = prefs.getInt('win_h');
      final maximized = prefs.getBool('win_maximized') ?? false;

      bool hasValidData = left != null && top != null && width != null && height != null;

      if (hasValidData) {
        final screenW = 1920.0;
        final screenH = 1080.0;
        final validW = width >= 400 && width <= screenW * 1.5;
        final validH = height >= 300 && height <= screenH * 1.5;
        final validX = left > -screenW && left < screenW;
        final validY = top > -screenH && top < screenH;

        hasValidData = validW && validH && validX && validY;
      }

      if (hasValidData) {
        await _wm.setSize(Size(width!.toDouble(), height!.toDouble()));
        await _wm.setPosition(Offset(left!.toDouble(), top!.toDouble()));
      } else {
        await _wm.setSize(const Size(1280, 800));
        await _wm.center();
      }

      if (maximized) {
        await _wm.maximize();
      }
    } catch (e) {
      debugPrint('Error restoring window: $e');
    }
  }

  Future<void> saveWindow() async {
    if (!_initialized) return;
    try {
      final isMaximized = await _wm.isMaximized();
      final pos = await _wm.getPosition();
      final size = await _wm.getSize();

      if (size.width < 100 || size.height < 100) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('win_x', pos.dx.toInt());
      await prefs.setInt('win_y', pos.dy.toInt());
      await prefs.setInt('win_w', size.width.toInt());
      await prefs.setInt('win_h', size.height.toInt());
      await prefs.setBool('win_maximized', isMaximized);
    } catch (e) {
      debugPrint('Error saving window: $e');
    }
  }
}
