import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/DB/db.dart';
import 'dart:math';

// ═══════════════════════════════════════════════════════════
// Colors y constantes
// ═══════════════════════════════════════════════════════════

const Color accentPurple = Color(0xFF8B5CF6);
const Color accentPurpleDark = Color(0xFF6D28D9);
const Color textDark = Color(0xFF1E293B);
const Color successGreen = Color(0xFF10B981);
const Color errorRed = Color(0xFFEF4444);
const Color warningAmber = Color(0xFFF59E0B);
const Color infoBlue = Color(0xFF3B82F6);

// ═══════════════════════════════════════════════════════════
// NUEVA MATRÍCULA SCREEN
// ═══════════════════════════════════════════════════════════

class NuevaMatriculaScreen extends StatefulWidget {
  const NuevaMatriculaScreen({super.key});

  @override
  State<NuevaMatriculaScreen> createState() => _NuevaMatriculaScreenState();
}

class _NuevaMatriculaScreenState extends State<NuevaMatriculaScreen> {
  // ── FOLIO GENERADO AUTOMÁTICAMENTE ──
  late final String _folioMatricula;

  // ── DATOS DE INSCRIPCIÓN ──
  String? _cicloSeleccionado;
  String? _nivelSeleccionado;
  String? _gradoSeleccionado;
  String? _seccionSeleccionada;
  String? _turnoSeleccionado;
  String? _tipoIngresoSeleccionado;

  // ── CONTROL FINANCIERO ──
  bool _pagoInscripcionRealizado = false;
  String? _metodoPagoSeleccionado;
  String? _planPagosSeleccionado;

  // ── CONTROLLERS ALUMNO ──
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();
  final _fechaNacController = TextEditingController();
  final _lugarNacController = TextEditingController();
  final _nacionalidadController = TextEditingController(text: 'Hondureña');

  // ── INFORMACIÓN MÉDICA (SIMPLIFICADA) ──
  final _observacionesSaludController = TextEditingController();

  // ── TUTOR RESPONSABLE (UNIFICADO) ──
  final _tutorNombreController = TextEditingController();
  final _tutorTelefonoController = TextEditingController();
  final _tutorEmailController = TextEditingController();

  // ── DIRECCIÓN ──
  final _direccionController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _cpController = TextEditingController();
  final _municipioController = TextEditingController();
  final _departamentoController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── OPCIONES DE DROPDOWN ──
  final List<String> _ciclos = ['2025', '2025-2026', '2026', '2026-2027', '2027', '2027-2028'];
  final List<String> _niveles = ['Pre-Básica', 'Básica', 'Media', 'Diversificado'];
  final Map<String, List<String>> _gradosPorNivel = {
    'Pre-Básica': ['Prekínder', 'Kínder'],
    'Básica': ['1° Grado', '2° Grado', '3° Grado', '4° Grado', '5° Grado', '6° Grado', '7° Grado', '8° Grado', '9° Grado'],
    'Media': ['1° Año', '2° Año', '3° Año'],
    'Diversificado': ['1° Bachillerato', '2° Bachillerato', '3° Bachillerato'],
  };
  final List<String> _secciones = ['Sección A', 'Sección B', 'Sección C', 'Sección Única'];
  final List<String> _turnos = ['Matutino', 'Vespertino', 'Nocturno'];
  final List<String> _tiposIngreso = ['Nuevo Ingreso', 'Reingreso', 'Traslado / Convalidación'];
  final List<String> _metodosPago = ['Efectivo', 'Transferencia Bancaria', 'Tarjeta de Crédito/Débito', 'Cheque', 'Pago en Línea'];
  final List<String> _planesPagos = ['Regular (Sin Beca)', 'Beca 20%', 'Beca 50%', 'Beca 100%', 'Hijo de Trabajador', 'Convenio Empresarial'];
  final List<String> _parentescos = ['Padre', 'Madre', 'Abuelo(a)', 'Tío(a)', 'Hermano(a)', 'Tutor Legal'];

  String? _tutorParentescoSeleccionado;

  _NuevaMatriculaScreenState()
      : _folioMatricula = _generarFolio();

