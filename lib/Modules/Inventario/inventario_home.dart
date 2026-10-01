import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_form.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_list.dart';
import 'package:portal_pilot_app/Modules/Inventario/kardex.dart';
import 'package:portal_pilot_app/Modules/Inventario/bodegas.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/canal_moderno_home.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_stats_card.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_empty_state.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_swipe_tile.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_context_menu.dart';

const _inventarioColor = Color(0xFFF59E0B);
const _inventarioIcon = Icons.inventory_2_rounded;

class InventarioHome extends StatefulWidget {
  const InventarioHome({super.key});

  @override
  State<InventarioHome> createState() => _InventarioHomeState();
}

class _InventarioHomeState extends State<InventarioHome> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _bodegas = [];
  int _totalProductos = 0;
  int _stockBajo = 0;
  int _agotados = 0;
  double _valorInventario = 0.0;
  bool _cargando = true;

  // Cuadro superior derecho cambiante: alterna entre Stock Bajo y Agotados
  // cada 3 segundos cuando ambos existen.
  Timer? _kpiCycleTimer;
  bool _kpiMostrandoAgotados = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    appThemeNotifier.addListener(_onThemeChanged);
    _kpiCycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _stockBajo > 0 && _agotados > 0) {
        setState(() => _kpiMostrandoAgotados = !_kpiMostrandoAgotados);
      }
    });
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _kpiCycleTimer?.cancel();
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (mounted && _productos.isEmpty) setState(() => _cargando = true);

    // 1. Carga local inmediata: la UI se pinta al instante y no se queda
    //    en skeleton mientras la API responde.
    await _cargarLocales();

    // 2. Refresco con la API en segundo plano (actualiza el dashboard cuando
    //    llega, sin bloquear la primera pintada).
    try {
      // Productos y bodegas en paralelo para cargar el dashboard más rápido.
      final results = await Future.wait([_fetchProductos(), _fetchBodegas()]);
      final productos = results[0];
      final bodegas = results[1];

      int stockBajo = 0;
      int agotados = 0;
      double valor = 0.0;

      for (final p in productos) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
        if (stock <= 0) {
          agotados++;
        } else if (minimo > 0 && stock <= minimo) {
          stockBajo++;
        }
        valor += stock * precio;
      }

      if (mounted) {
        setState(() {
          _productos = productos;
          _bodegas = bodegas;
          _totalProductos = productos.length;
          _stockBajo = stockBajo;
          _agotados = agotados;
          _valorInventario = valor;
          _cargando = false;
        });
      }
      // Cache de la ÚLTIMA respuesta real del API: la próxima apertura pinta
      // esto al instante (idéntico a lo que mostrará el refresh) y ya no se
      // ven "datos viejos que se actualizan de la nada".
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('productos_api_cache', jsonEncode(productos));
      } catch (_) {}
    } catch (e) {
      debugPrint('[Inventario] Error cargando datos: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Pinta al instante desde el cache de la última respuesta del API (o de
  /// los registros locales como último recurso, p.ej. primera vez offline).
  Future<void> _cargarLocales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Preferir el cache fresco del API sobre la lista vieja de 'productos'.
      final cacheFuente = prefs.getString('productos_api_cache') ?? prefs.getString('productos');
      final localProductos = JsonGuard
          .safeListOfMaps(cacheFuente, source: 'Inventario/local/productos')
          .cast<Map<String, dynamic>>();

      if (!mounted || localProductos.isEmpty) return;

      int stockBajo = 0;
      int agotados = 0;
      double valor = 0.0;
      for (final p in localProductos) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
        if (stock <= 0) {
          agotados++;
        } else if (minimo > 0 && stock <= minimo) {
          stockBajo++;
        }
        valor += stock * precio;
      }

      setState(() {
        _productos = localProductos;
        _totalProductos = localProductos.length;
        _stockBajo = stockBajo;
        _agotados = agotados;
        _valorInventario = valor;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('[Inventario] Carga local falló: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductos() async {
    List<Map<String, dynamic>> productos = [];
    var respuestaRemotaValida = false;
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/productos');
      if (api.isSuccess(res)) {
        respuestaRemotaValida = true;
        final data = res['productos'] ?? res['data'];
        if (data is List) {
          productos = data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('[Inventario] API load failed, falling back to local: $e');
    }
    // Una respuesta válida vacía significa inventario vacío; no volver a
    // mostrar registros antiguos del dispositivo como si fueran actuales.
    if (!respuestaRemotaValida) {
      final prefs = await SharedPreferences.getInstance();
      final productosJson = prefs.getString('productos') ?? '[]';
      final List<dynamic> localProductos = JsonGuard.safeListOfMaps(productosJson, source: 'Inventario/productos');
      productos = localProductos.cast<Map<String, dynamic>>();
    }
    return productos;
  }

  Future<List<Map<String, dynamic>>> _fetchBodegas() async {
    List<Map<String, dynamic>> bodegas = [];
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/bodegas');
      if (api.isSuccess(res)) {
        final data = res['bodegas'] ?? res['data'];
        if (data is List) {
          bodegas = data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('[Inventario] Bodegas API failed: $e');
    }
    if (bodegas.isEmpty) {
      bodegas = [{'nombre': 'General'}];
    }
    return bodegas;
  }

  Future<void> _abrirProductoForm([Map<String, dynamic>? producto]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoForm(productoExistente: producto),
      ),
    );
    await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MobileUtils.isMobile(context);

    return PPModuleScaffold(
      moduleId: 'inventario',
      screenTitle: 'Inventario',
      moduleIcon: _inventarioIcon,
      moduleColor: _inventarioColor,
      onNew: _abrirProductoForm,
      onRefresh: _cargarDatos,
      loading: _cargando,
      onGlobalSearch: (q) async {
        if (q.trim().isEmpty) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductoList()),
        );
      },
      child: _buildContent(isMobile),
    );
  }

  Widget _buildContent(bool isMobile) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final productosBajo = _productos.where((p) {
      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
      final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
      return stock > 0 && minimo > 0 && stock <= minimo;
    }).toList();

    return ListView(
      padding: MobileUtils.getPagePadding(context),
      children: [
        _buildHeader(palette),
        const SizedBox(height: 18),
        PPStatsGrid(
          cards: [
            PPStatsCard(
              label: 'Productos',
              value: '$_totalProductos',
              icon: Icons.inventory_2_rounded,
              color: _inventarioColor,
            ),
            _buildKpiCambiante(palette),
            PPStatsCard(
              label: 'Bodegas',
              value: '${_bodegas.length}',
              icon: Icons.warehouse_rounded,
              color: palette.infoBlue,
            ),
            PPStatsCard(
              label: 'Valor Inventario',
              value: 'L.${_formatNumber(_valorInventario)}',
              icon: Icons.attach_money_rounded,
              color: palette.successGreen,
            ),
          ],
        ),
        if (productosBajo.isNotEmpty || _agotados > 0) ...[
          const SizedBox(height: 16),
          _buildAlertBanner(palette, productosBajo.length, _agotados),
        ],
        const SizedBox(height: 22),
        _buildSectionTitle(palette, 'ACCIONES RÁPIDAS'),
        const SizedBox(height: 12),
        _buildActions(palette),
        const SizedBox(height: 22),
        _buildSectionTitle(palette, 'ÚLTIMOS PRODUCTOS'),
        const SizedBox(height: 12),
        if (_productos.isEmpty)
          PPEmptyState(
            title: 'No hay productos registrados',
            message: 'Agrega tu primer producto para comenzar a gestionar tu inventario.',
            icon: _inventarioIcon,
            accentColor: _inventarioColor,
            action: FilledButton.icon(
              onPressed: _abrirProductoForm,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Nuevo Producto',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          _buildRecentProducts(palette),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    // Icono de marca PNG centrado sobre el título del dashboard.
    final logoSize = (MediaQuery.sizeOf(context).shortestSide * 0.2).clamp(92.0, 128.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'img/Iconos/Inventario.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Image.asset(
          'img/texto/Inventario.webp',
          width: 190,
          height: MobileUtils.responsiveFontSize(context, 30),
          alignment: Alignment.centerLeft,
          fit: BoxFit.contain,
          color: palette.isDark ? Colors.white : Colors.black,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: 4),
        Text(
          'Productos, kardex y bodegas',
          style: GoogleFonts.dmSans(fontSize: 13, color: palette.textMuted),
        ),
      ],
    );
  }

  /// Cuadro superior derecho CAMBIANTE: si hay productos con stock bajo Y
  /// agotados, alterna entre ambos cada 3 segundos con una transición suave;
  /// si solo existe una de las dos condiciones, muestra esa fija.
  Widget _buildKpiCambiante(ThemePalette palette) {
    final mostrarAgotados =
        _agotados > 0 && (_kpiMostrandoAgotados || _stockBajo == 0);
    final label = mostrarAgotados ? 'Agotados' : 'Stock Bajo';
    final value = mostrarAgotados ? _agotados : _stockBajo;
    final icon = mostrarAgotados
        ? Icons.remove_shopping_cart_rounded
        : Icons.warning_amber_rounded;
    final color = mostrarAgotados ? palette.errorRed : _inventarioColor;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: PPStatsCard(
        key: ValueKey('$label-$value'),
        label: label,
        value: '$value',
        icon: icon,
        color: color,
      ),
    );
  }

  Widget _buildAlertBanner(ThemePalette palette, int count, int agotados) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${count + agotados} producto${count + agotados == 1 ? '' : 's'} requieren atencion',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                ),
                Text(
                  '${agotados > 0 ? '$agotados agotados' : ''}${agotados > 0 && count > 0 ? ' - ' : ''}${count > 0 ? '$count con stock bajo' : ''}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemePalette palette, String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: palette.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActions(ThemePalette palette) {
    return Column(
      children: [
        _buildActionRow(
          Icons.add_circle_outline_rounded,
          'Nuevo Producto',
          'Agregar producto al catálogo',
          _inventarioColor,
          _abrirProductoForm,
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.list_alt_rounded,
          'Ver Catálogo',
          'Lista completa de productos',
          palette.infoBlue,
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductoList()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.swap_horiz_rounded,
          'Kardex',
          'Historial de movimientos de stock',
          palette.successGreen,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KardexScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.warehouse_rounded,
          'Bodegas',
          'Gestionar almacenes',
          palette.brand,
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BodegasScreen()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.account_balance_rounded,
          'Canal Moderno',
          'Multi-sucursal, transferencias y consolidado',
          palette.infoBlue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CanalModernoHome()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return PPSwipeTile(
      accentColor: color,
      onTap: onTap,
      contextMenuItems: () => [
        PPContextMenuItem(
          icon: Icons.open_in_new_rounded,
          label: 'Abrir $title',
          color: palette.textPrimary,
          onTap: onTap,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProducts(ThemePalette palette) {
    final recientes = List<Map<String, dynamic>>.from(_productos)
      ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    return Column(
      children: recientes.take(5).map((p) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
        final bajo = stock <= minimo && minimo > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PPSwipeTile(
            accentColor: bajo ? palette.errorRed : _inventarioColor,
            onTap: () => _verDetalle(p),
            onDelete: () => _eliminarProducto(p),
            onEdit: () => _abrirProductoForm(p),
            contextMenuItems: () => [
              PPContextMenuItem(
                icon: Icons.visibility_rounded,
                label: 'Ver detalle',
                onTap: () => _verDetalle(p),
              ),
              PPContextMenuItem(
                icon: Icons.edit_rounded,
                label: 'Editar',
                color: palette.infoBlue,
                onTap: () => _abrirProductoForm(p),
              ),
              PPContextMenuItem(
                icon: Icons.delete_rounded,
                label: 'Eliminar',
                color: palette.errorRed,
                onTap: () => _eliminarProducto(p),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (bajo ? palette.errorRed : _inventarioColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      bajo ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                      color: bajo ? palette.errorRed : _inventarioColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['nombre'] ?? '',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p['codigo'] ?? 'S/C'} • ${p['categoria'] ?? 'Sin categoría'}',
                          style: GoogleFonts.dmMono(fontSize: 11, color: palette.textDim),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Stock: $stock',
                        style: GoogleFonts.dmMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: bajo ? palette.errorRed : palette.successGreen,
                        ),
                      ),
                      Text(
                        'L.${precio.toStringAsFixed(2)}',
                        style: GoogleFonts.dmMono(fontSize: 11, color: palette.textDim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _verDetalle(Map<String, dynamic> p) {
    PPNotifications.info(
      context,
      '${p['nombre'] ?? 'Producto'} — ${p['codigo'] ?? 'S/C'}',
      title: 'Detalle de producto',
    );
  }

  Future<void> _eliminarProducto(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar producto', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas eliminar "${p['nombre'] ?? ''}"?', style: TextStyle(color: Theme.of(ctx).hintColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';

    // Borra de Drift, de 'productos'/'productos_pos' y encola el borrado en el
    // backend (por id UUID o codigo) para que el producto no reaparezca.
    await LocalDatabaseService.instance.eliminarProductoGlobal(
      empresaId: empresaCodigo,
      producto: p,
    );

    if (mounted) {
      PPNotifications.success(context, 'Producto eliminado correctamente', title: 'Eliminado');
      await _cargarDatos();
    }
  }

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
