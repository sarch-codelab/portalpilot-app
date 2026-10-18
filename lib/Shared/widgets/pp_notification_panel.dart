import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/models/notification.dart';
import 'package:portal_pilot_app/Shared/services/notification_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/time_utils.dart';

class PPNotificationPanel extends StatefulWidget {
  const PPNotificationPanel({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PPNotificationPanel(),
    );
  }

  @override
  State<PPNotificationPanel> createState() => _PPNotificationPanelState();
}

class _PPNotificationPanelState extends State<PPNotificationPanel> {
  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: Theme.of(context).brightness == Brightness.dark);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 720;
    final maxWidth = isDesktop ? 420.0 : double.infinity;
    final maxHeight = size.height * 0.92;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topRight,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8),
          decoration: BoxDecoration(
            color: palette.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: palette.isDark ? 0.5 : 0.12),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(palette),
              Expanded(child: _buildList(palette)),
              _buildFooter(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderLight.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Text(
            'Notificaciones',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: NotificationService.instance,
            builder: (_, __) {
              final hasUnread = NotificationService.instance.unreadCount > 0;
              return TextButton(
                onPressed: hasUnread ? NotificationService.instance.markAllRead : null,
                child: Text(
                  'Marcar todas como leídas',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: hasUnread ? palette.infoBlue : palette.textDim,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemePalette palette) {
    return AnimatedBuilder(
      animation: NotificationService.instance,
      builder: (_, __) {
        final items = NotificationService.instance.items;
        if (items.isEmpty) {
          return _buildEmpty(palette);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: palette.borderLight.withValues(alpha: 0.4)),
          itemBuilder: (_, i) => _buildItem(items[i], palette),
        );
      },
    );
  }

  Widget _buildEmpty(ThemePalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.bgSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none_rounded, size: 40, color: palette.textDim),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo está al día',
              style: GoogleFonts.dmSans(fontSize: 13, color: palette.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(PPNotification n, ThemePalette palette) {
    final unread = !n.read;
    return InkWell(
      onTap: () {
        NotificationService.instance.markRead(n.id);
        if (n.actions != null && n.actions!.isNotEmpty) {
          final a = n.actions!.first;
          if (a.route != null) {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed(a.route!);
          }
          a.onTap?.call();
        }
      },
      child: Container(
        color: unread ? palette.bgSecondary.withValues(alpha: 0.4) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: n.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.icon, color: n.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(n.createdAt),
                        style: GoogleFonts.dmSans(fontSize: 11.5, color: palette.textDim),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(Icons.close_rounded, size: 16, color: palette.textDim),
                        onPressed: () => NotificationService.instance.remove(n.id),
                      ),
                    ],
                  ),
                  Text(
                    n.message,
                    style: GoogleFonts.dmSans(fontSize: 13, height: 1.4, color: palette.textMuted),
                  ),
                  if (n.actions != null && n.actions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: n.actions!.map((a) {
                        return OutlinedButton(
                          onPressed: () {
                            if (a.route != null) {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushNamed(a.route!);
                            }
                            a.onTap?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            side: BorderSide(color: a.destructive ? palette.errorRed : palette.borderLight),
                            foregroundColor: a.destructive ? palette.errorRed : palette.infoBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(a.label, style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderLight.withValues(alpha: 0.4))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: NotificationService.instance.clear,
          child: Text(
            'Limpiar todo',
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textDim),
          ),
        ),
      ),
    );
  }
}
