import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// Botón de acción de la toolbar.
class PPActionItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool primary;

  const PPActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.primary = false,
  });
}

/// Toolbar de acciones fija (desktop) / enfila (mobile).
///
/// Coloca las acciones principales a la vista sin depender del scroll,
/// y en desktop muestra siempre en la barra superior.
class PPActionToolbar extends StatelessWidget {
  final List<PPActionItem> actions;
  final bool sticky;

  const PPActionToolbar({
    super.key,
    required this.actions,
    this.sticky = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MobileUtils.isMobile(context);
    final wrap = actions.length > (isMobile ? 3 : 5);

    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 0),
      child: wrap
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map(_buildButton).toList(),
            )
          : Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildButton(actions[i]),
                ],
              ],
            ),
    );

    return content;
  }

  Widget _buildButton(PPActionItem item) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final color = item.color ?? (item.primary ? palette.brand : palette.textMuted);

    if (item.primary) {
      return ElevatedButton.icon(
        onPressed: item.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(item.icon, size: 18),
        label: Text(
          item.label,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    }

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.bgSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: color, size: 17),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}