  static String _generarFolio() {
    final now = DateTime.now();
    final random = Random().nextInt(9000) + 1000;
    return 'MAT-${now.year}-${now.month.toString().padLeft(2, '0')}-$random';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _fechaNacController.dispose();
    _lugarNacController.dispose();
    _nacionalidadController.dispose();
    _observacionesSaludController.dispose();
    _tutorNombreController.dispose();
    _tutorTelefonoController.dispose();
    _tutorEmailController.dispose();
    _direccionController.dispose();
    _coloniaController.dispose();
    _cpController.dispose();
    _municipioController.dispose();
    _departamentoController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Nueva Matrícula',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── FOLIO BANNER ──
                    _buildFolioBanner(),
                    const SizedBox(height: 24),

                    // ═══ 1. DETALLES DE INSCRIPCIÓN ═══
                    _buildSectionTitle('Detalles de la Inscripción', Icons.assignment_ind_rounded, accentPurple),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Ciclo Escolar',
                      items: _ciclos,
                      value: _cicloSeleccionado,
                      onChanged: (v) => setState(() => _cicloSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Tipo de Ingreso',
                      items: _tiposIngreso,
                      value: _tipoIngresoSeleccionado,
                      onChanged: (v) => setState(() => _tipoIngresoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Nivel Educativo',
                      items: _niveles,
                      value: _nivelSeleccionado,
                      onChanged: (v) {
                        setState(() {
                          _nivelSeleccionado = v;
                          _gradoSeleccionado = null;
                        });
                      },
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Grado',
                      items: _nivelSeleccionado != null ? _gradosPorNivel[_nivelSeleccionado]! : [],
                      value: _gradoSeleccionado,
                      onChanged: (v) => setState(() => _gradoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Sección / Grupo',
                      items: _secciones,
                      value: _seccionSeleccionada,
                      onChanged: (v) => setState(() => _seccionSeleccionada = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Turno',
                      items: _turnos,
                      value: _turnoSeleccionado,
                      onChanged: (v) => setState(() => _turnoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 32),

                    // ═══ 2. DATOS DEL ALUMNO ═══
                    _buildSectionTitle('Datos del Alumno', Icons.child_care_rounded, infoBlue),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nombreController,
                      label: 'Nombre(s)',
                      hint: 'Ej. Gissel Sofia',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _apellidoController,
                      label: 'Apellido(s)',
                      hint: 'Ej. Guzman Castro',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _dniController,
                      label: 'DNI / Identificación',
                      hint: 'Ej. 0501-2010-03127',
                      icon: Icons.badge_outlined,
                      isMono: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _fechaNacController,
                      label: 'Fecha de Nacimiento',
                      hint: 'DD/MM/AAAA',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_FechaNacimientoInputFormatter()],
                      maxLength: 10,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatorio';
                        if (v.length != 10) return 'Formato inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _lugarNacController,
                      label: 'Lugar de Nacimiento',
                      hint: 'Ej. Tegucigalpa, M.D.C.',
                      icon: Icons.location_city_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nacionalidadController,
                      label: 'Nacionalidad',
                      hint: 'Hondureña',
                      icon: Icons.flag_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 32),

                    // ═══ 3. OBSERVACIONES DE SALUD ═══
                    _buildSectionTitle('Observaciones de Salud', Icons.medical_services_outlined, errorRed),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _observacionesSaludController,
                      label: 'Observaciones de Salud',
                      hint: 'Ej. Alergia severa a la penicilina, asmático...',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // ═══ 4. TUTOR RESPONSABLE ═══
                    _buildSectionTitle('Datos del Tutor Responsable', Icons.family_restroom_rounded, warningAmber),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Parentesco',
                      items: _parentescos,
                      value: _tutorParentescoSeleccionado,
                      onChanged: (v) => setState(() => _tutorParentescoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _tutorNombreController,
                      label: 'Nombre Completo',
                      hint: 'Ej. Juan Pérez Rodríguez',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _tutorTelefonoController,
                      label: 'Teléfono de Contacto',
                      hint: 'Ej. +504 9999-9999',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _tutorEmailController,
                      label: 'Correo Electrónico',
                      hint: 'Ej. tutor@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatorio';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // ═══ 5. DIRECCIÓN ═══
                    _buildSectionTitle('Dirección de Residencia', Icons.home_work_outlined, accentPurple),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _direccionController,
                      label: 'Calle y Número / Colonia',
                      hint: 'Ej. Barrio El Centro, Casa #123',
                      icon: Icons.location_on_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _municipioController,
                      label: 'Municipio',
                      hint: 'Ej. Tegucigalpa',
                      icon: Icons.location_city_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _departamentoController,
                      label: 'Departamento',
                      hint: 'Ej. Francisco Morazán',
                      icon: Icons.map_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _coloniaController,
                      label: 'Referencia / Punto de referencia',
                      hint: 'Ej. Frente al parque central',
                      icon: Icons.near_me_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _cpController,
                      label: 'Código Postal (Opcional)',
                      hint: 'Ej. 11101',
                      icon: Icons.markunread_mailbox_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),

                    // ═══ 6. CONTROL FINANCIERO ═══
                    _buildSectionTitle('Control Financiero', Icons.account_balance_wallet_rounded, successGreen),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Cuota de Inscripción Pagada',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _pagoInscripcionRealizado ? 'PAGO VERIFICADO' : 'Pendiente de pago',
                        style: GoogleFonts.spaceGrotesk(
                          color: _pagoInscripcionRealizado ? successGreen : warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      value: _pagoInscripcionRealizado,
                      onChanged: (v) => setState(() => _pagoInscripcionRealizado = v),
                      activeColor: successGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_pagoInscripcionRealizado) ...[
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Método de Pago',
                        items: _metodosPago,
                        value: _metodoPagoSeleccionado,
                        onChanged: (v) => setState(() => _metodoPagoSeleccionado = v),
                        validator: (v) => _pagoInscripcionRealizado && (v == null || v.isEmpty) ? 'Seleccione un método' : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Plan de Pagos / Colegiatura',
                      items: _planesPagos,
                      value: _planPagosSeleccionado,
                      onChanged: (v) => setState(() => _planPagosSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 40),

                    // ── BOTÓN GUARDAR ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardarMatricula,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                        label: Text(
                          'Registrar Matrícula',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 8,
                          shadowColor: accentPurple.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // COMPONENTES UI
  // ═══════════════════════════════════════════════════════════

  Widget _buildFolioBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentPurple.withOpacity(0.2), accentPurpleDark.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPurple.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentPurple, accentPurpleDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tag_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NÚMERO DE MATRÍCULA / FOLIO',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _folioMatricula,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: successGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: successGreen.withOpacity(0.4)),
            ),
            child: Text(
              'AUTO',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: successGreen,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    bool isMono = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111114),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: Colors.white,
              fontFamily: isMono ? 'monospace' : null,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Colors.white38),
              prefixIcon: Icon(icon, color: Colors.white38, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              counterText: '',
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: errorRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111114),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: const Color(0xFF111114),
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Seleccionar...',
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Colors.white38),
              prefixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: errorRed),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white)),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GUARDAR EN SUPABASE
  // ═══════════════════════════════════════════════════════════

  Future<void> _guardarMatricula() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los campos obligatorios'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('company_code') ?? 'ROOT';

      await PortalPilotDB.insertMatriculaCompleta(
        // IDENTIFICADOR INSTITUCIONAL
        folioMatricula: _folioMatricula,

        // DETALLES DE INSCRIPCIÓN
        cicloEscolar: _cicloSeleccionado ?? '',
        nivelEducativo: _nivelSeleccionado ?? '',
        grado: _gradoSeleccionado ?? '',
        seccion: _seccionSeleccionada ?? '',
        turno: _turnoSeleccionado ?? '',
        tipoIngreso: _tipoIngresoSeleccionado ?? '',

        // DATOS DEL ALUMNO
        alumnoNombre: _nombreController.text.trim(),
        alumnoApellido: _apellidoController.text.trim(),
        alumnoDni: _dniController.text.trim(),
        alumnoFechaNacimiento: _fechaNacController.text.trim(),
        alumnoLugarNacimiento: _lugarNacController.text.trim(),
        alumnoNacionalidad: _nacionalidadController.text.trim(),

        // SALUD (SIMPLIFICADA)
        observacionesSalud: _observacionesSaludController.text.trim(),

        // TUTOR RESPONSABLE
        tutorParentesco: _tutorParentescoSeleccionado ?? '',
        tutorNombre: _tutorNombreController.text.trim(),
        tutorTelefono: _tutorTelefonoController.text.trim(),
        tutorEmail: _tutorEmailController.text.trim(),

        // DIRECCIÓN
        direccionCalle: _direccionController.text.trim(),
        direccionMunicipio: _municipioController.text.trim(),
        direccionDepartamento: _departamentoController.text.trim(),
        direccionReferencia: _coloniaController.text.trim(),
        direccionCP: _cpController.text.trim(),

        // CONTROL FINANCIERO
        pagoInscripcionRealizado: _pagoInscripcionRealizado,
        metodoPago: _metodoPagoSeleccionado ?? (_pagoInscripcionRealizado ? '' : 'No aplica'),
        planPagos: _planPagosSeleccionado ?? '',

        // EMPRESA
        empresaCodigo: empresaCodigo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Matrícula $_folioMatricula registrada correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _cicloSeleccionado = null;
      _nivelSeleccionado = null;
      _gradoSeleccionado = null;
      _seccionSeleccionada = null;
      _turnoSeleccionado = null;
      _tipoIngresoSeleccionado = null;
      _pagoInscripcionRealizado = false;
      _metodoPagoSeleccionado = null;
      _planPagosSeleccionado = null;
      _tutorParentescoSeleccionado = null;
    });
    _nombreController.clear();
    _apellidoController.clear();
    _dniController.clear();
    _fechaNacController.clear();
    _lugarNacController.clear();
    _nacionalidadController.text = 'Hondureña';
    _observacionesSaludController.clear();
    _tutorNombreController.clear();
    _tutorTelefonoController.clear();
    _tutorEmailController.clear();
    _direccionController.clear();
    _coloniaController.clear();
    _cpController.clear();
    _municipioController.clear();
    _departamentoController.clear();
  }
}

// ═══════════════════════════════════════════════════════════
// INPUT FORMATTER PARA FECHA DD/MM/AAAA
// ═══════════════════════════════════════════════════════════

class _FechaNacimientoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer();
    for (int i = 0; i < text.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}