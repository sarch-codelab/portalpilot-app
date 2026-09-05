import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_context_menu.dart';

/// Item de lista con gestos táctiles (swipe) + menú contextual (clic derecho).
///
/// - **Móvil**: swipe izquierdo/derecho para acciones rápidas (editar/eliminar).
/// - **Desktop**: clic derecho abre menú contextual.
class PPSwipeTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final Color? accentColor;
  final List<PPContextMenuItem> Function()? contextMenuItems;
  final DismissDirectionCallback? onDismissed;
  final Key? tileKey;

  const PPSwipeTile({
    super.key,
    required this.child,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.accentColor,
    this.contextMenuItems,
    this.onDismissed,
    this.tileKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final hasSwipe = onEdit != null || onDelete != null;

    final item = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.cardColor, palette.cardElevated],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    );

    Widget result = item;

    if (hasSwipe) {
      Widget? secondaryBg;
      Widget? primaryBg;

      if (onEdit != null) {
        primaryBg = _SwipeActionBackground(
          alignment: Alignment.centerLeft,
          color: palette.infoBlue,
          icon: Icons.edit_rounded,
          label: 'Editar',
        );
      }
      if (onDelete != null) {
        secondaryBg = _SwipeActionBackground(
          alignment: Alignment.centerRight,
          color: palette.errorRed,
          icon: Icons.delete_rounded,
          label: 'Eliminar',
        );
      }

      result = Dismissible(
        key: tileKey ?? UniqueKey(),
        direction: DismissDirection.horizontal,
        background: primaryBg ?? secondaryBg,
        secondaryBackground: secondaryBg,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit?.call();
            return false;
          }
          if (direction == DismissDirection.endToStart) {
            final confirmed = await _confirmDelete(context);
            if (confirmed) {
              onDelete?.call();
            }
            return false;
          }
          return false;
        },
        onDismissed: onDismissed,
        child: item,
      );
    }

    final items = contextMenuItems;
    if (items != null) {
      result = PPContextMenuWrapper(
        itemsFn: items,
        child: result,
      );
    }

    return result;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Eliminar?',
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: palette.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: palette.errorRed)),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 4),
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }
}