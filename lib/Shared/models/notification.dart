import 'package:flutter/material.dart';

enum PPNotifPriority { critical, high, medium, low }

enum PPNotifType { system, sync, inventory, billing, support, plan, update }

class PPNotification {
  final String id;
  final String title;
  final String message;
  final PPNotifType type;
  final PPNotifPriority priority;
  final DateTime createdAt;
  final bool read;
  final List<PPNotifAction>? actions;
  final String? groupKey;

  PPNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.priority = PPNotifPriority.medium,
    required this.createdAt,
    this.read = false,
    this.actions,
    this.groupKey,
  });

  PPNotification copyWith({
    bool? read,
    List<PPNotifAction>? actions,
  }) {
    return PPNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      priority: priority,
      createdAt: createdAt,
      read: read ?? this.read,
      actions: actions ?? this.actions,
      groupKey: groupKey,
    );
  }

  IconData get icon {
    switch (type) {
      case PPNotifType.system:
        return Icons.settings_rounded;
      case PPNotifType.sync:
        return Icons.sync_rounded;
      case PPNotifType.inventory:
        return Icons.inventory_2_rounded;
      case PPNotifType.billing:
        return Icons.receipt_long_rounded;
      case PPNotifType.support:
        return Icons.headset_mic_rounded;
      case PPNotifType.plan:
        return Icons.workspace_premium_rounded;
      case PPNotifType.update:
        return Icons.system_update_rounded;
    }
  }

  Color get color {
    switch (priority) {
      case PPNotifPriority.critical:
        return const Color(0xFFFF453A);
      case PPNotifPriority.high:
        return const Color(0xFFFF9A0E);
      case PPNotifPriority.medium:
        return const Color(0xFF007AFF);
      case PPNotifPriority.low:
        return const Color(0xFF8E8E93);
    }
  }
}

class PPNotifAction {
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool destructive;

  PPNotifAction({
    required this.label,
    this.route,
    this.onTap,
    this.destructive = false,
  });
}
