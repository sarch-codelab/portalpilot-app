import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class PreciosPorCanal extends StatefulWidget {
  const PreciosPorCanal({super.key});

  @override
  State<PreciosPorCanal> createState() => _PreciosPorCanalState();
}

class _PreciosPorCanalState extends State<PreciosPorCanal> {
  List<Map<String, dynamic>> _productos = [
    {
      'id': '1',
      'nombre': 'Arroz Premium 5kg',
      'precio_pulperia': 45.00,
      'precio_super': 42.00,
      'precio_membresia': 38.00,
    },
    {
      'id': '2',
      'nombre': 'Frijol Negro 1kg',
      'precio_pulperia': 28.00,
      'precio_super': 25.00,
      'precio_membresia': 22.00,
    },
    {
      'id': '3',
      'nombre': 'Azúcar 5kg',
      'precio_pulperia': 35.00,
      'precio_super': 32.00,
      'precio_membresia': 29.00,
    },
  ];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFEC4899),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Precios por Canal',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFFEC4899),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productos.length,
        itemBuilder: (context, index) {
          final producto = _productos[index];
          return _buildProductCard(producto, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddProductDialog();
        },
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Agregar Producto',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> producto,
    ThemePalette palette,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            producto['nombre'],
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Pulpería',
            producto['precio_pulperia'],
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Supermercado',
            producto['precio_super'],
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Membresía',
            producto['precio_membresia'],
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String canal, double precio, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            canal,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Text(
          'L.$precio.toStringAsFixed(2)',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showAddProductDialog() {
    final nombreController = TextEditingController();
    final pulperiaController = TextEditingController();
    final superController = TextEditingController();
    final membresiaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Agregar Producto',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del producto',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pulperiaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Precio Pulpería',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: superController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Precio Supermercado',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: membresiaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Precio Membresía',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _productos.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'precio_pulperia':
                      double.tryParse(pulperiaController.text) ?? 0.0,
                  'precio_super': double.tryParse(superController.text) ?? 0.0,
                  'precio_membresia':
                      double.tryParse(membresiaController.text) ?? 0.0,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
