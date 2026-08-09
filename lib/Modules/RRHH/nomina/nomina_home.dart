import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/RRHH/nomina/recibo_nomina.dart';

class NominaHome extends StatefulWidget {
  const NominaHome({super.key});

  @override
  State<NominaHome> createState() => _NominaHomeState();
}

class _NominaHomeState extends State<NominaHome> {
  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> _recibos = [];
  double _totalNomina = 0.0;
  double _totalDeducciones = 0.0;
  double _totalNeto = 0.0;
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  final List<String> _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  // Honduras deductions
  static const double _ihssEmpleado = 0.025; // 2.5%
  static const double _rapEmpleado = 0.015;  // 1.5%
  static const double _rpvEmpleador = 0.02;  // 2%
  static const double _ihssEmpleador = 0.031; // 3.1%
  static const double _limiteIHSS = 15631.78; // Monthly salary cap for IHSS 2026

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final empJson = prefs.getString('empleados') ?? '[]';
    final recJson = prefs.getString('recibos_nomina') ?? '[]';

    setState(() {
      _empleados = List<Map<String, dynamic>>.from(jsonDecode(empJson));
      _recibos = List<Map<String, dynamic>>.from(jsonDecode(recJson));
    });

    _calcularNomina();
  }

  void _calcularNomina() {
    double totalBruto = 0;
    double totalDeducciones = 0;

    for (final e in _empleados) {
      if (e['activo'] != true) continue;
      final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;

      final baseIHSS = salario > _limiteIHSS ? _limiteIHSS : salario;
      final ihss = baseIHSS * _ihssEmpleado;
      final rap = salario * _rapEmpleado;
      final deducciones = ihss + rap;

      totalBruto += salario;
      totalDeducciones += deducciones;
    }

    setState(() {
      _totalNomina = totalBruto;
      _totalDeducciones = totalDeducciones;
      _totalNeto = totalBruto - totalDeducciones;
    });
  }

  Future<void> _generarRecibos() async {
    final activos = _empleados.where((e) => e['activo'] == true).toList();
    if (activos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay empleados activos', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    final nuevosRecibos = <Map<String, dynamic>>[];

    for (final e in activos) {
      final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
      final baseIHSS = salario > _limiteIHSS ? _limiteIHSS : salario;
      final ihss = baseIHSS * _ihssEmpleado;
      final rap = salario * _rapEmpleado;
      final totalDeducciones = ihss + rap;
      final neto = salario - totalDeducciones;
      final ihssEmpleador = baseIHSS * _ihssEmpleador;
      final rpvEmpleador = salario * _rpvEmpleador;

      nuevosRecibos.add({
        'id': '${e['id']}_${_anioSeleccionado}_$_mesSeleccionado',
        'empleado_id': e['id'],
        'empleado_nombre': '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.trim(),
        'cargo': e['cargo'] ?? '',
        'mes': _mesSeleccionado,
        'anio': _anioSeleccionado,
        'salario_bruto': salario,
        'ihss_empleado': ihss,
        'rap_empleado': rap,
        'total_deducciones': totalDeducciones,
        'salario_neto': neto,
        'ihss_empleador': ihssEmpleador,
        'rpv_empleador': rpvEmpleador,
        'total_costo_empleador': salario + ihssEmpleador + rpvEmpleador,
        'fecha_generacion': DateTime.now().toIso8601String(),
      });
    }

    final prefs = await SharedPreferences.getInstance();
    // Remove old receipts for this month/year
    final existentes = _recibos.where((r) =>
      !(r['mes'] == _mesSeleccionado && r['anio'] == _anioSeleccionado)
    ).toList();
    existentes.addAll(nuevosRecibos);
    await prefs.setString('recibos_nomina', jsonEncode(existentes));

    setState(() => _recibos = existentes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${nuevosRecibos.length} recibos generados', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFF10B981)),
      );
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'NÓMINA',
              style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildResumenCard(),
          const SizedBox(height: 16),
          _buildDeduccionesCard(),
          const SizedBox(height: 16),
          _buildGenerarButton(),
          const SizedBox(height: 20),
          _buildSectionTitle('Empleados Activos (${_empleados.where((e) => e['activo'] == true).length})'),
          const SizedBox(height: 10),
          _buildEmpleadosList(),
          const SizedBox(height: 20),
          _buildSectionTitle('Recibos Generados'),
          const SizedBox(height: 10),
          _buildRecibosList(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              value: _mesSeleccionado,
              dropdownColor: const Color(0xFF1A1A1A),
              underline: const SizedBox(),
              isExpanded: true,
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_meses[i + 1]))),
              onChanged: (v) => setState(() { _mesSeleccionado = v!; _calcularNomina(); }),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _anioSeleccionado,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
            items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - 2 + i, child: Text('${DateTime.now().year - 2 + i}'))),
            onChanged: (v) => setState(() { _anioSeleccionado = v!; _calcularNomina(); }),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFEC4899).withValues(alpha: 0.1), const Color(0xFFDB2777).withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESUMEN NOMINAL', style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFEC4899), letterSpacing: 1)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildResumenItem('Bruto', _totalNomina, Colors.white),
              _buildResumenItem('Deducciones', -_totalDeducciones, const Color(0xFFEF4444)),
              _buildResumenItem('Neto a Pagar', _totalNeto, const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          'L.${amount.abs().toStringAsFixed(2)}',
          style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
      ],
    );
  }

  Widget _buildDeduccionesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEDUCCIONES HONDURAS (2026)', style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF59E0B), letterSpacing: 0.8)),
          const SizedBox(height: 12),
          _buildDeduccRow('IHSS Empleado', '2.5% (tope L.15,631.78)', Icons.local_hospital_rounded, const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          _buildDeduccRow('RAP Empleado', '1.5%', Icons.savings_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(height: 6),
          _buildDeduccRow('IHSS Empleador', '3.1%', Icons.business_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _buildDeduccRow('RPV Empleador', '2.0%', Icons.receipt_rounded, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildDeduccRow(String title, String detail, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        const Spacer(),
        Text(detail, style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373))),
      ],
    );
  }

  Widget _buildGenerarButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _empleados.where((e) => e['activo'] == true).isEmpty ? null : _generarRecibos,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
        label: Text(
          'Generar Recibos de ${_meses[_mesSeleccionado]}',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          disabledBackgroundColor: const Color(0xFF262626),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8));
  }

  Widget _buildEmpleadosList() {
    final activos = _empleados.where((e) => e['activo'] == true).toList();
    if (activos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
        child: Center(child: Text('No hay empleados activos', style: GoogleFonts.dmSans(color: const Color(0xFF525252)))),
      );
    }

    return Column(
      children: activos.map((e) {
        final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
        final baseIHSS = salario > _limiteIHSS ? _limiteIHSS : salario;
        final deducciones = (baseIHSS * _ihssEmpleado) + (salario * _rapEmpleado);
        final neto = salario - deducciones;
        final nombre = '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF262626))),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_rounded, color: Color(0xFFEC4899), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre.isNotEmpty ? nombre : 'Sin nombre', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text(e['cargo'] ?? '', style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('L.${salario.toStringAsFixed(0)}', style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                  Text('Neto: L.${neto.toStringAsFixed(0)}', style: GoogleFonts.dmMono(fontSize: 10, color: const Color(0xFF10B981))),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecibosList() {
    final recibosMes = _recibos.where((r) =>
      r['mes'] == _mesSeleccionado && r['anio'] == _anioSeleccionado
    ).toList();

    if (recibosMes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
        child: Center(child: Text('No hay recibos para este mes', style: GoogleFonts.dmSans(color: const Color(0xFF525252)))),
      );
    }

    return Column(
      children: recibosMes.map((r) {
        final neto = (r['salario_neto'] as num?)?.toDouble() ?? 0.0;
        final bruto = (r['salario_bruto'] as num?)?.toDouble() ?? 0.0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReciboNomina(recibo: r))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.receipt_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['empleado_nombre'] ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('${_meses[r['mes'] ?? 1]} ${r['anio']}', style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('L.${neto.toStringAsFixed(2)}', style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                    Text('Bruto: L.${bruto.toStringAsFixed(0)}', style: GoogleFonts.dmMono(fontSize: 10, color: const Color(0xFF737373))),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
