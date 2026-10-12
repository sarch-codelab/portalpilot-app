import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';
import 'package:portal_pilot_app/Modules/module_manager.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/haptic_service.dart';
import 'package:portal_pilot_app/Shared/services/pp_module_navigator.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notification_panel.dart';
import 'package:portal_pilot_app/Shared/services/notification_service.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notification_panel.dart';
import 'package:portal_pilot_app/Shared/services/notification_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

/// Núcleo de navegación de Portal Pilot.
///
/// - **Desktop/Tablet**: Sidebar lateral con módulos, colapsable.
/// - **Móvil**: Drawer + Bottom nav con botón "Núcleo" central.
///
/// Todo módulo debe envolverse con este shell para mantener la identidad
/// Portal Pilot y una navegación consistente en cualquier dispositivo.
class PPAppShell extends StatefulWidget {
  /// Módulo actual (define el item activo del sidebar/bottomnav).
  final String moduleId;

  /// Widget del contenido principal (debe ser el `body` de la pantalla).
  final Widget child;

  /// Búsqueda global (Ctrl+K).
  final Future<void> Function(String query)? onGlobalSearch;

  /// Acción "Nuevo" (Ctrl+N) para el módulo.
  final VoidCallback? onNew;

  /// Acción "Guardar" (Ctrl+S) para el módulo.
  final Future<void> Function()? onSave;

  /// Si `true` no muestra la topbar automática (para pantallas que
  /// gestionan su propio encabezado).
  final bool hideTopBar;

  /// Título corto de la pantalla actual (para breadcrumb).
  final String? screenTitle;

  /// Icono del módulo actual (para breadcrumb).
  final IconData? moduleIcon;

  /// Color del módulo actual.
  final Color? moduleColor;

  /// Lista de acciones extra para la barra superior.
  final List<Widget>? actions;

  /// Deshabilitar navegación/búsqueda global (para screens embebidos).
  final bool immersive;

  /// Acción de logout (se usa el de HomeScreen por defecto).
  final VoidCallback? onLogout;

  const PPAppShell({
    super.key,
    required this.moduleId,
    required this.child,
    this.onGlobalSearch,
    this.onNew,
    this.onSave,
    this.hideTopBar = false,
    this.screenTitle,
    this.moduleIcon,
    this.moduleColor,
    this.actions,
    this.immersive = false,
    this.onLogout,
  });

  static PPController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_PPInherited>()?.controller;
  }

  @override
  State<PPAppShell> createState() => _PPAppShellState();
}

/// Controlador accesible desde cualquier hijo del shell.
class PPController {
  final _PPAppShellState _state;

  PPController._(this._state);

  void openModule(Modulo modulo) => _state._openModule(context: _state.context, modulo: modulo);
  void openModuleById(String id) => _state._openModuleById(_state.context, id);
  void openDrawer() => _state._scaffoldKey.currentState?.openDrawer();
  void toggleSidebar() => _state.toggleSidebar();
  void logout() => _state._handleLogout(_state.context);
}

class _PPInherited extends InheritedWidget {
  final PPController controller;
  const _PPInherited({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_PPInherited oldWidget) => false;
}

class _PPAppShellState extends State<PPAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresca topbar/sidebar/bottomnav cuando cambia el tema global.
    appThemeNotifier.addListener(_onThemeChanged);
    // Refresca la navegación cuando se recalculan los módulos del plan.
    ModuleManager.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  List<Modulo> get _allModules => Modulo.modulosDisponibles;

  /// Módulos visibles en la navegación (sidebar/drawer): solo los del plan
    /// contratado. Los módulos de sistema se muestran en una sección separada.
  List<Modulo> get _navModules {
    return _allModules
      .where((m) => !_isSystemModule(m.id) && ModuleManager.instance.isAppModuleAllowed(m.id))
        .toList();
  }

    List<Modulo> get _systemModules => _allModules
      .where((m) => const {'settings', 'soporte', 'estado_sistema'}.contains(m.id))
      .toList();

    bool _isSystemModule(String id) =>
      const {'settings', 'soporte', 'estado_sistema'}.contains(id);

