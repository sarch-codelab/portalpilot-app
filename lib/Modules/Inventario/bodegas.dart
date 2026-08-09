import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BodegasScreen extends StatefulWidget {
  const BodegasScreen({super.key});

  @override
  State<BodegasScreen> createState() => _BodegasScreenState();
}

class _BodegasScreenState extends State<BodegasScreen> {
  List<String> _bodegas = ['General'];
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bodegas = List<String>.from(jsonDecode(prefs.getString('bodegas') ?? '["General"]'));
      _productos = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('productos') ?? '[]'));
    });
  }

  int _productosEnBodega(String bodega) {
    return _productos.where((p) => (p['bodega'] ?? 'General') == bodega).length;
  }

  int _stockEnBodega(String bodega) {
    return _productos.where((p) => (p['bodega'] ?? 'General') == bodega)
        .fold(0, (sum, p) => sum + ((p['stock_actual'] as num?)?.toInt() ?? 0));
  }

  void _agregarBodega() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nueva Bodega', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: Colors.white)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Nombre de la bodega',
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && !_bodegas.contains(controller.text)) {
                final prefs = await SharedPreferences.getInstance();
                _bodegas.add(controller.text);
                await prefs.setString('bodegas', jsonEncode(_bodegas));
                _cargarDatos();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            child: Text('Agregar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _eliminarBodega(String nombre) {
    if (nombre == 'General') return;
    final count = _productosEnBodega(nombre);
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hay $count productos en esta bodega. Reasignalos primero.', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar "$nombre"?', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              _bodegas.remove(nombre);
              await prefs.setString('bodegas', jsonEncode(_bodegas));
              _cargarDatos();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
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
        title: Text('BODEGAS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarBodega,
        backgroundColor: const Color(0xFFF59E0B),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bodegas.length,
        itemBuilder: (_, i) {
          final nombre = _bodegas[i];
          final prodCount = _productosEnBodega(nombre);
          final stockTotal = _stockEnBodega(nombre);
          final esGeneral = nombre == 'General';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warehouse_rounded, color: Color(0xFF8B5CF6), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$prodCount productos  •  $stockTotal unidades',
                        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
                      ),
                    ],
                  ),
                ),
                if (!esGeneral)
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
                    onPressed: () => _eliminarBodega(nombre),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
