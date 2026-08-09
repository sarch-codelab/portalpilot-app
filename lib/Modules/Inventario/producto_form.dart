import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProductoForm extends StatefulWidget {
  final Map<String, dynamic>? productoExistente;

  const ProductoForm({super.key, this.productoExistente});

  @override
  State<ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<ProductoForm> {
  final _codigoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _stockActualController = TextEditingController();
  final _stockMinimoController = TextEditingController();

  String _categoria = 'General';
  String _unidadMedida = 'Unidad';
  String _bodega = 'General';
  double _isvRate = 15.0;
  bool _exento = false;

  List<String> _bodegas = ['General'];

  final List<String> _categorias = [
    'General', 'Electrónica', 'Ropa', 'Alimentos', 'Bebidas', 'Farmacia',
    'Herramientas', 'Materiales', 'Papelería', 'Limpieza', 'Otros'
  ];

  final List<String> _unidades = [
    'Unidad', 'Pieza', 'Kilogramo', 'Libra', 'Litro', 'Metro',
    'Caja', 'Paquete', 'Docena', 'Par', 'Juego'
  ];

  @override
  void initState() {
    super.initState();
    _cargarBodegas();
    if (widget.productoExistente != null) _cargarProducto();
  }

  Future<void> _cargarBodegas() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('bodegas') ?? '["General"]';
    setState(() => _bodegas = List<String>.from(jsonDecode(json)));
  }

  void _cargarProducto() {
    final p = widget.productoExistente!;
    _codigoController.text = p['codigo'] ?? '';
    _nombreController.text = p['nombre'] ?? '';
    _descripcionController.text = p['descripcion'] ?? '';
    _precioCompraController.text = (p['precio_compra'] as num?)?.toString() ?? '';
    _precioVentaController.text = (p['precio_venta'] as num?)?.toString() ?? '';
    _stockActualController.text = (p['stock_actual'] as num?)?.toString() ?? '0';
    _stockMinimoController.text = (p['stock_minimo'] as num?)?.toString() ?? '0';
    _categoria = p['categoria'] ?? 'General';
    _unidadMedida = p['unidad_medida'] ?? 'Unidad';
    _bodega = p['bodega'] ?? 'General';
    _isvRate = (p['isv_rate'] as num?)?.toDouble() ?? 15.0;
    _exento = p['exento'] == true;
  }

  Future<void> _guardarProducto() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El nombre es obligatorio', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('productos') ?? '[]';
    final List<dynamic> productos = jsonDecode(json);

    final producto = {
      'id': widget.productoExistente != null ? widget.productoExistente!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      'codigo': _codigoController.text.isNotEmpty ? _codigoController.text : 'P${productos.length + 1}',
      'nombre': _nombreController.text,
      'descripcion': _descripcionController.text,
      'categoria': _categoria,
      'unidad_medida': _unidadMedida,
      'precio_compra': double.tryParse(_precioCompraController.text) ?? 0,
      'precio_venta': double.tryParse(_precioVentaController.text) ?? 0,
      'stock_actual': int.tryParse(_stockActualController.text) ?? 0,
      'stock_minimo': int.tryParse(_stockMinimoController.text) ?? 0,
      'bodega': _bodega,
      'isv_rate': _isvRate,
      'exento': _exento,
      'created_at': widget.productoExistente != null ? widget.productoExistente!['created_at'] : DateTime.now().toIso8601String(),
    };

    if (widget.productoExistente != null) {
      final idx = productos.indexWhere((p) => p['id'] == producto['id']);
      if (idx >= 0) productos[idx] = producto;
    } else {
      productos.add(producto);
    }

    await prefs.setString('productos', jsonEncode(productos));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.productoExistente != null ? 'Producto actualizado' : 'Producto guardado', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
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
          widget.productoExistente != null ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Información Básica'),
          const SizedBox(height: 8),
          _buildField('Código / SKU', _codigoController, hint: 'Se genera automáticamente si está vacío'),
          const SizedBox(height: 12),
          _buildField('Nombre del Producto *', _nombreController),
          const SizedBox(height: 12),
          _buildField('Descripción', _descripcionController),
          const SizedBox(height: 16),
          _buildSection('Clasificación'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDropdown('Categoría', _categoria, _categorias, (v) => setState(() => _categoria = v!))),
              const SizedBox(width: 10),
              Expanded(child: _buildDropdown('Unidad', _unidadMedida, _unidades, (v) => setState(() => _unidadMedida = v!))),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown('Bodega', _bodega, _bodegas, (v) => setState(() => _bodega = v!)),
          const SizedBox(height: 16),
          _buildSection('Precios e ISV'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Precio Compra (L.)', _precioCompraController, keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _buildField('Precio Venta (L.)', _precioVentaController, keyboard: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown('ISV', _isvRate == 15 ? '15%' : _isvRate == 18 ? '18%' : '0%', ['15%', '18%', '0%'], (v) {
                  setState(() {
                    if (v == '18%') {
                      _isvRate = 18;
                    } else if (v == '0%') { _isvRate = 0; _exento = true; }
                    else { _isvRate = 15; _exento = false; }
                  });
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exento de ISV', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: _exento,
                            onChanged: (v) => setState(() {
                              _exento = v;
                              if (v) _isvRate = 0;
                            }),
                            activeThumbColor: const Color(0xFFF59E0B),
                          ),
                          Text(_exento ? 'Sí' : 'No', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection('Stock'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Stock Actual', _stockActualController, keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _buildField('Stock Mínimo', _stockMinimoController, keyboard: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardarProducto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.productoExistente != null ? 'Actualizar Producto' : 'Guardar Producto',
                style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF737373), letterSpacing: 0.8),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String hint = '', TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
