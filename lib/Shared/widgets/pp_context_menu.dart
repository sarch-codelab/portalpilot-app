import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

/// Menú contextual (clic derecho en desktop) con la identidad Portal Pilot.
///
/// En móvil el menú también puede invocarse con "toque largo" via
/// [PPContextMenu.showAt].
class PPContextMenu {
  /// Muestra el menú en una posición global (para `onSecondaryTapUp`).
  static Future<PPContextMenuItem?> showAt(
    BuildContext context, {
    required Offset position,
    required List<PPContextMenuItem> items,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<PPContextMenuItem>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: ThemePalette(isDark: appThemeNotifier.isDark).cardElevated,
      items: items
          .map((e) => PopupMenuItem(
                value: e,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _MenuItem(icon: e.icon, label: e.label, color: e.color, shortcut: e.shortcut),
              ))
          .toList(),
    );
    return selected;
  }
}

class PPContextMenuItem {
  final IconData icon;
  final String label;
  final Color? color;
  final String? shortcut;
  final VoidCallback onTap;

  const PPContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.shortcut,
  });
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final String? shortcut;

  const _MenuItem({required this.icon, required this.label, this.color, this.shortcut});

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final c = color ?? palette.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: c),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: palette.textPrimary),
        ),
        if (shortcut != null) ...[
          const SizedBox(width: 18),
          Text(
            shortcut!,
            style: GoogleFonts.spaceGrotesk(fontSize: 10, color: palette.textDim),
          ),
        ],
      ],
    );
  }
}

/// Envoltorio que habilita menú contextual por clic derecho/estrés largo.
class PPContextMenuWrapper extends StatelessWidget {
  final Widget child;
  final List<PPContextMenuItem> Function() itemsFn;
  final void Function(PPContextMenuItem item)? onItemSelected;

  const PPContextMenuWrapper({
    super.key,
    required this.child,
    required this.itemsFn,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) async {
        final items = itemsFn();
        if (items.isEmpty) return;
        final selected = await PPContextMenu.showAt(
          context,
          position: details.globalPosition,
          items: items,
        );
        if (selected != null) onItemSelected?.call(selected);
      },
      onLongPress: () async {
        final items = itemsFn();
        if (items.isEmpty) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final selected = await PPContextMenu.showAt(
          context,
          position: box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2)),
          items: items,
        );
        if (selected != null) onItemSelected?.call(selected);
      },
      child: child,
    );
  }
}