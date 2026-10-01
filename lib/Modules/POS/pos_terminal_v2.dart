// Versión mejorada del POS Terminal con escáner de códigos de barras 100% funcional
// y diseño responsivo para móviles sin elementos superpuestos

import 'dart:async';
import 'dart:convert';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_hardware_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/nfc_card_service.dart';
import 'package:portal_pilot_app/Shared/widgets/sync_status_indicator.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/utils/fiscal_compliance.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';

class PosTerminalV2 extends StatefulWidget {
  const PosTerminalV2({super.key});

  @override
  State<PosTerminalV2> createState() => _PosTerminalV2State();
}

class _PosTerminalV2State extends State<PosTerminalV2> with WidgetsBindingObserver {
  final PosService _posService = PosService.instance;
  final PosHardwareService _hardwareService = PosHardwareService.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final SyncService _syncService = SyncService.instance;
  final AuthController _auth = AuthController.instance;
  final AIManager _aiService = AIManager.instance;

  final List<PosCarritoItem> _carrito = [];
  List<Producto> _productos = [];
  final List<({Producto producto, String motivo})> _sugerenciasUpsell = [];
  bool _sugerenciasCargando = false;
  Timer? _upsellDebounce;
  OverlayEntry? _toastPos;
  bool _toastPosSticky = false;
  TarjetaDetectada? _tarjetaDetectada;
  bool _leyendoTarjeta = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String _metodoPago = 'efectivo';
  bool _isProcessing = false;
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  bool _torchOn = false;
  StreamSubscription<SyncStatus>? _syncSubscription;

  // ── Lector de códigos de barras USB/Bluetooth (keyboard wedge) ──
  // Mientras el foco NO esté en un campo de texto, una ráfaga de caracteres
  // que termina en Enter (típico de un lector conectado) se interpreta como
  // un código escaneado y el producto entra solo al carrito.
  final List<String> _wedgeBuffer = [];
  DateTime _wedgeLastKeyAt = DateTime.now();

