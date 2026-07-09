import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════
// THEME PROVIDER
// ═══════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // ── PALETA OSCURA ──
  Color get bgPrimary => _isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  Color get bgSecondary => _isDarkMode ? const Color(0xFF080808) : const Color(0xFFEDEDED);
  Color get bgTertiary => _isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFE5E5EA);
  Color get cardColor => _isDarkMode ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);
  Color get accentPurpleLight => const Color(0xFFA78BFA);
  Color get accentPurpleDeep => const Color(0xFF5B21B6);

  Color get textPrimary => _isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get textSecondary => _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFF3A3A3C);
  Color get textMuted => _isDarkMode ? const Color(0xFFA3A3A3) : const Color(0xFF6E6E73);
  Color get textDark => _isDarkMode ? const Color(0xFF525252) : const Color(0xFFAEAEB2);

  Color get successGreen => const Color(0xFF10B981);
  Color get errorRed => const Color(0xFFEF4444);
  Color get warningAmber => const Color(0xFFF59E0B);
  Color get infoBlue => const Color(0xFF3B82F6);

  Color get borderLight => _isDarkMode ? const Color(0x29FFFFFF) : const Color(0x1A000000);
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

  // Theme
  late ThemeProvider _themeProvider;

  // ── Controladores del formulario ──
  final _nombresController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _curpController = TextEditingController();
  final _lugarNacimientoController = TextEditingController();
  final _nacionalidadController = TextEditingController();
  final _nssController = TextEditingController();

  String? _fechaNacimiento;
  String? _generoSeleccionado;
  String? _tipoSangreSeleccionado;

  // Info médica
  final _alergiasController = TextEditingController();
  final _condicionesController = TextEditingController();
  final _medicamentosController = TextEditingController();
  final _pesoController = TextEditingController();
  final _estaturaController = TextEditingController();
  final _discapacidadController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Tutores (3 cuadros separados)
  final _nombrePadreController = TextEditingController();
  final _nombreMadreController = TextEditingController();
  final _nombreTutorController = TextEditingController();

  final _ocupacionPadreController = TextEditingController();
  final _ocupacionMadreController = TextEditingController();
  final _ocupacionTutorController = TextEditingController();

  final _telefonoPadreController = TextEditingController();
  final _telefonoMadreController = TextEditingController();
  final _telefonoTutorController = TextEditingController();

  final _emailPadreController = TextEditingController();
  final _emailMadreController = TextEditingController();
  final _emailTutorController = TextEditingController();

  // Contacto emergencia (NO obligatorio)
  final _emergenciaNombreController = TextEditingController();
  final _emergenciaParentescoController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();

  // Dirección (OBLIGATORIO)
  final _calleController = TextEditingController();
  final _coloniaController = TextEditingController();
  final _cpController = TextEditingController();
  final _alcaldiaController = TextEditingController();
  final _estadoController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // ── Filtros de estudiantes ──
  String _nivelSeleccionado = 'Todos';
  String? _gradoSeleccionado;
  String _seccionSeleccionada = 'Todas';

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
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
    _nombresController.dispose();
    _apellidoPaternoController.dispose();
    _apellidosController.dispose();
    _curpController.dispose();
    _lugarNacimientoController.dispose();
    _nacionalidadController.dispose();
    _nssController.dispose();
    _alergiasController.dispose();
    _condicionesController.dispose();
    _medicamentosController.dispose();
    _pesoController.dispose();
    _estaturaController.dispose();
    _discapacidadController.dispose();
    _observacionesController.dispose();
    _nombrePadreController.dispose();
    _nombreMadreController.dispose();
    _nombreTutorController.dispose();
    _ocupacionPadreController.dispose();
    _ocupacionMadreController.dispose();
    _ocupacionTutorController.dispose();
    _telefonoPadreController.dispose();
    _telefonoMadreController.dispose();
    _telefonoTutorController.dispose();
    _emailPadreController.dispose();
    _emailMadreController.dispose();
    _emailTutorController.dispose();
    _emergenciaNombreController.dispose();
    _emergenciaParentescoController.dispose();
    _emergenciaTelefonoController.dispose();
    _calleController.dispose();
    _coloniaController.dispose();
    _cpController.dispose();
    _alcaldiaController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2015, 1, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _themeProvider.accentPurple,
              onPrimary: Colors.white,
              surface: _themeProvider.cardColor,
              onSurface: _themeProvider.textPrimary,
            ),
            dialogBackgroundColor: _themeProvider.cardColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaNacimiento = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isMobile = screenWidth < 1024;

        return Scaffold(
          backgroundColor: _themeProvider.bgPrimary,
          drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: _themeProvider.bgSecondary,
                  elevation: 0,
                  iconTheme: IconThemeData(color: _themeProvider.textPrimary),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _themeProvider.accentPurple.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(Icons.school_rounded, color: _themeProvider.textPrimary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PORTAL PILOT',
                        style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _themeProvider.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    _buildThemeToggle(),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _themeProvider.accentPurple, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _themeProvider.accentPurple.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: _themeProvider.bgTertiary,
                        child: Text(
                          'AD',
                          style: TextStyle(
                            color: _themeProvider.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  child: _buildSidebar(isDrawer: false),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.5,
                      colors: [
                        _themeProvider.accentPurple.withOpacity(_themeProvider.isDarkMode ? 0.03 : 0.05),
                        _themeProvider.bgPrimary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isMobile) _buildDesktopHeader(),
                        Expanded(
                          child: IndexedStack(
                            index: _selectedMenuIndex,
                            children: [
                              _buildDashboardView(screenWidth),
                              _buildNuevoRegistroView(),
                              _buildEstudiantesView(),
                              _buildGruposView(),
                              _buildCalendarioView(),
                              _buildCopilotView(),
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
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // THEME TOGGLE
  // ═══════════════════════════════════════════════════════════

  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: () => _themeProvider.toggleTheme(),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _themeProvider.bgTertiary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _themeProvider.borderLight),
        ),
        child: Icon(
          _themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: _themeProvider.isDarkMode ? _themeProvider.warningAmber : _themeProvider.accentPurple,
          size: 18,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTAS PRINCIPALES
  // ═══════════════════════════════════════════════════════════

  Widget _buildDashboardView(double screenWidth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Dashboard Escolar',
            'Gestión integral de registro estudiantil con inteligencia artificial.',
            icon: Icons.dashboard_customize_rounded,
          ),
          const SizedBox(height: 36),
          _buildResponsiveKpiGrid(screenWidth),
          const SizedBox(height: 36),
          _buildChartsAndAlertsRow(screenWidth),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NUEVO REGISTRO (MEJORADO)
  // ═══════════════════════════════════════════════════════════

  Widget _buildNuevoRegistroView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(
              'Nuevo Registro Estudiantil',
              'Formulario completo de inscripción con validación automática.',
              icon: Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: 36),
            _buildRegistrationSteps(),
            const SizedBox(height: 32),

            // ═══ DATOS DEL ALUMNO ═══
            _buildFormSection(
              'Datos del Alumno',
              Icons.child_care_rounded,
              _themeProvider.accentPurple,
              [
                _buildFormRow([
                  _buildFormField('Nombre(s)', 'Ej. Carlos Eduardo', Icons.person_outline_rounded,
                      controller: _nombresController, required: true),
                  _buildFormField('Apellido Paterno', 'Ej. Mendoza', Icons.person_outline_rounded,
                      controller: _apellidoPaternoController, required: true),
                ]),
                _buildFormRow([
                  _buildFormField('Apellido(s)', 'Ej. López García', Icons.person_outline_rounded,
                      controller: _apellidosController, required: true),
                  _buildFormField('CURP', 'Ej. MELC050115HDFNRL09', Icons.badge_outlined,
                      controller: _curpController, isMono: true, required: true),
                ]),
                _buildFormRow([
                  _buildDateField('Fecha de Nacimiento', _fechaNacimiento, required: true),
                  _buildFormField('Lugar de Nacimiento', 'Ej. Ciudad de México', Icons.location_city_outlined,
                      controller: _lugarNacimientoController, required: true),
                ]),
                _buildFormRow([
                  _buildDropdownField(
                    'Género *',
                    'Seleccionar...',
                    Icons.wc_rounded,
                    _generoSeleccionado,
                    ['Masculino', 'Femenino'],
                    (value) => setState(() => _generoSeleccionado = value),
                    required: true,
                  ),
                  _buildFormField('Nacionalidad', 'Mexicana', Icons.flag_outlined,
                      controller: _nacionalidadController, required: true),
                ]),
                _buildFormRow([
                  _buildDropdownField(
                    'Tipo de Sangre',
                    'Seleccionar (Opcional)',
                    Icons.bloodtype_rounded,
                    _tipoSangreSeleccionado,
                    ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                    (value) => setState(() => _tipoSangreSeleccionado = value),
                    required: false,
                  ),
                  _buildFormField('NSS', 'Opcional', Icons.health_and_safety_outlined,
                      controller: _nssController, required: false),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ INFORMACIÓN MÉDICA ═══
            _buildFormSection(
              'Información Médica',
              Icons.medical_services_outlined,
              _themeProvider.errorRed,
              [
                _buildFormField('Alergias', 'Ej. Penicilina, mariscos, polen...',
                    Icons.warning_amber_rounded,
                    controller: _alergiasController, isMultiline: true),
                _buildOptionalNote(),
                const SizedBox(height: 16),
                _buildFormField('Condiciones Médicas', 'Ej. Asma, diabetes, epilepsia...',
                    Icons.medication_outlined,
                    controller: _condicionesController, isMultiline: true),
                _buildOptionalNote(),
                const SizedBox(height: 16),
                _buildFormField('Medicamentos Actuales', 'Ej. Salbutamol inhalador cada 8 horas...',
                    Icons.local_pharmacy_outlined,
                    controller: _medicamentosController, isMultiline: true),
                _buildOptionalNote(),
                const SizedBox(height: 16),
                _buildFormRow([
                  _buildFormField('Peso (kg)', 'Ej. 35', Icons.monitor_weight_outlined,
                      controller: _pesoController),
                  _buildFormField('Estatura (cm)', 'Ej. 142', Icons.height_rounded,
                      controller: _estaturaController),
                  _buildFormField('Discapacidad', 'Ninguna', Icons.accessible_forward_outlined,
                      controller: _discapacidadController),
                ]),
                const SizedBox(height: 16),
                _buildFormField('Observaciones Médicas Adicionales',
                    'Cualquier información relevante para el personal escolar...',
                    Icons.notes_rounded,
                    controller: _observacionesController, isMultiline: true),
                _buildOptionalNote(),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ DATOS DEL PADRE / MADRE / TUTOR ═══
            _buildFormSection(
              'Datos del Padre / Madre / Tutor',
              Icons.family_restroom_rounded,
              _themeProvider.infoBlue,
              [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _themeProvider.infoBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _themeProvider.infoBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: _themeProvider.infoBlue, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Debe completar al menos UNO de los tres: Padre, Madre o Tutor.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _themeProvider.infoBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Nombres completos
                _buildSubsectionTitle('Nombre Completo', Icons.person_outline_rounded),
                _buildFormRow([
                  _buildFormField('Padre', 'Nombre completo del padre', Icons.male_outlined,
                      controller: _nombrePadreController),
                  _buildFormField('Madre', 'Nombre completo de la madre', Icons.female_outlined,
                      controller: _nombreMadreController),
                ]),
                _buildFormField('Tutor', 'Nombre completo del tutor (si aplica)', Icons.person_outline_rounded,
                    controller: _nombreTutorController),
                const SizedBox(height: 20),

                // Ocupaciones
                _buildSubsectionTitle('Ocupación', Icons.work_outline_rounded),
                _buildFormRow([
                  _buildFormField('Ocupación del Padre', 'Ej. Ingeniero', Icons.work_outline_rounded,
                      controller: _ocupacionPadreController),
                  _buildFormField('Ocupación de la Madre', 'Ej. Doctora', Icons.work_outline_rounded,
                      controller: _ocupacionMadreController),
                ]),
                _buildFormField('Ocupación del Tutor', 'Ej. Abogado (si aplica)', Icons.work_outline_rounded,
                    controller: _ocupacionTutorController),
                const SizedBox(height: 20),

                // Teléfonos
                _buildSubsectionTitle('Teléfono Celular', Icons.phone_android_outlined),
                _buildFormRow([
                  _buildFormField('Teléfono del Padre', '55 1234 5678', Icons.phone_outlined,
                      controller: _telefonoPadreController, isPhone: true),
                  _buildFormField('Teléfono de la Madre', '55 8765 4321', Icons.phone_outlined,
                      controller: _telefonoMadreController, isPhone: true),
                ]),
                _buildFormField('Teléfono del Tutor', '55 9876 5432 (si aplica)', Icons.phone_outlined,
                    controller: _telefonoTutorController, isPhone: true),
                const SizedBox(height: 20),

                // Correos
                _buildSubsectionTitle('Correo Electrónico', Icons.email_outlined),
                _buildFormRow([
                  _buildFormField('Correo del Padre', 'padre@email.com', Icons.email_outlined,
                      controller: _emailPadreController, isEmail: true),
                  _buildFormField('Correo de la Madre', 'madre@email.com', Icons.email_outlined,
                      controller: _emailMadreController, isEmail: true),
                ]),
                _buildFormField('Correo del Tutor', 'tutor@email.com (si aplica)', Icons.email_outlined,
                    controller: _emailTutorController, isEmail: true),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ CONTACTO DE EMERGENCIA (NO OBLIGATORIO) ═══
            _buildFormSection(
              'Contacto de Emergencia',
              Icons.emergency_outlined,
              _themeProvider.warningAmber,
              [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _themeProvider.warningAmber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _themeProvider.warningAmber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: _themeProvider.warningAmber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta sección es OPCIONAL. Puede dejarla en blanco.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _themeProvider.warningAmber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormRow([
                  _buildFormField('Nombre del Contacto', 'Ej. Roberto Mendoza', Icons.person_outline_rounded,
                      controller: _emergenciaNombreController),
                  _buildFormField('Parentesco', 'Tío, Abuelo, etc.', Icons.badge_outlined,
                      controller: _emergenciaParentescoController),
                ]),
                _buildFormField('Teléfono de Emergencia', '55 5555 5555', Icons.phone_outlined,
                    controller: _emergenciaTelefonoController, isPhone: true),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ DIRECCIÓN DEL ALUMNO (OBLIGATORIO) ═══
            _buildFormSection(
              'Dirección del Alumno',
              Icons.home_work_outlined,
              _themeProvider.accentPurpleLight,
              [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _themeProvider.errorRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _themeProvider.errorRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: _themeProvider.errorRed, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta sección es OBLIGATORIA. Todos los campos deben completarse.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _themeProvider.errorRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFormField('Calle y Número', 'Ej. Av. Insurgentes Sur 1234', Icons.location_on_outlined,
                    controller: _calleController, required: true),
                const SizedBox(height: 16),
                _buildFormRow([
                  _buildFormField('Colonia', 'Ej. Del Valle Centro', Icons.location_city_outlined,
                      controller: _coloniaController, required: true),
                  _buildFormField('Código Postal', 'Ej. 03100', Icons.markunread_mailbox_outlined,
                      controller: _cpController, required: true),
                ]),
                _buildFormRow([
                  _buildFormField('Alcaldía / Municipio', 'Ej. Benito Juárez', Icons.location_city_outlined,
                      controller: _alcaldiaController, required: true),
                  _buildFormField('Estado', 'Ciudad de México', Icons.map_outlined,
                      controller: _estadoController, required: true),
                ]),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ DOCUMENTOS REQUERIDOS ═══
            _buildFormSection(
              'Documentos Requeridos',
              Icons.folder_open_rounded,
              _themeProvider.successGreen,
              [
                _buildDocumentUploadRow([
                  _buildDocumentCard('Acta de Nacimiento', 'PDF, JPG', Icons.description_outlined, true),
                  _buildDocumentCard('CURP del Alumno', 'PDF', Icons.badge_outlined, true),
                  _buildDocumentCard('Cartilla de Vacunación', 'PDF, JPG', Icons.vaccines_outlined, false),
                  _buildDocumentCard('Comprobante de Domicilio', 'PDF, JPG', Icons.receipt_long_outlined, false),
                ]),
                _buildDocumentUploadRow([
                  _buildDocumentCard('CURP del Tutor', 'PDF', Icons.badge_outlined, false),
                  _buildDocumentCard('Certificado Escolar Anterior', 'PDF', Icons.school_outlined, false),
                  _buildDocumentCard('Fotografía Infantil', 'JPG, PNG', Icons.photo_camera_outlined, false),
                  _buildDocumentCard('Constancia Médica', 'PDF', Icons.local_hospital_outlined, false),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            // ═══ BOTONES DE ACCIÓN ═══
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _themeProvider.bgTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _themeProvider.borderLight),
                    ),
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.save_outlined, size: 18, color: _themeProvider.textPrimary),
                      label: Text(
                        'Guardar Borrador',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _themeProvider.textPrimary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _themeProvider.accentPurple.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _validateAndSubmit,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Registrar Alumno',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _validateAndSubmit() {
    // Validar tutores: al menos uno debe estar completo
    final hasPadre = _nombrePadreController.text.trim().isNotEmpty;
    final hasMadre = _nombreMadreController.text.trim().isNotEmpty;
    final hasTutor = _nombreTutorController.text.trim().isNotEmpty;

    if (!hasPadre && !hasMadre && !hasTutor) {
      _showErrorDialog('Debe completar al menos uno: Padre, Madre o Tutor');
      return;
    }

    // Si solo llenó tutor, ocupación del tutor es obligatoria
    if (hasTutor && !hasPadre && !hasMadre) {
      if (_ocupacionTutorController.text.trim().isEmpty) {
        _showErrorDialog('La ocupación del tutor es obligatoria cuando solo se registra al tutor');
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      _showSuccessDialog('¡Alumno registrado exitosamente!');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: _themeProvider.errorRed),
            const SizedBox(width: 10),
            Text('Error', style: GoogleFonts.syne(color: _themeProvider.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(message, style: GoogleFonts.dmSans(color: _themeProvider.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: GoogleFonts.dmSans(color: _themeProvider.accentPurple)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: _themeProvider.successGreen),
            const SizedBox(width: 10),
            Text('Éxito', style: GoogleFonts.syne(color: _themeProvider.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(message, style: GoogleFonts.dmSans(color: _themeProvider.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continuar', style: GoogleFonts.dmSans(color: _themeProvider.accentPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(
        children: [
          Icon(icon, color: _themeProvider.accentPurple, size: 16),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _themeProvider.accentPurple,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _themeProvider.textDark, size: 14),
          const SizedBox(width: 6),
          Text(
            'Dejar en blanco si no padece de problemas médicos.',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: _themeProvider.textDark,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, String? value, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase() + (required ? ' *' : ''),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _themeProvider.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _themeProvider.bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _themeProvider.borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: _themeProvider.textMuted, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? 'DD / MM / AAAA',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: value != null ? _themeProvider.textPrimary : _themeProvider.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: _themeProvider.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String hint,
    IconData icon,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _themeProvider.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _themeProvider.bgTertiary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _themeProvider.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Row(
                children: [
                  Icon(icon, color: _themeProvider.textMuted, size: 18),
                  const SizedBox(width: 12),
                  Text(hint, style: GoogleFonts.dmSans(fontSize: 14, color: _themeProvider.textDark)),
                ],
              ),
              isExpanded: true,
              dropdownColor: _themeProvider.cardColor,
              icon: Icon(Icons.arrow_drop_down_rounded, color: _themeProvider.textMuted),
              style: GoogleFonts.dmSans(fontSize: 14, color: _themeProvider.textPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: BorderRadius.circular(14),
              items: options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(icon, color: _themeProvider.accentPurple, size: 16),
                      const SizedBox(width: 10),
                      Text(opt),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ESTUDIANTES (CON FILTROS MEJORADOS)
  // ═══════════════════════════════════════════════════════════

  Widget _buildEstudiantesView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Directorio de Estudiantes',
            'Base de datos completa con búsqueda y filtros avanzados.',
            icon: Icons.people_alt_rounded,
          ),
          const SizedBox(height: 24),

          // ═══ FILTROS ═══
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _themeProvider.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _themeProvider.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: _themeProvider.accentPurple, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'FILTROS DE BÚSQUEDA',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _themeProvider.accentPurple,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Nivel educativo
                    _buildFilterSegmented(
                      label: 'Nivel',
                      options: ['Todos', 'Básica', 'Media', 'Superior'],
                      selected: _nivelSeleccionado,
                      onChanged: (v) => setState(() {
                        _nivelSeleccionado = v;
                        _gradoSeleccionado = null;
                        _seccionSeleccionada = 'Todas';
                      }),
                    ),
                    // Grado (abre modal)
                    _buildFilterModal(
                      label: _gradoSeleccionado ?? 'Selecciona el nivel educativo',
                      icon: Icons.school_rounded,
                      onTap: _showGradoModal,
                    ),
                    // Sección
                    _buildFilterSegmented(
                      label: 'Sección',
                      options: _getSeccionesDisponibles(),
                      selected: _seccionSeleccionada,
                      onChanged: (v) => setState(() => _seccionSeleccionada = v),
                    ),
                  ],
                ),
                // Mensaje de sección
                if (_gradoSeleccionado != null && _getSeccionesDisponibles().length == 1) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _themeProvider.warningAmber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _themeProvider.warningAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _themeProvider.warningAmber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este grado no cuenta con Sección 1, 2 o 3. Solo tiene Sección Única.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _themeProvider.warningAmber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ═══ LISTA DE ESTUDIANTES ═══
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _themeProvider.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _themeProvider.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.4 : 0.08),
                  blurRadius: 50,
                  offset: const Offset(0, 25),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStudentRow(
                  'Carlos Mendoza López', '6° A - Primaria', 'Promedio: 9.2',
                  _themeProvider.successGreen, 'Activo', 'CM', 'Tutor: María López García',
                ),
                _buildStudentRow(
                  'Ana Sofía Ramírez Torres', '5° B - Primaria', 'Promedio: 8.8',
                  _themeProvider.successGreen, 'Activo', 'AR', 'Tutor: Juan Ramírez Pérez',
                ),
                _buildStudentRow(
                  'Diego Hernández Ruiz', '4° A - Primaria', 'Promedio: 7.5',
                  _themeProvider.warningAmber, 'Regular', 'DH', 'Tutor: Laura Hernández',
                ),
                _buildStudentRow(
                  'Valentina García Morales', '3° C - Primaria', 'Promedio: 9.5',
                  _themeProvider.successGreen, 'Activo', 'VG', 'Tutor: Roberto García',
                ),
                _buildStudentRow(
                  'Mateo Sánchez Flores', '2° A - Primaria', 'Promedio: 6.8',
                  _themeProvider.errorRed, 'Bajo Rend.', 'MS', 'Tutor: Patricia Sánchez',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSeccionesDisponibles() {
    if (_gradoSeleccionado == null) return ['Todas', 'Sección Única', 'Sección 1', 'Sección 2'];
    
    // Lógica: Maternal y Kinder solo tienen Sección Única
    if (['Maternal', 'Kinder'].contains(_gradoSeleccionado)) {
      return ['Todas', 'Sección Única'];
    }
    // 1° y 2° grado solo tienen Sección Única
    if (['1° Grado', '2° Grado'].contains(_gradoSeleccionado)) {
      return ['Todas', 'Sección Única'];
    }
    // Grados superiores tienen todas las secciones
    return ['Todas', 'Sección Única', 'Sección 1', 'Sección 2'];
  }

  void _showGradoModal() {
    final grados = [
      'Maternal', 'Kinder',
      '1° Grado', '2° Grado', '3° Grado', '4° Grado',
      '5° Grado', '6° Grado', '7° Grado', '8° Grado',
      '9° Grado', '10° Grado', '11° Grado', '12° Grado',
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _themeProvider.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _themeProvider.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.5 : 0.15),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Seleccionar Nivel Educativo',
                    style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _themeProvider.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: grados.length,
                  itemBuilder: (context, index) {
                    final grado = grados[index];
                    final isSelected = _gradoSeleccionado == grado;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _gradoSeleccionado = grado;
                            _seccionSeleccionada = 'Todas';
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      _themeProvider.accentPurple.withOpacity(0.2),
                                      _themeProvider.accentPurpleDark.withOpacity(0.1),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : _themeProvider.bgTertiary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _themeProvider.accentPurple.withOpacity(0.5)
                                  : _themeProvider.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: isSelected ? _themeProvider.accentPurple : _themeProvider.textDark,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                grado,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? _themeProvider.textPrimary : _themeProvider.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _gradoSeleccionado = null;
                          _seccionSeleccionada = 'Todas';
                        });
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: _themeProvider.bgTertiary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Limpiar', style: GoogleFonts.dmSans(color: _themeProvider.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: _themeProvider.accentPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cerrar', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSegmented({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _themeProvider.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _themeProvider.bgTertiary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _themeProvider.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isSelected = selected == opt;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark],
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _themeProvider.accentPurple.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    opt,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : _themeProvider.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterModal({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GRADO',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _themeProvider.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _themeProvider.bgTertiary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _themeProvider.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _themeProvider.accentPurple, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _gradoSeleccionado != null ? _themeProvider.textPrimary : _themeProvider.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_drop_down_rounded, color: _themeProvider.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // COMPONENTES DE FORMULARIO
  // ═══════════════════════════════════════════════════════════

  Widget _buildFormField(
    String label,
    String hint,
    IconData icon, {
    TextEditingController? controller,
    bool isDropdown = false,
    bool isMultiline = false,
    bool isMono = false,
    bool isPhone = false,
    bool isEmail = false,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase() + (required ? ' *' : ''),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _themeProvider.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _themeProvider.bgTertiary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _themeProvider.borderLight),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            keyboardType: isPhone
                ? TextInputType.phone
                : isEmail
                    ? TextInputType.emailAddress
                    : TextInputType.text,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: _themeProvider.textPrimary,
            ).copyWith(fontFamily: isMono ? 'monospace' : null),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
                : isEmail
                    ? (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      }
                    : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: _themeProvider.textDark),
              prefixIcon: Icon(icon, color: _themeProvider.textMuted, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: _themeProvider.errorRed),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OTROS COMPONENTES (Dashboard, Grupos, Calendario, Copilot)
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeaderSection(String title, String subtitle, {required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _themeProvider.accentPurple.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _themeProvider.textPrimary,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: GoogleFonts.dmSans(fontSize: 14, color: _themeProvider.textMuted, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveKpiGrid(double width) {
    int crossAxisCount = width < 768 ? 1 : (width < 1200 ? 2 : 3);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 22,
      mainAxisSpacing: 22,
      childAspectRatio: 2.0,
      children: [
        _buildKpiCard('TOTAL ALUMNOS', '1,247', '+42 este mes', Icons.people_alt_rounded,
            _themeProvider.successGreen, [40, 55, 48, 62, 58, 72, 68, 85, 78, 92, 88, 95]),
        _buildKpiCard('INSCRIPCIONES PENDIENTES', '38', 'Por validar', Icons.pending_actions_rounded,
            _themeProvider.warningAmber, [80, 75, 82, 70, 65, 58, 62, 55, 50, 48, 45, 42]),
        _buildKpiCard('ASISTENCIA HOY', '96.2%', 'Excelente', Icons.how_to_reg_rounded,
            _themeProvider.accentPurple, [90, 92, 88, 95, 94, 96, 93, 97, 95, 98, 96, 97]),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String badgeText, IconData icon, Color statusColor, List<int> sparklineData) {
    return Container(
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _themeProvider.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 35, offset: const Offset(0, 18)),
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
              Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _themeProvider.textMuted, letterSpacing: 1.8)),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Icon(icon, color: statusColor, size: 17),
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
                    Text(value, style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900, color: _themeProvider.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(badgeText, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 95,
                height: 42,
                child: CustomPaint(painter: SparklinePainter(data: sparklineData, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsAndAlertsRow(double width) {
    final bool useRow = width > 1200;
    return useRow
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _buildAnalyticsCard()),
            const SizedBox(width: 26),
            Expanded(child: _buildTerminalAlerts()),
          ])
        : Column(children: [
            _buildAnalyticsCard(),
            const SizedBox(height: 26),
            _buildTerminalAlerts(),
          ]);
  }

  Widget _buildAnalyticsCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _themeProvider.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 35, offset: const Offset(0, 18))],
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
                  Text('Métricas de Inscripción', style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary)),
                  const SizedBox(height: 5),
                  Text('Ciclo 2026-2027', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _themeProvider.textMuted, letterSpacing: 1.2)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _themeProvider.accentPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _themeProvider.accentPurple.withOpacity(0.3)),
                ),
                child: Icon(Icons.trending_up_rounded, color: _themeProvider.accentPurple, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildCustomProgressBar('Preescolar', 0.82, _themeProvider.accentPurple),
          _buildCustomProgressBar('Primaria', 0.68, _themeProvider.accentPurpleLight),
          _buildCustomProgressBar('Secundaria', 0.54, _themeProvider.successGreen),
          const SizedBox(height: 24),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: _themeProvider.bgTertiary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _themeProvider.borderLight),
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: AreaChartPainter(
                accentPurpleColor: _themeProvider.accentPurple,
                accentPurpleLightColor: _themeProvider.accentPurpleLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProgressBar(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: _themeProvider.textMuted, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                child: Text('${(percentage * 100).toInt()}%', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 9,
                decoration: BoxDecoration(
                  color: _themeProvider.bgTertiary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _themeProvider.borderLight),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage),
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

  Widget _buildTerminalAlerts() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _themeProvider.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 35, offset: const Offset(0, 18))],
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
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: _themeProvider.accentPurple,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(_pulseAnimation.value * 0.7), blurRadius: 14, spreadRadius: 2)],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text('ALERTAS EN VIVO', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary, letterSpacing: 1.8)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _themeProvider.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _themeProvider.successGreen.withOpacity(0.3)),
                ),
                child: Text('ACTIVE', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: _themeProvider.successGreen, letterSpacing: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _themeProvider.bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _themeProvider.borderLight),
            ),
            child: Column(
              children: [
                _buildTerminalLine('[OK] SISTEMA_REGISTRO_ONLINE // PORTAL_ACTIVE', _themeProvider.successGreen),
                _buildTerminalLine('[INFO] 38_INSCRIPCIONES_PENDIENTES_VALIDACION', _themeProvider.accentPurple),
                _buildTerminalLine('[WARN] DOCUMENTOS_VENCIDOS: 5_ALUMNOS', _themeProvider.warningAmber),
                _buildTerminalLine('[SYSTEM] COPILOT_IA_ANALISIS_COMPLETADO', _themeProvider.accentPurpleLight),
                _buildTerminalLine('[OK] BACKUP_DIARIO_COMPLETADO // 03:00', _themeProvider.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_themeProvider.accentPurple.withOpacity(0.12), _themeProvider.accentPurpleDark.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _themeProvider.accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _themeProvider.accentPurple, size: 15),
                    const SizedBox(width: 9),
                    Text('AI INSIGHT', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _themeProvider.accentPurple, letterSpacing: 1.8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Se detectó un incremento del 18% en inscripciones vs. ciclo anterior. Se recomienda ampliar grupo de 1° grado.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: _themeProvider.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalLine(String text, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 5)]),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(text, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildRegistrationSteps() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _themeProvider.borderLight),
      ),
      child: Row(
        children: [
          _buildStepIndicator(1, 'Datos Alumno', true, Icons.child_care_rounded),
          _buildStepConnector(true),
          _buildStepIndicator(2, 'Info Médica', false, Icons.medical_services_outlined),
          _buildStepConnector(false),
          _buildStepIndicator(3, 'Tutores', false, Icons.family_restroom_rounded),
          _buildStepConnector(false),
          _buildStepIndicator(4, 'Dirección', false, Icons.home_work_outlined),
          _buildStepConnector(false),
          _buildStepIndicator(5, 'Documentos', false, Icons.folder_outlined),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: active ? LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]) : null,
              color: active ? null : _themeProvider.bgTertiary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? Colors.transparent : _themeProvider.borderLight),
              boxShadow: active ? [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
            ),
            child: Icon(icon, color: active ? Colors.white : _themeProvider.textMuted, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? _themeProvider.textPrimary : _themeProvider.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool completed) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: completed ? LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]) : null,
          color: completed ? null : _themeProvider.bgTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _themeProvider.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(title, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: _themeProvider.textPrimary, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: Padding(padding: EdgeInsets.only(right: i < children.length - 1 ? 12 : 0), child: children[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentUploadRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: Padding(padding: EdgeInsets.only(right: i < children.length - 1 ? 12 : 0), child: children[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String title, String format, IconData icon, bool uploaded) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _themeProvider.bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uploaded ? _themeProvider.successGreen.withOpacity(0.4) : _themeProvider.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: uploaded ? _themeProvider.successGreen.withOpacity(0.15) : _themeProvider.accentPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: uploaded ? _themeProvider.successGreen.withOpacity(0.3) : _themeProvider.accentPurple.withOpacity(0.3)),
            ),
            child: Icon(uploaded ? Icons.check_circle_rounded : icon, color: uploaded ? _themeProvider.successGreen : _themeProvider.accentPurple, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(format, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.textDark)),
          const SizedBox(height: 10),
          Text(uploaded ? 'Cargado' : 'Pendiente', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: uploaded ? _themeProvider.successGreen : _themeProvider.warningAmber)),
        ],
      ),
    );
  }

  Widget _buildStudentRow(String name, String grade, String avg, Color avgColor, String status, String initials, String tutor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _themeProvider.bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeProvider.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_themeProvider.accentPurple.withOpacity(0.3), _themeProvider.accentPurpleDark.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _themeProvider.accentPurple.withOpacity(0.4)),
            ),
            child: Center(child: Text(initials, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary)),
                const SizedBox(height: 4),
                Text(tutor, style: GoogleFonts.dmSans(fontSize: 11, color: _themeProvider.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grade, style: GoogleFonts.dmSans(fontSize: 12, color: _themeProvider.textMuted)),
                const SizedBox(height: 4),
                Text(avg, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: avgColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: avgColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: avgColor.withOpacity(0.3)),
            ),
            child: Text(status, style: GoogleFonts.dmSans(fontSize: 10, color: avgColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _themeProvider.bgSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _themeProvider.borderLight),
            ),
            child: Icon(Icons.more_horiz_rounded, color: _themeProvider.textMuted, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildGruposView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Gestión de Grupos', 'Organización de clases y asignación de docentes.', icon: Icons.groups_rounded),
          const SizedBox(height: 36),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 22,
            mainAxisSpacing: 22,
            childAspectRatio: 1.8,
            children: [
              _buildGroupCard('1° A', 'Primaria', 32, 'Prof. García', _themeProvider.successGreen),
              _buildGroupCard('1° B', 'Primaria', 30, 'Prof. Martínez', _themeProvider.successGreen),
              _buildGroupCard('2° A', 'Primaria', 28, 'Prof. López', _themeProvider.successGreen),
              _buildGroupCard('3° A', 'Primaria', 31, 'Prof. Hernández', _themeProvider.warningAmber),
              _buildGroupCard('4° A', 'Primaria', 29, 'Prof. Ramírez', _themeProvider.successGreen),
              _buildGroupCard('5° B', 'Primaria', 27, 'Prof. Sánchez', _themeProvider.successGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(String grade, String level, int students, String teacher, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _themeProvider.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(grade, style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: _themeProvider.textPrimary)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Icon(Icons.groups_rounded, color: statusColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level, style: GoogleFonts.dmSans(fontSize: 12, color: _themeProvider.textMuted)),
              const SizedBox(height: 4),
              Text(teacher, style: GoogleFonts.dmSans(fontSize: 11, color: _themeProvider.textDark, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: _themeProvider.accentPurple, size: 14),
                  const SizedBox(width: 6),
                  Text('$students alumnos', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _themeProvider.accentPurple, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarioView() {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Calendario Escolar', 'Eventos, exámenes y fechas importantes del ciclo.', icon: Icons.calendar_month_rounded),
          const SizedBox(height: 36),
          Expanded(
            child: ListView(
              children: [
                _buildCalendarTimelineCard('15', 'Jul', 'Inicio de Inscripciones', 'Período de registro para nuevo ciclo escolar 2026-2027.', true, Icons.how_to_reg_rounded),
                _buildCalendarTimelineCard('22', 'Jul', 'Junta de Padres de Familia', 'Reunión informativa para tutores de nuevo ingreso.', false, Icons.groups_rounded),
                _buildCalendarTimelineCard('05', 'Ago', 'Curso Propedéutico', 'Semana de nivelación para alumnos de primer ingreso.', false, Icons.menu_book_rounded),
                _buildCalendarTimelineCard('12', 'Ago', 'Inicio de Clases', 'Primer día del ciclo escolar 2026-2027.', true, Icons.school_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTimelineCard(String day, String month, String title, String desc, bool important, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: important ? _themeProvider.accentPurple.withOpacity(0.4) : _themeProvider.borderLight),
        boxShadow: important
            ? [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 12))]
            : [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.25 : 0.05), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: important
                    ? [_themeProvider.accentPurple.withOpacity(0.25), _themeProvider.accentPurpleDark.withOpacity(0.1)]
                    : [_themeProvider.accentPurple.withOpacity(0.15), _themeProvider.accentPurpleDark.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: important ? _themeProvider.accentPurple.withOpacity(0.5) : _themeProvider.accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(day, style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w900, color: _themeProvider.textPrimary, letterSpacing: -0.5)),
                Text(month.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _themeProvider.textMuted, letterSpacing: 1.8)),
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
                    Icon(icon, color: important ? _themeProvider.accentPurple : _themeProvider.textMuted, size: 17),
                    const SizedBox(width: 9),
                    Expanded(child: Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary))),
                  ],
                ),
                const SizedBox(height: 7),
                Text(desc, style: GoogleFonts.dmSans(fontSize: 13, color: _themeProvider.textMuted, height: 1.6)),
              ],
            ),
          ),
          if (important)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.3), blurRadius: 12)],
              ),
              child: Text('IMPORTANTE', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            ),
        ],
      ),
    );
  }

  Widget _buildCopilotView() {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection('Portal Pilot Copilot', 'Asistente inteligente para gestión administrativa escolar.', icon: Icons.smart_toy_rounded),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _themeProvider.cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _themeProvider.borderLight),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.4 : 0.08), blurRadius: 50, offset: const Offset(0, 25))],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: _themeProvider.bgTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _themeProvider.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _themeProvider.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _themeProvider.successGreen.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('COPILOT IA · ONLINE', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _themeProvider.successGreen, letterSpacing: 1.5)),
                        const Spacer(),
                        Icon(Icons.shield_rounded, color: _themeProvider.accentPurple, size: 15),
                        const SizedBox(width: 8),
                        Text('CIFRADO E2E', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildChatMessage('Copilot IA', 'Buenos días. He detectado 3 registros pendientes de validación documental. ¿Deseas que te muestre el resumen?', false, '08:00'),
                        _buildChatMessage('Tú (Administrador)', 'Sí, muéstrame cuáles son y qué documentos faltan.', true, '08:02'),
                        _buildChatMessage('Copilot IA', 'Procesando base de datos... [OK]\n\n▸ Carlos Mendoza: Falta cartilla de vacunación\n▸ Ana Ramírez: CURP del tutor ilegible\n▸ Diego Hernández: Comprobante de domicilio vencido', false, '08:02'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _themeProvider.bgTertiary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _themeProvider.borderLight),
                          ),
                          child: TextField(
                            style: GoogleFonts.dmSans(color: _themeProvider.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Pregúntale a la IA escolar...',
                              hintStyle: GoogleFonts.dmSans(color: _themeProvider.textDark),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              prefixIcon: Icon(Icons.add_circle_outline_rounded, color: _themeProvider.textMuted, size: 20),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: _themeProvider.accentPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.mic_rounded, color: _themeProvider.accentPurple, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
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

  Widget _buildChatMessage(String sender, String text, bool isMe, String time) {
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
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 15),
                  ),
                Text(sender, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? _themeProvider.accentPurple : _themeProvider.textMuted, letterSpacing: 0.6)),
                const SizedBox(width: 9),
                Text(time, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.textDark, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isMe ? LinearGradient(colors: [_themeProvider.accentPurple.withOpacity(0.2), _themeProvider.accentPurpleDark.withOpacity(0.08)]) : null,
                color: isMe ? null : _themeProvider.bgTertiary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isMe ? _themeProvider.accentPurple.withOpacity(0.4) : _themeProvider.borderLight),
              ),
              child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: _themeProvider.textPrimary, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESKTOP HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: BoxDecoration(
        color: _themeProvider.bgSecondary,
        border: Border(bottom: BorderSide(color: _themeProvider.borderLight, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconButton(
                icon: _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
              ),
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _themeProvider.bgTertiary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _themeProvider.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: _themeProvider.textMuted, size: 15),
                    const SizedBox(width: 10),
                    Text('Buscar alumno, grupo...', style: GoogleFonts.dmSans(fontSize: 12, color: _themeProvider.textDark, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _themeProvider.bgPrimary,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _themeProvider.borderLight),
                      ),
                      child: Text('⌘K', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildThemeToggle(),
              const SizedBox(width: 12),
              _buildNotificationButton(),
              const SizedBox(width: 14),
              _buildIconButton(icon: Icons.bolt_rounded, color: _themeProvider.accentPurple, onTap: () {}),
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                  boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.4), blurRadius: 14)],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: _themeProvider.bgSecondary,
                  child: Text('AD', style: TextStyle(color: _themeProvider.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, Color? color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _themeProvider.bgTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _themeProvider.borderLight),
        ),
        child: Icon(icon, size: 19, color: color ?? _themeProvider.textMuted),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        _buildIconButton(icon: Icons.notifications_none_rounded, onTap: () {}),
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _themeProvider.accentPurple,
              shape: BoxShape.circle,
              border: Border.all(color: _themeProvider.bgSecondary, width: 2),
              boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.6), blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SIDEBAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSidebar({required bool isDrawer}) {
    final bool showFullText = _isSidebarExpanded || isDrawer;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: _themeProvider.bgSecondary,
        border: Border(right: BorderSide(color: _themeProvider.borderLight, width: 1)),
      ),
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
                    gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.5), blurRadius: 24, spreadRadius: 1)],
                  ),
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 23),
                ),
                if (showFullText) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PORTAL PILOT', style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w900, color: _themeProvider.textPrimary, letterSpacing: 1.2), overflow: TextOverflow.ellipsis),
                        Text('v2.4.1 · Escolar', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.textMuted, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (showFullText)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              child: Text('MÓDULOS', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _themeProvider.textDark, letterSpacing: 2.2)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _buildSidebarMenuItem(0, Icons.dashboard_customize_rounded, 'Dashboard', showFullText, false),
                _buildSidebarMenuItem(1, Icons.person_add_alt_1_rounded, 'Nuevo Registro', showFullText, true),
                _buildSidebarMenuItem(2, Icons.people_alt_rounded, 'Estudiantes', showFullText, false),
                _buildSidebarMenuItem(3, Icons.groups_rounded, 'Grupos', showFullText, false),
                _buildSidebarMenuItem(4, Icons.calendar_month_rounded, 'Calendario', showFullText, false),
                _buildSidebarMenuItem(5, Icons.smart_toy_rounded, 'Copilot IA', showFullText, true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26.0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _themeProvider.bgTertiary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _themeProvider.borderLight),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeProvider.isDarkMode ? 0.3 : 0.05), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
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
                          Text('Escuela Central', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: _themeProvider.textPrimary)),
                          Text('CICLO 2026-2027', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _themeProvider.accentPurple, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarMenuItem(int index, IconData icon, String label, bool showFull, bool isPremium) {
    final bool isSelected = _selectedMenuIndex == index;

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
            gradient: isSelected ? LinearGradient(colors: [_themeProvider.accentPurple.withOpacity(0.18), _themeProvider.accentPurpleDark.withOpacity(0.08)]) : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? _themeProvider.accentPurple.withOpacity(0.4) : Colors.transparent),
            boxShadow: isSelected ? [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))] : [],
          ),
          child: Row(
            mainAxisAlignment: showFull ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 3.5,
                  height: 22,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_themeProvider.accentPurple, _themeProvider.accentPurpleDark]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: _themeProvider.accentPurple.withOpacity(0.7), blurRadius: 8)],
                  ),
                ),
              Icon(icon, color: isSelected ? _themeProvider.accentPurple : _themeProvider.textMuted, size: 21),
              if (showFull) ...[
                const SizedBox(width: 18),
                Expanded(
                  child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? _themeProvider.textPrimary : _themeProvider.textMuted), overflow: TextOverflow.ellipsis),
                ),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: _themeProvider.warningAmber.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.workspace_premium_rounded, color: _themeProvider.warningAmber, size: 12),
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
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════

class SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;

  SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).toDouble();
    if (range == 0) return;

    final paint = Paint()..color = color..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    final fillPaint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.35), color.withOpacity(0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
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
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).toDouble();

    final paint = Paint()
      ..shader = LinearGradient(colors: [accentPurpleColor, accentPurpleLightColor]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - ((data[i - 1] - minValue) / range) * size.height * 0.8 - size.height * 0.1;
        final controlX1 = prevX + stepX / 2;
        final controlX2 = x - stepX / 2;
        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
      }
    }
    canvas.drawPath(path, paint);

    final fillPaint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accentPurpleColor.withOpacity(0.25), accentPurpleLightColor.withOpacity(0.08), Colors.transparent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}