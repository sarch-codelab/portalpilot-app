import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/image_service.dart';

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
  String? _imagenBase64;
  String? _imagenUrl; // URL real de Supabase Storage
  bool _isUploadingImage = false;

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
    _imagenBase64 = p['imagen_base64'] as String?;
    _imagenUrl = p['imagen_url'] as String? ?? p['imagenUrl'] as String?;
  }

  Future<void> _seleccionarImagen() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null) return;
      
      setState(() => _isUploadingImage = true);
      
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.length > 400 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen muy pesada (máx ~400 KB). Usa una más pequeña.', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      }
      
      // Guardar base64 localmente para visualización
      setState(() => _imagenBase64 = base64Encode(bytes));
      
      // Subir a Supabase Storage para obtener URL real
      final imageUrl = await ImageService.instance.uploadImage(
        base64OrPath: picked.path,
        bucketName: 'productos',
        folder: 'imagenes',
      );
      
      if (imageUrl != null) {
        setState(() => _imagenUrl = imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen subida exitosamente', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Fallback: usar data URL si Supabase Storage falla
        setState(() => _imagenUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen guardada localmente (sin URL pública)', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
      }
      
      setState(() => _isUploadingImage = false);
      
    } on PlatformException catch (e) {
      debugPrint('❌ ImagePicker error: ${e.message}');
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la galería en este dispositivo', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      debugPrint('❌ ImagePicker error: $e');
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _guardarProducto() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El nombre es obligatorio', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
    final localDb = LocalDatabaseService.instance;
    
    // Generar ID si es nuevo producto
    final id = widget.productoExistente != null 
        ? widget.productoExistente!['id'] 
        : DateTime.now().millisecondsSinceEpoch.toString();
    
    final codigo = _codigoController.text.isNotEmpty 
        ? _codigoController.text 
        : 'P${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final producto = {
      'id': id,
      'codigo': codigo,
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
      'imagen_url': _imagenUrl ?? _imagenBase64, // Prioridad a URL de Supabase, fallback a base64
      'imagen_base64': _imagenBase64, // Mantener para compatibilidad local
      'created_at': widget.productoExistente != null ? widget.productoExistente!['created_at'] : DateTime.now().toIso8601String(),
    };

    // Guardar en base de datos local Drift
    await localDb.upsertProductosLocal(
      empresaId: empresaCodigo,
      productos: [producto],
    );

    // También mantener en SharedPreferences para compatibilidad con POS
    final json = prefs.getString('productos') ?? '[]';
    final List<dynamic> productos = jsonDecode(json);

    if (widget.productoExistente != null) {
      final idx = productos.indexWhere((p) => p['id'] == producto['id']);
      if (idx >= 0) productos[idx] = producto;
    } else {
      productos.add(producto);
    }

    await prefs.setString('productos', jsonEncode(productos));
    
    // También guardar en 'productos_pos' para que el Terminal POS los encuentre
    final productosPosJson = prefs.getString('productos_pos') ?? '[]';
    final List<dynamic> productosPos = jsonDecode(productosPosJson);
    
    final productoPos = {
      'id': producto['id'],
      'codigo': producto['codigo'],
      'nombre': producto['nombre'],
      'descripcion': producto['descripcion'],
      'categoria': producto['categoria'],
      'unidad_medida': producto['unidad_medida'],
      'precio_compra': producto['precio_compra'],
      'precio_venta': producto['precio_venta'],
      'stock_actual': producto['stock_actual'],
      'stock_minimo': producto['stock_minimo'],
      'bodega': producto['bodega'],
      'isv_rate': producto['isv_rate'],
      'exento': producto['exento'],
      'imagen_base64': producto['imagen_url'],
      'created_at': producto['created_at'],
    };
    
    if (widget.productoExistente != null) {
      final idx = productosPos.indexWhere((p) => p['id'] == producto['id']);
      if (idx >= 0) productosPos[idx] = productoPos;
    } else {
      productosPos.add(productoPos);
    }
    
    await prefs.setString('productos_pos', jsonEncode(productosPos));

    // La sincronización ya se maneja automáticamente por LocalDatabaseService

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

  Widget _buildImagenPicker() {
    final tieneImagen = _imagenBase64 != null && _imagenBase64!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tieneImagen)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFF0F0F0F),
                child: Image.memory(
                  base64Decode(_imagenBase64!),
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 160,
                    height: 160,
                    color: const Color(0xFF0F0F0F),
                    child: const Icon(Icons.broken_image_rounded, color: Color(0xFF404040), size: 40),
                  ),
                ),
              ),
            ),
          )
        else
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, color: const Color(0xFF404040), size: 36),
                  const SizedBox(height: 6),
                  Text('Sin imagen', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF525252))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 6),
                    Text(tieneImagen ? 'Cambiar imagen' : 'Agregar imagen', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                  ],
                ),
              ),
            ),
            if (tieneImagen) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _imagenBase64 = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 6),
                      Text('Quitar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
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
          _buildImagenPicker(),
          const SizedBox(height: 16),
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