  bool _handleWedgeKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final focus = FocusManager.instance.primaryFocus;
    final focusCtx = focus?.context;
    if (focusCtx != null && focusCtx.findAncestorStateOfType<EditableTextState>() != null) {
      return false; // el usuario está escribiendo en un campo: no interferir
    }
    final now = DateTime.now();
    if (now.difference(_wedgeLastKeyAt) > const Duration(milliseconds: 150)) {
      _wedgeBuffer.clear();
    }
    _wedgeLastKeyAt = now;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_wedgeBuffer.isNotEmpty) {
        final code = _wedgeBuffer.join().trim();
        _wedgeBuffer.clear();
        if (code.length >= 3) {
          // Fuera del dispatch del evento de teclado: mutar el carrito
          // (setState) dentro del dispatch puede dejar el árbol a medio
          // reconstruir entre build y layout y congelar la pantalla.
          Future<void>.microtask(() {
            if (mounted) _agregarPorCodigo(code);
          });
          return true;
        }
      }
      return false;
    }
    final ch = event.character?.trim() ?? '';
    if (ch.length == 1 && RegExp(r'[0-9A-Za-z\-_.]').hasMatch(ch)) {
      _wedgeBuffer.add(ch);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleWedgeKey);
    _initializePos();
    _listenSyncStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleWedgeKey);
    _searchController.dispose();
    _syncSubscription?.cancel();
    _scannerController?.dispose();
    _upsellDebounce?.cancel();
    _ocultarToastPos();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Manejar cambios de ciclo de vida para el escáner
  }

  Future<void> _initializePos() async {
    final empresaCodigo = _auth.empresaCodigo;

    // 1) Contexto de usuario. Si la base local falla, el POS debe seguir
    //    funcionando (antes un error de drift dejaba la pantalla muerta).
    try {
      final userQuery = _localDb.database.select(_localDb.database.usuarios)
        ..where((u) => u.email.equals(_auth.email));
      // Timeout: si la base local cuelga (isolate de drift muerto), el POS
      // debe arrancar igual y no quedarse en la pantalla congelada.
      final user = await userQuery.getSingleOrNull().timeout(const Duration(seconds: 4));
      _posService.setContext(
        empresaId: empresaCodigo,
        terminalId: 'TERM-$empresaCodigo-01',
        usuarioId: user?.id ?? 'unknown',
      );
    } catch (e) {
      debugPrint('[POS] Sin usuario local, se continúa: $e');
      _posService.setContext(
        empresaId: empresaCodigo,
        terminalId: 'TERM-$empresaCodigo-01',
        usuarioId: 'unknown',
      );
    }

    // 2) Hardware (impresora, cajón, NFC). Nunca debe bloquear la pantalla.
    try {
      await _hardwareService.initialize().timeout(const Duration(seconds: 4));
      await _hardwareService.loadConfig(empresaCodigo, 'TERM-$empresaCodigo-01').timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[POS] Hardware no disponible: $e');
    }

    // 3) Catálogo. Cualquier error cae al fallback de SharedPreferences.
    try {
      await _cargarProductos();
    } catch (e) {
      debugPrint('[POS] Error cargando catálogo: $e');
      await _cargarProductosFromSharedPreferences();
      if (mounted) setState(() => _isLoading = false);
    }

    // 4) Configuración fiscal: la tasa ISV del POS sale de la config real
    //    (Configuración → Fiscal). Con el default (15%) nada cambia.
    try {
      await FiscalCompliance().loadConfig();
    } catch (_) {}

    // Catálogo en vivo: no hay botón de sincronizar porque la pestaña ya
    // está conectada a la base de datos; al entrar se pide la lista fresca
    // al backend en segundo plano (pull-to-refresh también disponible).
    unawaited(_cargarProductosFromSupabase(silencioso: true));
  }

  void _listenSyncStatus() {
    _syncSubscription = _syncService.statusStream.listen((_) {});
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    
    try {
      await _localDb.initialize().timeout(const Duration(seconds: 4));
      final productos = await _localDb
          .getProductos(_auth.empresaCodigo)
          .timeout(const Duration(seconds: 4));
      
      if (mounted) {
        setState(() {
          _productos = productos;
          _isLoading = false;
        });
        
        if (productos.isEmpty) {
          debugPrint('⚠️ No hay productos en base local, intentando descargar de Supabase...');
          await _cargarProductosFromSupabase();
          
          // Si aún no hay, usar SharedPreferences como último fallback
          final productosAfterSync = await _localDb
              .getProductos(_auth.empresaCodigo)
              .timeout(const Duration(seconds: 4));
          if (productosAfterSync.isEmpty) {
            await _cargarProductosFromSharedPreferences();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando productos: $e');
      await _cargarProductosFromSharedPreferences();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _cargarProductosFromSupabase({bool silencioso = false}) async {
    try {
      final empresaCodigo = _auth.empresaCodigo;
      debugPrint('📡 Intentando descargar productos de Supabase para empresa: $empresaCodigo');
      
      final api = ApiService.instance;
      final result = await api.get('/api/productos');
      
      if (api.isSuccess(result)) {
        final productosData = result['productos'] ?? [];
        debugPrint('📦 Productos recibidos: ${(productosData as List).length}');
        
        if (productosData.isNotEmpty) {
          await _localDb
              .upsertProductosLocal(
                empresaId: empresaCodigo,
                productos: productosData.cast<Map<String, dynamic>>(),
                enqueueSync: false,
              )
              .timeout(const Duration(seconds: 4));
          debugPrint('✅ Productos guardados en base local');
          
          final productos = await _localDb
              .getProductos(empresaCodigo)
              .timeout(const Duration(seconds: 4));
          debugPrint('📊 Productos en base local después de guardar: ${productos.length}');
          
          if (mounted) {
            setState(() {
              _productos = productos;
            });
            if (!silencioso) {
              _mostrarSnackBar('Sincronizados ${productos.length} productos', isError: false);
            }
          }
        } else {
          debugPrint('⚠️ La API devolvió una lista vacía');
          if (mounted && !silencioso) {
            _mostrarSnackBar('No hay productos en la base de datos', isError: true);
          }
        }
      } else {
        final error = api.getError(result);          debugPrint('❌ Error en API: $error');
          if (mounted && !silencioso) {
            _mostrarSnackBar('Error de API: $error', isError: true);
          }
      }
    } catch (e) {
      debugPrint('❌ Error descargando productos de Supabase: $e');
      if (mounted && !silencioso) {
        _mostrarSnackBar('Error de conexión: $e', isError: true);
      }
    }
  }

  Future<void> _cargarProductosFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productosJson = prefs.getString('productos') ?? prefs.getString('productos_pos') ?? '[]';
      final List<dynamic> productosData = JsonGuard.safeListOfMaps(productosJson, source: 'POS/terminal/productos');
      
      final productosFallback = <Producto>[];
      for (final p in productosData) {
        try {
          productosFallback.add(Producto(
            id: p['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
            empresaId: _auth.empresaCodigo,
            codigo: p['codigo']?.toString(),
            barcode: p['barcode']?.toString(),
            marca: p['marca']?.toString(),
            presentacion: p['presentacion']?.toString(),
            nombre: p['nombre']?.toString() ?? '',
            descripcion: p['descripcion']?.toString(),
            categoria: p['categoria']?.toString(),
            unidadMedida: p['unidad_medida']?.toString() ?? p['unidadMedida']?.toString() ?? 'Unidad',
            precioCompra: (p['precio_compra'] as num?)?.toDouble() ?? (p['precioCompra'] as num?)?.toDouble() ?? 0.0,
            precioVenta: (p['precio_venta'] as num?)?.toDouble() ?? (p['precioVenta'] as num?)?.toDouble() ?? 0.0,
            stockMinimo: (p['stock_minimo'] as num?)?.toInt() ?? (p['stockMinimo'] as num?)?.toInt() ?? 0,
            stockActual: (p['stock_actual'] as num?)?.toInt() ?? (p['stockActual'] as num?)?.toInt() ?? 0,
            bodega: p['bodega']?.toString() ?? 'General',
            isvRate: (p['isv_rate'] as num?)?.toDouble() ?? (p['isvRate'] as num?)?.toDouble() ?? 15.0,
            exento: (p['exento'] as bool?) ?? false,
            isPerishable: (p['is_perishable'] as bool?) ?? false,
            imagenUrl: p['imagen_url']?.toString() ??
                p['imagenUrl']?.toString() ??
                p['imagen_base64']?.toString(),
            activo: true,
            synced: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        } catch (e) {
          debugPrint('Error convirtiendo producto $p: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _productos = productosFallback;
          _isLoading = false;
        });
        
        if (productosFallback.isNotEmpty) {
          _mostrarSnackBar('Usando productos locales de respaldo', isError: false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando productos fallback: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _mostrarSnackBar('No hay productos disponibles. Agrega productos desde Inventario.', isError: true);
    }
  }

  void _agregarAlCarrito(Producto producto) {
    setState(() {
      final existente = _carrito.indexWhere((c) => c.productoId == producto.id);
      if (existente >= 0) {
        _carrito[existente] = _carrito[existente].copyWith(
          cantidad: _carrito[existente].cantidad + 1,
        );
      } else {
        _carrito.add(PosCarritoItem(
          productoId: producto.id,
          codigo: producto.codigo ?? '',
          nombre: producto.nombre,
          cantidad: 1,
          precioUnitario: producto.precioVenta,
          isvRate: producto.isvRate,
        ));
      }
    });
    HapticFeedback.lightImpact();
    _solicitarUpsell();
  }

  /// Enter en la buscadora: si el texto es exactamente un código de barras /
  /// código interno (típico de un lector USB con foco en el buscador),
  /// agrega el producto directo al carrito y limpia la búsqueda.
  void _buscarOCapturarCodigo(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return;
    final exactos = _productos
        .where((p) =>
            (p.codigo ?? '').toLowerCase() == q ||
            (p.barcode ?? '').toLowerCase() == q)
        .toList();
    if (exactos.length == 1) {
      _agregarAlCarrito(exactos.first);
      _searchController.clear();
      setState(() => _searchQuery = '');
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _agregarPorCodigo(String codigo) {
    final q = codigo.trim().toLowerCase();
    final prod = _productos.where((p) =>
      (p.codigo ?? '').toLowerCase() == q ||
      (p.barcode ?? '').toLowerCase() == q ||
      p.nombre.toLowerCase() == q
    ).toList();
    
    if (prod.isNotEmpty) {
      _agregarAlCarrito(prod.first);
    } else {
      _mostrarSnackBar('Producto no encontrado: $codigo', isError: true);
    }
  }

  void _actualizarCantidad(int index, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarDelCarrito(index);
      return;
    }
    setState(() {
      _carrito[index] = _carrito[index].copyWith(cantidad: nuevaCantidad);
    });
  }

  void _eliminarDelCarrito(int index) {
    setState(() => _carrito.removeAt(index));
  }

  void _limpiarCarrito() {
    _upsellDebounce?.cancel();
    setState(() {
      _carrito.clear();
      _sugerenciasUpsell.clear();
      _sugerenciasCargando = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // UPSELl IA (sugerencias de productos complementarios)
  // ═══════════════════════════════════════════════════════════════

  void _solicitarUpsell() {
    _upsellDebounce?.cancel();
    if (_carrito.isEmpty) {
      if (mounted) {
        setState(() {
          _sugerenciasUpsell.clear();
          _sugerenciasCargando = false;
        });
      }
      return;
    }
    if (_productos.length < 2) return;
    setState(() => _sugerenciasCargando = true);
    _upsellDebounce = Timer(const Duration(milliseconds: 800), _buscarUpsell);
  }

  Future<void> _buscarUpsell() async {
    try {
      final enCarritoIds = _carrito.map((c) => c.productoId).toSet();
      final candidatos = _productos
          .where((p) => !enCarritoIds.contains(p.id) && p.stockActual > 0)
          .toList();
      if (candidatos.isEmpty) {
        if (mounted) {
          setState(() {
            _sugerenciasUpsell.clear();
            _sugerenciasCargando = false;
          });
        }
        return;
      }

      final carritoPayload = _carrito.map((c) {
        final prod = _productos.where((p) => p.id == c.productoId).firstOrNull;
        return {
          'codigo': c.codigo,
          'nombre': c.nombre,
          'cantidad': c.cantidad,
          'precio': c.precioUnitario,
          'categoria': prod?.categoria,
        };
      }).toList();

      final catalogoPayload = candidatos.map((p) => {
        'codigo': p.codigo ?? '',
        'nombre': p.nombre,
        'categoria': p.categoria,
        'precio': p.precioVenta,
        'stock': p.stockActual,
      }).toList();

      final sugerencias = await _aiService.obtenerSugerenciasUpsell(
        carrito: carritoPayload,
        catalogo: catalogoPayload,
      );

      if (!mounted) return;
      setState(() {
        if (_carrito.isEmpty) {
          _sugerenciasUpsell.clear();
        } else {
          _sugerenciasUpsell
            ..clear()
            ..addAll(sugerencias.map((s) {
              final p = _matchSugerencia(s, candidatos);
              if (p == null) return null;
              return (producto: p, motivo: s.motivo);
            }).whereType<({Producto producto, String motivo})>().take(3));
        }
        _sugerenciasCargando = false;
      });
    } catch (e) {
      debugPrint('[POS] Error al buscar upsell: $e');
      if (mounted) {
        setState(() {
          _sugerenciasUpsell.clear();
          _sugerenciasCargando = false;
        });
      }
    }
  }

  Producto? _matchSugerencia(UpsellSugerencia s, List<Producto> candidatos) {
    for (final p in candidatos) {
      if ((p.codigo ?? '').isNotEmpty && (p.codigo ?? '') == s.codigo) return p;
    }
    final nombreNorm = s.nombre.trim().toLowerCase();
    if (nombreNorm.isNotEmpty) {
      for (final p in candidatos) {
        if (p.nombre.trim().toLowerCase() == nombreNorm) return p;
      }
    }
    return null;
  }

  Future<void> _cobrar({String? notasExtra, double? vuelto}) async {
    if (_carrito.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final carritoConPromos = await _posService.aplicarPromociones(List.from(_carrito));
      final subtotal = carritoConPromos.fold<double>(0, (s, i) => s + i.precioUnitario * i.cantidad);
      final descuentoItems = carritoConPromos.fold<double>(0, (s, i) => s + i.descuento);
      double isv15 = 0, isv18 = 0;

      // La tasa estándar sale de la Configuración Fiscal (default 15%); los
      // productos con tasa especial (>=15) conservan su propio porcentaje.
      final tasaEstandar = FiscalCompliance().config.tasaISV / 100;
      for (final item in carritoConPromos) {
        final base = item.precioUnitario * item.cantidad - item.descuento;
        if (item.isvRate >= 17.99) {
          isv18 += base * 0.18;
        } else if (item.isvRate >= 14.99) {
          isv15 += base * (item.isvRate > 0.01 && (item.isvRate - 15).abs() > 0.01
              ? item.isvRate / 100
              : tasaEstandar);
        }
      }
      
      final total = subtotal - descuentoItems + isv15 + isv18;

      String? notasTarjeta;
      if (_metodoPago == 'tarjeta' && _tarjetaDetectada != null) {
        final t = _tarjetaDetectada!;
        final tail4 = t.ultimos4 ?? t.uid.substring(t.uid.length - 4);
        notasTarjeta = 'Pago: tarjeta · ${t.marca} ····$tail4 (chip NFC, sin cobro electrónico)';
      }
      if (notasExtra != null && notasExtra.isNotEmpty) {
        notasTarjeta = notasTarjeta == null ? notasExtra : '$notasTarjeta · $notasExtra';
      }

      final venta = await _posService.registrarVenta(
        items: carritoConPromos.map((i) => PosVentaItemInput(
          productoId: i.productoId,
          codigo: i.codigo,
          nombre: i.nombre,
          cantidad: i.cantidad,
          precioUnitario: i.precioUnitario,
          descuento: i.descuento,
          isvRate: i.isvRate,
          promocionAplicada: i.promocionAplicada,
        )).toList(),
        metodoPago: _metodoPago,
        descuentoGlobal: 0,
        notas: notasTarjeta,
      );

      if (venta == null) throw Exception('Error creando venta');

      Logger().audit(
        'venta',
        'venta',
        venta.id,
        userId: _auth.email,
        module: 'pos',
        changes: {
          'metodo_pago': _metodoPago,
          'total': total.toStringAsFixed(2),
          'items': carritoConPromos.length,
        },
      );

      // La venta viaja a la nube por la cola de sincronización (SyncService
      // → /api/pos/ventas, ruta soportada por el backend desplegado). No se
      // duplica el envío aquí para no registrar la venta dos veces.

      if (_hardwareService.isPrinterConnected) {
        await _imprimirTicket(venta, carritoConPromos, subtotal, descuentoItems, isv15, isv18, total);
      }

      HapticFeedback.heavyImpact();
      _limpiarCarrito();
      
      if (mounted) {
        await _mostrarDialogoVentaExitosa(venta, total, vuelto: vuelto);
      }
    } catch (e) {
      _mostrarSnackBar('Error al procesar venta: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _procesarPagoConBanco(double monto) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoProcesandoBanco(
        monto: _posService.formatCurrency(monto),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 4200));
    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    HapticFeedback.mediumImpact();
  }

  Future<void> _imprimirTicket(dynamic venta, List<PosCarritoItem> items, double subtotal, double descuento, double isv15, double isv18, double total) async {
    // Implementación de impresión de ticket
    debugPrint('Imprimiendo ticket...');
  }

  Future<void> _mostrarDialogoVentaExitosa(dynamic venta, double total, {double? vuelto}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              '¡Venta Exitosa!',
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _posService.formatCurrency(total),
              style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
            ),
            if (vuelto != null && vuelto > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Vuelto a entregar: ${_posService.formatCurrency(vuelto)}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('CONTINUAR', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // COBRO POR MÉTODO DE PAGO: efectivo (recibido → vuelto), mixto,
  // tarjeta sin NFC (referencia manual) y transferencia (banco).
  // ═════════════════════════════════════════════════════════════

  /// Orquesta el cobro según el método seleccionado.
  Future<void> _confirmarCobro() async {
    if (_carrito.isEmpty || _isProcessing) return;
    switch (_metodoPago) {
      case 'efectivo':
        final pago = await _mostrarCobroEfectivo();
        if (pago == null) return;
        await _cobrar(
          notasExtra: 'Efectivo recibido: ${_posService.formatCurrency(pago.recibido)} · Vuelto: ${_posService.formatCurrency(pago.vuelto)}',
          vuelto: pago.vuelto,
        );
      case 'tarjeta':
        String? refManual;
        if (_tarjetaDetectada == null) {
          refManual = await _pedirReferenciaTarjeta();
          if (refManual == null) return; // canceló el cobro
        }
        await _cobrar(
          notasExtra: refManual == null
              ? null
              : (refManual.isEmpty ? 'Pago con tarjeta (sin referencia)' : 'Pago con tarjeta (ref: $refManual)'),
        );
      case 'transferencia':
        await _procesarPagoConBanco(_total);
        await _cobrar(notasExtra: 'Pago por transferencia bancaria');
      case 'mixto':
        final m = await _mostrarCobroMixto();
        if (m == null) return;
        await _cobrar(
          notasExtra: 'Mixto: efectivo ${_posService.formatCurrency(m.efectivo)} + tarjeta/transferencia ${_posService.formatCurrency(m.tarjeta)}',
        );
    }
  }

  /// Pide el monto recibido en efectivo y calcula el vuelto en vivo.
  /// Devuelve (recibido, vuelto) o null si el usuario canceló.
  Future<({double recibido, double vuelto})?> _mostrarCobroEfectivo() async {
    final total = _total;
    final ctrl = TextEditingController(
      text: total == total.roundToDouble() ? total.toStringAsFixed(0) : total.toStringAsFixed(2),
    );
    double recibido = total;
    return showDialog<({double recibido, double vuelto})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final vuelto = recibido - total;
          final haySuficiente = recibido + 0.009 >= total;
          final colorOk = haySuficiente ? const Color(0xFF10B981) : const Color(0xFFDC2626);
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobro en efectivo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              // Scrollable: con fuentes grandes (accesibilidad) o ventanas
              // angostas el contenido del diálogo nunca se desborda.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total a cobrar', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _posService.formatCurrency(total),
                      style: GoogleFonts.syne(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '¿Cuánto recibió?',
                    labelStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
                    prefixText: 'L ',
                    prefixStyle: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316))),
                  ),
                  onChanged: (v) => setS(() => recibido = double.tryParse(v.replaceAll(',', '')) ?? 0),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in const [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0])
                      _botonMontoRapido('L ${m.toStringAsFixed(0)}', onTap: () {
                        ctrl.text = m.toStringAsFixed(0);
                        setS(() => recibido = m);
                      }),
                    _botonMontoRapido('Exacto', onTap: () {
                      ctrl.text = total.toStringAsFixed(2);
                      setS(() => recibido = total);
                    }),
                  ],
                ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorOk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorOk.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      children: [
                        Icon(haySuficiente ? Icons.savings_rounded : Icons.error_outline_rounded, color: colorOk, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            haySuficiente
                                ? 'Vuelto: ${_posService.formatCurrency(vuelto)}'
                                : 'Faltan: ${_posService.formatCurrency(total - recibido)}',
                            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: colorOk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA1A1AA))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: haySuficiente ? () => Navigator.of(ctx).pop((recibido: recibido, vuelto: vuelto)) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          disabledBackgroundColor: const Color(0xFF404040),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'CONFIRMAR COBRO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _botonMontoRapido(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE4E4E7))),
      ),
    );
  }

  /// Cobro mixto: reparte el total entre efectivo y tarjeta/transferencia.
  Future<({double efectivo, double tarjeta})?> _mostrarCobroMixto() async {
    final total = _total;
    final ctrlEfectivo = TextEditingController();
    final ctrlTarjeta = TextEditingController(text: total.toStringAsFixed(2));
    return showDialog<({double efectivo, double tarjeta})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final efectivo = double.tryParse(ctrlEfectivo.text.replaceAll(',', '')) ?? 0;
          final tarjeta = double.tryParse(ctrlTarjeta.text.replaceAll(',', '')) ?? 0;
          final suma = efectivo + tarjeta;
          final ok = suma + 0.009 >= total;
          final colorOk = ok ? const Color(0xFF10B981) : const Color(0xFFDC2626);
          InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
                prefixText: 'L ',
                prefixStyle: GoogleFonts.dmSans(color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF0F0F0F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316))),
              );
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF97316), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobro mixto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a cobrar: ${_posService.formatCurrency(total)}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrlEfectivo,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  style: GoogleFonts.dmSans(color: Colors.white),
                  decoration: deco('Monto en efectivo'),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrlTarjeta,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  style: GoogleFonts.dmSans(color: Colors.white),
                  decoration: deco('Monto con tarjeta/transferencia'),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 14),
                Text(
                  ok ? 'Cubierto: ${_posService.formatCurrency(suma)}' : 'Faltan: ${_posService.formatCurrency(total - suma)}',
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: colorOk),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA1A1AA))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: ok ? () => Navigator.of(ctx).pop((efectivo: efectivo, tarjeta: tarjeta)) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          disabledBackgroundColor: const Color(0xFF404040),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'CONFIRMAR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// En PC (sin NFC) pide una referencia opcional del pago con tarjeta.
  /// Devuelve null si canceló; string (posiblemente vacío) si continúa.
  Future<String?> _pedirReferenciaTarjeta() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.credit_card_rounded, color: Color(0xFF8B5CF6), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pago con tarjeta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este dispositivo no tiene NFC. Si quieres, anota los últimos 4 dígitos o la referencia del voucher.',
              style: GoogleFonts.dmSans(fontSize: 12.5, color: const Color(0xFFA1A1AA)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.dmSans(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ej: 4321 o REF-0092',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                filled: true,
                fillColor: const Color(0xFF0F0F0F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA1A1AA))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'CONFIRMAR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleScanner() async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      // Solicitar permiso de cámara
      final status = await Permission.camera.request();
      if (status.isGranted) {
        _scannerController?.dispose();
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.code93,
            BarcodeFormat.itf,
            BarcodeFormat.dataMatrix,
            BarcodeFormat.qrCode,
          ],
        );
        setState(() {
          _showScanner = !_showScanner;
          _torchOn = false;
        });
      } else {
        _mostrarSnackBar('Permiso de cámara denegado', isError: true);
        // Si no hay permiso, mostrar diálogo manual
        _mostrarDialogoCodigoManual();
      }
    } else {
      // En PC (Windows/Linux) mobile_scanner no expone la cámara: se ofrece
      // entrada manual y el lector USB/Bluetooth funciona en vivo (wedge).
      _mostrarDialogoCodigoManual();
    }
  }

  void _cerrarScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() {
      _showScanner = false;
      _torchOn = false;
    });
  }

  Future<void> _toggleLinterna() async {
    final controller = _scannerController;
    if (controller == null) return;
    setState(() => _torchOn = !_torchOn);
    try {
      await controller.toggleTorch();
    } catch (_) {
      if (mounted) setState(() => _torchOn = !_torchOn);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    debugPrint('📷 BarcodeCapture recibido');
    debugPrint('📷 raw: ${capture.raw}');
    debugPrint('📷 barcodes.length: ${capture.barcodes.length}');
    
    // Intentar obtener el código de barras de múltiples formas
    String? code;
    
    // Método 1: raw value
    if (capture.raw is String && (capture.raw as String).isNotEmpty) {
      code = capture.raw as String;
      debugPrint('📷 Código desde raw: $code');
    }
    
    // Método 2: barcodes list
    if (code == null && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      code = barcode.rawValue;
      debugPrint('📷 Código desde rawValue: $code');
    }
    
    // Método 3: displayValue
    if (code == null && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      code = barcode.displayValue;
      debugPrint('📷 Código desde displayValue: $code');
    }
    
    if (code != null && code.isNotEmpty) {
      debugPrint('✅ Código detectado: $code');
      _agregarPorCodigo(code);
      if (mounted) {
        _cerrarScanner();
        _mostrarSnackBar('Código escaneado: $code', isError: false);
      }
    } else {
      debugPrint('⚠️ No se pudo extraer código del barcode');
    }
  }

  void _mostrarDialogoCodigoManual() {
    final codigoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF97316), size: 22),
            const SizedBox(width: 10),
            Text('Ingresar Código', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: codigoController,
              autofocus: true,
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Ej: 7501234567890',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                filled: true,
                fillColor: const Color(0xFF0F0F0F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316))),
                prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF525252)),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _agregarPorCodigo(v.trim());
                  Navigator.of(ctx).pop();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.usb_rounded, color: Color(0xFF8B5CF6), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Con un lector USB/Bluetooth conectado no necesitas esto: estando en el POS, escanea y el producto entra al carrito automáticamente.',
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _ocultarToastPos() {
    final entry = _toastPos;
    _toastPos = null;
    _toastPosSticky = false;
    try {
      entry?.remove();
    } catch (_) {
      // El overlay ya no existe (pantalla destruida): nada que hacer.
    }
  }

  void _autodescartarToastPos() {
    if (!_toastPosSticky) _ocultarToastPos();
  }

  void _mostrarToastPos({
    required Color color,
    required Widget icono,
    required String titulo,
    String? subtitulo,
    Duration duracion = const Duration(seconds: 3),
  }) {
    _ocultarToastPos();
    _toastPosSticky = duracion == Duration.zero;
    // El toast vive en el overlay raíz. Debe ser NO interactivo (IgnorePointer)
    // y con constraints ACOTADAS (Positioned.fill + Align): una entrada del
    // overlay sin altura definida puede quedar a medio layout y romper el
    // hit-test de todo lo que esté debajo (freeze del POS).
    final entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: -1.2, end: 0),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, t, child) =>
                      Transform.translate(offset: Offset(0, 36 * t), child: child),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      elevation: 16,
                      shadowColor: color.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      color: color,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: icono),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (subtitulo != null)
                                    Text(
                                      subtitulo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    _toastPos = entry;
    if (!_toastPosSticky) {
      Timer(duracion, _autodescartarToastPos);
    }
  }

  void _mostrarSnackBar(String message, {bool isError = false}) {
    // Mismo diseño que producto_form.dart (toast overlay) — reemplaza SnackBar
    final msg = message.length > 180 ? '${message.substring(0, 177)}...' : message;
    _mostrarToastPos(
      color: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      icono: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
        color: Colors.white,
        size: 22,
      ),
      titulo: msg,
      duracion: Duration(seconds: isError ? 5 : 3),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANÁLISIS DE CAJA CON IA
  // ═══════════════════════════════════════════════════════════════

  Future<void> _mostrarAnalisisCaja() async {
    // Contexto local (Reporte Z): solo se incluye si hay transacciones reales;
    // si está en ceros, el backend usará las ventas de la nube (Supabase).
    String contexto = '{}';
    int totalTransaccionesLocal = 0;
    try {
      final reporte = await _posService.getReporteZ();
      final arqueo = await _posService.getArqueoAbierto();
      totalTransaccionesLocal = (reporte['total_transacciones'] as num?)?.toInt() ?? 0;
      contexto = jsonEncode({
        if (totalTransaccionesLocal > 0)
          'reporte_z_local': {
            'periodo': reporte['periodo'],
            'total_ventas': reporte['total_ventas'],
            'total_transacciones': reporte['total_transacciones'],
            'efectivo': reporte['efectivo'],
            'tarjeta': reporte['tarjeta'],
            'transferencia': reporte['transferencia'],
            'promedio_ticket': reporte['promedio_ticket'],
            'top_productos': reporte['top_productos'],
          },
        'caja_abierta': arqueo != null,
        'items_actuales_carrito': _carrito.length,
      });
    } catch (e) {
      debugPrint('[POS] Error generando contexto de caja: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogoCargandoAnalisis(),
    );

    final hoy = DateTime.now();
    final desdeDias = hoy.subtract(const Duration(days: 29));
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final respuesta = await _aiService.posAnalysis(
      'Analiza el estado de la caja del POS del periodo (ultimos 30 dias).\nDatos locales:\n$contexto\n'
      'Incluye: total de ventas y desglose por m\u00e9todo de pago, ticket promedio, top productos, '
      'salud del arqueo (sobrantes/faltantes) y 3 recomendaciones accionables.\n'
      'Usa L. (lempiras) como moneda, formato "L 1,234.56". Nunca uses \u20AC.\n'
      'Si no hay datos de ventas en el periodo, dilo con claridad y no inventes cifras ni ejemplos.',
      dateRange: {'desde': fmt(desdeDias), 'hasta': fmt(hoy)},
      empresaCodigo: _auth.empresaCodigo,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await _mostrarResultadoAnalisis(respuesta);
  }

  Future<void> _mostrarResultadoAnalisis(AIResponse r) async {
    final ancho = math.min(MediaQuery.of(context).size.width * 0.92, 520.0);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'An\u00e1lisis de Caja',
              style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        content: SizedBox(
          width: ancho,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!r.success)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.error ?? 'No se pudo generar el an\u00e1lisis',
                          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: r.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.dmSans(fontSize: 13, height: 1.65, color: const Color(0xFFE4E4E7)),
                        strong: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        em: GoogleFonts.dmSans(fontSize: 13, fontStyle: FontStyle.italic, color: const Color(0xFFE4E4E7)),
                        h1: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.4),
                        h2: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.4),
                        h3: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        listBullet: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFE4E4E7)),
                        blockquote: GoogleFonts.dmSans(fontSize: 13, fontStyle: FontStyle.italic, color: const Color(0xFFA1A1AA)),
                        blockquoteDecoration: BoxDecoration(
                          border: const Border(left: BorderSide(color: Color(0xFF8B5CF6), width: 3)),
                          color: const Color(0xFF27272A).withValues(alpha: 0.5),
                        ),
                        code: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFF97316), backgroundColor: const Color(0xFF27272A)),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        tableHead: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        tableBody: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFE4E4E7)),
                        tableBorder: TableBorder.all(color: const Color(0xFF27272A), width: 1),
                        horizontalRuleDecoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFF27272A))),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Modelo: ${r.modelId}',
                  style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF52525B)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: r.text.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: r.text));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                          content: Text('An\u00e1lisis copiado al portapapeles'),
                          backgroundColor: Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ));
                    }
                  },
            icon: const Icon(Icons.copy_rounded, color: Color(0xFFA78BFA), size: 16),
            label: Text('Copiar', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFA78BFA))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cerrar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Productos visibles según la búsqueda (sin búsqueda: todo el catálogo).
  List<Producto> get _productosFiltrados {
    if (_searchQuery.isEmpty) return _productos;
    return _productos
        .where((p) =>
            p.nombre.toLowerCase().contains(_searchQuery) ||
            (p.codigo?.toLowerCase().contains(_searchQuery) ?? false) ||
            (p.barcode?.toLowerCase().contains(_searchQuery) ?? false))
        .toList();
  }

  double get _subtotal => _carrito.fold<double>(0, (s, i) => s + i.precioUnitario * i.cantidad);
  double get _descuentoItems => _carrito.fold<double>(0, (s, i) => s + i.descuento);
  double get _isv15 => _carrito.fold<double>(0, (s, i) {
    if (i.isvRate >= 14.99 && i.isvRate < 17.99) return s + (i.precioUnitario * i.cantidad - i.descuento) * 0.15;
    return s;
  });
  double get _isv18 => _carrito.fold<double>(0, (s, i) {
    if (i.isvRate >= 17.99) return s + (i.precioUnitario * i.cantidad - i.descuento) * 0.18;
    return s;
  });
  double get _total => _subtotal - _descuentoItems + _isv15 + _isv18;
  int get _totalItems => _carrito.fold<int>(0, (s, i) => s + i.cantidad);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      // Keep the terminal body bounded to the viewport. If an outer route
      // provides loose height constraints, the mobile Column can otherwise
      // receive infinite height and lose hit-test/layout sizes.
      body: SizedBox.expand(
        child: _showScanner
            ? _buildScannerView()
            : (MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? _buildWideLayout()
                : _buildMobileLayout()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF080808),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF97316), size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: LayoutBuilder(
        builder: (context, c) {
          // En ventanas muy angostas el espacio del título se agota: se oculta
          // el ícono decorativo para que el texto nunca desborde.
          final compacto = c.maxWidth < 150;
          return Row(
            children: [
              if (!compacto) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  'POS Terminal',
                  style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        SyncStatusIndicator(
          showDetails: false,
          onTap: () => showDialog(context: context, builder: (_) => const SyncStatusDialog()),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF97316), size: 22),
          onPressed: _toggleScanner,
          tooltip: 'Escanear código',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.auto_graph_rounded, color: Color(0xFF8B5CF6), size: 20),
          onPressed: _mostrarAnalisisCaja,
          tooltip: 'Análisis de caja con IA',
        ),
        if (_carrito.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            onPressed: _limpiarCarrito,
            tooltip: 'Limpiar carrito',
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget? _buildUpsellStrip() {
    if (_sugerenciasCargando) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF292524)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Buscando sugerencias IA...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(color: const Color(0xFFA1A1AA), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_sugerenciasUpsell.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Sugerencias IA',
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFA78BFA),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _sugerenciasUpsell.clear()),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF737373), size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Ocultar sugerencias',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sugerenciasUpsell.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final s = _sugerenciasUpsell[index];
              return _buildUpsellCard(producto: s.producto, motivo: s.motivo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpsellCard({required Producto producto, required String motivo}) {
    final imagenRaw = producto.imagenUrl;
    final esDataUrl = (imagenRaw ?? '').startsWith('data:');
    final esBase64Plano = !esDataUrl &&
        (imagenRaw?.isNotEmpty ?? false) &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(imagenRaw!);
    final esUrl = (imagenRaw ?? '').startsWith('http') && !esDataUrl;
    Widget? imagen;
    if (esDataUrl || esBase64Plano) {
      try {
        final String raw = esDataUrl
            ? imagenRaw!.substring(imagenRaw.indexOf(',') + 1)
            : imagenRaw!;
        imagen = Image.memory(base64Decode(raw), width: 40, height: 40, fit: BoxFit.cover);
      } catch (_) {
        imagen = null;
      }
    } else if (esUrl) {
      imagen = Image.network(imagenRaw!, width: 40, height: 40, fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () => _agregarAlCarrito(producto),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: imagen ??
                    Container(
                      color: const Color(0xFF262626),
                      child: Center(
                        child: Text(
                          producto.nombre[0].toUpperCase(),
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    producto.nombre,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    motivo,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: const Color(0xFFA78BFA),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _posService.formatCurrency(producto.precioVenta),
                    style: GoogleFonts.syne(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF97316),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_rounded, color: Color(0xFF8B5CF6), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildProductList()),
            ],
          ),
        ),
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            border: Border(left: BorderSide(color: Color(0xFF262626))),
          ),
          child: Column(
            children: [
              if (_buildUpsellStrip() != null) _buildUpsellStrip()!,
              Expanded(child: _buildCarritoView()),
              if (_carrito.isNotEmpty && _metodoPago == 'tarjeta')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTarjetaNfcPanel(),
                ),
              if (_carrito.isNotEmpty) _buildCobrarBar(),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout móvil: sugerencias IA + carrito + productos viven en UN solo
  /// CustomScrollView. Antes el carrito tenía altura fija (34% de la
  /// pantalla) y con la barra de cobro causaba "BOTTOM OVERFLOWED BY 68 PX"
  /// al elegir un producto. Ahora solo quedan fijos la buscadora arriba y
  /// la barra de cobro abajo; el resto hace scroll sin límite de altura.
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFF97316),
            onRefresh: () async {
              await _cargarProductosFromSupabase(silencioso: true);
              await _cargarProductos();
            },
            child: CustomScrollView(
              slivers: [
                if (_buildUpsellStrip() != null)
                  SliverToBoxAdapter(child: _buildUpsellStrip()!),
                if (_carrito.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _buildCarritoHeader()),
                  SliverList.builder(
                    itemCount: _carrito.length,
                    itemBuilder: (context, index) => _buildCarritoItem(_carrito[index], index),
                  ),
                  if (_metodoPago == 'tarjeta')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _buildTarjetaNfcPanel(),
                      ),
                    ),
                ],
                SliverToBoxAdapter(child: _buildTituloProductos()),
                _buildSliverProductos(),
              ],
            ),
          ),
        ),
        if (_carrito.isNotEmpty) _buildCobrarBar(),
      ],
    );
  }

  Widget _buildTituloProductos() {
    final n = _productosFiltrados.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Text(
            'Productos',
            style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$n',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF97316)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverProductos() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
        ),
      );
    }
    if (_productos.isEmpty) {
      return const SliverToBoxAdapter(
        child: _ProductoVacio(
          mensaje: 'No hay productos',
          detalle: 'Agrega productos desde Inventario',
        ),
      );
    }
    final filtrados = _productosFiltrados;
    if (filtrados.isEmpty) {
      return const SliverToBoxAdapter(
        child: _ProductoVacio(mensaje: 'No se encontraron productos', icono: Icons.search_off),
      );
    }
    final ancho = MediaQuery.sizeOf(context).width;
    final cols = ancho >= 1200 ? 5 : ancho >= 900 ? 4 : ancho >= 600 ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.all(14),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildProductCard(filtrados[index]),
          childCount: filtrados.length,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        textInputAction: TextInputAction.done,
        onSubmitted: _buscarOCapturarCodigo,
        decoration: InputDecoration(
          hintText: 'Buscar producto por nombre, código...',
          hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF525252), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, color: const Color(0xFF404040), size: 64),
            const SizedBox(height: 16),
            Text(
              'No hay productos',
              style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos desde Inventario',
              style: GoogleFonts.dmSans(color: const Color(0xFF525252), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final productosFiltrados = _productosFiltrados;

    if (productosFiltrados.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: const Color(0xFF404040), size: 48),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _cargarProductosFromSupabase(silencioso: true);
        await _cargarProductos();
      },
      color: const Color(0xFFF97316),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth;
          final cols = ancho >= 1200
              ? 5
              : ancho >= 900
                  ? 4
                  : ancho >= 600
                      ? 3
                      : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: productosFiltrados.length,
            itemBuilder: (context, index) {
              final producto = productosFiltrados[index];
              return _buildProductCard(producto);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Producto producto) {
    final imagenRaw = producto.imagenUrl;
    final esDataUrl = (imagenRaw ?? '').startsWith('data:');
    final esBase64Plano = !esDataUrl &&
        (imagenRaw?.isNotEmpty ?? false) &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(imagenRaw!);
    final esUrl = (imagenRaw ?? '').startsWith('http') && !esDataUrl;
    final imagenUrl = esUrl ? imagenRaw : null;
    Uint8List? imagenBytes;
    if (esDataUrl || esBase64Plano) {
      try {
        final String raw = esDataUrl
            ? imagenRaw!.substring(imagenRaw.indexOf(',') + 1)
            : imagenRaw!;
        imagenBytes = base64Decode(raw);
      } catch (_) {
        imagenBytes = null;
      }
    }

    return GestureDetector(
      onTap: () => _agregarAlCarrito(producto),
      onLongPress: () => _mostrarOpcionesProducto(producto),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262626)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      image: imagenUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imagenUrl),
                              fit: BoxFit.cover,
                            )
                          : imagenBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(imagenBytes),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: imagenUrl == null && imagenBytes == null
                        ? _buildImagePlaceholder(producto)
                        : null,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildStockBadge(producto),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      producto.codigo ?? 'S/C',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFF737373),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _posService.formatCurrency(producto.precioVenta),
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF97316),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _agregarAlCarrito(producto),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF97316),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(Producto producto) {
    final tieneStock = producto.stockActual > 0;
    final bajo = !tieneStock ||
        (producto.stockActual <= producto.stockMinimo);
    final color = tieneStock
        ? (bajo ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_rounded, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            '${producto.stockActual}',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(Producto producto) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFF404040),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            producto.nombre[0].toUpperCase(),
            style: GoogleFonts.syne(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF262626),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesProducto(Producto producto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      producto.nombre[0].toUpperCase(),
                      style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        producto.codigo ?? 'S/C',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildOpcionButton(
                    icon: Icons.add_shopping_cart,
                    label: 'Agregar al carrito',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _agregarAlCarrito(producto);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOpcionButton(
                    icon: Icons.add_circle_outline,
                    label: 'Agregar cantidad',
                    color: const Color(0xFFF97316),
                    onTap: () {
                      Navigator.pop(context);
                      for (int i = 0; i < 3; i++) {
                        _agregarAlCarrito(producto);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarritoView() {
    return Column(
      children: [
        _buildCarritoHeader(),
        Expanded(child: _buildCarritoItems()),
      ],
    );
  }

  Widget _buildCarritoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF262626)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Carrito ($_totalItems items)',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: _carrito.isEmpty ? null : _limpiarCarrito,
            child: const Icon(Icons.close, color: Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildCarritoItems() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      itemCount: _carrito.length,
      itemBuilder: (context, index) {
        final item = _carrito[index];
        return _buildCarritoItem(item, index);
      },
    );
  }

  Widget _buildCarritoItem(PosCarritoItem item, int index) {
    final totalLinea = item.precioUnitario * item.cantidad - item.descuento;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.codigo.isEmpty ? 'S/C' : item.codigo} · ${_posService.formatCurrency(item.precioUnitario)} c/u',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: const Color(0xFF737373),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _posService.formatCurrency(totalLinea),
                  style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _botonPaso(
                  Icons.remove,
                  color: const Color(0xFF262626),
                  onTap: () => _actualizarCantidad(index, item.cantidad - 1),
                ),
                _CantidadEditable(
                  valor: item.cantidad,
                  onCambiada: (n) => _actualizarCantidad(index, n),
                ),
                _botonPaso(
                  Icons.add,
                  color: const Color(0xFFF97316),
                  onTap: () => _actualizarCantidad(index, item.cantidad + 1),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _eliminarDelCarrito(index),
            tooltip: 'Eliminar producto',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _botonPaso(IconData icono, {required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
        child: Icon(icono, color: Colors.white, size: 16),
      ),
    );
  }

  /// Barra de cobro compacta (métodos + total + COBRAR). Igual en móvil y
  /// escritorio; los chips hacen scroll horizontal para no desbordar a 320px.
  Widget _buildCobrarBar() {
    return Container(
      key: const ValueKey('pos-cobrar-bar'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          top: BorderSide(color: Color(0xFF262626)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _buildMetodoChip('efectivo', 'Efectivo', Icons.payments_rounded),
                  const SizedBox(width: 8),
                  _buildMetodoChip('tarjeta', 'Tarjeta', Icons.credit_card_rounded),
                  const SizedBox(width: 8),
                  _buildMetodoChip('transferencia', 'Transferencia', Icons.account_balance_rounded),
                  const SizedBox(width: 8),
                  _buildMetodoChip('mixto', 'Mixto', Icons.account_balance_wallet_rounded),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subtotal ${_posService.formatCurrency(_subtotal - _descuentoItems)} · ISV ${_posService.formatCurrency(_isv15 + _isv18)}',
                        style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // FittedBox: el total NUNCA se corta ni desborda;
                      // se encoge levemente si la ventana es angosta.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total ${_posService.formatCurrency(_total)}',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF97316),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmarCobro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    disabledBackgroundColor: const Color(0xFF404040),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'COBRAR',
                          style: GoogleFonts.syne(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetodoChip(String metodo, String label, IconData icon) {
    final isSelected = _metodoPago == metodo;
    return GestureDetector(
      onTap: () => setState(() {
        _metodoPago = metodo;
        if (metodo != 'tarjeta') _tarjetaDetectada = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF97316).withValues(alpha: 0.15) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFF97316) : const Color(0xFF262626)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFF97316) : const Color(0xFF737373), size: 14),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFFF97316) : const Color(0xFF737373))),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaNfcPanel() {
    final t = _tarjetaDetectada;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t != null
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
            : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t != null ? const Color(0xFF8B5CF6) : const Color(0xFF262626),
        ),
      ),
      child: t != null
          ? Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chip NFC detectado', style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFA78BFA))),
                      Text('${t.marca} ···· ${t.ultimos4Visibles}', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Solo detecci\u00f3n \u2014 no se cobr\u00f3 ning\u00fan monto', style: GoogleFonts.dmSans(fontSize: 10.5, color: const Color(0xFFA1A1AA))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _tarjetaDetectada = null),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFA1A1AA), size: 18),
                ),
              ],
            )
          : Row(
              children: [
                _leyendoTarjeta
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
                      )
                    : const Icon(Icons.nfc_rounded, color: Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _leyendoTarjeta
                        ? 'Acercando la tarjeta al tel\u00e9fono...'
                        : 'Pago por tarjeta: detecta el chip por NFC (sin cobro electr\u00f3nico)',
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFA1A1AA)),
                  ),
                ),
                if (!_leyendoTarjeta)
                  TextButton(
                    onPressed: _leerTarjeta,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
                    child: Text('LEER CHIP', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
    );
  }

  Future<void> _leerTarjeta() async {
    if (_leyendoTarjeta) return;
    final listo = await NfcCardService.instance.nfcListo();
    if (!listo) {
      _mostrarToastPos(
        color: const Color(0xFFDC2626),
        icono: const Icon(Icons.nfc_rounded, color: Colors.white, size: 22),
        titulo: 'NFC no disponible en este dispositivo',
        subtitulo: 'Necesitas un tel\u00e9fono Android con NFC para leer el chip.',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _leyendoTarjeta = true);

    final future = NfcCardService.instance.detectar();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoLeyendoTarjeta(
        onCancel: () {
          NfcCardService.instance.cancelar();
          Navigator.of(ctx).pop();
        },
      ),
    );

    try {
      final tarjeta = await future;
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _procesarPagoConBanco(_total);
      if (!mounted) return;
      setState(() {
        _tarjetaDetectada = tarjeta;
        _leyendoTarjeta = false;
      });
      _mostrarToastPos(
        color: const Color(0xFF059669),
        icono: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
        titulo: 'Chip detectado: ${tarjeta.marca}',
        subtitulo: 'Tarjeta \u00b7\u00b7\u00b7\u00b7${tarjeta.ultimos4Visibles}. No se cobr\u00f3 nada.',
      );
    } on NfcException catch (e) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _leyendoTarjeta = false);
      _mostrarSnackBar(e.mensaje, isError: true);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _leyendoTarjeta = false);
      _mostrarSnackBar('No se pudo leer la tarjeta: $e', isError: true);
    }
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error de cámara: $error',
                    style: GoogleFonts.dmSans(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cerrarScanner,
                    child: Text('Cerrar', style: GoogleFonts.dmSans()),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Apunte al código de barras del producto',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            onPressed: _cerrarScanner,
            icon: const Icon(Icons.close_rounded),
            label: Text('Cerrar Escáner', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 20,
          child: FloatingActionButton.small(
            heroTag: 'linterna',
            backgroundColor: _torchOn
                ? const Color(0xFFF97316)
                : Colors.black.withValues(alpha: 0.6),
            onPressed: _toggleLinterna,
            child: Icon(
              _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de cantidad editable del carrito: se escribe la cantidad y se
/// confirma con Enter (o al tocar fuera). Convive con los botones +/-.
class _CantidadEditable extends StatefulWidget {
  final int valor;
  final ValueChanged<int> onCambiada;

  const _CantidadEditable({required this.valor, required this.onCambiada});

  @override
  State<_CantidadEditable> createState() => _CantidadEditableState();
}

class _CantidadEditableState extends State<_CantidadEditable> {
  late final TextEditingController _ctrl = TextEditingController(text: '${widget.valor}');
  late final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _CantidadEditable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && '${widget.valor}' != _ctrl.text) {
      _ctrl.text = '${widget.valor}';
    }
  }

  void _commit() {
    final n = (int.tryParse(_ctrl.text.trim()) ?? widget.valor).clamp(1, 99999);
    _ctrl.text = '$n';
    if (n != widget.valor) widget.onCambiada(n);
  }

  @override
  Widget build(BuildContext context) {
    // Altura 32: deja aire al InputDecorator (fuente + padding + bordes);
    // con 28 el decorador desbordaba 1px vertical.
    return SizedBox(
      width: 44,
      height: 32,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF0F0F0F),
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFF262626))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFF97316))),
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          if (_focus.hasFocus) {
            _focus.unfocus();
            // El commit toca el carrito (setState del padre). Fuera del
            // dispatch del pointer event para no reconstruir el árbol en
            // medio de un frame.
            Future<void>.microtask(_commit);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}

