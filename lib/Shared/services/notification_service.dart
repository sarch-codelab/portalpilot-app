import 'dart:async';
import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/models/notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final List<PPNotification> _items = [];
  Timer? _poller;

  List<PPNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  void startPolling() {
    if (_poller != null) return;
    _poller = Timer.periodic(const Duration(seconds: 30), (_) {
      // Demo ligero: puedes reemplazar por API/websocket
    });
  }

  void stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  void addDemo(String title, String message, PPNotifType type, PPNotifPriority priority) {
    final n = PPNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      createdAt: DateTime.now(),
    );
    _items.insert(0, n);
    notifyListeners();
  }

  void markAllRead() {
    bool changed = false;
    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true);
      notifyListeners();
    }
  }

  void remove(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _items.removeAt(idx);
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
    }
  }
}
