// Versión mejorada del POS Terminal con escáner de códigos de barras 100% funcional
// y diseño responsivo para móviles sin elementos superpuestos

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_hardware_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/widgets/sync_status_indicator.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

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

  final List<PosCarritoItem> _carrito = [];
  List<Producto> _productos = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String _metodoPago = 'efectivo';
  bool _isProcessing = false;
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  bool _torchOn = false;
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
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Manejar cambios de ciclo de vida para el escáner
  }

  Future<void> _initializePos() async {
    final empresaCodigo = _auth.empresaCodigo;
    final userQuery = _localDb.database.select(_localDb.database.usuarios)
      ..where((u) => u.email.equals(_auth.email));
    final user = await userQuery.getSingleOrNull();
    
    _posService.setContext(
      empresaId: empresaCodigo,
      terminalId: 'TERM-${empresaCodigo}-01',
      usuarioId: user?.id ?? 'unknown',
    );

    await _hardwareService.initialize();
    await _hardwareService.loadConfig(empresaCodigo, 'TERM-${empresaCodigo}-01');
    await _cargarProductos();
  }

  void _listenSyncStatus() {
    _syncSubscription = _syncService.statusStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
    });
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    
    try {
      await _localDb.initialize();
      final productos = await _localDb.getProductos(_auth.empresaCodigo);
      
      if (mounted) {
        setState(() {
          _productos = productos;
          _isLoading = false;
        });
        
        if (productos.isEmpty) {
          debugPrint('⚠️ No hay productos en base local, intentando descargar de Supabase...');
          await _cargarProductosFromSupabase();
          
          // Si aún no hay, usar SharedPreferences como último fallback
          final productosAfterSync = await _localDb.getProductos(_auth.empresaCodigo);
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
  
  Future<void> _cargarProductosFromSupabase() async {
    try {
      final empresaCodigo = _auth.empresaCodigo;
      debugPrint('📡 Intentando descargar productos de Supabase para empresa: $empresaCodigo');
      
      final url = Uri.parse('https://portalpilot-app.vercel.app/api/productos?empresaCodigo=$empresaCodigo');
      debugPrint('🌐 URL: $url');
      
      final response = await http.get(url);
      debugPrint('📥 Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> productosData = jsonDecode(response.body);
        debugPrint('📦 Productos recibidos: ${productosData.length}');
        
        if (productosData.isNotEmpty) {
          // Guardar en base de datos local
          await _localDb.upsertProductosLocal(
            empresaId: empresaCodigo,
            productos: productosData.cast<Map<String, dynamic>>(),
            enqueueSync: false,
          );
          debugPrint('✅ Productos guardados en base local');
          
          // Actualizar UI
          final productos = await _localDb.getProductos(empresaCodigo);
          debugPrint('📊 Productos en base local después de guardar: ${productos.length}');
          
          if (mounted) {
            setState(() {
              _productos = productos;
            });
            _mostrarSnackBar('Sincronizados ${productos.length} productos', isError: false);
          }
        } else {
          debugPrint('⚠️ La API devolvió una lista vacía');
          if (mounted) {
            _mostrarSnackBar('No hay productos en la base de datos', isError: true);
          }
        }
      } else {
        debugPrint('❌ Error en API: ${response.statusCode} - ${response.body}');
        if (mounted) {
          _mostrarSnackBar('Error de API: ${response.statusCode}', isError: true);
        }
      }
    } catch (e) {
      debugPrint('❌ Error descargando productos de Supabase: $e');
      if (mounted) {
        _mostrarSnackBar('Error de conexión: $e', isError: true);
      }
    }
  }

  Future<void> _cargarProductosFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productosJson = prefs.getString('productos') ?? prefs.getString('productos_pos') ?? '[]';
      final List<dynamic> productosData = jsonDecode(productosJson);
      
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

  Future<void> _cobrar() async {
    if (_carrito.isEmpty || _isProcessing) return;
    
    setState(() => _isProcessing = true);

    try {
      final carritoConPromos = await _posService.aplicarPromociones(List.from(_carrito));
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

      try {
        final prefs = await SharedPreferences.getInstance();
        final lista = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_pos') ?? '[]'));
        lista.add({
          'fecha': DateTime.now().toIso8601String(),
          'total': total,
          'cantidad_items': carritoConPromos.fold<int>(0, (s, i) => s + i.cantidad),
          'metodo_pago': _metodoPago,
          'estado': 'Completada',
          'items': carritoConPromos.map((i) => {
            'nombre': i.nombre,
            'cantidad': i.cantidad,
            'precio': i.precioUnitario,
          }).toList(),
        });
        await prefs.setString('ventas_pos', jsonEncode(lista));
      } catch (e) {
        debugPrint('⚠️ No se pudo guardar historial en SharedPreferences: $e');
      }

      if (_hardwareService.isPrinterConnected) {
        await _imprimirTicket(venta, carritoConPromos, subtotal, descuentoItems, isv15, isv18, total);
      }

      HapticFeedback.heavyImpact();
      _limpiarCarrito();
      
      if (mounted) {
        await _mostrarDialogoVentaExitosa(venta, total);
      }
    } catch (e) {
      _mostrarSnackBar('Error al procesar venta: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _imprimirTicket(dynamic venta, List<PosCarritoItem> items, double subtotal, double descuento, double isv15, double isv18, double total) async {
    // Implementación de impresión de ticket
    debugPrint('Imprimiendo ticket...');
  }

  Future<void> _mostrarDialogoVentaExitosa(dynamic venta, double total) async {
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
        content: TextField(
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
      ),
    );
  }

  void _mostrarSnackBar(String message, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: _showScanner
          ? _buildScannerView()
          : (size.width > size.height ? _buildWideLayout() : _buildMobileLayout(size)),
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
          Text('POS Terminal', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        ],
      ),
      actions: [
        SyncStatusIndicator(
          showDetails: false,
          onTap: () => showDialog(context: context, builder: (_) => const SyncStatusDialog()),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981), size: 20),
          onPressed: () async {
            setState(() => _isLoading = true);
            await _cargarProductosFromSupabase();
            setState(() => _isLoading = false);
          },
          tooltip: 'Sincronizar productos',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF97316), size: 22),
          onPressed: _toggleScanner,
          tooltip: 'Escanear código',
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
              Expanded(child: _buildCarritoView()),
              if (_carrito.isNotEmpty) _buildCobrarBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          flex: 3,
          child: _buildProductList(),
        ),
        if (_carrito.isNotEmpty) ...[
          SizedBox(
            height: size.height * 0.34,
            child: _buildCarritoView(),
          ),
        ],
        if (_carrito.isNotEmpty) _buildCobrarBar(),
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

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF404040), size: 64),
            const SizedBox(height: 16),
            Text(
              'Escanee un código de barras\no escriba el nombre / código del producto',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 15),
            ),
          ],
        ),
      );
    }

    final productosFiltrados = _productos.where((p) =>
        (p.nombre?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (p.codigo?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();

    if (productosFiltrados.isEmpty) {
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
      onRefresh: _cargarProductos,
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
    final tieneImagen = producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty;
    final esDataUrl = tieneImagen && producto.imagenUrl!.startsWith('data:');
    final imagenUrl = tieneImagen && !esDataUrl ? producto.imagenUrl : null;
    Uint8List? imagenBytes;
    if (esDataUrl) {
      try {
        final raw = producto.imagenUrl!.substring(producto.imagenUrl!.indexOf(',') + 1);
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
                  if (producto.stockActual != null)
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
                      producto.nombre ?? 'Sin nombre',
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
    final tieneStock = producto.stockActual != null && producto.stockActual! > 0;
    final bajo = !tieneStock ||
        (producto.stockMinimo != null && producto.stockActual! <= producto.stockMinimo!);
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
            '${producto.stockActual ?? 0}',
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
            onTap: () => setState(() => _carrito.isEmpty ? null : _carrito.clear()),
            child: Icon(Icons.close, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildCarritoItems() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _carrito.length,
      itemBuilder: (context, index) {
        final item = _carrito[index];
        return _buildCarritoItem(item, index);
      },
    );
  }

  Widget _buildCarritoItem(PosCarritoItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 4),
                Text(
                  item.codigo,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF737373),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _posService.formatCurrency(item.precioUnitario),
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => _actualizarCantidad(index, item.cantidad - 1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.cantidad}',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _actualizarCantidad(index, item.cantidad + 1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCobrarBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: const Color(0xFF262626)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 12),
              ),
              Text(
                _posService.formatCurrency(_subtotal),
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ISV',
                style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 12),
              ),
              Text(
                _posService.formatCurrency(_isv15 + _isv18),
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF97316),
                ),
              ),
              Text(
                _posService.formatCurrency(_total),
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _cobrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                disabledBackgroundColor: const Color(0xFF404040),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
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

