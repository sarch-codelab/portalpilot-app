import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class PreciosCentralizados extends StatefulWidget {
  const PreciosCentralizados({super.key});

  @override
  State<PreciosCentralizados> createState() => _PreciosCentralizadosState();
}

class _PreciosCentralizadosState extends State<PreciosCentralizados> {
  List<Map<String, dynamic>> _productos = [
    {
      'id': '1',
      'nombre': 'Arroz Premium 5kg',
      'precio_base': 40.00,
      'aplicado': true,
    },
    {
      'id': '2',
      'nombre': 'Frijol Negro 1kg',
      'precio_base': 22.00,
      'aplicado': true,
    },
    {
      'id': '3',
      'nombre': 'Azúcar 5kg',
      'precio_base': 29.00,
      'aplicado': false,
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
            color: Color(0xFF6366F1),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Precios Centralizados',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
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
        backgroundColor: const Color(0xFF6366F1),
        icon: Icon(Icons.add_rounded, color: appPalette.cardColor),
        label: Text(
          'Agregar Producto',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: appPalette.textPrimary,
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
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appPalette.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'],
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: appThemeNotifier.isDark
                        ? appPalette.textPrimary
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Precio base: L.${producto['precio_base'].toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: appThemeNotifier.isDark
                        ? appPalette.textMuted
                        : appPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: producto['aplicado'],
            onChanged: (value) {
              setState(() {
                producto['aplicado'] = value;
              });
            },
            activeColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nombreController = TextEditingController();
    final precioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appPalette.cardColor,
        title: Text(
          'Agregar Producto',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
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
                      ? appPalette.textMuted
                      : appPalette.textMuted,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appPalette.borderLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precioController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Precio base',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? appPalette.textMuted
                      : appPalette.textMuted,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appPalette.borderLight,
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
              style: GoogleFonts.dmSans(color: appPalette.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _productos.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'precio_base': double.tryParse(precioController.text) ?? 0.0,
                  'aplicado': true,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(color: appPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
