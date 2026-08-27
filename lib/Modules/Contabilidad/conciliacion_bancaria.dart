import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ConciliacionBancaria extends StatefulWidget {
  const ConciliacionBancaria({super.key});

  @override
  State<ConciliacionBancaria> createState() => _ConciliacionBancariaState();
}

class _ConciliacionBancariaState extends State<ConciliacionBancaria> {
  List<Map<String, dynamic>> _transacciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    List<Map<String, dynamic>> cargadas = [];
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/transacciones');
      if (api.isSuccess(result)) {
        final data = result['transacciones'] ?? result['data'];
        if (data is List) {
          cargadas = data
              .whereType<Map>()
              .map((t) => _normalizarTransaccion(Map<String, dynamic>.from(t)))
              .toList();
        }
      }
    } catch (_) {}
    if (cargadas.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('transacciones') ?? '[]';
        final locales = jsonDecode(json) as List<dynamic>;
        cargadas = locales
            .whereType<Map>()
            .map((t) => _normalizarTransaccion(Map<String, dynamic>.from(t)))
            .toList();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _transacciones = cargadas;
      _cargando = false;
    });
  }

  Map<String, dynamic> _normalizarTransaccion(Map<String, dynamic> t) {
    final tipoRaw = (t['tipo'] ?? '').toString().toLowerCase();
    final esEgreso =
        tipoRaw == 'egreso' || tipoRaw == 'gasto' || tipoRaw == 'compra';
    return {
      'id':
          (t['id'] ?? t['server_id'] ?? DateTime.now().microsecondsSinceEpoch)
              .toString(),
      'tipo': esEgreso ? 'Egreso' : 'Ingreso',
      'descripcion':
          (t['descripcion'] ?? t['concepto'] ?? 'Transaccion').toString(),
      'monto': (t['monto'] as num?)?.toDouble() ?? 0.0,
      'estado': (t['estado'] ?? 'Pendiente').toString(),
    };
  }

  Future<bool> _guardarTransaccion(
    String descripcion,
    String montoTexto,
    String tipo,
  ) async {
    final monto = double.tryParse(montoTexto) ?? 0.0;
    if (descripcion.trim().isEmpty || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una descripcion y un monto validos'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return false;
    }
    final nueva = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'tipo': tipo,
      'descripcion': descripcion.trim(),
      'monto': monto,
      'estado': 'Pendiente',
    };
    setState(() {
      _transacciones.add(nueva);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('transacciones') ?? '[]';
      final locales = jsonDecode(json) as List<dynamic>;
      locales.add({
        'id': nueva['id'],
        'tipo': tipo == 'Ingreso' ? 'ingreso' : 'gasto',
        'descripcion': nueva['descripcion'],
        'monto': monto,
        'fecha': DateTime.now().toIso8601String(),
        'estado': 'Pendiente',
      });
      await prefs.setString('transacciones', jsonEncode(locales));
    } catch (_) {}
    try {
      final api = ApiService.instance;
      await api.post('/api/transacciones', body: {
        'empresa_codigo': api.empresaCodigo,
        'transaccion': {
          'tipo': tipo == 'Ingreso' ? 'ingreso' : 'gasto',
          'descripcion': nueva['descripcion'],
          'monto': monto,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'Pendiente',
        },
      });
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaccion guardada'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
    return true;
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
            color: Color(0xFF3B82F6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Conciliacion Bancaria',
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
              color: const Color(0xFF3B82F6),
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
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            )
          : _transacciones.isEmpty
          ? Center(
              child: Text(
                'No hay transacciones registradas',
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
              itemCount: _transacciones.length,
              itemBuilder: (context, index) {
                final transaccion = _transacciones[index];
                return _buildTransaccionCard(transaccion, palette);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransaccionDialog(),
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nueva Transaccion',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTransaccionCard(
    Map<String, dynamic> transaccion,
    ThemePalette palette,
  ) {
    final tipoColor = transaccion['tipo'] == 'Ingreso'
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final estadoColor = transaccion['estado'] == 'Conciliado'
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

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
                transaccion['descripcion'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaccion['tipo'],
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tipoColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaccion['estado'],
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'L.${transaccion['monto'].toStringAsFixed(2)}',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tipoColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransaccionDialog() {
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    String tipo = 'Ingreso';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Nueva Transaccion',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                DropdownMenuItem(value: 'Ingreso', child: Text('Ingreso')),
                DropdownMenuItem(value: 'Egreso', child: Text('Egreso')),
              ],
              onChanged: (value) {
                tipo = value ?? 'Ingreso';
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
            onPressed: () async {
              final guardado = await _guardarTransaccion(
                descripcionController.text,
                montoController.text,
                tipo,
              );
              if (guardado && context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
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
