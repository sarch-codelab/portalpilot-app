import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class Retenciones extends StatefulWidget {
  const Retenciones({super.key});

  @override
  State<Retenciones> createState() => _RetencionesState();
}

class _RetencionesState extends State<Retenciones> {
  List<Map<String, dynamic>> _retenciones = [
    {
      'id': '1',
      'tipo': 'ISR',
      'proveedor': 'Distribuidora Nacional',
      'monto': 2500.00,
      'fecha': '2026-08-01',
    },
    {
      'id': '2',
      'tipo': 'IVA',
      'proveedor': 'Importadora Centro',
      'monto': 1250.00,
      'fecha': '2026-08-02',
    },
    {
      'id': '3',
      'tipo': 'ISR',
      'proveedor': 'Servicios Técnicos',
      'monto': 800.00,
      'fecha': '2026-08-03',
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
            color: Color(0xFFDC2626),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Retenciones de Impuestos',
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
              color: const Color(0xFFDC2626),
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
        itemCount: _retenciones.length,
        itemBuilder: (context, index) {
          final retencion = _retenciones[index];
          return _buildRetencionCard(retencion, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRetencionDialog(),
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nueva Retención',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRetencionCard(
    Map<String, dynamic> retencion,
    ThemePalette palette,
  ) {
    final tipoColor = retencion['tipo'] == 'ISR'
        ? const Color(0xFFDC2626)
        : const Color(0xFF8B5CF6);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                retencion['proveedor'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tipoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  retencion['tipo'],
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tipoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Monto Retenido',
                  'L.${retencion['monto'].toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoRow('Fecha', retencion['fecha'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: appThemeNotifier.isDark
                ? const Color(0xFFA3A3A3)
                : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showAddRetencionDialog() {
    final tipoController = TextEditingController();
    final proveedorController = TextEditingController();
    final montoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Nueva Retención',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tipoController,
              decoration: InputDecoration(
                labelText: 'Tipo (ISR/IVA)',
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
              controller: proveedorController,
              decoration: InputDecoration(
                labelText: 'Proveedor',
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
              controller: montoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto (L.)',
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
                _retenciones.add({
                  'id': DateTime.now().toString(),
                  'tipo': tipoController.text,
                  'proveedor': proveedorController.text,
                  'monto': double.tryParse(montoController.text) ?? 0.0,
                  'fecha': DateTime.now().toString().substring(0, 10),
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
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
