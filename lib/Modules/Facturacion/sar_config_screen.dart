// lib/Modules/Facturacion/sar_config_screen.dart
// Configuración completa de Facturación SAR Honduras:
// datos de la empresa + CAI/rango por tipo de documento.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';

class SarConfigScreen extends StatefulWidget {
  const SarConfigScreen({super.key});

  @override
  State<SarConfigScreen> createState() => _SarConfigScreenState();
}

class _SarConfigScreenState extends State<SarConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  final _razonSocial = TextEditingController();
  final _nombreComercial = TextEditingController();
  final _rtn = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _representante = TextEditingController();
  final _actividad = TextEditingController();
  final _establecimiento = TextEditingController(text: '001');
  final _puntoEmision = TextEditingController(text: '001');

  // Campos por tipo de documento
  final _cai = TextEditingController();
  final _resolucion = TextEditingController();
  final _rangoInicio = TextEditingController();
  final _rangoFin = TextEditingController();
  DateTime? _fechaLimite;

  String _tipoSeleccionado = SarTipoDocumento.factura;
  String _regimen = 'general';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _razonSocial.dispose();
    _nombreComercial.dispose();
    _rtn.dispose();
    _direccion.dispose();
    _telefono.dispose();
    _email.dispose();
    _representante.dispose();
    _actividad.dispose();
    _establecimiento.dispose();
    _puntoEmision.dispose();
    _cai.dispose();
    _resolucion.dispose();
    _rangoInicio.dispose();
    _rangoFin.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final config = await SarService.instance.getConfiguracion();
    if (config != null) {
      _razonSocial.text = config.razonSocial ?? '';
      _nombreComercial.text = config.nombreComercial ?? '';
      _rtn.text = config.rtn ?? '';
      _direccion.text = config.direccion ?? '';
      _telefono.text = config.telefono ?? '';
      _email.text = config.email ?? '';
      _representante.text = config.representanteLegal ?? '';
      _actividad.text = config.actividadEconomica ?? '';
      _establecimiento.text = config.establecimiento;
      _puntoEmision.text = config.puntoEmision;
      _regimen = config.regimen;
      if (config.regimen == 'simplificado') {
        _tipoSeleccionado = SarTipoDocumento.cf;
      }
    }
    await _cargarTipo();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarTipo() async {
    final row = await SarService.instance.getCorrelativoPorTipo(
      _tipoSeleccionado,
    );
    _cai.text = row.cai ?? '';
    _resolucion.text = row.numeroResolucion ?? '';
    _rangoInicio.text = row.rangoInicio ?? '';
    _rangoFin.text = row.rangoFin ?? '';
    _fechaLimite = row.fechaLimiteEmision;
  }

  void _cambiarTipo(String tipo) async {
    await _guardarTipoLocal();
    setState(() => _tipoSeleccionado = tipo);
    await _cargarTipo();
  }

  Future<void> _guardarTipoLocal() async {
    await SarService.instance.guardarCaiPorTipo(
      tipoDocumento: _tipoSeleccionado,
      cai: _cai.text,
      numeroResolucion: _resolucion.text,
      rangoInicio: _rangoInicio.text,
      rangoFin: _rangoFin.text,
      fechaLimiteEmision: _fechaLimite,
    );
  }

  Future<void> _guardarTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    await _guardarTipoLocal();

    final validacionRTN = SarService.esRTNValido(_rtn.text);
    await SarService.instance.guardarConfiguracion(
      rtn: _rtn.text,
      razonSocial: _razonSocial.text,
      nombreComercial: _nombreComercial.text,
      direccion: _direccion.text,
      telefono: _telefono.text,
      email: _email.text,
      representanteLegal: _representante.text,
      actividadEconomica: _actividad.text,
      establecimiento: _establecimiento.text,
      puntoEmision: _puntoEmision.text,
      regimen: _regimen,
    );

    setState(() => _guardando = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          validacionRTN
              ? 'Configuración SAR guardada'
              : 'Guardada. Nota: el RTN no pasó la validación de dígito verificador.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: validacionRTN
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONFIGURACIÓN SAR',
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection('DATOS DE LA EMPRESA'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    'Razón Social',
                    _razonSocial,
                    hint: 'INVERSIONES XYZ, S. DE R.L.',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Nombre Comercial',
                    _nombreComercial,
                    hint: 'XYZ',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'RTN',
                    _rtn,
                    hint: '0801-199901-12345',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El RTN es obligatorio';
                      }
                      if (!SarService.esRTNValido(v)) {
                        return 'RTN inválido (14 dígitos)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField('Dirección', _direccion),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Teléfono', _telefono)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField('Correo', _email)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField('Representante Legal', _representante),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Actividad Económica',
                    _actividad,
                    hint: 'CIIU 4711 ...',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Establecimiento',
                          _establecimiento,
                          hint: '001',
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          'Punto de Emisión',
                          _puntoEmision,
                          hint: '001',
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSection('RÉGIMEN FISCAL'),
                  const SizedBox(height: 10),
                  _buildRegimenSelector(),
                  const SizedBox(height: 12),
                  if (_regimen == 'simplificado') _buildRstInfoBox(),
                  const SizedBox(height: 24),
                  if (_regimen == 'simplificado') ...[
                    _buildSection('COMPROBANTE FISCAL (RST)'),
                    const SizedBox(height: 10),
                    _buildTextField(
                      'Número de Resolución (autorización RST)',
                      _resolucion,
                      isMono: true,
                    ),
                  ] else ...[
                    _buildSection('CAI Y RANGO POR DOCUMENTO'),
                    const SizedBox(height: 10),
                    _buildTipoSelector(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'CAI',
                      _cai,
                      hint: 'XXXXXXXXXX-XXXXXXXXXXXXXXX',
                      isMono: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Número de Resolución',
                      _resolucion,
                      isMono: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Rango Inicio',
                            _rangoInicio,
                            hint: '001-001-01-00000001',
                            isMono: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            'Rango Fin',
                            _rangoFin,
                            hint: '001-001-01-00000500',
                            isMono: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFechaLimite(),
                    const SizedBox(height: 24),
                    _buildResumenRango(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardarTodo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.save_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                      label: Text(
                        'Guardar Configuración SAR',
                        style: GoogleFonts.syne(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildResumenRango() {
    final inicio = SarService.numeroDeCorrelativo(_rangoInicio.text) ?? 0;
    final fin = SarService.numeroDeCorrelativo(_rangoFin.text) ?? 0;
    final total = fin >= inicio ? fin - inicio + 1 : 0;
    final caiValido = SarService.esCAIValido(_cai.text);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen',
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _resumenRow(
            'CAI',
            _cai.text.isEmpty
                ? 'No configurado'
                : '${_cai.text.length} caracteres',
            _cai.text.isEmpty
                ? const Color(0xFFEF4444)
                : (caiValido
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 6),
          _resumenRow(
            'Documentos disponibles',
            total > 0 ? '$total' : '—',
            total > 0 ? const Color(0xFF10B981) : const Color(0xFF737373),
          ),
          const SizedBox(height: 6),
          _resumenRow(
            'Vence',
            _fechaLimite != null ? SarService.fmtFecha(_fechaLimite!) : '—',
            const Color(0xFF737373),
          ),
          if (_fechaLimite != null &&
              _fechaLimite!.isBefore(DateTime.now())) ...[
            const SizedBox(height: 8),
            Text(
              '⚠ Este CAI está vencido.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumenRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFFA3A3A3),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRegimenSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: DropdownButton<String>(
        value: _regimen,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1A1A),
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFF737373),
        ),
        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
        items: const [
          DropdownMenuItem(value: 'general', child: Text('Régimen General')),
          DropdownMenuItem(
            value: 'simplificado',
            child: Text('Régimen Simplificado (RST)'),
          ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _regimen = v;
            if (v == 'simplificado') {
              _tipoSeleccionado = SarTipoDocumento.cf;
            }
          });
        },
      ),
    );
  }

  Widget _buildRstInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Sin CAI',
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'En el Régimen Simplificado se emite Comprobante Fiscal (CF) sin CAI. '
            'La numeración es controlada por la SAR mediante autorización.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFFA3A3A3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: DropdownButton<String>(
        value: _tipoSeleccionado,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1A1A),
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFF737373),
        ),
        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
        items: SarTipoDocumento.tiposHabituales.map((t) {
          return DropdownMenuItem(
            value: t,
            child: Text(SarTipoDocumento.etiqueta(t)),
          );
        }).toList(),
        onChanged: (v) => v != null ? _cambiarTipo(v) : null,
      ),
    );
  }

  Widget _buildFechaLimite() {
    return GestureDetector(
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: _fechaLimite ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF10B981),
                surface: Color(0xFF1A1A1A),
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF1A1A1A),
              ),
            ),
            child: child!,
          ),
        );
        if (fecha != null) setState(() => _fechaLimite = fecha);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: Color(0xFF737373), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _fechaLimite != null
                    ? SarService.fmtFecha(_fechaLimite!)
                    : 'Fecha límite de emisión',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _fechaLimite != null
                      ? Colors.white
                      : const Color(0xFF404040),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF737373),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool numeric = false,
    bool isMono = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style:
              (isMono
                      ? GoogleFonts.dmMono(fontSize: 14)
                      : GoogleFonts.dmSans(fontSize: 14))
                  .copyWith(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
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
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
