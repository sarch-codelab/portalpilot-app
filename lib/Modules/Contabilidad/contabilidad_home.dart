import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/cierres_mensuales.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/conciliacion_bancaria.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/configuracion_impuestos.dart';

class ContabilidadHome extends StatefulWidget {
  const ContabilidadHome({super.key});

  @override
  State<ContabilidadHome> createState() => _ContabilidadHomeState();
}

class _ContabilidadHomeState extends State<ContabilidadHome> {
  List<Map<String, dynamic>> _transacciones = [];
  double _totalIngresos = 0.0;
  double _totalGastos = 0.0;
  double _balance = 0.0;
  double _ingresosMes = 0.0;
  double _gastosMes = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('transacciones') ?? '[]';
    final locales = List<Map<String, dynamic>>.from(jsonDecode(json));

    _procesarTransacciones(locales);

    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isEmpty) return;
      final remotas = await PortalPilotDB.getTransacciones(empresa);
      if (remotas.isNotEmpty) {
        final mapa = <String, Map<String, dynamic>>{};
        for (final t in locales) {
          mapa[_claveTransaccion(t)] = Map.from(t);
        }
        for (final r in remotas) {
          final row = Map<String, dynamic>.from(r);
          row['server_id'] = row['id'];
          mapa[_claveTransaccion(row)] = row;
        }
        final fusion = mapa.values.toList();
        await prefs.setString('transacciones', jsonEncode(fusion));
        _procesarTransacciones(fusion);
      }
    } catch (_) {}
  }

  String _claveTransaccion(Map<String, dynamic> t) {
    return '${t['fecha'] ?? ''}|${t['monto'] ?? 0}|${t['descripcion'] ?? ''}';
  }

  void _procesarTransacciones(List<Map<String, dynamic>> transacciones) {
    double ingresos = 0, gastos = 0;
    double ingresosMes = 0, gastosMes = 0;
    final ahora = DateTime.now();

    for (final t in transacciones) {
      final monto = (t['monto'] as num?)?.toDouble() ?? 0.0;
      final tipo = t['tipo'] ?? '';
      final fecha = DateTime.tryParse(t['fecha'] ?? '');

      if (tipo == 'ingreso') {
        ingresos += monto;
        if (fecha != null && fecha.year == ahora.year && fecha.month == ahora.month) {
          ingresosMes += monto;
        }
      } else if (tipo == 'gasto') {
        gastos += monto;
        if (fecha != null && fecha.year == ahora.year && fecha.month == ahora.month) {
          gastosMes += monto;
        }
      }
    }

    setState(() {
      _transacciones = List<Map<String, dynamic>>.from(transacciones);
      _totalIngresos = ingresos;
      _totalGastos = gastos;
      _balance = ingresos - gastos;
      _ingresosMes = ingresosMes;
      _gastosMes = gastosMes;
    });
  }

  Future<void> _agregarTransaccion() async {
    final conceptoController = TextEditingController();
    final montoController = TextEditingController();
    final referenciaController = TextEditingController();
    String tipo = 'ingreso';
    String categoria = 'Venta';
    String metodoPago = 'efectivo';

    final categorias = {
      'ingreso': ['Venta', 'Servicio', 'Préstamo', 'Inversión', 'Otro'],
      'gasto': ['Compra', 'Nómina', 'Alquiler', 'Servicios', 'Impuestos', 'Otro'],
    };

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF404040),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nueva Transacción',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              tipo = 'ingreso';
                              categoria = categorias['ingreso']!.first;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tipo == 'ingreso'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tipo == 'ingreso'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF262626),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.trending_up_rounded,
                                      color: tipo == 'ingreso'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF737373),
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ingreso',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tipo == 'ingreso'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF737373),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              tipo = 'gasto';
                              categoria = categorias['gasto']!.first;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tipo == 'gasto'
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                    : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tipo == 'gasto'
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF262626),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.trending_down_rounded,
                                      color: tipo == 'gasto'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF737373),
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gasto',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tipo == 'gasto'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF737373),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Concepto', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: conceptoController,
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Descripción de la transacción',
                        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF262626)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF262626)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monto (L.)', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: montoController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                                  filled: true,
                                  fillColor: const Color(0xFF0F0F0F),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF262626)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF262626)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Categoría', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F0F),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF262626)),
                                ),
                                child: DropdownButton<String>(
                                  value: categoria,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1A1A1A),
                                  underline: const SizedBox(),
                                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                                  items: (categorias[tipo] ?? []).map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c))
                                  ).toList(),
                                  onChanged: (v) => setModalState(() => categoria = v ?? categoria),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Referencia (opcional)', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: referenciaController,
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'N° factura, recibo, etc.',
                        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF262626)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF262626)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Método de Pago', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: DropdownButton<String>(
                        value: metodoPago,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1A),
                        underline: const SizedBox(),
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                        items: ['efectivo', 'tarjeta', 'transferencia', 'cheque', 'otro'].map((m) =>
                          DropdownMenuItem(value: m, child: Text(m[0].toUpperCase() + m.substring(1)))
                        ).toList(),
                        onChanged: (v) => setModalState(() => metodoPago = v ?? metodoPago),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (conceptoController.text.isEmpty || montoController.text.isEmpty) return;
                          final monto = double.tryParse(montoController.text) ?? 0;
                          if (monto <= 0) return;

                          final prefs = await SharedPreferences.getInstance();
                          final json = prefs.getString('transacciones') ?? '[]';
                          final List<dynamic> transacciones = jsonDecode(json);

                          transacciones.add({
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'tipo': tipo,
                            'categoria': categoria,
                            'descripcion': conceptoController.text,
                            'monto': monto,
                            'metodo_pago': metodoPago,
                            'referencia': referenciaController.text,
                            'fecha': DateTime.now().toIso8601String(),
                          });

                          await prefs.setString('transacciones', jsonEncode(transacciones));

                          try {
                            final empresa = prefs.getString('company_code') ?? '';
                            if (empresa.isNotEmpty) {
                              await PortalPilotDB.insertTransaccion(
                                transaccion: {
                                  'tipo': tipo,
                                  'categoria': categoria,
                                  'descripcion': conceptoController.text,
                                  'monto': monto,
                                  'metodo_pago': metodoPago,
                                  'referencia': referenciaController.text,
                                  'fecha': DateTime.now().toIso8601String(),
                                },
                                empresaCodigo: empresa,
                              );
                            }
                          } catch (_) {}

                          if (ctx.mounted) Navigator.pop(ctx);
                          _cargarDatos();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Guardar Transacción',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaccionesMes = _transacciones.where((t) {
      final fecha = DateTime.tryParse(t['fecha'] ?? '');
      final ahora = DateTime.now();
      return fecha != null && fecha.year == ahora.year && fecha.month == ahora.month;
    }).toList()
      ..sort((a, b) => (b['fecha'] ?? '').compareTo(a['fecha'] ?? ''));

    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF3B82F6), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'CONTABILIDAD',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF3B82F6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarTransaccion,
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nueva Transacción',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 14),
            _buildResumenMensual(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    Icons.calendar_month_rounded,
                    'Cierres Mensuales',
                    const Color(0xFF8B5CF6),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CierresMensuales())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    Icons.account_balance_rounded,
                    'Conciliacion',
                    const Color(0xFF3B82F6),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConciliacionBancaria())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    Icons.percent_rounded,
                    'Impuestos',
                    const Color(0xFF10B981),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracionImpuestos())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'ÚLTIMAS TRANSACCIONES',
              style: GoogleFonts.syne(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF737373),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            if (transaccionesMes.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Center(
                  child: Text(
                    'No hay transacciones este mes',
                    style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
                  ),
                ),
              )
            else
              ...transaccionesMes.take(10).map((t) => _buildTransaccionTile(t)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final isPositive = _balance >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.12),
            const Color(0xFF1D4ED8).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Total',
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
          ),
          const SizedBox(height: 6),
          Text(
            'L.${_balance.toStringAsFixed(2)}',
            style: GoogleFonts.syne(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Ingresos',
                  'L.${_totalIngresos.toStringAsFixed(2)}',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildMiniStat(
                  'Gastos',
                  'L.${_totalGastos.toStringAsFixed(2)}',
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF525252))),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildResumenMensual() {
    final now = DateTime.now();
    final nombreMes = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][now.month - 1];
    final neta = _ingresosMes - _gastosMes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN $nombreMes ${now.year}',
            style: GoogleFonts.syne(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem('Ingresos', _ingresosMes, const Color(0xFF10B981)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResumenItem('Gastos', _gastosMes, const Color(0xFFEF4444)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResumenItem('Neto', neta, neta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, double monto, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
        const SizedBox(height: 4),
        Text(
          'L.${monto.toStringAsFixed(0)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmMono(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFA3A3A3)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransaccionTile(Map<String, dynamic> t) {
    final tipo = t['tipo'] ?? '';
    final monto = (t['monto'] as num?)?.toDouble() ?? 0.0;
    final fecha = t['fecha'] ?? '';
    final dt = DateTime.tryParse(fecha);

    final isIngreso = tipo == 'ingreso';
    final color = isIngreso ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIngreso ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['descripcion'] ?? '',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${t['categoria'] ?? ''}  •  ${dt != null ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}' : ''}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
                ),
              ],
            ),
          ),
          Text(
            '${isIngreso ? '+' : '-'}L.${monto.toStringAsFixed(2)}',
            style: GoogleFonts.dmMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
