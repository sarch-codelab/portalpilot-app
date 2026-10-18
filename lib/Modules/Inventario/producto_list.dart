import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:http/http.dart' as http;
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_form.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

class ProductoList extends StatefulWidget {
  const ProductoList({super.key});

  @override
  State<ProductoList> createState() => _ProductoListState();
}

class _ProductoListState extends State<ProductoList> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _filtrados = [];
  String _busqueda = '';
  String _filtroCategoria = 'Todas';
  String _filtroStock = 'Todos';
  String _filtroEstado = 'Activos';
  String _orden = 'Nombre';
  final Set<String> _seleccionados = {};
  bool _modoSeleccion = false;

  // Actualización en vivo: un producto registrado desde otro equipo aparece
  // solo en esta lista, sin refresco manual ni skeletons.
  Timer? _liveRefreshTimer;
  bool _refrescoEnCurso = false;

  static const _liveRefreshInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _liveRefreshTimer = Timer.periodic(_liveRefreshInterval, (_) {
      if (mounted && !_refrescoEnCurso) {
        _refrescoEnCurso = true;
        _refrescarDesdeApi().whenComplete(() => _refrescoEnCurso = false);
      }
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';

      // Primero intentar cargar desde la base de datos local Drift
      final localDb = LocalDatabaseService.instance;
      final productosDb = await localDb.getProductos(
        empresaCodigo,
        includeInactive: true,
      );

      // Convertir al formato esperado
      final productosFromDb = productosDb.map(_productoDbAMap).toList();

      // Si hay productos en SharedPreferences, mezclarlos (para migración)
      final json = prefs.getString('productos') ?? '[]';
      final productosFromPrefs = JsonGuard.safeListOfMaps(
        json,
        source: 'Inventario/producto_list',
      );

      // Usar productos de DB como prioridad, agregar los de prefs que no estén en DB
      final identidadesEnDb = productosFromDb
          .map(
            (p) =>
                '${(p['codigo'] ?? '').toString().trim()}::${(p['bodega'] ?? 'General').toString().trim()}',
          )
          .where((c) => !c.startsWith('::'))
          .toSet();
      final productosFinales = [...productosFromDb];
      for (final p in productosFromPrefs) {
        final codigo = (p['codigo'] ?? '').toString();
        final identidad =
            '$codigo::${(p['bodega'] ?? 'General').toString().trim()}';
        if (codigo.isEmpty || !identidadesEnDb.contains(identidad)) {
          productosFinales.add(p);
        }
      }

      // El cache fresco del API tiene prioridad: trae imagen_url y stock real;
      // los productos locales que no estén en el cache se conservan.
      final cacheJson = prefs.getString('productos_api_cache');
      final cache = JsonGuard.safeListOfMaps(
        cacheJson,
        source: 'Inventario/producto_list/cache',
      );
      if (cache.isNotEmpty) {
        String identidad(Map<String, dynamic> p) {
          final c = (p['codigo'] ?? '').toString().trim();
          if (c.isNotEmpty)
            return 'c:$c::${(p['bodega'] ?? 'General').toString().trim()}';
          final b = (p['barcode'] ?? '').toString().trim();
          if (b.isNotEmpty) return 'b:$b';
          return 'id:${p['id']}';
        }

        final porIdentidad = <String, Map<String, dynamic>>{};
        for (final p in productosFinales) {
          porIdentidad[identidad(p)] = p;
        }
        for (final p in cache) {
          porIdentidad[identidad(p)] = p;
        }
        productosFinales
          ..clear()
          ..addAll(porIdentidad.values);
      }

      setState(() {
        _productos = _dedupePorCodigo(productosFinales);
        _aplicarFiltros();
      });
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      // Fallback a SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('productos') ?? '[]';
      setState(() {
        _productos = _dedupePorCodigo(
          JsonGuard.safeListOfMaps(
            json,
            source: 'Inventario/producto_list/fallback',
          ),
        );
        _aplicarFiltros();
      });
    }

    // Refresco en vivo contra el API (imagen_url + stock reales), sin
    // bloquear la primera pintada local.
    unawaited(_refrescarDesdeApi());
  }

  Future<void> _refrescarDesdeApi() async {
    if (_refrescoEnCurso) return;
    _refrescoEnCurso = true;
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/productos');
      if (!api.isSuccess(res)) return;
      final data = res['productos'] ?? res['data'];
      if (data is! List || data.isEmpty) return;
      final remotos = data.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _productos = _dedupePorCodigo(remotos);
        _aplicarFiltros();
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('productos_api_cache', jsonEncode(remotos));
      } catch (_) {}
    } catch (e) {
      debugPrint('[ProductoList] Refresco API falló: $e');
    } finally {
      _refrescoEnCurso = false;
    }
  }

  Map<String, dynamic> _productoDbAMap(Producto p) => {
    'id': p.id,
    'codigo': p.codigo,
    'barcode': p.barcode,
    'marca': p.marca,
    'presentacion': p.presentacion,
    'nombre': p.nombre,
    'descripcion': p.descripcion,
    'categoria': p.categoria,
    'unidad_medida': p.unidadMedida,
    'precio_compra': p.precioCompra,
    'precio_venta': p.precioVenta,
    'stock_actual': p.stockActual,
    'stock_minimo': p.stockMinimo,
    'bodega': p.bodega,
    'isv_rate': p.isvRate,
    'exento': p.exento,
    'is_perishable': p.isPerishable,
    'imagen_url': p.imagenUrl,
    'activo': p.activo,
    'created_at': p.createdAt.toIso8601String(),
    'updated_at': p.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _productoAPosMap(Map<String, dynamic> p) => {
    'id': p['id'],
    'codigo': p['codigo'],
    'barcode': p['barcode'],
    'marca': p['marca'],
    'presentacion': p['presentacion'],
    'nombre': p['nombre'],
    'descripcion': p['descripcion'],
    'categoria': p['categoria'],
    'unidad_medida': p['unidad_medida'],
    'precio_compra': p['precio_compra'],
    'precio_venta': p['precio_venta'],
    'stock_actual': p['stock_actual'],
    'stock_minimo': p['stock_minimo'],
    'bodega': p['bodega'],
    'isv_rate': p['isv_rate'],
    'exento': p['exento'],
    'is_perishable': p['is_perishable'],
    'imagen_base64': p['imagen_url'],
    'created_at': p['created_at'],
  };

  List<Map<String, dynamic>> _dedupePorCodigo(
    List<Map<String, dynamic>> items,
  ) {
    // El mismo SKU puede tener existencias independientes en varias bodegas.
    // El barcode compartido entre esas filas sigue representando el mismo SKU.
    final vistoCodigo = <String>{};
    final vistoBarcode = <String>{};
    final resultado = <Map<String, dynamic>>[];
    for (final p in items) {
      final codigo = (p['codigo'] ?? '').toString().trim();
      final barcode = (p['barcode'] ?? '').toString().trim();
      final bodega = (p['bodega'] ?? 'General').toString().trim();
      final identidadCodigo = '$codigo::$bodega';
      if (codigo.isNotEmpty) {
        if (vistoCodigo.add(identidadCodigo)) {
          if (barcode.isNotEmpty) vistoBarcode.add(barcode);
          resultado.add(p);
        }
        continue;
      }
      if (barcode.isNotEmpty) {
        if (vistoBarcode.add(barcode)) {
          resultado.add(p);
        }
        continue;
      }
      resultado.add(p);
    }
    return resultado;
  }

  Future<void> _sincronizarDesdeSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';

      debugPrint(
        '📡 Sincronizando productos de Supabase para empresa: $empresaCodigo',
      );

      final url = Uri.parse(
        '${PortalPilotDB.apiRoot}/api/productos?empresaCodigo=$empresaCodigo',
      );
      debugPrint('🌐 URL completa: $url');

      final token = AuthController.instance.token;
      final headers = {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
      final response = await http.get(url, headers: headers);
      debugPrint('📥 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = JsonGuard.tryDecode(response.body);
        final List<dynamic> productosData;
        if (decoded is List) {
          productosData = decoded;
        } else if (decoded is Map) {
          final arr = decoded['productos'];
          productosData = arr is List ? arr : [];
        } else {
          productosData = [];
        }
        debugPrint('📦 Productos recibidos: ${productosData.length}');

        if (productosData.isNotEmpty) {
          // Upsert en BD local (dedupe por codigo en el propio método). No se
          // re-encola sync porque estos datos ya vienen del servidor.
          final localDb = LocalDatabaseService.instance;
          await localDb.upsertProductosLocal(
            empresaId: empresaCodigo,
            productos: productosData.cast<Map<String, dynamic>>(),
            enqueueSync: false,
          );
          debugPrint('✅ Productos guardados en base local (sin duplicados)');

          // Reconstruir prefs 'productos' y 'productos_pos' desde la BD local
          final dbProductos = await localDb.getProductos(empresaCodigo);
          final lista = dbProductos.map(_productoDbAMap).toList();
          final dedup = _dedupePorCodigo(lista);
          await prefs.setString('productos', jsonEncode(dedup));
          await prefs.setString(
            'productos_pos',
            jsonEncode(dedup.map(_productoAPosMap).toList()),
          );
          debugPrint(
            '✅ SharedPreferences reconstruidas con ${dedup.length} productos únicos',
          );

          await _cargarProductos();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sincronizados ${dedup.length} productos',
                  style: GoogleFonts.dmSans(),
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } else {
          debugPrint('⚠️ La API devolvió una lista vacía');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay productos en la base de datos',
                  style: GoogleFonts.dmSans(),
                ),
                backgroundColor: const Color(0xFFF59E0B),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Error de API: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error de API: ${response.statusCode}',
                style: GoogleFonts.dmSans(),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e', style: GoogleFonts.dmSans()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> r = List.from(_productos);

    if (_busqueda.isNotEmpty) {
      r = r.where((p) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final codigo = (p['codigo'] ?? '').toString().toLowerCase();
        final barcode = (p['barcode'] ?? '').toString().toLowerCase();
        final cat = (p['categoria'] ?? '').toString().toLowerCase();
        return nombre.contains(_busqueda.toLowerCase()) ||
            codigo.contains(_busqueda.toLowerCase()) ||
            barcode.contains(_busqueda.toLowerCase()) ||
            cat.contains(_busqueda.toLowerCase());
      }).toList();
    }

    if (_filtroCategoria != 'Todas') {
      r = r.where((p) => p['categoria'] == _filtroCategoria).toList();
    }

    if (_filtroEstado == 'Activos') {
      r = r.where((p) => p['activo'] != false).toList();
    } else if (_filtroEstado == 'Inactivos') {
      r = r.where((p) => p['activo'] == false).toList();
    }

    if (_filtroStock == 'Bajo') {
      r = r.where((p) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final min = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        return stock <= min && min > 0;
      }).toList();
    } else if (_filtroStock == 'Agotado') {
      r = r
          .where((p) => ((p['stock_actual'] as num?)?.toInt() ?? 0) == 0)
          .toList();
    }

    r.sort((a, b) {
      switch (_orden) {
        case 'Stock (mayor a menor)':
          return ((b['stock_actual'] as num?)?.toDouble() ?? 0).compareTo(
            (a['stock_actual'] as num?)?.toDouble() ?? 0,
          );
        case 'Precio (menor a mayor)':
          return ((a['precio_venta'] as num?)?.toDouble() ?? 0).compareTo(
            (b['precio_venta'] as num?)?.toDouble() ?? 0,
          );
        case 'Última actualización':
          final aDate = DateTime.tryParse((a['updated_at'] ?? '').toString());
          final bDate = DateTime.tryParse((b['updated_at'] ?? '').toString());
          return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
        default:
          return (a['nombre'] ?? '').toString().toLowerCase().compareTo(
            (b['nombre'] ?? '').toString().toLowerCase(),
          );
      }
    });

    setState(() => _filtrados = r);
  }

  List<String> get _categoriasDisponibles => {
    for (final producto in _productos)
      if ((producto['categoria'] ?? '').toString().trim().isNotEmpty)
        producto['categoria'].toString().trim(),
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Future<void> _abrirFormulario([Map<String, dynamic>? producto]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoForm(productoExistente: producto),
      ),
    );
    if (mounted) await _cargarProductos();
  }

  void _alternarSeleccion(String id) {
    setState(() {
      if (!_seleccionados.add(id)) _seleccionados.remove(id);
    });
  }

  void _seleccionarTodosVisibles() {
    final idsVisibles = _filtrados
        .map((producto) => (producto['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    setState(() {
      if (_seleccionados.containsAll(idsVisibles)) {
        _seleccionados.removeAll(idsVisibles);
      } else {
        _seleccionados.addAll(idsVisibles);
      }
    });
  }

  Future<void> _cambiarEstadoSeleccionados(bool activo) async {
    final prefs = await SharedPreferences.getInstance();
    final empresaId = prefs.getString('empresa_codigo') ?? 'ROOT';
    final selectedProducts = _productos
        .where(
          (producto) => _seleccionados.contains(producto['id']?.toString()),
        )
        .toList();
    await LocalDatabaseService.instance.upsertProductosLocal(
      empresaId: empresaId,
      productos: selectedProducts,
      enqueueSync: false,
    );
    final localProducts = await LocalDatabaseService.instance.getProductos(
      empresaId,
      includeInactive: true,
    );
    final localIds = selectedProducts.map((producto) {
      final codigo = (producto['codigo'] ?? '').toString();
      final bodega = (producto['bodega'] ?? 'General').toString();
      return localProducts
              .where(
                (local) => local.codigo == codigo && local.bodega == bodega,
              )
              .map((local) => local.id)
              .firstOrNull ??
          (producto['id'] ?? '').toString();
    }).toSet();
    await LocalDatabaseService.instance.setProductosActivos(
      empresaId: empresaId,
      ids: localIds,
      activo: activo,
    );
    if (!mounted) return;
    setState(_seleccionados.clear);
    await _cargarProductos();
  }

  Future<void> _eliminarSeleccionados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Eliminar ${_seleccionados.length} productos?',
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        content: Text(
          'Esta acción quitará los productos seleccionados del catálogo.',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ids = Set<String>.from(_seleccionados);
    final productos = _productos
        .where((p) => ids.contains(p['id']?.toString()))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
    for (final producto in productos) {
      await LocalDatabaseService.instance.eliminarProductoGlobal(
        empresaId: empresaCodigo,
        producto: producto,
      );
    }
    if (!mounted) return;
    setState(_seleccionados.clear);
    await _cargarProductos();
  }

  Future<void> _ajustarStock(Map<String, dynamic> producto) async {
    final cantidadCtrl = TextEditingController();
    final referenciaCtrl = TextEditingController();
    var tipo = 'entrada';
    final cantidad =
        await showDialog<({int cantidad, String tipo, String referencia})>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: Text(
                'Ajustar stock',
                style: GoogleFonts.syne(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    producto['nombre']?.toString() ?? '',
                    style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'entrada',
                        label: Text('Entrada'),
                        icon: Icon(Icons.add_rounded),
                      ),
                      ButtonSegment(
                        value: 'salida',
                        label: Text('Salida'),
                        icon: Icon(Icons.remove_rounded),
                      ),
                    ],
                    selected: {tipo},
                    onSelectionChanged: (selected) =>
                        setDialogState(() => tipo = selected.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                  TextField(
                    controller: referenciaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo o referencia (opcional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(cantidadCtrl.text) ?? 0;
                    if (value > 0) {
                      Navigator.pop(ctx, (
                        cantidad: value,
                        tipo: tipo,
                        referencia: referenciaCtrl.text.trim(),
                      ));
                    }
                  },
                  child: const Text('Guardar ajuste'),
                ),
              ],
            ),
          ),
        );
    cantidadCtrl.dispose();
    referenciaCtrl.dispose();
    if (cantidad == null || !mounted) return;

    try {
      final empresaId = AuthController.instance.empresaCodigo;
      await LocalDatabaseService.instance.upsertProductosLocal(
        empresaId: empresaId,
        productos: [producto],
        enqueueSync: false,
      );
      final codigo = (producto['codigo'] ?? '').toString();
      final bodega = (producto['bodega'] ?? 'General').toString();
      final localProducts = await LocalDatabaseService.instance.getProductos(
        empresaId,
        includeInactive: true,
      );
      final localProduct = localProducts.firstWhere(
        (local) => local.codigo == codigo && local.bodega == bodega,
      );
      await LocalDatabaseService.instance.registrarMovimientoInventario(
        empresaCodigo: empresaId,
        productoId: localProduct.id,
        productoCodigo: codigo,
        tipo: cantidad.tipo,
        cantidad: cantidad.cantidad,
        referencia: cantidad.referencia.isEmpty
            ? 'Ajuste desde catálogo'
            : cantidad.referencia,
      );
      await _cargarProductos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          '¿Eliminar producto?',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          '${producto['nombre'] ?? ''} (${producto['codigo'] ?? 'S/C'}) se eliminará también del catálogo.',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';

    // Borra de Drift, de 'productos'/'productos_pos' en SharedPreferences y
    // encola el borrado en el backend (por id UUID o codigo): así el producto
    // no reaparece al volver a cargar desde el servidor.
    await LocalDatabaseService.instance.eliminarProductoGlobal(
      empresaId: empresaCodigo,
      producto: producto,
    );

    _cargarProductos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CATÁLOGO DE PRODUCTOS',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_seleccionados.isNotEmpty) ...[
            IconButton(
              tooltip: 'Activar seleccionados',
              icon: const Icon(
                Icons.visibility_rounded,
                color: Color(0xFF10B981),
              ),
              onPressed: () => _cambiarEstadoSeleccionados(true),
            ),
            IconButton(
              tooltip: 'Desactivar seleccionados',
              icon: const Icon(
                Icons.visibility_off_rounded,
                color: Color(0xFFF59E0B),
              ),
              onPressed: () => _cambiarEstadoSeleccionados(false),
            ),
            IconButton(
              tooltip: 'Eliminar seleccionados',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
              ),
              onPressed: _eliminarSeleccionados,
            ),
          ],
          IconButton(
            tooltip: _modoSeleccion
                ? 'Terminar selección'
                : 'Seleccionar varios',
            icon: Icon(
              _modoSeleccion ? Icons.close_rounded : Icons.checklist_rounded,
              color: const Color(0xFF38BDF8),
            ),
            onPressed: () => setState(() {
              _modoSeleccion = !_modoSeleccion;
              if (!_modoSeleccion) _seleccionados.clear();
            }),
          ),
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add_box_rounded, color: Color(0xFFF59E0B)),
            onPressed: _abrirFormulario,
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
            onPressed: () async {
              await _sincronizarDesdeSupabase();
            },
            tooltip: 'Sincronizar desde Supabase',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                setState(() => _busqueda = v);
                _aplicarFiltros();
              },
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o categoría...',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF404040),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', _filtroStock == 'Todos', () {
                  setState(() => _filtroStock = 'Todos');
                  _aplicarFiltros();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Stock Bajo', _filtroStock == 'Bajo', () {
                  setState(() => _filtroStock = 'Bajo');
                  _aplicarFiltros();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Agotado', _filtroStock == 'Agotado', () {
                  setState(() => _filtroStock = 'Agotado');
                  _aplicarFiltros();
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDropdownFilter(
                  width: 168,
                  value: _filtroCategoria,
                  items: ['Todas', ..._categoriasDisponibles],
                  label: 'Categoría',
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _filtroCategoria = value);
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  width: 132,
                  value: _filtroEstado,
                  items: const ['Activos', 'Inactivos', 'Todos'],
                  label: 'Estado',
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _filtroEstado = value);
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  width: 202,
                  value: _orden,
                  items: const [
                    'Nombre',
                    'Stock (mayor a menor)',
                    'Precio (menor a mayor)',
                    'Última actualización',
                  ],
                  label: 'Ordenar',
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _orden = value);
                    _aplicarFiltros();
                  },
                ),
              ],
            ),
          ),
          if (_modoSeleccion) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${_seleccionados.length} seleccionados',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _seleccionarTodosVisibles,
                    icon: const Icon(Icons.select_all_rounded, size: 17),
                    label: const Text('Visibles'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(
                    child: Text(
                      _busqueda.isNotEmpty
                          ? 'Sin resultados'
                          : 'No hay productos',
                      style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
                      final min = (p['stock_minimo'] as num?)?.toInt() ?? 0;
                      final precio =
                          (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                      final bajo = stock <= min && min > 0;
                      final agotado = stock == 0;

                      final productoId = (p['id'] ?? '').toString();
                      final seleccionado = _seleccionados.contains(productoId);
                      final costo =
                          (p['precio_compra'] as num?)?.toDouble() ?? 0.0;

                      return GestureDetector(
                        onTap: () async {
                          if (_modoSeleccion) {
                            _alternarSeleccion(productoId);
                          } else {
                            await _abrirFormulario(p);
                          }
                        },
                        onLongPress: () => _showOptions(p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: seleccionado
                                  ? const Color(0xFF38BDF8)
                                  : agotado
                                  ? const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.3)
                                  : bajo
                                  ? const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.3)
                                  : const Color(0xFF262626),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_modoSeleccion)
                                Checkbox(
                                  value: seleccionado,
                                  onChanged: (_) =>
                                      _alternarSeleccion(productoId),
                                  activeColor: const Color(0xFF38BDF8),
                                )
                              else
                                _buildProductoImagen(
                                  p,
                                  agotado
                                      ? const Color(0xFFEF4444)
                                      : bajo
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p['nombre'] ?? '',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (agotado) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFEF4444,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'AGOTADO',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ] else if (bajo) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'BAJO',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (p['activo'] == false) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF737373,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'INACTIVO',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFA3A3A3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p['codigo'] ?? 'S/C'}  •  ${p['categoria'] ?? ''}  •  ${p['bodega'] ?? 'General'}',
                                      style: GoogleFonts.dmMono(
                                        fontSize: 11,
                                        color: const Color(0xFF737373),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        minHeight: 4,
                                        value: min > 0
                                            ? (stock / min).clamp(0.0, 1.0)
                                            : (stock > 0 ? 1 : 0),
                                        backgroundColor: const Color(
                                          0xFF262626,
                                        ),
                                        color: agotado
                                            ? const Color(0xFFEF4444)
                                            : bajo
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF10B981),
                                      ),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: agotado
                                          ? const Color(0xFFEF4444)
                                          : bajo
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'L.${precio.toStringAsFixed(2)}',
                                    style: GoogleFonts.dmMono(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Costo L.${costo.toStringAsFixed(2)}',
                                    style: GoogleFonts.dmMono(
                                      fontSize: 10,
                                      color: const Color(0xFF737373),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_modoSeleccion) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Editar producto',
                                  onPressed: () => _abrirFormulario(p),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 34,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Ajustar stock',
                                  onPressed: () => _ajustarStock(p),
                                  icon: const Icon(
                                    Icons.inventory_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 34,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: const Color(0xFF111111),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Agregar producto',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required double width,
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : uniqueItems.first;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0xFF262626)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white),
          hint: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: const Color(0xFF737373),
            ),
          ),
          items: uniqueItems
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildProductoImagen(Map<String, dynamic> producto, Color accent) {
    const double size = 44;
    // Acepta http(s), data:URL y base64 plano (mismo criterio que el POS).
    final url = (producto['imagen_url'] as String? ?? '').trim();
    final base64Raw = (producto['imagen_base64'] as String? ?? url).trim();
    final esDataUrl = url.startsWith('data:');
    final esBase64Plano =
        !esDataUrl &&
        url.isNotEmpty &&
        !url.startsWith('http') &&
        RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(url);
    final esUrl = url.startsWith('http') && !esDataUrl;
    Uint8List? bytes;
    if (esDataUrl || esBase64Plano || (!esUrl && base64Raw.isNotEmpty)) {
      try {
        var b = esDataUrl ? url.substring(url.indexOf(',') + 1) : base64Raw;
        if (b.contains(',')) b = b.split(',').last;
        bytes = base64Decode(b);
      } catch (_) {
        bytes = null;
      }
    }
    final fallback = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.inventory_2_rounded, color: accent, size: 20),
    );
    if (esUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    return fallback;
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFF59E0B) : const Color(0xFF262626),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFFF59E0B) : const Color(0xFF737373),
          ),
        ),
      ),
    );
  }

  void _showOptions(Map<String, dynamic> producto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              producto['nombre'] ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.edit_rounded,
                color: Color(0xFF3B82F6),
                size: 22,
              ),
              title: Text(
                'Editar',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductoForm(productoExistente: producto),
                  ),
                );
                _cargarProductos();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
              title: Text(
                'Eliminar',
                style: GoogleFonts.dmSans(color: const Color(0xFFEF4444)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _eliminarProducto(producto);
              },
            ),
          ],
        ),
      ),
    );
  }
}