  Modulo get _currentModule {
    for (final m in _allModules) {
      if (m.id == widget.moduleId) return m;
    }
    return _allModules.first;
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    ModuleManager.instance.removeListener(_onThemeChanged);
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  Future<void> _openModule({required BuildContext context, required Modulo modulo}) async {
    if (!ModuleManager.instance.isAppModuleAllowed(modulo.id)) {
      PPNotifications.info(context, 'Este módulo no está incluido en tu plan.', title: 'Módulo no disponible');
      return;
    }
    HapticService.instance.lightImpact();
    await PPModuleNavigator.push(context, modulo);
  }

  Future<void> _openModuleById(BuildContext context, String id) async {
    for (final m in _allModules) {
      if (m.id == id) {
        if (!ModuleManager.instance.isAppModuleAllowed(id)) {
          PPNotifications.info(context, 'Este módulo no está incluido en tu plan.', title: 'Módulo no disponible');
          return;
        }
        await _openModule(context: context, modulo: m);
        return;
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    widget.onLogout?.call();
  }

  void _refreshModule() {
    HapticService.instance.lightImpact();
    if (!mounted) return;
    PPNotifications.info(context, 'Datos actualizados', title: 'Sincronizado');
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final isMobile = MobileUtils.isMobile(context);
    final isDesktop = MobileUtils.isDesktop(context);

    final controller = PPController._(this);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          if (widget.immersive) return;
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          widget.onNew?.call();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          widget.onSave?.call();
        },
        const SingleActivator(LogicalKeyboardKey.f5): _refreshModule,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: _PPInherited(
          controller: controller,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: palette.bgPrimary,
            drawer: isMobile ? _buildMobileDrawer(palette, controller) : null,
            drawerEdgeDragWidth: isMobile ? 32 : 0,
            endDrawerEnableOpenDragGesture: false,
            body: Row(
              children: [
                if (isDesktop) _buildSidebar(palette, controller),
                Expanded(
                  child: Column(
                    children: [
                      if (!widget.immersive && !widget.hideTopBar)
                        _buildTopBar(palette, controller, isMobile),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                isMobile && !widget.immersive ? _buildBottomNav(palette, controller) : null,
            floatingActionButton: _buildMobileFab(palette),
          ),
        ),
      ),
    );
  }

  /// FAB flotante en móvil: da acceso visible a la acción "Nuevo" del módulo
  /// (crear producto, factura, cliente...) sin depender solo de la topbar.
  Widget? _buildMobileFab(ThemePalette palette) {
    if (!MobileUtils.isMobile(context) || widget.immersive) return null;
    final color = widget.moduleColor ?? _currentModule.color;
    return FloatingActionButton.extended(
      heroTag: 'pp_module_new_fab',
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 4,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: widget.onNew,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(
        'Nuevo',
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─────────────────────────── Sidebar (Desktop) ───────────────────────────
  Widget _buildSidebar(ThemePalette palette, PPController controller) {
    final collapsed = _sidebarCollapsed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: collapsed ? MobileUtils.sidebarCollapsedWidth : MobileUtils.sidebarWidth,
      decoration: BoxDecoration(
        color: palette.sidebarColor,
        border: Border(right: BorderSide(color: palette.borderLight)),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(palette, collapsed),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (!collapsed) _buildSidebarLabel('MÓDULOS', palette),
                ..._navModules.map((m) => _buildNavItem(m, palette, controller)),
                const SizedBox(height: 10),
                if (!collapsed) _buildSidebarLabel('SISTEMA', palette),
                ..._systemModules.map((m) => _buildNavItem(m, palette, controller)),
              ],
            ),
          ),
          if (collapsed)
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: 'Cerrar sesión',
                icon: Icon(Icons.logout_rounded, color: palette.errorRed, size: 20),
                onPressed: () => controller.logout(),
              ),
            )
          else
            _buildSidebarVersion(palette, controller),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(ThemePalette palette, bool collapsed) {
    return GestureDetector(
      onTap: toggleSidebar,
      child: Container(
        height: 68,
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.borderLight)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!collapsed) ...[
              Image.asset('assets/img/robot_logo.png', width: 34, height: 34, fit: BoxFit.contain),
              const SizedBox(width: 10),
              // Expanded+FittedBox: con sidebar angosto (o a mitad del colapso)
              // el título no cabía y desbordaba ~30px a la derecha.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'img/Iconos/Portal Pilot.png',
                        width: 118,
                        height: 24,
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.contain,
                        color: palette.isDark ? Colors.white : Colors.black,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      Text(
                        'WORKSPACE',
                        style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: palette.brand, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.menu_open_rounded, color: palette.textMuted, size: 18),
            ] else
              Image.asset('assets/img/robot_logo.png', width: 34, height: 34, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarLabel(String label, ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: palette.textDim, letterSpacing: 1.6),
      ),
    );
  }

  Widget _buildNavItem(Modulo modulo, ThemePalette palette, PPController controller) {
    final selected = modulo.id == widget.moduleId;
    final collapsed = _sidebarCollapsed;
    final accent = selected
        ? (widget.moduleColor ?? modulo.color)
        : modulo.color;

    return Tooltip(
      message: collapsed ? modulo.nombre : '',
      waitDuration: const Duration(milliseconds: 600),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 2),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (selected && widget.moduleId != 'home') return;
              controller.openModule(modulo);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: palette.isDark ? 0.4 : 0.3)
                    : Colors.transparent,
                width: 1,
              ),
              ),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    modulo.icono,
                    color: selected ? accent : palette.textMuted,
                    size: 20,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        modulo.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? palette.textPrimary : palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarVersion(ThemePalette palette, PPController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: palette.successGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'v0.1.5 · Todos los sistemas',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: palette.textDim),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: Icon(Icons.logout_rounded, color: palette.errorRed, size: 18),
            onPressed: () => controller.logout(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Top bar ──────────────────────────────────────
  Widget _buildTopBar(ThemePalette palette, PPController controller, bool isMobile) {
    return Material(
      color: palette.appBarColor,
      child: Container(
        height: MobileUtils.getAppBarHeight(context),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.borderLight)),
        ),
        child: Row(
          children: [
            if (isMobile) ...[
              IconButton(
                tooltip: 'Menú',
                icon: Icon(Icons.menu_rounded, color: palette.textPrimary),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 4),
              // Breadcrumb compacto en móvil: icono del módulo + título.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(builder: (ctx) {
                      final module = _currentModule;
                      final color = widget.moduleColor ?? module.color;
                      final icon = widget.moduleIcon ?? module.icono;
                      return Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 15),
                      );
                    }),
                    const SizedBox(width: 4),
                    // Flexible: a 320px el texto + espaciadores fijos excedían
                    // el ancho flexible y desbordaban ~9px (quita 8px al gap).
                    Flexible(child: _buildModuleTitle(palette, widget.screenTitle ?? _currentModule.nombre)),
                  ],
                ),
              ),
            ] else
              // Flexible: en ventanas desktop angostas el breadcrumb + buscador
              // fijo (250px) + botones excedían el ancho y desbordaban ~79px.
              Flexible(
                child: _buildBreadcrumb(palette),
              ),
            if (!isMobile && widget.onGlobalSearch != null)
              _buildGlobalSearch(palette),
            if (widget.actions != null) ...[
              const SizedBox(width: 8),
              ...widget.actions!,
            ],
            if (widget.onNew != null) ...[
              const SizedBox(width: 8),
              _buildNewButton(palette),
            ],
            const SizedBox(width: 8),
            _buildThemeToggle(palette),
            const SizedBox(width: 6),
            _buildNotificationBell(palette),
            const SizedBox(width: 6),
            const _NetworkHealthIndicator(),
            const SizedBox(width: 4),
            _buildHomeButton(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(ThemePalette palette) {
    final module = _currentModule;
    final color = widget.moduleColor ?? module.color;
    final icon = widget.moduleIcon ?? module.icono;
    final title = widget.screenTitle ?? module.nombre;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(child: _buildModuleTitle(palette, title)),
      ],
    );
  }

  Widget _buildHomeButton(ThemePalette palette) {
    return Tooltip(
      message: 'Inicio',
      child: InkWell(
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.bgSecondary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.home_rounded, color: palette.textMuted, size: 17),
        ),
      ),
    );
  }

  Widget _buildModuleTitle(ThemePalette palette, String fallback) {
    final asset = _moduleWordmark(widget.moduleId);
    if (asset == null) {
      return Text(fallback, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Image.asset(
      asset,
      width: 104,
      height: 22,
      alignment: Alignment.centerLeft,
      fit: BoxFit.contain,
      color: palette.isDark ? Colors.white : Colors.black,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) => Text(fallback, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildGlobalSearch(ThemePalette palette) {
    return SizedBox(
      width: 250,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.dmSans(fontSize: 13, color: palette.textPrimary),
        onSubmitted: widget.onGlobalSearch,
        decoration: InputDecoration(
          hintText: 'Buscar...   (Ctrl+K)',
          hintStyle: GoogleFonts.dmSans(fontSize: 12, color: palette.textDim),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB94DDC), size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: palette.bgSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB94DDC), width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildNewButton(ThemePalette palette) {
    return Tooltip(
      message: 'Nuevo (Ctrl+N)',
      child: InkWell(
        onTap: widget.onNew,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.brandGradient),
            borderRadius: BorderRadius.circular(10),
            boxShadow: palette.glowShadow(palette.brand, blur: 14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              if (!MobileUtils.isMobile(context)) ...[
                const SizedBox(width: 6),
                Text(
                  'Nuevo',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Selector de tema claro/oscuro/sistema (funciona en móvil y escritorio).
  Widget _buildThemeToggle(ThemePalette palette) {
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Cambiar tema',
      position: PopupMenuPosition.under,
      color: palette.cardElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (mode) async {
        HapticService.instance.lightImpact();
        await appThemeNotifier.setMode(mode);
      },
      itemBuilder: (_) => [
        _themeMenuItem(ThemeMode.light, Icons.light_mode_rounded, 'Claro', palette),
        _themeMenuItem(ThemeMode.dark, Icons.dark_mode_rounded, 'Oscuro', palette),
        _themeMenuItem(ThemeMode.system, Icons.brightness_auto_rounded, 'Sistema', palette),
      ],
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.bgSecondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          switch (appThemeNotifier.value) {
            ThemeMode.light => Icons.light_mode_rounded,
            ThemeMode.dark => Icons.dark_mode_rounded,
            ThemeMode.system => Icons.brightness_auto_rounded,
          },
          color: palette.brandOnSurface,
          size: 18,
        ),
      ),
    );
  }

  PopupMenuItem<ThemeMode> _themeMenuItem(
    ThemeMode mode,
    IconData icon,
    String label,
    ThemePalette palette,
  ) {
    final selected = appThemeNotifier.value == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? palette.brandOnSurface : palette.textMuted,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? palette.textPrimary : palette.textMuted,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_rounded, size: 16, color: palette.brandOnSurface),
        ],
      ),
    );
  }

  // ─────────────────────────── Bottom nav (Móvil) ───────────────────────────
  Widget _buildBottomNav(ThemePalette palette, PPController controller) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.cardColor,
            border: Border(top: BorderSide(color: palette.borderLight)),
            boxShadow: [
              BoxShadow(
                color: palette.isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMobileNavButton(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  isSelected: widget.moduleId == 'home',
                  palette: palette,
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
              Expanded(
                child: _buildMobileNavButton(
                  icon: Icons.settings_rounded,
                  label: 'Config',
                  isSelected: widget.moduleId == 'settings',
                  palette: palette,
                  onTap: () => controller.openModuleById('settings'),
                ),
              ),
              _buildPortalCoreButton(palette, controller),
              Expanded(
                child: _buildMobileNavButton(
                  icon: ModuleManager.instance.isAppModuleAllowed('chat_ia')
                      ? Icons.auto_awesome_rounded
                      : Icons.support_agent_rounded,
                  label: ModuleManager.instance.isAppModuleAllowed('chat_ia')
                      ? 'Navi'
                      : 'Soporte',
                  isSelected: widget.moduleId == 'chat_ia' ||
                      (!ModuleManager.instance.isAppModuleAllowed('chat_ia') &&
                          widget.moduleId == 'soporte'),
                  palette: palette,
                  onTap: () => controller.openModuleById(
                    ModuleManager.instance.isAppModuleAllowed('chat_ia')
                        ? 'chat_ia'
                        : 'soporte',
                  ),
                ),
              ),
              Expanded(
                child: _buildMobileNavButton(
                  icon: Icons.logout_rounded,
                  label: 'Salir',
                  isSelected: false,
                  palette: palette,
                  onTap: () => controller.logout(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required ThemePalette palette,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? palette.brand : palette.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.brand.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            // FittedBox: dentro del Expanded la celda puede quedar más angosta
            // que el label y desbordaba 4px hacia abajo.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalCoreButton(ThemePalette palette, PPController controller) {
    return Tooltip(
      message: 'Núcleo Portal Pilot',
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.brandBright, palette.brandDeep],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
            boxShadow: [
              BoxShadow(color: palette.brand.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Image.asset('img/Iconos/robot_logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Drawer (Móvil) ───────────────────────────────
  Widget _buildMobileDrawer(ThemePalette palette, PPController controller) {
    final modules = _navModules;

    return Drawer(
      backgroundColor: palette.cardColor,
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette.brandGradient),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/img/robot_logo.png', width: 34, height: 34, fit: BoxFit.contain),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Portal Pilot',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
                              'WORKSPACE',
                              style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.75), letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.wifi_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Conectado',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('MÓDULOS', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: palette.textDim, letterSpacing: 1.5)),
                  ),
                  ...modules.map((m) => _buildDrawerModuleItem(m, palette, controller)),
                  Divider(height: 32, color: palette.borderLight),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('SISTEMA', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: palette.textDim, letterSpacing: 1.5)),
                  ),
                  ..._systemModules.map(
                    (m) => _buildDrawerModuleItem(m, palette, controller),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.borderLight))),
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: palette.errorRed),
                title: Text('Cerrar sesión', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: palette.errorRed)),
                onTap: () {
                  Navigator.pop(context);
                  controller.logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerModuleItem(Modulo modulo, ThemePalette palette, PPController controller) {
    final selected = modulo.id == widget.moduleId;
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: modulo.color.withValues(alpha: selected ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(modulo.icono, color: modulo.color, size: 19),
      ),
      title: Text(
        modulo.nombre,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? palette.textPrimary : palette.textMuted,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: palette.textDim, size: 13),
      onTap: () {
        Navigator.pop(context);
        if (!selected) controller.openModule(modulo);
      },
    );
  }

}

class _AppPingMonitor extends ChangeNotifier {
  _AppPingMonitor._();

  static final _AppPingMonitor instance = _AppPingMonitor._();

  Timer? _timer;
  int _clients = 0;
  bool _checking = false;
  bool online = false;
  int? latencyMs;

  void attach() {
    _clients++;
    if (_timer != null) return;
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _probe());
  }

  void detach() {
    _clients = (_clients - 1).clamp(0, 1 << 20);
    if (_clients != 0) return;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _probe() async {
    if (_checking) return;
    _checking = true;
    final stopwatch = Stopwatch()..start();
    try {
      final result = await ApiService.instance.get('/api/me');
      online = result['networkError'] != true && result['timeoutError'] != true;
      latencyMs = online ? stopwatch.elapsedMilliseconds : null;
    } catch (_) {
      online = false;
      latencyMs = null;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }
}

class _NetworkHealthIndicator extends StatefulWidget {
  const _NetworkHealthIndicator();

  @override
  State<_NetworkHealthIndicator> createState() => _NetworkHealthIndicatorState();
}

class _NetworkHealthIndicatorState extends State<_NetworkHealthIndicator> {
  final _monitor = _AppPingMonitor.instance;

  @override
  void initState() {
    super.initState();
    _monitor.addListener(_onPingChanged);
    _monitor.attach();
  }

  @override
  void dispose() {
    _monitor.removeListener(_onPingChanged);
    _monitor.detach();
    super.dispose();
  }

  void _onPingChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final latency = _monitor.latencyMs;
    final level = !_monitor.online || latency == null
        ? 1
        : latency <= 250
            ? 3
            : latency <= 700
                ? 2
                : 1;
    final color = !_monitor.online
        ? palette.errorRed
        : latency == null
            ? palette.textDim
            : latency <= 250
                ? palette.successGreen
                : latency <= 700
                    ? const Color(0xFFF59E0B)
                    : palette.errorRed;
    final label = !_monitor.online
        ? 'Sin conexión'
        : latency == null
            ? 'Midiendo conexión'
            : 'Ping autenticado a Portal Pilot: $latency ms';

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 17,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  return Container(
                    width: 4,
                    height: 6 + index * 4,
                    decoration: BoxDecoration(
                      color: index < level ? color : palette.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                latency == null ? '-- ms' : '$latency ms',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _moduleWordmark(String moduleId) {
  const assets = <String, String>{
    'inventario': 'Inventario.webp',
    'facturacion': 'Facturacion.webp',
    'cotizaciones': 'Cotizaciones.webp',
    'crm': 'CRM.webp',
    'comercial': 'Comercial.webp',
    'contabilidad': 'Contabilidad.webp',
    'membresias': 'Membresias.webp',
  };
  final asset = assets[moduleId.toLowerCase()];
  return asset == null ? null : 'img/texto/$asset';
}
