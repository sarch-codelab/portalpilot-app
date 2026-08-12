import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_hardware_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/widgets/sync_status_indicator.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';

class PosTerminal extends StatefulWidget {
  const PosTerminal({super.key});

  @override
  State<PosTerminal> createState() => _PosTerminalState();
}

class _PosTerminalState extends State<PosTerminal> with WidgetsBindingObserver {
  final PosService _posService = PosService.instance;
  final PosHardwareService _hardwareService = PosHardwareService.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final SyncService _syncService = SyncService.instance;
  final AuthController _auth = AuthController.instance;

  // Carrito con items tipados
  final List<PosCarritoItem> _carrito = [];
  List<Producto> _productos = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String _metodoPago = 'efectivo';
  bool _isProcessing = false;
  bool _showScanner = false;
  StreamSubscription<SyncStatus>? _syncSubscription;
  SyncStatus _syncStatus = SyncStatus(pendingCount: 0, message: 'Iniciando...');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePos();
    _listenSyncStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Escáner deshabilitado en Windows
  }

  Future<void> _initializePos() async {
    // Configurar contexto POS
    final empresaCodigo = _auth.empresaCodigo;
    final userQuery = _localDb.database.select(_localDb.database.usuarios)
      ..where((u) => u.email.equals(_auth.email));
    final user = await userQuery.getSingleOrNull();
    
    _posService.setContext(
      empresaId: empresaCodigo,
      terminalId: 'TERM-${empresaCodigo}-01',
      usuarioId: user?.id ?? 'unknown',
    );

    // Cargar config hardware
    await _hardwareService.initialize();
    await _hardwareService.loadConfig(empresaCodigo, 'TERM-${empresaCodigo}-01');

    // Cargar productos
    await _cargarProductos();
  }

  void _listenSyncStatus() {
    _syncSubscription = _localDb.syncStatusStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
    });
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    
    try {
      // Inicializar base de datos local si no está inicializada
      await _localDb.initialize();
      
      final productos = await _localDb.getProductos(_auth.empresaCodigo);
      
      if (mounted) {
        setState(() {
          _productos = productos;
          _isLoading = false;
        });
        
        debugPrint('✅ Cargados ${productos.length} productos de base de datos local');
        
        if (productos.isEmpty) {
          // Fallback: intentar cargar desde SharedPreferences
          await _cargarProductosFromSharedPreferences();
        } else {
          // Mostrar primeros productos para debugging
          if (productos.length > 0) {
            debugPrint('Primeros productos: ${productos.take(3).map((p) => p.nombre).toList()}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando productos: $e');
      // Fallback a SharedPreferences en caso de error
      await _cargarProductosFromSharedPreferences();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarProductosFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // El módulo de Inventario guarda en 'productos', no en 'productos_pos'
      final productosJson = prefs.getString('productos') ?? prefs.getString('productos_pos') ?? '[]';
      final List<dynamic> productosData = jsonDecode(productosJson);
      
      // Convertir a formato Producto
      final productosFallback = <Producto>[];
      for (final p in productosData) {
        try {
          productosFallback.add(Producto(
            id: p['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
            empresaId: _auth.empresaCodigo,
            codigo: p['codigo']?.toString(),
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
            imagenUrl: p['imagen_url']?.toString() ?? p['imagenUrl']?.toString(),
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
        
        debugPrint('✅ Cargados ${productosFallback.length} productos de SharedPreferences (fallback)');
        
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

  // ═══════════════════════════════════════════════════════════════
  // CART OPERATIONS
  // ═══════════════════════════════════════════════════════════════

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
  }

  void _agregarPorCodigo(String codigo) {
    final prod = _productos.where((p) => 
      (p.codigo ?? '').toLowerCase() == codigo.toLowerCase() ||
      (p.nombre ?? '').toLowerCase() == codigo.toLowerCase()
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
    setState(() => _carrito.clear());
  }

  // ═══════════════════════════════════════════════════════════════
  // COBRAR / PROCESAR VENTA
  // ═══════════════════════════════════════════════════════════════

  Future<void> _cobrar() async {
    if (_carrito.isEmpty || _isProcessing) return;
    
    setState(() => _isProcessing = true);

    try {
      // Aplicar promociones
      final carritoConPromos = await _posService.aplicarPromociones(List.from(_carrito));

      // Calcular totales
      final subtotal = carritoConPromos.fold<double>(0, (s, i) => s + i.precioUnitario * i.cantidad);
      final descuentoItems = carritoConPromos.fold<double>(0, (s, i) => s + i.descuento);
      double isv15 = 0, isv18 = 0;
      
      for (final item in carritoConPromos) {
        final base = item.precioUnitario * item.cantidad - item.descuento;
        if (item.isvRate >= 18) {
          isv18 += base * 0.18;
        } else {
          isv15 += base * 0.15;
        }
      }
      
      final total = subtotal - descuentoItems + isv15 + isv18;

      // Registrar venta offline-first
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
      );

      if (venta == null) throw Exception('Error creando venta');

      // Imprimir ticket si hay impresora
      if (_hardwareService.isPrinterConnected) {
        await _imprimirTicket(venta, carritoConPromos, subtotal, descuentoItems, isv15, isv18, total);
      }

      // Sonido de confirmación
      HapticFeedback.heavyImpact();

      if (!mounted) return;

      // Mostrar confirmación
      _mostrarConfirmacionVenta(venta, total, carritoConPromos.length);

      // Limpiar carrito
      _limpiarCarrito();

    } catch (e) {
      _mostrarSnackBar('Error procesando venta: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _imprimirTicket(
    PosVenta venta,
    List<PosCarritoItem> items,
    double subtotal,
    double descuento,
    double isv15,
    double isv18,
    double total,
  ) async {
    try {
      // Obtener info empresa
      final empresa = await _localDb.getEmpresaByCodigo(_auth.empresaCodigo);
      final userQuery = _localDb.database.select(_localDb.database.usuarios)
        ..where((u) => u.id.equals(_auth.empresaCodigo));
      final usuario = await userQuery.getSingleOrNull();

      // Logo (opcional)
      Uint8List? logoBytes;
      if (empresa?.logoUrl != null) {
        // TODO: Descargar logo si está en URL
      }

      final ticketItems = items.map((i) => PosTicketItem(
        productoId: i.productoId,
        codigo: i.codigo,
        nombre: i.nombre,
        cantidad: i.cantidad,
        precioUnitario: i.precioUnitario,
        descuento: i.descuento,
        isvRate: i.isvRate,
        promocionAplicada: i.promocionAplicada,
      )).toList();

      // Generar bytes ESC/POS
      final ticketBytes = _hardwareService.generateTicketBytes(
        empresaNombre: empresa?.nombre ?? 'Portal Pilot',
        empresaRtn: empresa?.rtn ?? '',
        empresaDireccion: empresa?.direccion ?? '',
        terminalId: 'TERM-${_auth.empresaCodigo}-01',
        correlativo: venta.correlativo ?? venta.id,
        fecha: venta.createdAt,
        items: ticketItems,
        subtotal: subtotal,
        descuento: descuento,
        isv15: isv15,
        isv18: isv18,
        total: total,
        metodoPago: _metodoPago,
        cajero: usuario?.nombre ?? _auth.nombreCompleto,
        logoBytes: logoBytes,
        abrirCajon: true,
      );

      // TODO: Enviar ticketBytes a la impresora Bluetooth usando bluetooth_print
      // Ejemplo:
      // if (_hardwareService.isPrinterConnected) {
      //   await BluetoothPrint.instance.writeBytes(ticketBytes);
      // }
      debugPrint('📄 Ticket generado (${ticketBytes.length} bytes) - Pendiente envío a impresora Bluetooth');
    } catch (e) {
      debugPrint('Error generando ticket: $e');
    }
  }

  void _mostrarConfirmacionVenta(PosVenta venta, double total, int itemCount) {
    showDialog(
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
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 50),
            ),
            const SizedBox(height: 16),
            Text('¡Venta Realizada!', style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              _posService.formatCurrency(total),
              style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
            ),
            const SizedBox(height: 4),
            Text('Ticket: ${venta.correlativo ?? venta.id}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
            Text('Items: $itemCount', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
            Text('Método: ${_metodoPago.toUpperCase()}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('NUEVA VENTA', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SCANNER
  // ═══════════════════════════════════════════════════════════════

  void _toggleScanner() async {
    // En Android/iOS usar el escáner de cámara real.
    // En Windows/Web no hay implementación nativa, usar diálogo manual.
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      // Solicitar permiso de cámara
      final status = await Permission.camera.request();
      if (status.isGranted) {
        setState(() => _showScanner = !_showScanner);
      } else {
        _mostrarSnackBar('Permiso de cámara denegado', isError: true);
        // Si no hay permiso, mostrar diálogo manual
        _mostrarDialogoCodigoManual();
      }
    } else {
      _mostrarDialogoCodigoManual();
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
        setState(() => _showScanner = false);
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
            const Icon(Icons.barcode_reader, color: Color(0xFFF97316), size: 22),
            const SizedBox(width: 10),
            Text('Ingresar Código', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'El escáner de cámara no está disponible en Windows.\nIngrese el código de barras manualmente:',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
                prefixIcon: const Icon(Icons.barcode_reader, color: Color(0xFF525252)),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _agregarPorCodigo(v.trim());
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          ElevatedButton(
            onPressed: () {
              if (codigoController.text.trim().isNotEmpty) {
                _agregarPorCodigo(codigoController.text.trim());
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Agregar', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI HELPERS
  // ═══════════════════════════════════════════════════════════════

  void _mostrarSnackBar(String msg, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError ? Icons.error_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? 'ERROR' : 'ÉXITO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isError) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text('Error copiado al portapapeles', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                      backgroundColor: const Color(0xFF6366F1),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Copiar', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      backgroundColor: isError
          ? const Color(0xFFDC2626)
          : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      duration: Duration(seconds: isError ? 6 : 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  double get _subtotal => _carrito.fold<double>(0, (s, i) => s + i.precioUnitario * i.cantidad);
  double get _descuentoItems => _carrito.fold<double>(0, (s, i) => s + i.descuento);
  double get _isv15 => _carrito.fold<double>(0, (s, i) {
    if (i.isvRate < 18) return s + (i.precioUnitario * i.cantidad - i.descuento) * 0.15;
    return s;
  });
  double get _isv18 => _carrito.fold<double>(0, (s, i) {
    if (i.isvRate >= 18) return s + (i.precioUnitario * i.cantidad - i.descuento) * 0.18;
    return s;
  });
  double get _total => _subtotal - _descuentoItems + _isv15 + _isv18;
  int get _totalItems => _carrito.fold<int>(0, (s, i) => s + i.cantidad);

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: _showScanner ? _buildScannerView() : (isWide ? _buildWideLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
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
                    onPressed: () => setState(() => _showScanner = false),
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
            onPressed: () => setState(() => _showScanner = false),
            icon: const Icon(Icons.close_rounded),
            label: Text('Cerrar Escáner', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Text('Terminal POS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        ],
      ),
      actions: [
        // Sync Status
        SyncStatusIndicator(
          showDetails: false,
          onTap: () => showDialog(context: context, builder: (_) => const SyncStatusDialog()),
        ),
        const SizedBox(width: 8),
        // Escáner: en Windows abre diálogo de código manual
        IconButton(
          icon: const Icon(Icons.barcode_reader, color: Color(0xFFF97316), size: 22),
          onPressed: _toggleScanner,
          tooltip: 'Escanear código',
        ),
        if (_carrito.isNotEmpty)
          TextButton.icon(
            onPressed: _limpiarCarrito,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            label: Text('Limpiar', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _carrito.isEmpty ? _buildProductList() : _buildCarritoView(),
        ),
        if (_carrito.isNotEmpty) _buildCobrarBar(),
      ],
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
            (producto.nombre ?? '')[0].toUpperCase(),
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
                      (producto.nombre ?? '')[0].toUpperCase(),
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
                        producto.nombre ?? 'Sin nombre',
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

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildProductList()),
          ],
        )),
        Container(width: 1, color: const Color(0xFF262626)),
        SizedBox(
          width: 400,
          child: Column(
            children: [
              _buildCarritoHeader(),
              Expanded(child: _buildCarritoItems()),
              _buildCobrarBar(),
            ],
          ),
        ),
      ],
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
        decoration: InputDecoration(
          hintText: 'Buscar producto por nombre, código o descripción...',
          hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF525252), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    // Estilo cajero: pantalla limpia al inicio.
    // Solo se muestran productos al buscar por código, nombre o descripción.
    final queryTrim = _searchQuery.trim();
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    // Sin búsqueda: mostrar pantalla de bienvenida (limpia, como cajero listo)
    if (queryTrim.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.barcode_reader, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'Listo para escanear',
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanee un código de barras o escriba\nel nombre / código del producto',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_rounded, color: Color(0xFFF97316), size: 18),
                  const SizedBox(width: 8),
                  Text('Use el campo de búsqueda', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Con búsqueda: filtrar productos
    final filtrados = _productos.where((p) => 
      (p.nombre ?? '').toLowerCase().contains(queryTrim) || 
      (p.codigo ?? '').toLowerCase().contains(queryTrim) ||
      (p.descripcion ?? '').toLowerCase().contains(queryTrim)
    ).toList();

    if (filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: const Color(0xFF262626), size: 60),
            const SizedBox(height: 12),
            Text(
              'No se encontraron productos',
              style: GoogleFonts.dmSans(fontSize: 16, color: const Color(0xFF525252)),
            ),
            const SizedBox(height: 6),
            Text(
              'Intenta con otro código o nombre',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF404040)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.25,
      ),
      itemCount: filtrados.length,
      itemBuilder: (context, index) => _buildProductCard(filtrados[index]),
    );
  }

  Widget _buildProductCard(Producto prod) {
    final stock = prod.stockActual;
    final lowStock = stock <= prod.stockMinimo && stock > 0;
    final noStock = stock <= 0;

    return GestureDetector(
      onTap: noStock ? null : () => _agregarAlCarrito(prod),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: noStock ? const Color(0xFF1A0A0A) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: noStock ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prod.nombre ?? 'Sin nombre',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: noStock ? const Color(0xFF737373) : Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!noStock)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded, color: Color(0xFFF97316), size: 16),
                  ),
              ],
            ),
            const Spacer(),
            if (lowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Stock: $stock', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            if (noStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('AGOTADO', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ),
            Text(
              _posService.formatCurrency(prod.precioVenta),
              style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: noStock ? const Color(0xFF737373) : const Color(0xFFF97316)),
            ),
            if ((prod.codigo ?? '').isNotEmpty)
              Text('Cód: ${prod.codigo}', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF525252))),
          ],
        ),
      ),
    );
  }

  Widget _buildCarritoHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: Color(0xFF080808)),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded, color: Color(0xFFF97316), size: 20),
          const SizedBox(width: 10),
          Text('Carrito', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('${_carrito.length} items', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF97316))),
          ),
        ],
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

  Widget _buildCarritoItems() {
    if (_carrito.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, color: const Color(0xFF262626), size: 50),
            const SizedBox(height: 12),
            Text('Carrito vacío', style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF525252))),
            const SizedBox(height: 4),
            Text('Toque un producto para agregarlo', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF404040))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _carrito.length,
      itemBuilder: (context, index) {
        final item = _carrito[index];
        final cantidad = item.cantidad;
        final precio = item.precioUnitario;
        final subtotal = precio * cantidad - item.descuento;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.nombre, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (item.promocionAplicada != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.promocionAplicada!, style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFFF97316))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${_posService.formatCurrency(precio)} c/u', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: const Color(0xFF737373))),
                    if (item.descuento > 0)
                      Text('Desc: -${_posService.formatCurrency(item.descuento)}', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQtyButton(Icons.remove_rounded, () => _actualizarCantidad(index, cantidad - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$cantidad', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  _buildQtyButton(Icons.add_rounded, () => _actualizarCantidad(index, cantidad + 1)),
                ],
              ),
              const SizedBox(width: 10),
              Text(_posService.formatCurrency(subtotal), style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFF97316))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _eliminarDelCarrito(index),
                child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF262626))),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCobrarBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        border: Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resumen
          if (_descuentoItems > 0 || _isv15 > 0 || _isv18 > 0) ...[
            Row(
              children: [
                Expanded(child: _buildResumenRow('Subtotal', _posService.formatCurrency(_subtotal))),
                if (_descuentoItems > 0) Expanded(child: _buildResumenRow('Descuento', '-${_posService.formatCurrency(_descuentoItems)}', color: const Color(0xFF10B981))),
                if (_isv15 > 0) Expanded(child: _buildResumenRow('ISV 15%', _posService.formatCurrency(_isv15))),
                if (_isv18 > 0) Expanded(child: _buildResumenRow('ISV 18%', _posService.formatCurrency(_isv18))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Método de pago
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetodoChip('efectivo', 'Efectivo', Icons.payments_rounded),
              _buildMetodoChip('tarjeta', 'Tarjeta', Icons.credit_card_rounded),
              _buildMetodoChip('transferencia', 'Transferencia', Icons.account_balance_rounded),
              _buildMetodoChip('mixto', 'Mixto', Icons.account_balance_wallet_rounded),
            ],
          ),
          const SizedBox(height: 12),
          // Total + Botón cobrar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF737373), letterSpacing: 1.5)),
                  Text(_posService.formatCurrency(_total), style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isProcessing ? null : _cobrar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _isProcessing 
                        ? const LinearGradient(colors: [Color(0xFF737373), Color(0xFF525252)])
                        : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isProcessing ? [] : [
                      BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      else ...[
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(_isProcessing ? 'PROCESANDO...' : 'COBRAR', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenRow(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF737373))),
        Text(value, style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? Colors.white)),
      ],
    );
  }

  Widget _buildMetodoChip(String metodo, String label, IconData icon) {
    final isSelected = _metodoPago == metodo;
    return GestureDetector(
      onTap: () => setState(() => _metodoPago = metodo),
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
}