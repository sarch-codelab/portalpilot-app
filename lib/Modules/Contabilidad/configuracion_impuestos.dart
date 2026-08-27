import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracionImpuestos extends StatefulWidget {
  const ConfiguracionImpuestos({super.key});

  @override
  State<ConfiguracionImpuestos> createState() => _ConfiguracionImpuestosState();
}

class _ConfiguracionImpuestosState extends State<ConfiguracionImpuestos> {
  static const String _prefsKey = 'impuestos_config';

  static const List<Map<String, dynamic>> _impuestosPredeterminados = [
    {
      'id': 'isv',
      'nombre': 'ISV (IVA)',
      'tasa': 15.0,
      'tipo': 'Ventas',
      'descripcion': 'Impuesto Sobre Ventas',
    },
    {
      'id': 'isr',
      'nombre': 'ISR',
      'tasa': 25.0,
      'tipo': 'Retencion',
      'descripcion': 'Impuesto Sobre Renta',
    },
    {
      'id': 'timbre',
      'nombre': 'Timbre Fiscal',
      'tasa': 0.5,
      'tipo': 'Fijo',
      'descripcion': 'Timbre de L.0.50 por factura',
    },
  ];

  List<Map<String, dynamic>> _impuestos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarImpuestos();
  }

  Future<void> _cargarImpuestos() async {
    List<Map<String, dynamic>> cargados = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final data = jsonDecode(json) as List<dynamic>;
        cargados = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (cargados.isEmpty) {
      cargados = _impuestosPredeterminados
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await _persistirImpuestos(cargados);
    }
    if (!mounted) return;
    setState(() {
      _impuestos = cargados;
      _cargando = false;
    });
  }

  Future<void> _persistirImpuestos(
    List<Map<String, dynamic>> impuestos,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(impuestos));
    } catch (_) {}
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
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuracion de Impuestos',
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
              color: const Color(0xFF8B5CF6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _impuestos.isEmpty
          ? Center(
              child: Text(
                'No hay impuestos configurados',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _impuestos.length,
              itemBuilder: (context, index) {
                final impuesto = _impuestos[index];
                return _buildImpuestoCard(impuesto, palette);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddImpuestoDialog(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nuevo Impuesto',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildImpuestoCard(
    Map<String, dynamic> impuesto,
    ThemePalette palette,
  ) {
    final tipoColor = impuesto['tipo'] == 'Ventas'
        ? const Color(0xFF10B981)
        : impuesto['tipo'] == 'Retencion'
        ? const Color(0xFFEF4444)
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
                impuesto['nombre'],
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
                  impuesto['tipo'],
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
                  'Tasa',
                  '${impuesto['tasa'].toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Descripcion', impuesto['descripcion']),
              ),
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

  void _showAddImpuestoDialog() {
    final nombreController = TextEditingController();
    final tasaController = TextEditingController();
    final descripcionController = TextEditingController();
    String tipo = 'Ventas';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Nuevo Impuesto',
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
                labelText: 'Nombre del impuesto',
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
              controller: tasaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tasa (%)',
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
              controller: descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripcion',
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
            DropdownButtonFormField<String>(
              initialValue: tipo,
              decoration: InputDecoration(
                labelText: 'Tipo',
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
              items: const [
                DropdownMenuItem(value: 'Ventas', child: Text('Ventas')),
                DropdownMenuItem(value: 'Retencion', child: Text('Retencion')),
                DropdownMenuItem(value: 'Fijo', child: Text('Fijo')),
              ],
              onChanged: (value) {
                tipo = value ?? 'Ventas';
              },
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
              final nombre = nombreController.text.trim();
              final tasa = double.tryParse(tasaController.text);
              if (nombre.isEmpty || tasa == null || tasa < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingrese un nombre y una tasa validos'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }
              setState(() {
                _impuestos.add({
                  'id': DateTime.now().microsecondsSinceEpoch.toString(),
                  'nombre': nombre,
                  'tasa': tasa,
                  'tipo': tipo,
                  'descripcion': descripcionController.text.trim(),
                });
              });
              _persistirImpuestos(_impuestos);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Impuesto guardado'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
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
