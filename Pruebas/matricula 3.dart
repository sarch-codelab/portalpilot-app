import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/theme/app_theme.dart';
import 'package:portal_pilot_app/DB/db.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════

void main() {
  runApp(const PortalPilotApp());
}

class PortalPilotApp extends StatelessWidget {
  const PortalPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Portal Pilot',
          themeMode: mode,
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF000000),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              secondary: Color(0xFFA78BFA),
            ),
          ),
          theme: ThemeData.light(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFFF4F8FF),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              secondary: Color(0xFF60A5FA),
            ),
          ),
          home: const RegistroEstudiantilScreen(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REGISTRO ESTUDIANTIL SCREEN
// ═══════════════════════════════════════════════════════════

class RegistroEstudiantilScreen extends StatefulWidget {
  const RegistroEstudiantilScreen({super.key});

  @override
  State<RegistroEstudiantilScreen> createState() => _RegistroEstudiantilScreenState();
}

class _RegistroEstudiantilScreenState extends State<RegistroEstudiantilScreen> {
  // ── CONTROLLERS NUEVO REGISTRO ──
  final _nombreController = TextEditingController();
  final _apellidoPController = TextEditingController();
  final _apellidoMController = TextEditingController();
  final _curpController = TextEditingController();
  final _fechaNacController = TextEditingController();
  final _lugarNacController = TextEditingController();
  String? _generoSeleccionado;
  final _nacionalidadController = TextEditingController(text: 'Mexicana');
  String? _tipoSangreSeleccionado;
  final _nssController = TextEditingController();

  // Médicos
  final _alergiasController = TextEditingController();
  final _condicionesController = TextEditingController();
  final _medicamentosController = TextEditingController();
  final _pesoController = TextEditingController();
  final _estaturaController = TextEditingController();
  final _discapacidadController = TextEditingController(text: 'Ninguna');
  final _obsMedicasController = TextEditingController();

  // Tutores
  final _nombrePadreController = TextEditingController();
  final _nombreMadreController = TextEditingController();
  final _nombreTutorController = TextEditingController();
  final _parentescoTutorController = TextEditingController();
  final _ocupacionPadreController = TextEditingController();
  final _ocupacionMadreController = TextEditingController();
  final _ocupacionTutorController = TextEditingController();
  final _curpTutorController = TextEditingController();
  final _telPadreController = TextEditingController();
  final _telMadreController = TextEditingController();
  final _telTutorController = TextEditingController();
  final _telCasaController = TextEditingController();
  final _emailPadreController = TextEditingController();
  final _emailMadreController = TextEditingController();
  final _emailTutorController = TextEditingController();
  final _telTrabajoController = TextEditingController();

  // Emergencia
  final _emergNombreController = TextEditingController();
  final _emergParentescoController = TextEditingController();
  final _emergTel1Controller = TextEditingController();
  final _emergTel2Controller = TextEditingController();
  final _emergDireccionController = TextEditingController();
  final _emergHorarioController = TextEditingController();

  // Dirección
  final _direccionController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _cpController = TextEditingController();
  final _alcaldiaController = TextEditingController();
  final _estadoController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // ── OPCIONES ──
  final List<String> _generos = ['Masculino', 'Femenino'];
  final List<String> _tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPController.dispose();
    _apellidoMController.dispose();
    _curpController.dispose();
    _fechaNacController.dispose();
    _lugarNacController.dispose();
    _nacionalidadController.dispose();
    _nssController.dispose();
    _alergiasController.dispose();
    _condicionesController.dispose();
    _medicamentosController.dispose();
    _pesoController.dispose();
    _estaturaController.dispose();
    _discapacidadController.dispose();
    _obsMedicasController.dispose();
    _nombrePadreController.dispose();
    _nombreMadreController.dispose();
    _nombreTutorController.dispose();
    _parentescoTutorController.dispose();
    _ocupacionPadreController.dispose();
    _ocupacionMadreController.dispose();
    _ocupacionTutorController.dispose();
    _curpTutorController.dispose();
    _telPadreController.dispose();
    _telMadreController.dispose();
    _telTutorController.dispose();
    _telCasaController.dispose();
    _emailPadreController.dispose();
    _emailMadreController.dispose();
    _emailTutorController.dispose();
    _telTrabajoController.dispose();
    _emergNombreController.dispose();
    _emergParentescoController.dispose();
    _emergTel1Controller.dispose();
    _emergTel2Controller.dispose();
    _emergDireccionController.dispose();
    _emergHorarioController.dispose();
    _direccionController.dispose();
    _coloniaController.dispose();
    _cpController.dispose();
    _alcaldiaController.dispose();
    _estadoController.dispose();
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
              p.accentPurple.withOpacity(p.isDark ? 0.03 : 0.06),
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
            _buildHeaderSection('Nuevo Registro Estudiantil', 'Formulario completo de inscripción con validación automática.',
                icon: Icons.person_add_alt_1_rounded, p: p),
            const SizedBox(height: 36),
            _buildRegistrationSteps(p),
            const SizedBox(height: 32),

            // ── DATOS DEL ALUMNO ──
            _buildFormSection(
              'Datos del Alumno',
              Icons.child_care_rounded,
              p.accentPurple,
              p,
              [
                _buildFormRow(p, [
                  _buildFormField('Nombre(s)', 'Ej. Gissel Sofia', Icons.person_outline_rounded, p, controller: _nombreController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Apellido(s)', 'Ej. Guzman Castro', Icons.person_outline_rounded, p, controller: _apellidoPController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Tabla Innecesaria', 'Quitar Cuadro', Icons.person_outline_rounded, p, controller: _apellidoMController),
                  _buildFormField('DNI', '0501 2010 03127', Icons.badge_outlined, p, controller: _curpController, isMono: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFechaNacimientoField(p),
                  _buildFormField('Lugar de Nacimiento', 'Ej. Ciudad de México', Icons.location_city_outlined, p, controller: _lugarNacController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildDropdownField('Género', 'Seleccionar...', Icons.wc_outlined, p,
                      items: _generos,
                      value: _generoSeleccionado,
                      onChanged: (v) => setState(() => _generoSeleccionado = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Nacionalidad', 'Hondureña', Icons.flag_outlined, p, controller: _nacionalidadController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildDropdownField(
                    'Tipo de Sangre (Opcional)',
                    'Seleccionar...',
                    Icons.bloodtype_outlined,
                    p,
                    items: _tiposSangre,
                    value: _tipoSangreSeleccionado,
                    onChanged: (v) => setState(() => _tipoSangreSeleccionado = v),
                    isOptional: true,
                  ),
                  _buildFormField('NSS (Opcional)', 'Número de Seguridad Social', Icons.health_and_safety_outlined, p, controller: _nssController),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ── INFORMACIÓN MÉDICA ──
            _buildFormSection(
              'Información Médica',
              Icons.medical_services_outlined,
              p.errorRed,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.errorRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.errorRed.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Todos los campos médicos son opcionales. Dejar en blanco si no padece problemas médicos.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.errorRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormField('Alergias', 'Ej. Penicilina, mariscos, polen...', Icons.warning_amber_rounded, p,
                    controller: _alergiasController, isMultiline: true),
                _buildHintText('Dejar en blanco si no padece de problemas médicos.', p),
                const SizedBox(height: 12),
                _buildFormField('Condiciones Médicas', 'Ej. Asma, diabetes, epilepsia...', Icons.medication_outlined, p,
                    controller: _condicionesController, isMultiline: true),
                _buildHintText('Dejar en blanco si no padece de problemas médicos.', p),
                const SizedBox(height: 12),
                _buildFormField('Medicamentos Actuales', 'Ej. Salbutamol inhalador cada 8 horas...', Icons.local_pharmacy_outlined, p,
                    controller: _medicamentosController, isMultiline: true),
                _buildHintText('Dejar en blanco si no padece de problemas médicos.', p),
                const SizedBox(height: 12),
                _buildFormRow(p, [
                  _buildFormField('Peso (kg)', 'Ej. 35', Icons.monitor_weight_outlined, p, controller: _pesoController),
                  _buildFormField('Estatura (cm)', 'Ej. 142', Icons.height_rounded, p, controller: _estaturaController),
                  _buildFormField('Discapacidad', 'Ninguna', Icons.accessible_forward_outlined, p, controller: _discapacidadController),
                ]),
                const SizedBox(height: 12),
                _buildFormField('Observaciones Médicas Adicionales', 'Cualquier información relevante...', Icons.notes_rounded, p,
                    controller: _obsMedicasController, isMultiline: true),
                _buildHintText('Dejar en blanco si no padece de problemas médicos.', p),
              ],
            ),
            const SizedBox(height: 24),

            // ── PADRE / MADRE / TUTOR ──
            _buildFormSection(
              'Datos del Padre / Madre / Tutor',
              Icons.family_restroom_rounded,
              p.infoBlue,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.infoBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.infoBlue.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.infoBlue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Debe llenar al menos uno: Padre, Madre o Tutor. Si solo llena Tutor, ese será obligatorio.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.infoBlue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Nombres
                _buildFormRow(p, [
                  _buildFormField('Nombre Completo del Padre', 'Ej. Juan Mendoza Pérez', Icons.man_outlined, p,
                      controller: _nombrePadreController),
                  _buildFormField('Nombre Completo de la Madre', 'Ej. María López García', Icons.woman_outlined, p,
                      controller: _nombreMadreController),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Nombre del Tutor', 'Ej. Roberto Mendoza López', Icons.person_outline_rounded, p,
                      controller: _nombreTutorController),
                  _buildFormField('Parentesco del Tutor', 'Ej. Tío, Abuelo...', Icons.badge_outlined, p,
                      controller: _parentescoTutorController),
                ]),
                // Ocupaciones
                _buildFormRow(p, [
                  _buildFormField('Ocupación del Padre', 'Ej. Ingeniero', Icons.work_outline_rounded, p,
                      controller: _ocupacionPadreController),
                  _buildFormField('Ocupación de la Madre', 'Ej. Doctora', Icons.work_outline_rounded, p,
                      controller: _ocupacionMadreController),
                  _buildFormField('Ocupación del Tutor', 'Ej. Arquitecto', Icons.work_outline_rounded, p,
                      controller: _ocupacionTutorController),
                ]),
                // Teléfonos
                _buildFormRow(p, [
                  _buildFormField('Teléfono del Padre', '55 1111 1111', Icons.phone_outlined, p, controller: _telPadreController),
                  _buildFormField('Teléfono de la Madre', '55 2222 2222', Icons.phone_outlined, p, controller: _telMadreController),
                  _buildFormField('Teléfono del Tutor', '55 3333 3333', Icons.phone_outlined, p, controller: _telTutorController),
                ]),
                // Emails
                _buildFormRow(p, [
                  _buildFormField('Email del Padre', 'padre@email.com', Icons.email_outlined, p, controller: _emailPadreController),
                  _buildFormField('Email de la Madre', 'madre@email.com', Icons.email_outlined, p, controller: _emailMadreController),
                  _buildFormField('Email del Tutor', 'tutor@email.com', Icons.email_outlined, p, controller: _emailTutorController),
                ]),
                // DNI Tutor y teléfono trabajo
                _buildFormRow(p, [
                  _buildFormField('DNI del Tutor', '0501 1990 07584', Icons.badge_outlined, p,
                      controller: _curpTutorController, isMono: true),
                  _buildFormField('Teléfono de Casa / Trabajo', '55 8765 4321', Icons.business_outlined, p,
                      controller: _telTrabajoController),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ── CONTACTO DE EMERGENCIA (NO OBLIGATORIO) ──
            _buildFormSection(
              'Contacto de Emergencia (Opcional)',
              Icons.emergency_outlined,
              p.warningAmber,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.warningAmber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.warningAmber.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: p.warningAmber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este apartado es opcional. Puede dejarlo en blanco.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.warningAmber, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormRow(p, [
                  _buildFormField('Nombre del Contacto', 'Ej. Roberto Mendoza López', Icons.person_outline_rounded, p,
                      controller: _emergNombreController),
                  _buildFormField('Parentesco', 'Tío, Abuelo, Vecino...', Icons.badge_outlined, p, controller: _emergParentescoController),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Teléfono Principal', '55 5555 5555', Icons.phone_outlined, p, controller: _emergTel1Controller),
                  _buildFormField('Teléfono Alternativo', '55 4444 4444', Icons.phone_android_outlined, p, controller: _emergTel2Controller),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Dirección', 'Calle, Número, Colonia, CP', Icons.home_outlined, p, controller: _emergDireccionController),
                  _buildFormField('Horario Disponible', 'Lun-Vie 8:00-18:00', Icons.schedule_outlined, p, controller: _emergHorarioController),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ── DIRECCIÓN DEL ALUMNO (OBLIGATORIO) ──
            _buildFormSection(
              'Dirección del Alumno',
              Icons.home_work_outlined,
              p.accentPurpleLight,
              p,
              [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.successGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.successGreen.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: p.successGreen, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Campo obligatorio. Toda la información de dirección es requerida.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.successGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormField('Calle y Número', 'Ej. Av. Insurgentes Sur 1234', Icons.location_on_outlined, p,
                    controller: _direccionController,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                const SizedBox(height: 16),
                _buildFormRow(p, [
                  _buildFormField('Colonia', 'Ej. Del Valle Centro', Icons.location_city_outlined, p,
                      controller: _coloniaController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Código Postal', 'Ej. 03100', Icons.markunread_mailbox_outlined, p,
                      controller: _cpController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Alcaldía / Municipio', 'Ej. Benito Juárez', Icons.location_city_outlined, p,
                      controller: _alcaldiaController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Estado', 'Ciudad de México', Icons.map_outlined, p,
                      controller: _estadoController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ── DOCUMENTOS ──
            _buildFormSection(
              'Documentos Requeridos',
              Icons.folder_open_rounded,
              p.successGreen,
              p,
              [
                _buildDocumentUploadRow(p, [
                  _buildDocumentCard('Acta de Nacimiento', 'PDF, JPG', Icons.description_outlined, true, p),
                  _buildDocumentCard('DNI del Alumno', 'PDF', Icons.badge_outlined, true, p),
                  _buildDocumentCard('Cartilla de Vacunación', 'PDF, JPG', Icons.vaccines_outlined, false, p),
                  _buildDocumentCard('Comprobante de Domicilio', 'PDF, JPG', Icons.receipt_long_outlined, false, p),
                ]),
                _buildDocumentUploadRow(p, [
                  _buildDocumentCard('DNI del Tutor', 'PDF', Icons.badge_outlined, false, p),
                  _buildDocumentCard('Certificado Anterior', 'PDF', Icons.school_outlined, false, p),
                  _buildDocumentCard('Fotografía', 'JPG, PNG', Icons.photo_camera_outlined, false, p),
                  _buildDocumentCard('Constancia Médica', 'PDF', Icons.local_hospital_outlined, false, p),
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
                      onPressed: () {},
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
                        BoxShadow(color: p.accentPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _validarYRegistrar,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                      label: Text('Registrar Alumno',
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
  // MÉTODO: GUARDAR EN SUPABASE
  // ═══════════════════════════════════════════════════════════

  Future<void> _validarYRegistrar() async {
    final padreLleno = _nombrePadreController.text.trim().isNotEmpty;
    final madreLlena = _nombreMadreController.text.trim().isNotEmpty;
    final tutorLleno = _nombreTutorController.text.trim().isNotEmpty;

    if (!padreLleno && !madreLlena && !tutorLleno) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Debe llenar al menos uno: Padre, Madre o Tutor'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!padreLleno && !madreLlena && tutorLleno) {
      if (_ocupacionTutorController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ocupación del Tutor es obligatoria'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

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

      String tutorNombre;
      String tutorParentesco;
      String tutorTelefono;
      String tutorEmail;
      String tutorOcupacion;
      String tutorCurp;

      if (padreLleno) {
        tutorNombre = _nombrePadreController.text.trim();
        tutorParentesco = 'Padre';
        tutorTelefono = _telPadreController.text.trim();
        tutorEmail = _emailPadreController.text.trim();
        tutorOcupacion = _ocupacionPadreController.text.trim();
        tutorCurp = ''; 
      } else if (madreLlena) {
        tutorNombre = _nombreMadreController.text.trim();
        tutorParentesco = 'Madre';
        tutorTelefono = _telMadreController.text.trim();
        tutorEmail = _emailMadreController.text.trim();
        tutorOcupacion = _ocupacionMadreController.text.trim();
        tutorCurp = '';
      } else {
        tutorNombre = _nombreTutorController.text.trim();
        tutorParentesco = _parentescoTutorController.text.trim();
        tutorTelefono = _telTutorController.text.trim();
        tutorEmail = _emailTutorController.text.trim();
        tutorOcupacion = _ocupacionTutorController.text.trim();
        tutorCurp = _curpTutorController.text.trim();
      }

      await PortalPilotDB.insertMatriculaCompleta(
        alumnoNombre: _nombreController.text.trim(),
        alumnoApellidoPaterno: _apellidoPController.text.trim(),
        alumnoApellidoMaterno: _apellidoMController.text.trim(),
        alumnoCurp: _curpController.text.trim(),
        alumnoFechaNacimiento: _fechaNacController.text.trim(),
        alumnoLugarNacimiento: _lugarNacController.text.trim(),
        alumnoGenero: _generoSeleccionado ?? '',
        alumnoNacionalidad: _nacionalidadController.text.trim(),
        alumnoTipoSangre: _tipoSangreSeleccionado ?? '',
        alumnoNss: _nssController.text.trim(),
        alumnoAlergias: _alergiasController.text.trim(),
        alumnoCondiciones: _condicionesController.text.trim(),
        alumnoMedicamentos: _medicamentosController.text.trim(),
        alumnoPeso: _pesoController.text.trim(),
        alumnoEstatura: _estaturaController.text.trim(),
        alumnoDiscapacidad: _discapacidadController.text.trim(),
        alumnoObsMedicas: _obsMedicasController.text.trim(),
        tutorNombre: tutorNombre,
        tutorParentesco: tutorParentesco,
        tutorTelefono: tutorTelefono,
        tutorEmail: tutorEmail,
        tutorOcupacion: tutorOcupacion,
        tutorCurp: tutorCurp,
        direccionCalle: _direccionController.text.trim(),
        direccionColonia: _coloniaController.text.trim(),
        direccionCP: _cpController.text.trim(),
        direccionAlcaldia: _alcaldiaController.text.trim(),
        direccionEstado: _estadoController.text.trim(),
        emergNombre: _emergNombreController.text.trim(),
        emergParentesco: _emergParentescoController.text.trim(),
        emergTel1: _emergTel1Controller.text.trim(),
        emergTel2: _emergTel2Controller.text.trim(),
        emergDireccion: _emergDireccionController.text.trim(),
        emergHorario: _emergHorarioController.text.trim(),
        empresaCodigo: empresaCodigo,
      );

      if (mounted) Navigator.pop(context);
      _limpiarFormulario();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Alumno registrado correctamente en Supabase'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  void _limpiarFormulario() {
    _nombreController.clear();
    _apellidoPController.clear();
    _apellidoMController.clear();
    _curpController.clear();
    _fechaNacController.clear();
    _lugarNacController.clear();
    setState(() => _generoSeleccionado = null);
    _nacionalidadController.text = 'Hondureña';
    setState(() => _tipoSangreSeleccionado = null);
    _nssController.clear();
    _alergiasController.clear();
    _condicionesController.clear();
    _medicamentosController.clear();
    _pesoController.clear();
    _estaturaController.clear();
    _discapacidadController.text = 'Ninguna';
    _obsMedicasController.clear();
    _nombrePadreController.clear();
    _nombreMadreController.clear();
    _nombreTutorController.clear();
    _parentescoTutorController.clear();
    _ocupacionPadreController.clear();
    _ocupacionMadreController.clear();
    _ocupacionTutorController.clear();
    _curpTutorController.clear();
    _telPadreController.clear();
    _telMadreController.clear();
    _telTutorController.clear();
    _telCasaController.clear();
    _emailPadreController.clear();
    _emailMadreController.clear();
    _emailTutorController.clear();
    _telTrabajoController.clear();
    _emergNombreController.clear();
    _emergParentescoController.clear();
    _emergTel1Controller.clear();
    _emergTel2Controller.clear();
    _emergDireccionController.clear();
    _emergHorarioController.clear();
    _direccionController.clear();
    _coloniaController.clear();
    _cpController.clear();
    _alcaldiaController.clear();
    _estadoController.clear();
  }

  Widget _buildHintText(String text, ThemePalette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          color: p.textMuted,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
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
            boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
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
          _buildStepIndicator(1, 'Alumno', true, Icons.child_care_rounded, p),
          _buildStepConnector(true, p),
          _buildStepIndicator(2, 'Médica', false, Icons.medical_services_outlined, p),
          _buildStepConnector(false, p),
          _buildStepIndicator(3, 'Tutores', false, Icons.family_restroom_rounded, p),
          _buildStepConnector(false, p),
          _buildStepIndicator(4, 'Dirección', false, Icons.home_work_outlined, p),
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
              boxShadow: active ? [BoxShadow(color: p.accentPurple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3))),
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
        border: Border.all(color: uploaded ? p.successGreen.withOpacity(0.4) : p.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: uploaded ? p.successGreen.withOpacity(0.15) : p.accentPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: uploaded ? p.successGreen.withOpacity(0.3) : p.accentPurple.withOpacity(0.3)),
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
// THEME PALETTE
// ═══════════════════════════════════════════════════════════

class ThemePalette {
  final bool isDark;
  ThemePalette({required this.isDark});

  Color get bgPrimary => isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  Color get bgSecondary => isDark ? const Color(0xFF080808) : const Color(0xFFEDEDED);
  Color get bgTertiary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE5E5EA);
  Color get cardColor => isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);
  Color get accentPurpleLight => const Color(0xFFA78BFA);
  Color get accentPurpleDeep => const Color(0xFF5B21B6);

  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textSecondary => isDark ? const Color(0xFFE5E5E5) : const Color(0xFF334155);
  Color get textMuted => isDark ? const Color(0xFFA3A3A3) : const Color(0xFF64748B);
  Color get textDark => isDark ? const Color(0xFF525252) : const Color(0xFF94A3B8);

  Color get successGreen => const Color(0xFF10B981);
  Color get errorRed => const Color(0xFFEF4444);
  Color get warningAmber => const Color(0xFFF59E0B);
  Color get infoBlue => const Color(0xFF3B82F6);

  Color get borderLight => isDark ? const Color(0x29FFFFFF) : const Color(0x1A000000);
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