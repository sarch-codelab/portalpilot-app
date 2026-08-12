import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:portal_pilot_app/Modules/Inventario/producto_form.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
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
  final String _filtroCategoria = 'Todas';
  String _filtroStock = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
      
      // Primero intentar cargar desde la base de datos local Drift
      final localDb = LocalDatabaseService.instance;
      final productosDb = await localDb.getProductos(empresaCodigo);
      
      // Convertir al formato esperado
      final productosFromDb = productosDb.map((p) => {
        'id': p.id,
        'codigo': p.codigo,
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
        'imagen_url': p.imagenUrl,
        'created_at': p.createdAt?.toIso8601String(),
      }).toList();
      
      // Si hay productos en SharedPreferences, mezclarlos (para migración)
      final json = prefs.getString('productos') ?? '[]';
      final productosFromPrefs = List<Map<String, dynamic>>.from(jsonDecode(json));
      
      // Usar productos de DB como prioridad, agregar los de prefs que no estén en DB
      final idsEnDb = productosFromDb.map((p) => p['id'] as String).toSet();
      final productosFinales = [...productosFromDb];
      for (final p in productosFromPrefs) {
        if (!idsEnDb.contains(p['id'])) {
          productosFinales.add(p);
        }
      }
      
      setState(() {
        _productos = productosFinales;
        _aplicarFiltros();
      });
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      // Fallback a SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('productos') ?? '[]';
      setState(() {
        _productos = List<Map<String, dynamic>>.from(jsonDecode(json));
        _aplicarFiltros();
      });
    }
  }
  
  Future<void> _sincronizarDesdeSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
      
      debugPrint('📡 Sincronizando productos de Supabase para empresa: $empresaCodigo');
      
      final url = Uri.parse('https://portalpilot-app.vercel.app/api/productos?empresaCodigo=$empresaCodigo');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> productosData = jsonDecode(response.body);
        
        if (productosData.isNotEmpty) {
          debugPrint('✅ Descargados ${productosData.length} productos de Supabase');
          
          // Guardar en base de datos local
          final localDb = LocalDatabaseService.instance;
          await localDb.upsertProductosLocal(
            empresaId: empresaCodigo,
            productos: productosData.cast<Map<String, dynamic>>(),
          );
          
          // También guardar en SharedPreferences
          await prefs.setString('productos', jsonEncode(productosData));
          
          // Recargar productos
          await _cargarProductos();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sincronizados ${productosData.length} productos', style: GoogleFonts.dmSans()),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No hay productos en la base de datos', style: GoogleFonts.dmSans()),
                backgroundColor: const Color(0xFFF59E0B),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Error de API: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de API: ${response.statusCode}', style: GoogleFonts.dmSans()),
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
        final cat = (p['categoria'] ?? '').toString().toLowerCase();
        return nombre.contains(_busqueda.toLowerCase()) ||
            codigo.contains(_busqueda.toLowerCase()) ||
            cat.contains(_busqueda.toLowerCase());
      }).toList();
    }

    if (_filtroCategoria != 'Todas') {
      r = r.where((p) => p['categoria'] == _filtroCategoria).toList();
    }

    if (_filtroStock == 'Bajo') {
      r = r.where((p) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final min = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        return stock <= min && min > 0;
      }).toList();
    } else if (_filtroStock == 'Agotado') {
      r = r.where((p) => ((p['stock_actual'] as num?)?.toInt() ?? 0) == 0).toList();
    }

    setState(() => _filtrados = r);
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('¿Eliminar producto?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text(
          '${producto['nombre'] ?? ''} (${producto['codigo'] ?? 'S/C'}) se eliminará también del catálogo.',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final id = producto['id'];
    final codigo = (producto['codigo'] ?? '').toString();
    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
    
    // Eliminar de SharedPreferences
    final json = prefs.getString('productos') ?? '[]';
    final List<dynamic> productos = jsonDecode(json);
    productos.removeWhere((p) => p['id'] == id);
    await prefs.setString('productos', jsonEncode(productos));
    
    // Eliminar de productos_pos también
    final productosPosJson = prefs.getString('productos_pos') ?? '[]';
    final List<dynamic> productosPos = jsonDecode(productosPosJson);
    productosPos.removeWhere((p) => p['id'] == id);
    await prefs.setString('productos_pos', jsonEncode(productosPos));
    
    // Sincronizar eliminación con Supabase
    await SyncService.instance.enqueueSync(
      tabla: 'productos',
      operacion: SyncOperation.delete,
      datos: {
        'empresa_codigo': empresaCodigo,
        'codigo': codigo,
      },
      empresaId: empresaCodigo,
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CATÁLOGO DE PRODUCTOS',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981), size: 20),
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
              onChanged: (v) { setState(() => _busqueda = v); _aplicarFiltros(); },
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o categoría...',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF404040), size: 20),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', _filtroStock == 'Todos', () { setState(() => _filtroStock = 'Todos'); _aplicarFiltros(); }),
                const SizedBox(width: 8),
                _buildFilterChip('Stock Bajo', _filtroStock == 'Bajo', () { setState(() => _filtroStock = 'Bajo'); _aplicarFiltros(); }),
                const SizedBox(width: 8),
                _buildFilterChip('Agotado', _filtroStock == 'Agotado', () { setState(() => _filtroStock = 'Agotado'); _aplicarFiltros(); }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(
                    child: Text(
                      _busqueda.isNotEmpty ? 'Sin resultados' : 'No hay productos',
                      style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
                      final min = (p['stock_minimo'] as num?)?.toInt() ?? 0;
                      final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                      final bajo = stock <= min && min > 0;
                      final agotado = stock == 0;

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoForm(productoExistente: p)));
                          _cargarProductos();
                        },
                        onLongPress: () => _showOptions(p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: agotado
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                  : bajo
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                      : const Color(0xFF262626),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (agotado
                                          ? const Color(0xFFEF4444)
                                          : bajo
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981))
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  color: agotado
                                      ? const Color(0xFFEF4444)
                                      : bajo
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                  size: 20,
                                ),
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
                                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (agotado) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                            child: Text('AGOTADO', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                                          ),
                                        ] else if (bajo) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                            child: Text('BAJO', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p['codigo'] ?? 'S/C'}  •  ${p['categoria'] ?? ''}  •  ${p['bodega'] ?? 'General'}',
                                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
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
                                      color: agotado ? const Color(0xFFEF4444) : bajo ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'L.${precio.toStringAsFixed(2)}',
                                    style: GoogleFonts.dmMono(fontSize: 12, color: const Color(0xFF737373)),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => _eliminarProducto(p),
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF525252), size: 20),
                                splashColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFF59E0B) : const Color(0xFF262626)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF404040), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(producto['nombre'] ?? '', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 22),
              title: Text('Editar', style: GoogleFonts.dmSans(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoForm(productoExistente: producto)));
                _cargarProductos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 22),
              title: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
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
