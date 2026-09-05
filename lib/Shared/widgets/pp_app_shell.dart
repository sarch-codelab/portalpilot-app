import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/haptic_service.dart';
import 'package:portal_pilot_app/Shared/services/pp_module_navigator.dart';

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
  final _PPAppShellState state;

  PPController._(this.state);

  void openModule(Modulo modulo) => state._openModule(context: state.context, modulo: modulo);
  void openModuleById(String id) => state._openModuleById(state.context, id);
  void openDrawer() => state._scaffoldKey.currentState?.openDrawer();
  void toggleSidebar() => state.toggleSidebar();
  void logout() => state._handleLogout(state.context);
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

  List<Modulo> get _allModules => Modulo.modulosDisponibles;

  Modulo get _currentModule {
    for (final m in _allModules) {
      if (m.id == widget.moduleId) return m;
    }
    return _allModules.first;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  Future<void> _openModule({required BuildContext context, required Modulo modulo}) async {
    HapticService.instance.lightImpact();
    await PPModuleNavigator.push(context, modulo);
  }

  Future<void> _openModuleById(BuildContext context, String id) async {
    for (final m in _allModules) {
      if (m.id == id) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Datos actualizados'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
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
          ),
        ),
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
                ..._allModules.map((m) => _buildNavItem(m, palette, controller)),
                if (!collapsed) ...[
                  const SizedBox(height: 10),
                  _buildSidebarLabel('SISTEMA', palette),
                  _buildSidebarFooterItem(palette, controller, collapsed),
                ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Portal Pilot',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary),
                  ),
                  Text(
                    'WORKSPACE',
                    style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: palette.brand, letterSpacing: 1.2),
                  ),
                ],
              ),
              const Spacer(),
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
                  color: selected ? accent.withValues(alpha: 0.4) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
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

  Widget _buildSidebarFooterItem(ThemePalette palette, PPController controller, bool collapsed) {
    return _buildNavItem(
      Modulo(
        id: 'settings',
        nombre: 'Configuración',
        descripcion: 'Config',
        icono: Icons.settings_rounded,
        color: palette.brand,
        ruta: '',
      ),
      palette,
      controller,
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
            ] else
              _buildBreadcrumb(palette),
            const Spacer(),
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
        InkWell(
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.bgSecondary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.home_rounded, color: palette.textMuted, size: 17),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF5D5672)),
        ),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: palette.textPrimary),
        ),
      ],
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
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18),
              if (!MobileUtils.isMobile(context)) ...[
                const SizedBox(width: 6),
                Text(
                  'Nuevo',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemePalette palette) {
    return Container(
      decoration: BoxDecoration(color: palette.bgSecondary, borderRadius: BorderRadius.circular(10)),
      child: Tooltip(
        message: appThemeNotifier.isDark ? 'Modo claro' : 'Modo oscuro',
        child: IconButton(
          icon: Icon(
            appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: palette.brand,
            size: 18,
          ),
          onPressed: () async => appThemeNotifier.toggle(),
        ),
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
            border: Border(top: BorderSide(color: palette.brand.withValues(alpha: 0.35))),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, -8)),
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
                  icon: Icons.auto_awesome_rounded,
                  label: 'Navi',
                  isSelected: widget.moduleId == 'chat_ia',
                  palette: palette,
                  onTap: () => controller.openModuleById('chat_ia'),
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
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(color: palette.brand.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  // ─────────────────────────── Drawer (Móvil) ───────────────────────────────
  Widget _buildMobileDrawer(ThemePalette palette, PPController controller) {
    final modules = _allModules;

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
                            Text(
                              'Portal Pilot',
                              style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
                              'WORKSPACE',
                              style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.wifi_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Conectado',
                        style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
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
                  _buildDrawerSysItem(Icons.settings_rounded, 'Configuración', palette, () => controller.openModuleById('settings')),
                  _buildDrawerSysItem(Icons.auto_awesome_rounded, 'Navi IA', palette, () => controller.openModuleById('chat_ia')),
                  _buildDrawerSysItem(Icons.business_rounded, 'Multi-Empresa', palette, () => controller.openModuleById('multi_empresa')),
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

  Widget _buildDrawerSysItem(IconData icon, String title, ThemePalette palette, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: palette.brand, size: 19),
      ),
      title: Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: palette.textMuted)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: palette.textDim, size: 13),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}