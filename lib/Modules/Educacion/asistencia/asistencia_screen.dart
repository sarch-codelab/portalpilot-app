import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Control de Asistencias: registro diario de alumnos con persistencia local.
class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  List<Map<String, dynamic>> _registros = [];
  final _nombreController = TextEditingController();
  String _fecha = '';
  String _estado = 'Presente';

  static const List<String> _estados = ['Presente', 'Ausente', 'Tardanza', 'Justificada'];

  static const Map<String, Color> _coloresEstado = {
    'Presente': Color(0xFF10B981),
    'Ausente': Color(0xFFEF4444),
    'Tardanza': Color(0xFFF59E0B),
    'Justificada': Color(0xFF3B82F6),
  };

  @override
  void initState() {
    super.initState();
    _fecha = _formatoFecha(DateTime.now());
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  String _formatoFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('asistencias_registro') ?? '[]';
    final List<dynamic> registros = jsonDecode(json);
    registros.sort((a, b) => (b['fecha'] ?? '').toString().compareTo(a['fecha'] ?? ''));
    if (mounted) setState(() => _registros = List<Map<String, dynamic>>.from(registros));
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingrese el nombre del alumno', style: GoogleFonts.dmSans()),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('asistencias_registro') ?? '[]';
    final List<dynamic> registros = jsonDecode(json);
    registros.add({
      'alumno': nombre,
      'fecha': _fecha,
      'estado': _estado,
      'registrado_en': DateTime.now().toIso8601String(),
    });
    await prefs.setString('asistencias_registro', jsonEncode(registros));
    _nombreController.clear();
    if (!mounted) return;
    setState(() => _registros = List<Map<String, dynamic>>.from(registros));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Asistencia de $nombre registrada', style: GoogleFonts.dmSans()),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _eliminar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('asistencias_registro') ?? '[]';
    final List<dynamic> registros = jsonDecode(json);
    registros.removeAt(index);
    await prefs.setString('asistencias_registro', jsonEncode(registros));
    setState(() => _registros = List<Map<String, dynamic>>.from(registros));
  }

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fecha = _formatoFecha(picked));
  }

  @override
  Widget build(BuildContext context) {
    final total = _registros.length;
    final presentes = _registros.where((r) => r['estado'] == 'Presente').length;
    final ausentes = _registros.where((r) => r['estado'] == 'Ausente').length;
    final tardanzas = _registros.where((r) => r['estado'] == 'Tardanza').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
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
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('CONTROL DE ASISTENCIAS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRegistroCard(),
            const SizedBox(height: 20),
            _buildResumen(total, presentes, ausentes, tardanzas),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('REGISTROS', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
                const Spacer(),
                Text('${_registros.length} total', style: GoogleFonts.dmMono(fontSize: 12, color: const Color(0xFF737373))),
              ],
            ),
            const SizedBox(height: 10),
            if (_registros.isEmpty) _buildVacio() else ..._registros.map(_buildRegistroTile),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6).withValues(alpha: 0.10), const Color(0xFF2563EB).withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NUEVO REGISTRO', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF3B82F6), letterSpacing: 1)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B82F6), size: 16),
                  const SizedBox(width: 10),
                  Text('ðŸ“…  $_fecha', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF737373)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nombreController,
            style: GoogleFonts.dmSans(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nombre del alumno...',
              hintStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
              prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF737373), size: 18),
              filled: true,
              fillColor: const Color(0xFF141414),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            ),
            onSubmitted: (_) => _guardar(),
          ),
          const SizedBox(height: 10),
          Row(
            children: _estados.map((e) {
              final selected = _estado == e;
              final color = _coloresEstado[e]!;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _estado = e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? color : const Color(0xFF262626)),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconoEstado(e), color: selected ? color : const Color(0xFF737373), size: 16),
                          const SizedBox(height: 4),
                          Text(e, style: GoogleFonts.dmSans(fontSize: 11, color: selected ? color : const Color(0xFF737373), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('REGISTRAR ASISTENCIA', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Presente':
        return Icons.check_circle_rounded;
      case 'Ausente':
        return Icons.cancel_rounded;
      case 'Tardanza':
        return Icons.access_time_rounded;
      default:
        return Icons.event_available_rounded;
    }
  }

  Widget _buildResumen(int total, int presentes, int ausentes, int tardanzas) {
    return Row(
      children: [
        _buildResumenItem('Presentes', '$presentes', const Color(0xFF10B981), Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _buildResumenItem('Ausentes', '$ausentes', const Color(0xFFEF4444), Icons.cancel_rounded),
        const SizedBox(width: 8),
        _buildResumenItem('Tardanzas', '$tardanzas', const Color(0xFFF59E0B), Icons.access_time_rounded),
      ],
    );
  }

  Widget _buildResumenItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373))),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistroTile(Map<String, dynamic> r) {
    final estado = (r['estado'] ?? 'Presente').toString();
    final color = _coloresEstado[estado] ?? const Color(0xFF10B981);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(_iconoEstado(estado), color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['alumno'] ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                Text('ðŸ“…  ${r['fecha'] ?? ''}', style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(estado, style: GoogleFonts.dmSans(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _eliminar(_registros.indexOf(r)),
            child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF525252), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.how_to_reg_rounded, color: Color(0xFF262626), size: 56),
          const SizedBox(height: 12),
          Text('Sin registros de asistencia', style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFF737373))),
          const SizedBox(height: 4),
          Text('Registra la asistencia de tus alumnos para comenzar', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF525252))),
        ],
      ),
    );
  }
}
