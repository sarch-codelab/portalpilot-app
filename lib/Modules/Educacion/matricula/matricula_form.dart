import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

// ═══════════════════════════════════════════════════════════
// REGISTRO ESTUDIANTIL SCREEN
// ═══════════════════════════════════════════════════════════

class RegistroEstudiantilScreen extends StatefulWidget {
  const RegistroEstudiantilScreen({super.key});

  @override
  State<RegistroEstudiantilScreen> createState() => _RegistroEstudiantilScreenState();
}

class _RegistroEstudiantilScreenState extends State<RegistroEstudiantilScreen> {
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

  _RegistroEstudiantilScreenState()
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
  // THEME
  // ═══════════════════════════════════════════════════════════

  ThemePalette _palette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ThemePalette(isDark: isDark);
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);

    if (!mounted) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: p.bgPrimary,
      appBar: AppBar(
        backgroundColor: p.bgSecondary,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.accentPurple, p.accentPurpleDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.school_rounded, color: p.textPrimary, size: 16),
            ),
            const SizedBox(width: 12),
            Text('PORTAL PILOT',
                style: GoogleFonts.syne(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: p.textPrimary, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: p.accentPurple,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
              if (mounted) setState(() {});
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.accentPurple, width: 2),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: p.bgTertiary,
              child: Text('AD', style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              p.accentPurple.withValues(alpha: p.isDark ? 0.03 : 0.06),
              p.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildNuevoRegistroView(p),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTA DE MATRÍCULA
  // ═══════════════════════════════════════════════════════════

  Widget _buildNuevoRegistroView(ThemePalette p) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection('Nuevo Registro Estudiantil', 'Formulario optimizado de inscripción con validación automática.',
                icon: Icons.person_add_alt_1_rounded, p: p),
            const SizedBox(height: 24),

            // ── FOLIO DE MATRÍCULA ──
            _buildFolioBanner(p),
            const SizedBox(height: 32),

            _buildRegistrationSteps(p),
            const SizedBox(height: 32),

            // ══════════════════════════════════════════════════
            // 1. DETALLES DE LA INSCRIPCIÓN (NUEVO)
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Detalles de la Inscripción',
              Icons.assignment_ind_rounded,
              p.accentPurple,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.accentPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.accentPurple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.accentPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seleccione el ciclo, nivel, grado y sección a la que ingresará el alumno. Todos los campos son obligatorios.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.accentPurple, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormRow(p, [
                  _buildDropdownField('Ciclo Escolar', 'Seleccionar ciclo...', Icons.calendar_month_outlined, p,
                      items: _ciclos,
                      value: _cicloSeleccionado,
                      onChanged: (v) => setState(() => _cicloSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildDropdownField('Tipo de Ingreso', 'Seleccionar...', Icons.login_rounded, p,
                      items: _tiposIngreso,
                      value: _tipoIngresoSeleccionado,
                      onChanged: (v) => setState(() => _tipoIngresoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildDropdownField('Nivel Educativo', 'Seleccionar nivel...', Icons.school_outlined, p,
                      items: _niveles,
                      value: _nivelSeleccionado,
                      onChanged: (v) {
                        setState(() {
                          _nivelSeleccionado = v;
                          _gradoSeleccionado = null;
                        });
                      },
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildDropdownField('Grado', 'Seleccionar grado...', Icons.grade_rounded, p,
                      items: _nivelSeleccionado != null ? _gradosPorNivel[_nivelSeleccionado]! : [],
                      value: _gradoSeleccionado,
                      onChanged: (v) => setState(() => _gradoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildDropdownField('Sección / Grupo', 'Seleccionar sección...', Icons.view_column_rounded, p,
                      items: _secciones,
                      value: _seccionSeleccionada,
                      onChanged: (v) => setState(() => _seccionSeleccionada = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildDropdownField('Turno', 'Seleccionar turno...', Icons.schedule_rounded, p,
                      items: _turnos,
                      value: _turnoSeleccionado,
                      onChanged: (v) => setState(() => _turnoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 2. DATOS DEL ALUMNO (SIMPLIFICADO)
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Datos del Alumno',
              Icons.child_care_rounded,
              p.infoBlue,
              p,
              [
                _buildFormRow(p, [
                  _buildFormField('Nombre(s)', 'Ej. María José', Icons.person_outline_rounded, p, controller: _nombreController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Apellido(s)', 'Ej. Flores Martínez', Icons.person_outline_rounded, p, controller: _apellidoController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('DNI / Identificación', 'Ej. 0501-2010-03127', Icons.badge_outlined, p, controller: _dniController, isMono: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFechaNacimientoField(p),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Lugar de Nacimiento', 'Ej. Tegucigalpa, M.D.C.', Icons.location_city_outlined, p, controller: _lugarNacController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Nacionalidad', 'Hondureña', Icons.flag_outlined, p, controller: _nacionalidadController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 3. INFORMACIÓN DE SALUD (SIMPLIFICADA)
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Observaciones de Salud Importantes',
              Icons.medical_services_outlined,
              p.errorRed,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.errorRed.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Indique únicamente condiciones críticas: alergias severas, enfermedades crónicas o medicamentos de uso diario. Dejar en blanco si no aplica.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.errorRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormField(
                  'Observaciones de Salud',
                  'Ej. Alergia severa a la penicilina, asmático...',
                  Icons.notes_rounded,
                  p,
                  controller: _observacionesSaludController,
                  isMultiline: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 4. TUTOR RESPONSABLE (UNIFICADO)
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Datos del Tutor Responsable',
              Icons.family_restroom_rounded,
              p.warningAmber,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.warningAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.warningAmber.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.warningAmber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registre los datos de la persona responsable legal del alumno. Todos los campos son obligatorios.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.warningAmber, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormRow(p, [
                  _buildDropdownField('Parentesco', 'Seleccionar...', Icons.badge_outlined, p,
                      items: _parentescos,
                      value: _tutorParentescoSeleccionado,
                      onChanged: (v) => setState(() => _tutorParentescoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Nombre Completo', 'Ej. Juan Pérez Rodríguez', Icons.person_outline_rounded, p,
                      controller: _tutorNombreController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Teléfono de Contacto', 'Ej. +504 9999-9999', Icons.phone_outlined, p,
                      controller: _tutorTelefonoController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Correo Electrónico', 'Ej. tutor@email.com', Icons.email_outlined, p,
                      controller: _tutorEmailController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 5. DIRECCIÓN DEL ALUMNO
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Dirección de Residencia',
              Icons.home_work_outlined,
              p.accentPurpleLight,
              p,
              [
                _buildFormField('Calle y Número / Colonia', 'Ej. Barrio El Centro, Casa #123', Icons.location_on_outlined, p,
                    controller: _direccionController,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                const SizedBox(height: 16),
                _buildFormRow(p, [
                  _buildFormField('Municipio', 'Ej. Tegucigalpa', Icons.location_city_outlined, p,
                      controller: _municipioController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Departamento', 'Ej. Francisco Morazán', Icons.map_outlined, p,
                      controller: _departamentoController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Referencia / Punto de referencia', 'Ej. Frente al parque central', Icons.near_me_outlined, p,
                      controller: _coloniaController),
                  _buildFormField('Código Postal (Opcional)', 'Ej. 11101', Icons.markunread_mailbox_outlined, p,
                      controller: _cpController),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 6. CONTROL FINANCIERO (NUEVO)
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Control Financiero',
              Icons.account_balance_wallet_rounded,
              p.successGreen,
              p,
              [
                // Toggle de pago de inscripción
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _pagoInscripcionRealizado
                          ? [p.successGreen.withValues(alpha: 0.15), p.successGreen.withValues(alpha: 0.05)]
                          : [p.bgTertiary, p.bgTertiary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _pagoInscripcionRealizado
                          ? p.successGreen.withValues(alpha: 0.5)
                          : p.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _pagoInscripcionRealizado
                              ? p.successGreen.withValues(alpha: 0.2)
                              : p.bgSecondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _pagoInscripcionRealizado ? Icons.check_circle_rounded : Icons.cancel_outlined,
                          color: _pagoInscripcionRealizado ? p.successGreen : p.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuota de Inscripción',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _pagoInscripcionRealizado ? 'PAGO VERIFICADO' : 'Pendiente de pago',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _pagoInscripcionRealizado ? p.successGreen : p.warningAmber,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _pagoInscripcionRealizado,
                        onChanged: (v) => setState(() => _pagoInscripcionRealizado = v),
                        activeThumbColor: p.successGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_pagoInscripcionRealizado) ...[
                  _buildDropdownField('Método de Pago', 'Seleccionar método...', Icons.payment_rounded, p,
                      items: _metodosPago,
                      value: _metodoPagoSeleccionado,
                      onChanged: (v) => setState(() => _metodoPagoSeleccionado = v),
                      validator: (v) => _pagoInscripcionRealizado && (v == null || v.isEmpty) ? 'Seleccione un método' : null),
                  const SizedBox(height: 16),
                ],
                _buildDropdownField('Plan de Pagos / Colegiatura', 'Seleccionar plan...', Icons.payments_rounded, p,
                    items: _planesPagos,
                    value: _planPagosSeleccionado,
                    onChanged: (v) => setState(() => _planPagosSeleccionado = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════
            // 7. DOCUMENTOS REQUERIDOS
            // ══════════════════════════════════════════════════
            _buildFormSection(
              'Documentos Requeridos',
              Icons.folder_open_rounded,
              p.accentPurpleDeep,
              p,
              [
                _buildDocumentUploadRow(p, [
                  _buildDocumentCard('Partida de Nacimiento', 'PDF, JPG', Icons.description_outlined, true, p),
                  _buildDocumentCard('DNI del Alumno', 'PDF', Icons.badge_outlined, true, p),
                  _buildDocumentCard('Cartilla de Vacunación', 'PDF, JPG', Icons.vaccines_outlined, false, p),
                  _buildDocumentCard('Comprobante de Domicilio', 'PDF, JPG', Icons.receipt_long_outlined, false, p),
                ]),
                _buildDocumentUploadRow(p, [
                  _buildDocumentCard('DNI del Tutor', 'PDF', Icons.badge_outlined, false, p),
                  _buildDocumentCard('Boletín / Certificado Anterior', 'PDF', Icons.school_outlined, false, p),
                  _buildDocumentCard('Fotografía Tamaño Carnet', 'JPG, PNG', Icons.photo_camera_outlined, false, p),
                  _buildDocumentCard('Constancia de Buena Salud', 'PDF', Icons.local_hospital_outlined, false, p),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            // ── BOTONES DE ACCIÓN ──
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.bgTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.borderLight),
                    ),
                    child: TextButton.icon(
                      onPressed: _guardarBorrador,
                      icon: Icon(Icons.save_outlined, size: 18, color: p.textPrimary),
                      label: Text('Guardar Borrador',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: p.accentPurple.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _validarYRegistrar,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                      label: Text('Registrar Matrícula',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FOLIO BANNER
  // ═══════════════════════════════════════════════════════════

  Widget _buildFolioBanner(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.accentPurple.withValues(alpha: 0.15), p.accentPurpleDark.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accentPurple.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: p.accentPurple.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accentPurple, p.accentPurpleDark],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: p.accentPurple.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.tag_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NÚMERO DE MATRÍCULA / FOLIO',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: p.textMuted,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _folioMatricula,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: p.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.successGreen,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: p.successGreen.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AUTO',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: p.successGreen,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MÉTODO: GUARDAR EN SUPABASE
  // ═══════════════════════════════════════════════════════════

  Future<void> _validarYRegistrar() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complete todos los campos obligatorios'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

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

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Matrícula $_folioMatricula registrada correctamente'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _guardarBorrador() async {
    final draft = {
      'folio': _folioMatricula,
      'guardado_en': DateTime.now().toIso8601String(),
      'ciclo': _cicloSeleccionado,
      'nivel': _nivelSeleccionado,
      'grado': _gradoSeleccionado,
      'seccion': _seccionSeleccionada,
      'turno': _turnoSeleccionado,
      'tipo_ingreso': _tipoIngresoSeleccionado,
      'pago_inscripcion': _pagoInscripcionRealizado,
      'metodo_pago': _metodoPagoSeleccionado,
      'plan_pagos': _planPagosSeleccionado,
      'tutor_parentesco': _tutorParentescoSeleccionado,
      'alumno_nombre': _nombreController.text.trim(),
      'alumno_apellido': _apellidoController.text.trim(),
      'alumno_dni': _dniController.text.trim(),
      'alumno_fecha_nacimiento': _fechaNacController.text.trim(),
      'alumno_lugar_nacimiento': _lugarNacController.text.trim(),
      'alumno_nacionalidad': _nacionalidadController.text.trim(),
      'observaciones_salud': _observacionesSaludController.text.trim(),
      'tutor_nombre': _tutorNombreController.text.trim(),
      'tutor_telefono': _tutorTelefonoController.text.trim(),
      'tutor_email': _tutorEmailController.text.trim(),
      'direccion_calle': _direccionController.text.trim(),
      'direccion_municipio': _municipioController.text.trim(),
      'direccion_departamento': _departamentoController.text.trim(),
      'direccion_referencia': _coloniaController.text.trim(),
      'direccion_cp': _cpController.text.trim(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final borradoresJson = prefs.getString('matricula_borradores') ?? '[]';
      final List<dynamic> borradores = jsonDecode(borradoresJson);
      final idx = borradores.indexWhere((b) => b['folio'] == _folioMatricula);
      if (idx != -1) {
        borradores[idx] = draft;
      } else {
        borradores.add(draft);
      }
      await prefs.setString('matricula_borradores', jsonEncode(borradores));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ðŸ’¾ Borrador $_folioMatricula guardado (${borradores.length} en total)'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar borrador: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  // ═══════════════════════════════════════════════════════════
  // REGISTRO COMPONENTS
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeaderSection(String title, String subtitle, {required IconData icon, required ThemePalette p}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: p.accentPurple.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.syne(fontSize: 34, fontWeight: FontWeight.w900, color: p.textPrimary, letterSpacing: -0.8, height: 1.1)),
              const SizedBox(height: 8),
              Text(subtitle, style: GoogleFonts.dmSans(fontSize: 14, color: p.textMuted, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationSteps(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.borderLight)),
      child: Row(
        children: [
          _buildStepIndicator(1, 'Inscripción', true, Icons.assignment_ind_rounded, p),
          _buildStepConnector(true, p),
          _buildStepIndicator(2, 'Alumno', false, Icons.child_care_rounded, p),
          _buildStepConnector(false, p),
          _buildStepIndicator(3, 'Tutor', false, Icons.family_restroom_rounded, p),
          _buildStepConnector(false, p),
          _buildStepIndicator(4, 'Financiero', false, Icons.account_balance_wallet_rounded, p),
          _buildStepConnector(false, p),
          _buildStepIndicator(5, 'Documentos', false, Icons.folder_outlined, p),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active, IconData icon, ThemePalette p) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: active ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]) : null,
              color: active ? null : p.bgTertiary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? Colors.transparent : p.borderLight),
              boxShadow: active ? [BoxShadow(color: p.accentPurple.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
            ),
            child: Icon(icon, color: active ? Colors.white : p.textMuted, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? p.textPrimary : p.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool completed, ThemePalette p) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: completed ? LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]) : null,
          color: completed ? null : p.bgTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, IconData icon, Color color, ThemePalette p, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.06), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3))),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(title, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: p.textPrimary, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormRow(ThemePalette p, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .asMap()
            .entries
            .map((e) => Expanded(
                  child: Padding(
                    padding: e.key < children.length - 1 ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
                    child: e.value,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFormField(String label, String hint, IconData icon, ThemePalette p, {
    TextEditingController? controller,
    bool isDropdown = false,
    bool isMultiline = false,
    bool isMono = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.borderLight)),
          child: TextFormField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            validator: validator,
            style: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary).copyWith(fontFamily: isMono ? 'monospace' : null),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: p.textDark),
              prefixIcon: Icon(icon, color: p.textMuted, size: 18),
              suffixIcon: isDropdown ? Icon(Icons.arrow_drop_down_rounded, color: p.textMuted) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: p.errorRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFechaNacimientoField(ThemePalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FECHA DE NACIMIENTO', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.borderLight)),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.cake_outlined, color: p.textMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _fechaNacController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    _FechaNacimientoInputFormatter(),
                  ],
                  maxLength: 10,
                  style: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: 'DD/MM/AAAA',
                    hintStyle: GoogleFonts.dmSans(fontSize: 14, color: p.textDark),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    counterText: '',
                    errorStyle: GoogleFonts.dmSans(fontSize: 11, color: p.errorRed),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obligatorio';
                    if (v.length != 10) return 'Formato inválido';
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.calendar_today_rounded, color: p.accentPurple, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String hint, IconData icon, ThemePalette p, {
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.borderLight)),
          child: DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: value,
            dropdownColor: p.bgTertiary,
            style: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: p.textDark),
              prefixIcon: Icon(icon, color: p.textMuted, size: 18),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: p.textMuted, size: 24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: p.errorRed),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary)),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
        if (isOptional)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Campo opcional', style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildDocumentUploadRow(ThemePalette p, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: children
            .asMap()
            .entries
            .map((e) => Expanded(
                  child: Padding(
                    padding: e.key < children.length - 1 ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
                    child: e.value,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String format, IconData icon, bool uploaded, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uploaded ? p.successGreen.withValues(alpha: 0.4) : p.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: uploaded ? p.successGreen.withValues(alpha: 0.15) : p.accentPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: uploaded ? p.successGreen.withValues(alpha: 0.3) : p.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Icon(uploaded ? Icons.check_circle_rounded : icon, color: uploaded ? p.successGreen : p.accentPurple, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: p.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(format, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.textDark, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Text(uploaded ? 'Cargado' : 'Pendiente',
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold,
                  color: uploaded ? p.successGreen : p.warningAmber, letterSpacing: 0.5)),
        ],
      ),
    );
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