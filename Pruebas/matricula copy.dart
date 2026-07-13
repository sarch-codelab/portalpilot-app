import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/theme/app_theme.dart';
import 'package:portal_pilot_app/DB/db.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// Areas/Educacion/Matricula/matricula.dart
// ═══════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════
// THEME PROVIDER
// ═══════════════════════════════════════════════════════════


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

class _RegistroEstudiantilScreenState extends State<RegistroEstudiantilScreen>
    with SingleTickerProviderStateMixin {
  bool _isSidebarExpanded = true;
  int _selectedMenuIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── FILTROS DE ESTUDIANTES ──
  String _filtroNivel = 'Todos';
  String _filtroGrado = 'Todos';
  String _filtroSeccion = 'Todas';

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

  // ── DATOS DE PRUEBA ──
  final List<Map<String, dynamic>> _estudiantes = [
    {'nombre': 'Carlos Mendoza López', 'grado': '6° Primaria', 'seccion': 'A', 'nivel': 'Básica', 'prom': '9.2', 'color': 'success', 'tutor': 'María López'},
    {'nombre': 'Ana Sofía Ramírez Torres', 'grado': '5° Primaria', 'seccion': 'B', 'nivel': 'Básica', 'prom': '8.8', 'color': 'success', 'tutor': 'Juan Ramírez'},
    {'nombre': 'Diego Hernández Ruiz', 'grado': '4° Primaria', 'seccion': 'A', 'nivel': 'Básica', 'prom': '7.5', 'color': 'warning', 'tutor': 'Laura Hernández'},
    {'nombre': 'Valentina García Morales', 'grado': '3° Primaria', 'seccion': 'C', 'nivel': 'Básica', 'prom': '9.5', 'color': 'success', 'tutor': 'Roberto García'},
    {'nombre': 'Mateo Sánchez Flores', 'grado': '2° Primaria', 'seccion': 'A', 'nivel': 'Básica', 'prom': '6.8', 'color': 'error', 'tutor': 'Patricia Sánchez'},
    {'nombre': 'Isabella Torres Ruiz', 'grado': '1° Secundaria', 'seccion': 'Única', 'nivel': 'Media', 'prom': '8.4', 'color': 'success', 'tutor': 'Laura Torres'},
    {'nombre': 'Sebastián Morales', 'grado': '2° Secundaria', 'seccion': '1', 'nivel': 'Media', 'prom': '9.1', 'color': 'success', 'tutor': 'Pedro Morales'},
    {'nombre': 'Renata Vargas', 'grado': '3° Bachillerato', 'seccion': '2', 'nivel': 'Superior', 'prom': '9.7', 'color': 'success', 'tutor': 'Ana Vargas'},
  ];

  // ── OPCIONES ──
  final List<String> _generos = ['Masculino', 'Femenino'];
  final List<String> _tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  final List<String> _niveles = ['Todos', 'Básica', 'Media', 'Superior'];
  final List<String> _secciones = ['Todas', 'Sección Única', 'Sección 1', 'Sección 2', 'Sección 3'];

  final Map<String, List<String>> _gradosPorNivel = {
    'Todos': ['Todos'],
    'Básica': ['Todos', 'Maternal', 'Kinder 1', 'Kinder 2', 'Kinder 3', '1° Primaria', '2° Primaria', '3° Primaria', '4° Primaria', '5° Primaria', '6° Primaria'],
    'Media': ['Todos', '1° Secundaria', '2° Secundaria', '3° Secundaria'],
    'Superior': ['Todos', '1° Bachillerato', '2° Bachillerato', '3° Bachillerato'],
  };

  List<String> get _gradosDisponibles {
    if (_filtroNivel == 'Todos') {
      return ['Todos', 'Maternal', 'Kinder 1', 'Kinder 2', 'Kinder 3',
              '1° Primaria', '2° Primaria', '3° Primaria', '4° Primaria', '5° Primaria', '6° Primaria',
              '1° Secundaria', '2° Secundaria', '3° Secundaria',
              '1° Bachillerato', '2° Bachillerato', '3° Bachillerato'];
    }
    return _gradosPorNivel[_filtroNivel] ?? ['Todos'];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    if (!mounted) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: p.bgPrimary,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true, p: p)) : null,
      appBar: isMobile
          ? AppBar(
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
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              width: _isSidebarExpanded ? 290 : 96,
              child: _buildSidebar(isDrawer: false, p: p),
            ),
          Expanded(
            child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile) _buildDesktopHeader(p),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedMenuIndex,
                        children: [
                          _buildDashboardView(screenWidth, p),
                          _buildNuevoRegistroView(p),
                          _buildEstudiantesView(p),
                          _buildGruposView(p),
                          _buildCalendarioView(p),
                          _buildCopilotView(p),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTAS
  // ═══════════════════════════════════════════════════════════

  Widget _buildDashboardView(double screenWidth, ThemePalette p) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Dashboard Escolar', 'Gestión integral de registro estudiantil con inteligencia artificial.',
              icon: Icons.dashboard_customize_rounded, p: p),
          const SizedBox(height: 36),
          _buildResponsiveKpiGrid(screenWidth, p),
          const SizedBox(height: 36),
          _buildChartsAndAlertsRow(screenWidth, p),
        ],
      ),
    );
  }

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
                  _buildFormField('Nombre(s)', 'Ej. Carlos Eduardo', Icons.person_outline_rounded, p, controller: _nombreController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                  _buildFormField('Apellido Paterno', 'Ej. Mendoza', Icons.person_outline_rounded, p, controller: _apellidoPController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                ]),
                _buildFormRow(p, [
                  _buildFormField('Apellido(s) Materno(s)', 'Ej. López García', Icons.person_outline_rounded, p, controller: _apellidoMController),
                  _buildFormField('CURP', 'MELC050115HDFNRL09', Icons.badge_outlined, p, controller: _curpController, isMono: true,
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
                  _buildFormField('Nacionalidad', 'Mexicana', Icons.flag_outlined, p, controller: _nacionalidadController,
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
                // CURP Tutor y teléfono trabajo
                _buildFormRow(p, [
                  _buildFormField('CURP del Tutor', 'LOGM850322MDFPRL05', Icons.badge_outlined, p,
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
                  _buildDocumentCard('CURP del Alumno', 'PDF', Icons.badge_outlined, true, p),
                  _buildDocumentCard('Cartilla de Vacunación', 'PDF, JPG', Icons.vaccines_outlined, false, p),
                  _buildDocumentCard('Comprobante de Domicilio', 'PDF, JPG', Icons.receipt_long_outlined, false, p),
                ]),
                _buildDocumentUploadRow(p, [
                  _buildDocumentCard('CURP del Tutor', 'PDF', Icons.badge_outlined, false, p),
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
  // MÉTODO CORREGIDO: GUARDAR EN SUPABASE
  // ═══════════════════════════════════════════════════════════

  Future<void> _validarYRegistrar() async {
    // Validar que al menos uno de padre/madre/tutor esté lleno
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

    // Si solo tutor está lleno, validar sus campos
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

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

    try {
      // Obtener código de empresa
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('company_code') ?? 'ROOT';

      // Determinar el tutor principal
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
        tutorCurp = ''; // El padre no tiene CURP separado
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

      // Guardar matrícula en Supabase
      await PortalPilotDB.insertMatriculaCompleta(
        // Datos del alumno
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
        
        // Información médica
        alumnoAlergias: _alergiasController.text.trim(),
        alumnoCondiciones: _condicionesController.text.trim(),
        alumnoMedicamentos: _medicamentosController.text.trim(),
        alumnoPeso: _pesoController.text.trim(),
        alumnoEstatura: _estaturaController.text.trim(),
        alumnoDiscapacidad: _discapacidadController.text.trim(),
        alumnoObsMedicas: _obsMedicasController.text.trim(),
        
        // Tutor principal
        tutorNombre: tutorNombre,
        tutorParentesco: tutorParentesco,
        tutorTelefono: tutorTelefono,
        tutorEmail: tutorEmail,
        tutorOcupacion: tutorOcupacion,
        tutorCurp: tutorCurp,
        
        // Dirección
        direccionCalle: _direccionController.text.trim(),
        direccionColonia: _coloniaController.text.trim(),
        direccionCP: _cpController.text.trim(),
        direccionAlcaldia: _alcaldiaController.text.trim(),
        direccionEstado: _estadoController.text.trim(),
        
        // Contacto de emergencia
        emergNombre: _emergNombreController.text.trim(),
        emergParentesco: _emergParentescoController.text.trim(),
        emergTel1: _emergTel1Controller.text.trim(),
        emergTel2: _emergTel2Controller.text.trim(),
        emergDireccion: _emergDireccionController.text.trim(),
        emergHorario: _emergHorarioController.text.trim(),
        
        // Empresa
        empresaCodigo: empresaCodigo,
      );

      // Cerrar indicador de carga
      if (mounted) Navigator.pop(context);

      // Limpiar formulario
      _limpiarFormulario();

      // Mostrar mensaje de éxito
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
      // Cerrar indicador de carga
      if (mounted) Navigator.pop(context);

      // Mostrar error
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
    _nacionalidadController.text = 'Mexicana';
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
  // ESTUDIANTES CON FILTROS
  // ═══════════════════════════════════════════════════════════

  Widget _buildEstudiantesView(ThemePalette p) {
    // Filtrar estudiantes
    var estudiantes = _estudiantes.where((e) {
      if (_filtroNivel != 'Todos' && e['nivel'] != _filtroNivel) return false;
      if (_filtroGrado != 'Todos' && e['grado'] != _filtroGrado) return false;
      if (_filtroSeccion != 'Todas') {
        final seccionAlumno = e['seccion'].toString();
        if (_filtroSeccion == 'Sección Única' && seccionAlumno != 'Única') return false;
        if (_filtroSeccion == 'Sección 1' && seccionAlumno != '1') return false;
        if (_filtroSeccion == 'Sección 2' && seccionAlumno != '2') return false;
        if (_filtroSeccion == 'Sección 3' && seccionAlumno != '3') return false;
      }
      return true;
    }).toList();

    // Verificar si el grado tiene secciones
    String? mensajeSeccion;
    if (_filtroSeccion != 'Todas' && estudiantes.isEmpty) {
      mensajeSeccion = 'Este grado no cuenta con $_filtroSeccion';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Directorio de Estudiantes', 'Base de datos completa con búsqueda y filtros inteligentes.',
              icon: Icons.people_alt_rounded, p: p),
          const SizedBox(height: 28),

          // ── FILTROS ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.borderLight),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.4 : 0.08), blurRadius: 30, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: p.accentPurple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.accentPurple.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.filter_list_rounded, color: p.accentPurple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Filtros',
                        style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: p.textPrimary, letterSpacing: -0.3)),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Selector de NIVEL
                    _buildFilterChip(
                      label: 'Nivel: $_filtroNivel',
                      icon: Icons.school_rounded,
                      onTap: () => _showNivelMenu(p),
                      p: p,
                    ),
                    // Botón selector de GRADO
                    _buildFilterChip(
                      label: _filtroGrado == 'Todos' ? 'Selecciona el grado' : 'Grado: $_filtroGrado',
                      icon: Icons.class_rounded,
                      onTap: () => _showGradoModal(p),
                      p: p,
                      isActive: _filtroGrado != 'Todos',
                    ),
                    // Selector de SECCIÓN
                    _buildFilterChip(
                      label: 'Sección: $_filtroSeccion',
                      icon: Icons.view_column_rounded,
                      onTap: () => _showSeccionMenu(p),
                      p: p,
                      isActive: _filtroSeccion != 'Todas',
                    ),
                    // Botón limpiar filtros
                    if (_filtroNivel != 'Todos' || _filtroGrado != 'Todos' || _filtroSeccion != 'Todas')
                      _buildFilterChip(
                        label: 'Limpiar filtros',
                        icon: Icons.clear_rounded,
                        onTap: () {
                          setState(() {
                            _filtroNivel = 'Todos';
                            _filtroGrado = 'Todos';
                            _filtroSeccion = 'Todas';
                          });
                        },
                        p: p,
                        isClear: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: estudiantes.isNotEmpty ? p.successGreen : p.warningAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${estudiantes.length} estudiante${estudiantes.length != 1 ? 's' : ''} encontrado${estudiantes.length != 1 ? 's' : ''}',
                      style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── MENSAJE DE SECCIÓN ──
          if (mensajeSeccion != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.warningAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.warningAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: p.warningAmber, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mensajeSeccion,
                      style: GoogleFonts.dmSans(fontSize: 14, color: p.warningAmber, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ── LISTA ──
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: p.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: p.borderLight),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.4 : 0.08), blurRadius: 50, offset: const Offset(0, 25)),
              ],
            ),
            child: estudiantes.isEmpty && mensajeSeccion == null
                ? Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, color: p.textMuted, size: 48),
                        const SizedBox(height: 16),
                        Text('No se encontraron estudiantes con los filtros seleccionados',
                            style: GoogleFonts.dmSans(fontSize: 14, color: p.textMuted), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : Column(
                    children: estudiantes.map((e) {
                      final colorName = e['color'] as String;
                      final color = colorName == 'success'
                          ? p.successGreen
                          : colorName == 'warning'
                              ? p.warningAmber
                              : p.errorRed;
                      return _buildStudentRow(
                        e['nombre'],
                        '${e['grado']} - Sección ${e['seccion']}',
                        'Promedio: ${e['prom']}',
                        color,
                        colorName == 'success' ? 'Activo' : colorName == 'warning' ? 'Regular' : 'Bajo Rend.',
                        (e['nombre'] as String).split(' ').take(2).map((w) => w[0]).join(''),
                        'Tutor: ${e['tutor']}',
                        p,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ThemePalette p,
    bool isActive = false,
    bool isClear = false,
  }) {
    final color = isClear ? p.errorRed : (isActive ? p.accentPurple : p.textMuted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(isClear ? 0.08 : (isActive ? 0.12 : 0.06)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(isActive || isClear ? 0.4 : 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              if (!isClear) Icon(Icons.arrow_drop_down_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showNivelMenu(ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => _buildFilterDialog(
        title: 'Selecciona el Nivel Educativo',
        options: _niveles,
        selected: _filtroNivel,
        onSelect: (v) {
          setState(() {
            _filtroNivel = v;
            _filtroGrado = 'Todos';
          });
          Navigator.pop(context);
        },
        p: p,
      ),
    );
  }

  void _showGradoModal(ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => _buildFilterDialog(
        title: 'Selecciona el Grado',
        subtitle: _filtroNivel == 'Todos' ? 'Mostrando todos los grados' : 'Nivel: $_filtroNivel',
        options: _gradosDisponibles,
        selected: _filtroGrado,
        onSelect: (v) {
          setState(() => _filtroGrado = v);
          Navigator.pop(context);
        },
        p: p,
      ),
    );
  }

  void _showSeccionMenu(ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => _buildFilterDialog(
        title: 'Selecciona la Sección',
        options: _secciones,
        selected: _filtroSeccion,
        onSelect: (v) {
          setState(() => _filtroSeccion = v);
          Navigator.pop(context);
        },
        p: p,
      ),
    );
  }

  Widget _buildFilterDialog({
    required String title,
    String? subtitle,
    required List<String> options,
    required String selected,
    required Function(String) onSelect,
    required ThemePalette p,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 20)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.accentPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.filter_alt_rounded, color: p.accentPurple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: p.textPrimary)),
                      if (subtitle != null)
                        Text(subtitle,
                            style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: p.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                shrinkWrap: true,
                children: options.map((opt) {
                  final isSelected = opt == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelect(opt),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [p.accentPurple.withOpacity(0.2), p.accentPurpleDark.withOpacity(0.08)])
                                : null,
                            color: isSelected ? null : p.bgTertiary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? p.accentPurple.withOpacity(0.4) : p.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(opt,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? p.textPrimary : p.textMuted,
                                    )),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: p.accentPurple,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GRUPOS / CALENDARIO / COPILOT
  // ═══════════════════════════════════════════════════════════

  Widget _buildGruposView(ThemePalette p) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Gestión de Grupos', 'Organización de clases y asignación de docentes.',
              icon: Icons.groups_rounded, p: p),
          const SizedBox(height: 36),
          _buildResponsiveGroupGrid(p),
        ],
      ),
    );
  }

  Widget _buildCalendarioView(ThemePalette p) {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Calendario Escolar', 'Eventos, exámenes y fechas importantes del ciclo.',
              icon: Icons.calendar_month_rounded, p: p),
          const SizedBox(height: 36),
          Expanded(
            child: ListView(
              children: [
                _buildCalendarTimelineCard('15', 'Jul', 'Inicio de Inscripciones', 'Período de registro para nuevo ciclo escolar 2026-2027.', true, Icons.how_to_reg_rounded, p),
                _buildCalendarTimelineCard('22', 'Jul', 'Junta de Padres', 'Reunión informativa para tutores de nuevo ingreso.', false, Icons.groups_rounded, p),
                _buildCalendarTimelineCard('05', 'Ago', 'Curso Propedéutico', 'Semana de nivelación para alumnos de primer ingreso.', false, Icons.menu_book_rounded, p),
                _buildCalendarTimelineCard('12', 'Ago', 'Inicio de Clases', 'Primer día del ciclo escolar 2026-2027.', true, Icons.school_rounded, p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopilotView(ThemePalette p) {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Edu AI', 'Asistente inteligente para gestión administrativa escolar.',
              icon: Icons.smart_toy_rounded, p: p),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: p.borderLight),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.4 : 0.08), blurRadius: 50, offset: const Offset(0, 25))],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.borderLight)),
                    child: Row(
                      children: [
                        Container(
                          width: 9, height: 9,
                          decoration: BoxDecoration(color: p.successGreen, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: p.successGreen.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]),
                        ),
                        const SizedBox(width: 12),
                        Text('COPILOT IA · ONLINE',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: p.successGreen, letterSpacing: 1.5)),
                        const Spacer(),
                        Icon(Icons.shield_rounded, color: p.accentPurple, size: 15),
                        const SizedBox(width: 8),
                        Text('CIFRADO E2E',
                            style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildChatMessage('Copilot IA', 'Buenos días. He detectado 3 registros pendientes de validación documental. ¿Deseas que te muestre el resumen?', false, '08:00', p),
                        _buildChatMessage('Tú (Admin)', 'Sí, muéstrame cuáles son y qué documentos faltan.', true, '08:02', p),
                        _buildChatMessage('Copilot IA',
                            'Procesando base de datos... [OK]\n\n▸ Carlos Mendoza: Falta cartilla de vacunación\n▸ Ana Ramírez: CURP del tutor ilegible\n▸ Diego Hernández: Comprobante vencido',
                            false, '08:02', p),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.borderLight)),
                          child: TextField(
                            style: GoogleFonts.dmSans(color: p.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Pregúntale a la IA escolar...',
                              hintStyle: GoogleFonts.dmSans(color: p.textDark),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              prefixIcon: Icon(Icons.add_circle_outline_rounded, color: p.textMuted, size: 20),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: p.accentPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.mic_rounded, color: p.accentPurple, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: () {}),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // COMPONENTES UI
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

  Widget _buildResponsiveKpiGrid(double width, ThemePalette p) {
    int count = width < 768 ? 1 : (width < 1200 ? 2 : 3);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: count,
      crossAxisSpacing: 22,
      mainAxisSpacing: 22,
      childAspectRatio: 2.0,
      children: [
        _buildKpiCard('TOTAL ALUMNOS', '1,247', '+42 este mes', Icons.people_alt_rounded, p.successGreen,
            [40, 55, 48, 62, 58, 72, 68, 85, 78, 92, 88, 95], p),
        _buildKpiCard('INSCRIPCIONES PENDIENTES', '38', 'Por validar', Icons.pending_actions_rounded, p.warningAmber,
            [80, 75, 82, 70, 65, 58, 62, 55, 50, 48, 45, 42], p),
        _buildKpiCard('ASISTENCIA HOY', '96.2%', 'Excelente', Icons.how_to_reg_rounded, p.accentPurple,
            [90, 92, 88, 95, 94, 96, 93, 97, 95, 98, 96, 97], p),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String badge, IconData icon, Color color, List<int> data, ThemePalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 35, offset: const Offset(0, 18)),
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 25, spreadRadius: -8),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: p.textMuted, letterSpacing: 1.8)),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: color.withOpacity(0.25))),
                child: Icon(icon, color: color, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900, color: p.textPrimary, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: color.withOpacity(0.3))),
                      child: Text(badge, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 95, height: 42,
                child: CustomPaint(painter: SparklinePainter(data: data, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsAndAlertsRow(double width, ThemePalette p) {
    final useRow = width > 1200;
    final children = [
      Expanded(flex: useRow ? 2 : 0, child: _buildAnalyticsCard(p)),
      if (useRow) const SizedBox(width: 26) else const SizedBox(height: 26),
      Expanded(flex: useRow ? 1 : 0, child: _buildTerminalAlerts(p)),
    ];
    return useRow ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children) : Column(children: children);
  }

  Widget _buildAnalyticsCard(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 35, offset: const Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Métricas de Inscripción', style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.bold, color: p.textPrimary)),
                  const SizedBox(height: 5),
                  Text('Ciclo 2026-2027', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: p.textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: p.accentPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: p.accentPurple.withOpacity(0.3))),
                child: Icon(Icons.trending_up_rounded, color: p.accentPurple, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildCustomProgressBar('Preescolar', 0.82, p.accentPurple, p),
          _buildCustomProgressBar('Primaria', 0.68, p.accentPurpleLight, p),
          _buildCustomProgressBar('Secundaria', 0.54, p.successGreen, p),
          const SizedBox(height: 24),
          Container(
            height: 130,
            decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.borderLight)),
            child: CustomPaint(
              size: Size.infinite,
              painter: AreaChartPainter(accentPurpleColor: p.accentPurple, accentPurpleLightColor: p.accentPurpleLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProgressBar(String label, double pct, Color color, ThemePalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                child: Text('${(pct * 100).toInt()}%', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 9,
                decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.borderLight)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Container(
                        width: constraints.maxWidth * value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalAlerts(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 35, offset: const Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(color: p.accentPurple, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(_pulseAnimation.value * 0.7), blurRadius: 14, spreadRadius: 2)]),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text('ALERTAS EN VIVO', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: p.textPrimary, letterSpacing: 1.8)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: p.successGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: p.successGreen.withOpacity(0.3))),
                child: Text('ACTIVE', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: p.successGreen, letterSpacing: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.borderLight)),
            child: Column(
              children: [
                _buildTerminalLine('[OK] SISTEMA_REGISTRO_ONLINE // PORTAL_ACTIVE', p.successGreen),
                _buildTerminalLine('[INFO] 38_INSCRIPCIONES_PENDIENTES_VALIDACION', p.accentPurple),
                _buildTerminalLine('[WARN] DOCUMENTOS_VENCIDOS: 5_ALUMNOS', p.warningAmber),
                _buildTerminalLine('[SYSTEM] COPILOT_IA_ANALISIS_COMPLETADO', p.accentPurpleLight),
                _buildTerminalLine('[OK] BACKUP_DIARIO_COMPLETADO // 03:00', p.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [p.accentPurple.withOpacity(0.12), p.accentPurpleDark.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: p.accentPurple, size: 15),
                    const SizedBox(width: 9),
                    Text('AI INSIGHT', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.accentPurple, letterSpacing: 1.8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Se detectó un incremento del 18% en inscripciones vs. ciclo anterior. Se recomienda ampliar grupo de 1° grado.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: p.textSecondary, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalLine(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Row(
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 5)]),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(text, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // REGISTRO COMPONENTS
  // ═══════════════════════════════════════════════════════════

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

  Widget _buildStudentRow(String name, String grade, String avg, Color avgColor, String status, String initials, String tutor, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [p.accentPurple.withOpacity(0.3), p.accentPurpleDark.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.accentPurple.withOpacity(0.4)),
            ),
            child: Center(child: Text(initials, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: p.textPrimary))),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: p.textPrimary)),
                const SizedBox(height: 4),
                Text(tutor, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grade, style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)),
                const SizedBox(height: 4),
                Text(avg, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: avgColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: avgColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9),
                border: Border.all(color: avgColor.withOpacity(0.3))),
            child: Text(status, style: GoogleFonts.dmSans(fontSize: 10, color: avgColor, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: p.bgSecondary, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.borderLight)),
            child: Icon(Icons.more_horiz_rounded, color: p.textMuted, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGroupGrid(ThemePalette p) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 22,
      mainAxisSpacing: 22,
      childAspectRatio: 1.8,
      children: [
        _buildGroupCard('1° A', 'Primaria', 32, 'Prof. García', p.successGreen, p),
        _buildGroupCard('1° B', 'Primaria', 30, 'Prof. Martínez', p.successGreen, p),
        _buildGroupCard('2° A', 'Primaria', 28, 'Prof. López', p.successGreen, p),
        _buildGroupCard('3° A', 'Primaria', 31, 'Prof. Hernández', p.warningAmber, p),
        _buildGroupCard('4° A', 'Primaria', 29, 'Prof. Ramírez', p.successGreen, p),
        _buildGroupCard('5° B', 'Primaria', 27, 'Prof. Sánchez', p.successGreen, p),
      ],
    );
  }

  Widget _buildGroupCard(String grade, String level, int students, String teacher, Color color, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(grade, style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: p.textPrimary)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Icon(Icons.groups_rounded, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level, style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)),
              const SizedBox(height: 4),
              Text(teacher, style: GoogleFonts.dmSans(fontSize: 11, color: p.textDark, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: p.accentPurple, size: 14),
                  const SizedBox(width: 6),
                  Text('$students alumnos', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: p.accentPurple, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTimelineCard(String day, String month, String title, String desc, bool important, IconData icon, ThemePalette p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: important ? p.accentPurple.withOpacity(0.4) : p.borderLight),
        boxShadow: important
            ? [BoxShadow(color: p.accentPurple.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 12))]
            : [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.25 : 0.05), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: important
                    ? [p.accentPurple.withOpacity(0.25), p.accentPurpleDark.withOpacity(0.1)]
                    : [p.accentPurple.withOpacity(0.15), p.accentPurpleDark.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: important ? p.accentPurple.withOpacity(0.5) : p.accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(day, style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w900, color: p.textPrimary, letterSpacing: -0.5)),
                Text(month.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.textMuted, letterSpacing: 1.8)),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: important ? p.accentPurple : p.textMuted, size: 17),
                    const SizedBox(width: 9),
                    Expanded(child: Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: p.textPrimary))),
                  ],
                ),
                const SizedBox(height: 7),
                Text(desc, style: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted, height: 1.6)),
              ],
            ),
          ),
          if (important)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.3), blurRadius: 12)],
              ),
              child: Text('IMPORTANTE',
                  style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(String sender, String text, bool isMe, String time, ThemePalette p) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe)
                  Container(
                    width: 30, height: 30,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 15),
                  ),
                Text(sender, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold,
                    color: isMe ? p.accentPurple : p.textMuted, letterSpacing: 0.6)),
                const SizedBox(width: 9),
                Text(time, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.textDark, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [p.accentPurple.withOpacity(0.2), p.accentPurpleDark.withOpacity(0.08)])
                    : null,
                color: isMe ? null : p.bgTertiary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isMe ? p.accentPurple.withOpacity(0.4) : p.borderLight),
              ),
              child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: p.textPrimary, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESKTOP HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildDesktopHeader(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: BoxDecoration(color: p.bgSecondary, border: Border(bottom: BorderSide(color: p.borderLight, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconButton(
                icon: _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                p: p,
              ),
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: p.textMuted, size: 15),
                    const SizedBox(width: 10),
                    Text('Buscar alumno, grupo...', style: GoogleFonts.dmSans(fontSize: 12, color: p.textDark, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: p.bgPrimary, borderRadius: BorderRadius.circular(5), border: Border.all(color: p.borderLight)),
                      child: Text('⌘K', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Theme toggle button
              _buildIconButton(
                icon: appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: p.accentPurple,
                onTap: () async {
                  await appThemeNotifier.toggle();
                  if (mounted) setState(() {});
                },
                p: p,
              ),
              const SizedBox(width: 14),
              _buildNotificationButton(p),
              const SizedBox(width: 14),
              _buildIconButton(icon: Icons.bolt_rounded, color: p.accentPurple, onTap: () {}, p: p),
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]),
                  boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.4), blurRadius: 14)],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: p.bgSecondary,
                  child: Text('AD', style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, Color? color, required VoidCallback onTap, required ThemePalette p}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: p.bgTertiary, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
        child: Icon(icon, size: 19, color: color ?? p.textMuted),
      ),
    );
  }

  Widget _buildNotificationButton(ThemePalette p) {
    return Stack(
      children: [
        _buildIconButton(icon: Icons.notifications_none_rounded, onTap: () {}, p: p),
        Positioned(
          top: 7, right: 7,
          child: Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: p.accentPurple,
              shape: BoxShape.circle,
              border: Border.all(color: p.bgSecondary, width: 2),
              boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.6), blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SIDEBAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSidebar({required bool isDrawer, required ThemePalette p}) {
    final showFullText = _isSidebarExpanded || isDrawer;
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(color: p.bgSecondary, border: Border(right: BorderSide(color: p.borderLight, width: 1))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(36.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.5), blurRadius: 24, spreadRadius: 1)],
                  ),
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 23),
                ),
                if (showFullText) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PORTAL PILOT', style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w900, color: p.textPrimary, letterSpacing: 1.2),
                            overflow: TextOverflow.ellipsis),
                        Text('v1.1.0 · Escolar', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.textMuted, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (showFullText)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              child: Text('MÓDULOS', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: p.textDark, letterSpacing: 2.2)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _buildSidebarMenuItem(0, Icons.dashboard_customize_rounded, 'Dashboard', showFullText, false, p),
                _buildSidebarMenuItem(1, Icons.person_add_alt_1_rounded, 'Nuevo Registro', showFullText, true, p),
                _buildSidebarMenuItem(2, Icons.people_alt_rounded, 'Estudiantes', showFullText, false, p),
                _buildSidebarMenuItem(3, Icons.groups_rounded, 'Grupos', showFullText, false, p),
                _buildSidebarMenuItem(4, Icons.calendar_month_rounded, 'Calendario', showFullText, false, p),
                _buildSidebarMenuItem(5, Icons.smart_toy_rounded, 'Copilot IA', showFullText, true, p),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26.0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.bgTertiary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.borderLight),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentPurple, p.accentPurpleDark]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.school_rounded, color: Colors.white, size: 17),
                  ),
                  if (showFullText) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Escuela Central', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: p.textPrimary)),
                          Text('CICLO 2026-2027', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: p.accentPurple, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarMenuItem(int index, IconData icon, String label, bool showFull, bool isPremium, ThemePalette p) {
    final isSelected = _selectedMenuIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          setState(() => _selectedMenuIndex = index);
          if (MediaQuery.of(context).size.width < 1024) Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [p.accentPurple.withOpacity(0.18), p.accentPurpleDark.withOpacity(0.08)])
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? p.accentPurple.withOpacity(0.4) : Colors.transparent),
            boxShadow: isSelected ? [BoxShadow(color: p.accentPurple.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))] : [],
          ),
          child: Row(
            mainAxisAlignment: showFull ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 3.5, height: 22,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.accentPurple, p.accentPurpleDark]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: p.accentPurple.withOpacity(0.7), blurRadius: 8)],
                  ),
                ),
              Icon(icon, color: isSelected ? p.accentPurple : p.textMuted, size: 21),
              if (showFull) ...[
                const SizedBox(width: 18),
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.dmSans(fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? p.textPrimary : p.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: p.warningAmber.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.workspace_premium_rounded, color: p.warningAmber, size: 12),
                  ),
              ],
            ],
          ),
        ),
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

// ═══════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════

class SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final range = (max - min).toDouble();
    if (range == 0) return;

    final paint = Paint()..color = color..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.35), color.withOpacity(0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AreaChartPainter extends CustomPainter {
  final Color accentPurpleColor;
  final Color accentPurpleLightColor;
  AreaChartPainter({required this.accentPurpleColor, required this.accentPurpleLightColor});

  @override
  void paint(Canvas canvas, Size size) {
    final data = [30, 45, 38, 55, 48, 62, 58, 72, 65, 78, 70, 85, 80, 92];
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final range = (max - min).toDouble();

    final paint = Paint()
      ..shader = LinearGradient(colors: [accentPurpleColor, accentPurpleLightColor])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - ((data[i - 1] - min) / range) * size.height * 0.8 - size.height * 0.1;
        path.cubicTo(prevX + stepX / 2, prevY, x - stepX / 2, y, x, y);
      }
    }
    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [accentPurpleColor.withOpacity(0.25), accentPurpleLightColor.withOpacity(0.08), Colors.transparent])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}