/// Estado vacío del catálogo de productos del POS.
class _ProductoVacio extends StatelessWidget {
  final String mensaje;
  final String detalle;
  final IconData icono;

  const _ProductoVacio({
    required this.mensaje,
    this.detalle = '',
    this.icono = Icons.inventory_2_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(icono, color: const Color(0xFF404040), size: 56),
          const SizedBox(height: 14),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 15),
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: const Color(0xFF525252), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogoCargandoAnalisis extends StatelessWidget {
  const _DialogoCargandoAnalisis();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Analizando la caja...',
              style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'La IA revisa ventas, pagos y arqueo',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoProcesandoBanco extends StatelessWidget {
  final String monto;
  const _DialogoProcesandoBanco({required this.monto});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 86,
              child: Lottie.asset(
                'assets/animaciones/banco_a_banco.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
              ),
              child: Text(
                'Validando pago $monto con el banco...',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFC4B5FD),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transferencia entre bancos en curso',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA1A1AA)),
            ),
            const SizedBox(height: 4),
            Text(
              'No cierres la pantalla mientras el banco confirma el cobro.',
              style: GoogleFonts.dmSans(fontSize: 10.5, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoLeyendoTarjeta extends StatefulWidget {
  final VoidCallback onCancel;
  const _DialogoLeyendoTarjeta({required this.onCancel});

  @override
  State<_DialogoLeyendoTarjeta> createState() => _DialogoLeyendoTarjetaState();
}

class _DialogoLeyendoTarjetaState extends State<_DialogoLeyendoTarjeta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _ctrl,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Acerca la tarjeta al tel\u00e9fono',
            style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'El lector NFC est\u00e1 escuchando el chip. No se realizar\u00e1 ning\u00fan cobro.',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA1A1AA)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFA1A1AA)),
            child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
