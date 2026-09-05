import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// AppBar de módulo Portal Pilot.
///
/// - **Desktop**: breadcrumb (Inicio > Módulo), búsqueda, acciones, tema.
/// - **Móvil**: botón de menú lateral, título, acciones.
class PPModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String moduleTitle;
  final IconData moduleIcon;
  final Color moduleColor;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final bool showMenuButton;

  const PPModuleAppBar({
    super.key,
    required this.moduleTitle,
    required this.moduleIcon,
    required this.moduleColor,
    this.actions,
    this.onBack,
    this.onMenu,
    this.showMenuButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final isMobile = MobileUtils.isMobile(context);

    if (isMobile) {
      return _buildMobileAppBar(context, palette);
    }
    return _buildDesktopAppBar(context, palette);
  }

  // ─── Móvil: menú + icono + título + acciones ──────────────────────────────
  Widget _buildMobileAppBar(BuildContext context, ThemePalette palette) {
    return Material(
      color: palette.appBarColor,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.borderLight)),
        ),
        child: Row(
          children: [
            if (showMenuButton)
              IconButton(
                tooltip: 'Menú',
                icon: Icon(Icons.menu_rounded, color: palette.textMuted),
                onPressed: onMenu,
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [moduleColor, moduleColor.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(color: moduleColor.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(moduleIcon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                moduleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (actions != null) ...[...actions!],
            _ThemeToggle(color: moduleColor),
          ],
        ),
      ),
    );
  }

  // ─── Desktop: breadcrumb Inicio > Módulo + acciones ───────────────────────
  Widget _buildDesktopAppBar(BuildContext context, ThemePalette palette) {
    return Material(
      color: palette.appBarColor,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.borderLight)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: palette.bgSecondary, borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.home_rounded, color: palette.textMuted, size: 17),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF5D5672)),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [moduleColor, moduleColor.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(color: moduleColor.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(moduleIcon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              moduleTitle,
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (actions != null) ...[...actions!, const SizedBox(width: 8)],
            _ThemeToggle(color: moduleColor),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final Color color;
  const _ThemeToggle({required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Container(
      decoration: BoxDecoration(color: palette.bgSecondary, borderRadius: BorderRadius.circular(10)),
      child: Tooltip(
        message: appThemeNotifier.isDark ? 'Modo claro' : 'Modo oscuro',
        child: IconButton(
          icon: Icon(
            appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: color,
            size: 18,
          ),
          onPressed: () async => appThemeNotifier.toggle(),
        ),
      ),
    );
  }
}