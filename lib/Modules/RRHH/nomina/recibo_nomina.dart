import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/modulos_avanzados_service.dart';

class ReciboNomina extends StatefulWidget {
  final Map<String, dynamic> recibo;

  const ReciboNomina({super.key, required this.recibo});

  @override
  State<ReciboNomina> createState() => _ReciboNominaState();
}

class _ReciboNominaState extends State<ReciboNomina> {
  late bool _pagado;
  late String _fechaPago;
  bool _pagando = false;

  static const List<String> _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _pagado = widget.recibo['pagado'] == true;
    _fechaPago = widget.recibo['fecha_pago']?.toString() ?? '';
  }

  Map<String, dynamic> get recibo => widget.recibo;

  Future<void> _marcarPagado() async {
    if (_pagando || _pagado) return;
    final id = recibo['id']?.toString();
    if (id == null || id.isEmpty) {
      _aviso('Este recibo no tiene identificador en el servidor', esError: true);
      return;
    }

    setState(() => _pagando = true);
    final r = await ModulosAvanzadosService.instance.pagarRecibo(id);
    if (!mounted) return;
    setState(() => _pagando = false);

    if (r.ok) {
      setState(() {
        _pagado = true;
        _fechaPago = DateTime.now().toIso8601String();
      });
      _aviso('Recibo marcado como pagado');
    } else {
      _aviso(
        r.planLimitado
            ? 'Este módulo no está incluido en tu plan actual.'
            : (r.error ?? 'No se pudo marcar el recibo'),
        esError: true,
      );
    }
  }

  void _aviso(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto, style: GoogleFonts.dmSans()),
      backgroundColor: esError ? const Color(0xFFC62828) : const Color(0xFF10B981),
    ));
  }

  String get _fechaGeneracion {
    final f = recibo['fecha_generacion']?.toString() ?? '';
    return f.length >= 10 ? f.substring(0, 10) : '';
  }

  @override
  Widget build(BuildContext context) {
    final bruto = (recibo['salario_bruto'] as num?)?.toDouble() ?? 0.0;
    final ihss = (recibo['ihss_empleado'] as num?)?.toDouble() ?? 0.0;
    final rap = (recibo['rap_empleado'] as num?)?.toDouble() ?? 0.0;
    final deducciones = (recibo['total_deducciones'] as num?)?.toDouble() ?? 0.0;
    final neto = (recibo['salario_neto'] as num?)?.toDouble() ?? 0.0;
    final ihssEmpleador = (recibo['ihss_empleador'] as num?)?.toDouble() ?? 0.0;
    final rpvEmpleador = (recibo['rpv_empleador'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RECIBO DE NÓMINA',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF10B981).withValues(alpha: 0.1), const Color(0xFF059669).withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Portal Pilot',
                  style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recibo de Nómina',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${_meses[recibo['mes'] ?? 1]} ${recibo['anio']}',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_pagado ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _pagado ? 'PAGADO' : 'PENDIENTE',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: _pagado ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Employee info
          _buildInfoSection('EMPLEADO', [
            _buildInfoRow('Nombre', recibo['empleado_nombre'] ?? ''),
            _buildInfoRow('Cargo', recibo['cargo'] ?? ''),
          ]),
          const SizedBox(height: 14),

          // Earnings
          _buildInfoSection('INGRESOS', [
            _buildInfoRow('Salario Bruto', 'L.${bruto.toStringAsFixed(2)}', valueColor: Colors.white),
          ]),
          const SizedBox(height: 14),

          // Deductions
          _buildInfoSection('DEDUCCIONES EMPLEADO', [
            _buildInfoRow('IHSS (2.5%)', 'L.${ihss.toStringAsFixed(2)}', valueColor: const Color(0xFFEF4444)),
            _buildInfoRow('RAP (1.5%)', 'L.${rap.toStringAsFixed(2)}', valueColor: const Color(0xFFEF4444)),
            const Divider(color: Color(0xFF262626), height: 20),
            _buildInfoRow('Total Deducciones', 'L.${deducciones.toStringAsFixed(2)}', valueColor: const Color(0xFFEF4444), bold: true),
          ]),
          const SizedBox(height: 14),

          // Net
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SALARIO NETO',
                    style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'L.${neto.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmMono(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Employer costs
          _buildInfoSection('COSTOS EMPLEADOR', [
            _buildInfoRow('IHSS Empleador (3.1%)', 'L.${ihssEmpleador.toStringAsFixed(2)}'),
            _buildInfoRow('RPV Empleador (2.0%)', 'L.${rpvEmpleador.toStringAsFixed(2)}'),
            const Divider(color: Color(0xFF262626), height: 20),
            _buildInfoRow('Total Costo Empleador', 'L.${(bruto + ihssEmpleador + rpvEmpleador).toStringAsFixed(2)}', bold: true),
          ]),
          const SizedBox(height: 20),

          // Payment status
          if (!_pagado) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _pagando ? null : _marcarPagado,
                icon: _pagando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                label: Text(
                  _pagando ? 'Registrando...' : 'Marcar como pagado',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: const Color(0xFF262626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Footer
          Center(
            child: Text(
              _pagado
                  ? 'Pagado el ${_fechaPago.length >= 10 ? _fechaPago.substring(0, 10) : '—'}'
                  : (_fechaGeneracion.isNotEmpty ? 'Generado el $_fechaGeneracion' : 'Pendiente de pago'),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: _pagado ? const Color(0xFF10B981) : const Color(0xFF525252),
                fontWeight: _pagado ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
          Text(title, style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF737373), letterSpacing: 1)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFA3A3A3)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmMono(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
