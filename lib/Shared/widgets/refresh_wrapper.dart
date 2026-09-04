import 'package:flutter/material.dart';

class RefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool enabled;
  final Color? refreshColor;
  final Color? backgroundColor;

  const RefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enabled = true,
    this.refreshColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: refreshColor ?? const Color(0xFF8B5CF6),
      backgroundColor: backgroundColor ?? const Color(0xFF111111),
      child: child,
    );
  }
}

class SwipeToDismissWrapper extends StatelessWidget {
  final Widget child;
  final DismissDirectionCallback? onDismissed;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final Color? dismissBackgroundColor;
  final bool confirmDismiss;

  const SwipeToDismissWrapper({
    super.key,
    required this.child,
    this.onDismissed,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.dismissBackgroundColor,
    this.confirmDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    final directions = <DismissDirection>[];
    if (onSwipeLeft != null) directions.add(DismissDirection.startToEnd);
    if (onSwipeRight != null) directions.add(DismissDirection.endToStart);
    if (onSwipeUp != null) directions.add(DismissDirection.down);
    if (onSwipeDown != null) directions.add(DismissDirection.up);

    if (directions.isEmpty) return child;

    return Dismissible(
      key: UniqueKey(),
      direction: directions.isEmpty ? DismissDirection.horizontal : directions.first,
      onDismissed: onDismissed,
      confirmDismiss: confirmDismiss
          ? (direction) async {
              if (direction == DismissDirection.startToEnd && onSwipeLeft != null) {
                onSwipeLeft!();
                return true;
              }
              if (direction == DismissDirection.endToStart && onSwipeRight != null) {
                onSwipeRight!();
                return true;
              }
              if (direction == DismissDirection.down && onSwipeUp != null) {
                onSwipeUp!();
                return true;
              }
              if (direction == DismissDirection.up && onSwipeDown != null) {
                onSwipeDown!();
                return true;
              }
              return false;
            }
          : null,
      background: Container(
        color: dismissBackgroundColor ?? const Color(0xFFEF4444),
        alignment: Alignment.center,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      child: child,
    );
  }
}

class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshText;
  final String? refreshingText;
  final bool enabled;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshText,
    this.refreshingText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF8B5CF6),
      backgroundColor: const Color(0xFF111111),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: child),
        ],
      ),
    );
  }
}