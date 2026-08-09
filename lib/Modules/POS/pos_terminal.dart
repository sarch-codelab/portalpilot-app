import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';

class PosTerminal extends StatefulWidget {
  const PosTerminal({super.key});

  @override
  State<PosTerminal> createState() => _PosTerminalState();
}

class _PosTerminalState extends State<PosTerminal> {
  final List<Map<String, dynamic>> _carrito = [];
  List<Map<String, dynamic>> _productos = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String _metodoPago = 'efectivo';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    final prefs = await SharedPreferences.getInstance();
    var locales = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('productos_pos') ?? '[]'));

    // Puente con Inventario: si el terminal no tiene productos propios,
    // toma los del inventario local (clave `productos`) normalizando campos.
    if (locales.isEmpty) {
      final inventarioJson = prefs.getString('productos') ?? '[]';
      final inventario = List<Map<String, dynamic>>.from(jsonDecode(inventarioJson));
      if (inventario.isNotEmpty) {
        locales = inventario.map((p) {
          return Map<String, dynamic>.from(p)
            ..['precio'] = p['precio_venta'] ?? p['precio'] ?? 0.0
            ..['cantidad'] = p['stock_actual'] ?? p['cantidad'] ?? 0;
        }).toList();
        await prefs.setString('productos_pos', jsonEncode(locales));
      }
    }

    setState(() {
      _productos = locales;
      _isLoading = false;
    });

    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isEmpty) return;
      final remotas = await PortalPilotDB.getProductos(empresa);
      if (remotas.isNotEmpty) {
        final mapa = <String, Map<String, dynamic>>{};
        for (final p in locales) {
          mapa[(p['codigo'] ?? p['nombre'] ?? '').toString()] = Map.from(p);
        }
        for (final r in remotas) {
          final row = Map<String, dynamic>.from(r);
          row['precio'] = row['precio_venta'] ?? row['precio'];
          row['cantidad'] = row['stock_actual'] ?? row['cantidad'];
          row['server_id'] = row['id'];
          mapa[(row['codigo'] ?? row['nombre'] ?? '').toString()] = row;
        }
        final fusion = mapa.values.toList();
        await prefs.setString('productos_pos', jsonEncode(fusion));
        if (mounted) setState(() => _productos = fusion);
      }
    } catch (_) {}
  }

  Future<void> _guardarVentas() async {
    final prefs = await SharedPreferences.getInstance();
    final ventasJson = prefs.getString('ventas_pos') ?? '[]';
    final List<dynamic> ventas = jsonDecode(ventasJson);
    ventas.add({
      'fecha': DateTime.now().toIso8601String(),
      'items': _carrito,
      'total': _totalCarrito,
      'metodo_pago': _metodoPago,
      'cantidad_items': _carrito.fold<int>(0, (sum, item) => sum + ((item['cantidad'] as int?) ?? 1)),
    });
    await prefs.setString('ventas_pos', jsonEncode(ventas));
  }

  /// Descuenta stock local de cada producto vendido y persiste la lista.
  Future<void> _descontarStock() async {
    final prefs = await SharedPreferences.getInstance();
    final prodJson = prefs.getString('productos_pos') ?? '[]';
    final List<dynamic> prods = jsonDecode(prodJson);

    for (final item in _carrito) {
      final codigo = (item['codigo'] ?? '').toString();
      final nombre = (item['nombre'] ?? '').toString();
      final cantidad = (item['cantidad'] as int?) ?? 1;
      for (final p in prods) {
        final match = (p['codigo'] ?? '').toString() == codigo || (p['nombre'] ?? '').toString() == nombre;
        if (match) {
          final actual = (p['cantidad'] as num?)?.toInt() ?? 0;
          p['cantidad'] = (actual - cantidad).clamp(0, 1 << 62);
        }
      }
    }

    await prefs.setString('productos_pos', jsonEncode(prods));
    if (mounted) setState(() => _productos = List<Map<String, dynamic>>.from(prods));
  }

  double get _totalCarrito => _carrito.fold<double>(0, (sum, item) {
    final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
    final cantidad = (item['cantidad'] as int?) ?? 1;
    return sum + (precio * cantidad);
  });

  int get _totalUnidades => _carrito.fold<int>(0, (sum, item) => sum + ((item['cantidad'] as int?) ?? 1));

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final existente = _carrito.indexWhere((c) => c['nombre'] == producto['nombre']);
      if (existente >= 0) {
        _carrito[existente]['cantidad'] = ((_carrito[existente]['cantidad'] as int?) ?? 1) + 1;
      } else {
        _carrito.add({
          'nombre': producto['nombre'],
          'precio': producto['precio'],
          'cantidad': 1,
          'codigo': producto['codigo'] ?? '',
        });
      }
    });
    HapticFeedback.lightImpact();
  }

  void _agregarPorCodigo(String codigo) {
    final prod = _productos.where((p) => (p['codigo'] ?? '').toString().toLowerCase() == codigo.toLowerCase()).toList();
    if (prod.isNotEmpty) {
      _agregarAlCarrito(prod.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto no encontrado: $codigo', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _disminuirDelCarrito(int index) {
    setState(() {
      final actual = (_carrito[index]['cantidad'] as int?) ?? 1;
      if (actual > 1) {
        _carrito[index]['cantidad'] = actual - 1;
      } else {
        _carrito.removeAt(index);
      }
    });
  }

  void _eliminarDelCarrito(int index) {
    setState(() => _carrito.removeAt(index));
  }

  void _limpiarCarrito() {
    setState(() => _carrito.clear());
  }

  Future<void> _cobrar() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El carrito está vacío', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    await _descontarStock();
    await _guardarVentas();

    // Sync a Supabase: registra factura de venta y descuenta stock server-side (best-effort).
    final prefs = await SharedPreferences.getInstance();
    final empresa = prefs.getString('company_code') ?? '';
    if (empresa.isNotEmpty) {
      try {
        await PortalPilotDB.registrarVenta(
          venta: {
            'fecha': DateTime.now().toIso8601String(),
            'items': _carrito,
            'total': _totalCarrito,
            'subtotal': _totalCarrito,
            'metodo_pago': _metodoPago,
          },
          empresaCodigo: empresa,
        );
      } catch (_) {}
    }

    HapticFeedback.heavyImpact();

    if (!mounted) return;

    showDialog(
      context: context,
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
            Text('Total: L.${_formatNumber(_totalCarrito)}', style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
            const SizedBox(height: 4),
            Text('Método: ${_metodoPago.toUpperCase()}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
            Text('Items: $_totalUnidades', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _limpiarCarrito();
            },
            child: Text('Nueva Venta', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
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
          if (_carrito.isNotEmpty)
            TextButton.icon(
              onPressed: _limpiarCarrito,
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
              label: Text('Limpiar', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildMobileLayout(),
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
          width: 380,
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
          hintText: 'Buscar producto o escanear código...',
          hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF525252), size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF97316), size: 20),
            onPressed: _mostrarDialogoCodigo,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _mostrarDialogoCodigo() {
    final codigoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Escanear Código', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        content: TextField(
          controller: codigoCtrl,
          autofocus: true,
          style: GoogleFonts.dmSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Código de barras...',
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316))),
          ),
          onSubmitted: (v) {
            _agregarPorCodigo(v.trim());
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
          TextButton(
            onPressed: () {
              _agregarPorCodigo(codigoCtrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: Text('Agregar', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: const Color(0xFFF97316))),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final filtrados = _searchQuery.isEmpty
        ? _productos
        : _productos.where((p) => (p['nombre'] ?? '').toString().toLowerCase().contains(_searchQuery) || (p['codigo'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    if (filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, color: const Color(0xFF262626), size: 60),
            const SizedBox(height: 12),
            Text('Sin productos', style: GoogleFonts.dmSans(fontSize: 16, color: const Color(0xFF525252))),
            const SizedBox(height: 6),
            Text('Agrega productos desde Inventario', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF404040))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
      ),
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final prod = filtrados[index];
        return _buildProductCard(prod);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> prod) {
    return GestureDetector(
      onTap: () => _agregarAlCarrito(prod),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(prod['nombre'] ?? 'Sin nombre', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded, color: Color(0xFFF97316), size: 16),
                ),
              ],
            ),
            const Spacer(),
            Text('L.${_formatNumber((prod['precio'] as num?)?.toDouble() ?? 0.0)}', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFF97316))),
            if ((prod['codigo'] ?? '').toString().isNotEmpty)
              Text('Cód: ${prod['codigo']}', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF525252))),
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _carrito.length,
      itemBuilder: (context, index) {
        final item = _carrito[index];
        final cantidad = (item['cantidad'] as int?) ?? 1;
        final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
        final subtotal = precio * cantidad;

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
                    Text(item['nombre'] ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('L.${_formatNumber(precio)} c/u', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: const Color(0xFF737373))),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQtyButton(Icons.remove_rounded, () => _disminuirDelCarrito(index)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$cantidad', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  _buildQtyButton(Icons.add_rounded, () {
                    setState(() => item['cantidad'] = cantidad + 1);
                  }),
                ],
              ),
              const SizedBox(width: 10),
              Text('L.${_formatNumber(subtotal)}', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFF97316))),
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
          Row(
            children: [
              _buildMetodoChip('efectivo', 'Efectivo', Icons.payments_rounded),
              const SizedBox(width: 8),
              _buildMetodoChip('tarjeta', 'Tarjeta', Icons.credit_card_rounded),
              const SizedBox(width: 8),
              _buildMetodoChip('transferencia', 'Transferencia', Icons.account_balance_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF737373), letterSpacing: 1.5)),
                  Text('L.${_formatNumber(_totalCarrito)}', style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cobrar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('COBRAR', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
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

  String _formatNumber(double n) => n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
