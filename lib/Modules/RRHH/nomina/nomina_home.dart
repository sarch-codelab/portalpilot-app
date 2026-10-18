import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/RRHH/nomina/recibo_nomina.dart';
import 'package:portal_pilot_app/Modules/RRHH/rrhh_datos.dart';
import 'package:portal_pilot_app/Shared/services/modulos_avanzados_service.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_empty_state.dart';

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
  bool _cargando = true;
  bool _generando = false;
  String? _error;
  bool _sinPermiso = false;

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
    setState(() {
      _cargando = true;
      _error = null;
      _sinPermiso = false;
    });

    final svc = ModulosAvanzadosService.instance;
    final rEmpleados = await svc.empleados();

    if (!mounted) return;
    if (!rEmpleados.ok) {
      setState(() {
        _cargando = false;
        _sinPermiso = rEmpleados.planLimitado;
        _error = rEmpleados.error;
        _empleados = <Map<String, dynamic>>[];
        _recibos = <Map<String, dynamic>>[];
      });
      _recalcularResumen();
      return;
    }

    _empleados = rEmpleados.datos ?? <Map<String, dynamic>>[];
    final rNomina = await svc.nomina(anio: _anioSeleccionado, mes: _mesSeleccionado);
    if (!mounted) return;

    setState(() {
      _cargando = false;
      if (rNomina.ok) {
        _recibos = _normalizarRecibos(rNomina.datos?['recibos']);
      } else {
        // El listado de empleados sí cargó: se muestran, y los recibos se
        // vuelven a pedir con la siguiente actualización.
        _recibos = <Map<String, dynamic>>[];
        if (rNomina.planLimitado) {
          _sinPermiso = true;
          _error = rNomina.error;
        }
      }
    });
    _recalcularResumen();
  }

  List<Map<String, dynamic>> _normalizarRecibos(dynamic bruto) {
    if (bruto is! List) return <Map<String, dynamic>>[];
    final porId = <String, Map<String, dynamic>>{
      for (final e in _empleados)
        if (e['id'] != null) e['id'].toString(): e,
    };
    return bruto
        .whereType<Map>()
        .map((r) => reciboDesdeServidor(
              Map<String, dynamic>.from(r),
              empleado: porId[r['empleado_id']?.toString()],
            ))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _recibosDelPeriodo() => _recibos
      .where((r) => r['mes'] == _mesSeleccionado && r['anio'] == _anioSeleccionado)
      .toList();

  /// Si el periodo ya está generado, el resumen sale de los recibos reales.
  /// Si no, se muestra una estimación a partir de los empleados activos.
  void _recalcularResumen() {
    double totalBruto = 0;
    double totalDeducciones = 0;

    final recibos = _recibosDelPeriodo();
    if (recibos.isNotEmpty) {
      for (final r in recibos) {
        totalBruto += (r['salario_bruto'] as num?)?.toDouble() ?? 0.0;
        totalDeducciones += (r['total_deducciones'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      for (final e in _empleados) {
        if (e['activo'] != true) continue;
        final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
        final baseIHSS = salario > _limiteIHSS ? _limiteIHSS : salario;
        totalBruto += salario;
        totalDeducciones += (baseIHSS * _ihssEmpleado) + (salario * _rapEmpleado);
      }
    }

    if (!mounted) return;
    setState(() {
      _totalNomina = totalBruto;
      _totalDeducciones = totalDeducciones;
      _totalNeto = totalBruto - totalDeducciones;
    });
  }

  Future<void> _cargarRecibosDelPeriodo() async {
    final r = await ModulosAvanzadosService.instance.nomina(
      anio: _anioSeleccionado,
      mes: _mesSeleccionado,
    );
    if (!mounted) return;
    if (r.ok) {
      setState(() => _recibos = _normalizarRecibos(r.datos?['recibos']));
    } else {
      setState(() => _recibos = <Map<String, dynamic>>[]);
      _aviso(r.error ?? 'No se pudieron cargar los recibos', esError: true);
    }
    _recalcularResumen();
  }

  Future<void> _generarRecibos() async {
    if (_generando) return;
    if (_empleados.where((e) => e['activo'] == true).isEmpty) {
      _aviso('No hay empleados activos', esError: true);
      return;
    }

    setState(() => _generando = true);
    final r = await ModulosAvanzadosService.instance.calcularNomina(
      anio: _anioSeleccionado,
      mes: _mesSeleccionado,
    );
    if (!mounted) return;

    if (r.ok) {
      final recibos = _normalizarRecibos(r.datos?['recibos']);
      setState(() => _recibos = recibos);
      _recalcularResumen();
      _aviso('${recibos.length} recibos generados', ok: true);
    } else {
      _aviso(
        r.planLimitado
            ? 'Este módulo no está incluido en tu plan actual.'
            : (r.error ?? 'No se pudieron generar los recibos'),
        esError: true,
      );
    }

    if (mounted) setState(() => _generando = false);
  }

  void _aviso(String texto, {bool esError = false, bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto, style: GoogleFonts.dmSans()),
      backgroundColor: esError
          ? const Color(0xFFC62828)
          : ok
              ? const Color(0xFF10B981)
              : const Color(0xFF2E7D32),
    ));
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
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : _error != null
              ? _estadoError()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  color: const Color(0xFFF59E0B),
                  backgroundColor: const Color(0xFF141414),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PPEmptyState(
          icon: _sinPermiso ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          accentColor: const Color(0xFFF59E0B),
          title: _sinPermiso ? 'No disponible en tu plan' : 'No se pudo cargar la nómina',
          message: _error ?? 'Error desconocido',
          action: FilledButton.icon(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
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
              onChanged: (v) {
                if (v == null) return;
                setState(() => _mesSeleccionado = v);
                _cargarRecibosDelPeriodo();
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _anioSeleccionado,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
            items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - 2 + i, child: Text('${DateTime.now().year - 2 + i}'))),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _anioSeleccionado = v);
              _cargarRecibosDelPeriodo();
            },
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
            children: [
              Expanded(child: _buildResumenItem('Bruto', _totalNomina, Colors.white)),
              Expanded(child: _buildResumenItem('Deducciones', -_totalDeducciones, const Color(0xFFEF4444))),
              Expanded(child: _buildResumenItem('Neto a Pagar', _totalNeto, const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, double amount, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'L.${amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
        ),
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
          _buildDeduccRow('IHSS Empleado', '${_pct(_ihssEmpleado)} (tope L.15,631.78)', Icons.local_hospital_rounded, const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          _buildDeduccRow('RAP Empleado', _pct(_rapEmpleado), Icons.savings_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(height: 6),
          _buildDeduccRow('IHSS Empleador', _pct(_ihssEmpleador), Icons.business_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _buildDeduccRow('RPV Empleador', _pct(_rpvEmpleador), Icons.receipt_rounded, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  /// El porcentaje vive junto a la constante que lo usa en el cálculo, para
  /// que la tarjeta informativa no se desincronice de la fórmula real.
  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  Widget _buildDeduccRow(String title, String detail, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Flexible: a 320px el detalle ("2.5% (tope L.15,631.78)") no cabe
        // junto al título y desbordaba ~39px a la derecha.
        Flexible(
          child: Text(
            detail,
            style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerarButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _generando
            ? null
            : (_empleados.where((e) => e['activo'] == true).isEmpty ? null : _generarRecibos),
        icon: _generando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
        label: Text(
          _generando ? 'Generando...' : 'Generar Recibos de ${_meses[_mesSeleccionado]}',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    final recibosMes = _recibosDelPeriodo();

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
        final pagado = r['pagado'] == true;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReciboNomina(recibo: r))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: pagado
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : const Color(0xFF10B981).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                    pagado ? Icons.check_circle_rounded : Icons.receipt_rounded,
                    color: const Color(0xFF10B981),
                    size: 18,
                  ),
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
                    Text(
                      pagado ? 'Pagado' : 'Bruto: L.${bruto.toStringAsFixed(0)}',
                      style: GoogleFonts.dmMono(
                        fontSize: 10,
                        color: pagado ? const Color(0xFF10B981) : const Color(0xFF737373),
                      ),
                    ),
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
