import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_app_shell.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_skeleton.dart';
import 'package:portal_pilot_app/Shared/widgets/read_only_guard.dart';
import 'package:portal_pilot_app/Shared/services/background_service.dart';

/// Scaffold de módulo Portal Pilot todo-en-uno.
///
/// Incluye:
/// - Shell de navegación (sidebar desktop / bottomnav+drawer móvil).
/// - Fondo "aurora" de marca con gradiente sutil.
/// - Loading state opcional con skeleton.
/// - Pull-to-refresh opcional.
///
/// Reemplaza al `Scaffold` + `AppBar` + `Stack(background)` repetido en cada
/// módulo, garantizando consistencia visual y responsiva.
class PPModuleScaffold extends StatelessWidget {
  final String moduleId;
  final String screenTitle;
  final IconData moduleIcon;
  final Color moduleColor;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onNew;
  final Future<void> Function(String query)? onGlobalSearch;
  final Future<void> Function()? onRefresh;
  final bool loading;
  final bool heroBackground;
  final bool immersive;
  final void Function()? onLogout;

  const PPModuleScaffold({
    super.key,
    required this.moduleId,
    required this.screenTitle,
    required this.moduleIcon,
    required this.moduleColor,
    required this.child,
    this.actions,
    this.onNew,
    this.onGlobalSearch,
    this.onRefresh,
    this.loading = false,
    this.heroBackground = true,
    this.immersive = false,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);

    Widget body;
    if (heroBackground) {
      body = Stack(
        children: [
          Positioned.fill(
            child: BackgroundService.instance.buildBackground(
              context: context,
              isDark: appThemeNotifier.isDark,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: appThemeNotifier.isDark ? 0.3 : 0.1),
                BlendMode.darken,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.aurora.map((c) => c.withValues(alpha: 0.3)).toList(),
              ),
            ),
            child: SafeArea(
              top: false,
              child: loading ? _buildLoading(context, palette) : child,
            ),
          ),
        ],
      );
    } else {
      body = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.aurora,
          ),
        ),
        child: SafeArea(
          top: false,
          child: loading ? _buildLoading(context, palette) : child,
        ),
      );
    }

    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: moduleColor,
        backgroundColor: palette.cardColor,
        displacement: 40,
        edgeOffset: 8,
        child: body,
      );
    }

    return PPAppShell(
      moduleId: moduleId,
      screenTitle: screenTitle,
      moduleIcon: moduleIcon,
      moduleColor: moduleColor,
      actions: actions,
      onNew: onNew == null
          ? null
          : () {
              if (ReadOnlyGuard.bloqueado(context)) return;
              onNew!();
            },
      onGlobalSearch: onGlobalSearch,
      onLogout: onLogout,
      immersive: immersive,
      child: body,
    );
  }

  Widget _buildLoading(BuildContext context, ThemePalette palette) {
    return Padding(
      padding: MobileUtils.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          PPSkeletonHeader(),
          SizedBox(height: 20),
          PPSkeleton(card: true, cards: 4),
        ],
      ),
    );
  }
}