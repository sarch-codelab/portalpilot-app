import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class CreditoAvanzado extends StatefulWidget {
  const CreditoAvanzado({super.key});

  @override
  State<CreditoAvanzado> createState() => _CreditoAvanzadoState();
}

class _CreditoAvanzadoState extends State<CreditoAvanzado> {
  List<Map<String, dynamic>> _clientes = [
    {
      'id': '1',
      'nombre': 'PulperÃ­a DoÃ±a MarÃ­a',
      'limite': 5000.00,
      'usado': 2340.00,
      'disponible': 2660.00,
      'estado': 'activo',
    },
    {
      'id': '2',
      'nombre': 'Mercadito San JosÃ©',
      'limite': 3500.00,
      'usado': 3500.00,
      'disponible': 0.00,
      'estado': 'sobre_limite',
    },
    {
      'id': '3',
      'nombre': 'AbarroterÃ­a El Vecino',
      'limite': 2000.00,
      'usado': 890.00,
      'disponible': 1110.00,
      'estado': 'activo',
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
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Control de CrÃ©dito Avanzado',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clientes.length,
        itemBuilder: (context, index) {
          final cliente = _clientes[index];
          return _buildClienteCard(cliente, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddClienteDialog();
        },
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Agregar Cliente',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente, ThemePalette palette) {
    final estadoColor = cliente['estado'] == 'activo'
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final porcentaje = cliente['usado'] / cliente['limite'];

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
                cliente['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cliente['estado'].toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCreditRow(
            'LÃ­mite',
            cliente['limite'],
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildCreditRow(
            'Usado',
            cliente['usado'],
            cliente['estado'] == 'activo'
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(height: 8),
          _buildCreditRow(
            'Disponible',
            cliente['disponible'],
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: porcentaje,
            backgroundColor: appThemeNotifier.isDark
                ? const Color(0xFF262626)
                : const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              cliente['estado'] == 'activo'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditRow(String label, double valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: appThemeNotifier.isDark
                ? const Color(0xFFA3A3A3)
                : const Color(0xFF6B7280),
          ),
        ),
        Text(
          'L.$valor.toStringAsFixed(2)',
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showAddClienteDialog() {
    final nombreController = TextEditingController();
    final limiteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Agregar Cliente',
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
                labelText: 'Nombre del cliente',
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
              controller: limiteController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'LÃ­mite de crÃ©dito',
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
                _clientes.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'limite': double.tryParse(limiteController.text) ?? 0.0,
                  'usado': 0.0,
                  'disponible': double.tryParse(limiteController.text) ?? 0.0,
                  'estado': 'activo',
                });
              });
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
