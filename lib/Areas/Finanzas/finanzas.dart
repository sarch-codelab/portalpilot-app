import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FinanzasDashboardScreen extends StatefulWidget {
  const FinanzasDashboardScreen({super.key});

  @override
  State<FinanzasDashboardScreen> createState() => _FinanzasDashboardScreenState();
}

class _FinanzasDashboardScreenState extends State<FinanzasDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isSidebarExpanded = true;
  int _selectedMenuIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    super.dispose();
  }

  // ── PALETA PREMIUM: NEGRO PROFUNDO + MORADO + BLANCO ──
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgSecondary = Color(0xFF080808);
  static const Color bgTertiary = Color(0xFF0F0F0F);
  static const Color cardColor = Color(0xFF111111);
  
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentPurpleLight = Color(0xFFA78BFA);
  static const Color accentPurpleDeep = Color(0xFF5B21B6);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE5E5E5);
  static const Color textMuted = Color(0xFFA3A3A3);
  static const Color textDark = Color(0xFF525252);
  
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);
  
  static const Color borderLight = Color(0x29FFFFFF);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    return Scaffold(
      backgroundColor: bgPrimary,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      appBar: isMobile
          ? AppBar(
              backgroundColor: bgSecondary,
              elevation: 0,
              iconTheme: const IconThemeData(color: textPrimary),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accentPurple, accentPurpleDark],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentPurple.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.blur_on_rounded, color: textPrimary, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PORTAL PILOT',
                    style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentPurple, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accentPurple.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: bgTertiary,
                    child: Text(
                      'CF',
                      style: TextStyle(
                        color: textPrimary,
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
                    accentPurple.withOpacity(0.03),
                    bgPrimary,
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
                          _buildTransactionsView(),
                          _buildXmlBillingView(),
                          _buildFiscalCalendarView(),
                          _buildCopilotChatView(),
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

  // ── VISTAS PRINCIPALES ─────────────────────────────────────────────────────

  Widget _buildDashboardView(double screenWidth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Dashboard Ejecutivo',
            'Supervisión financiera en tiempo real con inteligencia artificial.',
            icon: Icons.dashboard_customize_rounded,
          ),
          const SizedBox(height: 36),
          _buildResponsiveKpiGrid(screenWidth),
          const SizedBox(height: 36),
          _buildChartsAndLogsRow(screenWidth),
        ],
      ),
    );
  }

  Widget _buildTransactionsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Libro de Transacciones',
            'Historial auditado con tecnología blockchain inmutable.',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 50,
                  offset: const Offset(0, 25),
                ),
                BoxShadow(
                  color: accentPurple.withOpacity(0.05),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPremiumTransactionItem(
                  'Factura Emitida #2041',
                  'Ingreso - Cyberyx Corp',
                  '+\$14,500.00',
                  successGreen,
                  'Completado',
                  Icons.business_rounded,
                  'Hoy, 14:32',
                ),
                _buildPremiumTransactionItem(
                  'Pago de Nóminas Internas',
                  'Egreso Operativo',
                  '-\$8,400.00',
                  errorRed,
                  'Procesando',
                  Icons.people_alt_rounded,
                  'Hoy, 12:15',
                ),
                _buildPremiumTransactionItem(
                  'Retención Fiscal SAT',
                  'Impuestos directos',
                  '-\$1,250.00',
                  textMuted,
                  'Completado',
                  Icons.account_balance_rounded,
                  'Ayer, 18:00',
                ),
                _buildPremiumTransactionItem(
                  'Servicios Nube AWS',
                  'Infraestructura Dev',
                  '-\$380.00',
                  errorRed,
                  'Completado',
                  Icons.cloud_rounded,
                  'Ayer, 09:22',
                ),
                _buildPremiumTransactionItem(
                  'Inyección de Capital',
                  'Socio Inversionista',
                  '+\$50,000.00',
                  accentPurpleLight,
                  'Completado',
                  Icons.trending_up_rounded,
                  '01 Jun, 16:45',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildXmlBillingView() {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Facturación XML / SAT',
            'Buzón inteligente de carga y timbrado automatizado.',
            icon: Icons.code_rounded,
          ),
          const SizedBox(height: 48),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                padding: const EdgeInsets.all(56),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 70,
                      offset: const Offset(0, 30),
                    ),
                    BoxShadow(
                      color: accentPurple.withOpacity(0.08),
                      blurRadius: 50,
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accentPurple, accentPurpleDark],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: accentPurple.withOpacity(0.5 * _pulseAnimation.value),
                                blurRadius: 40,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: textPrimary,
                            size: 52,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Arrastra tus archivos XML o ZIP',
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'La IA procesará, validará y extraerá los conceptos fiscales de forma autónoma.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 14, color: textMuted, height: 1.7),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [accentPurple, accentPurpleDark],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentPurple.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.search_rounded, color: textPrimary, size: 20),
                        label: Text(
                          'Explorar Archivos',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFileTag('XML', accentPurple),
                        const SizedBox(width: 10),
                        _buildFileTag('ZIP', accentPurpleLight),
                        const SizedBox(width: 10),
                        _buildFileTag('PDF', accentPurpleDeep),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFileTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFiscalCalendarView() {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Calendario Fiscal',
            'Próximas obligaciones y proyecciones de impuestos.',
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 36),
          Expanded(
            child: ListView(
              children: [
                _buildCalendarTimelineCard(
                  '17',
                  'Jun',
                  'Declaración Provisional ISR/IVA',
                  'Evita recargos. Generando pre-cálculo autónomo.',
                  true,
                  Icons.warning_amber_rounded,
                ),
                _buildCalendarTimelineCard(
                  '30',
                  'Jun',
                  'Cierre de Auditoría Interna Q2',
                  'Revisión obligatoria de bitácoras y pólizas.',
                  false,
                  Icons.fact_check_rounded,
                ),
                _buildCalendarTimelineCard(
                  '10',
                  'Jul',
                  'Timbrado de Retenciones Especiales',
                  'Validación obligatoria frente a listas del SAT.',
                  false,
                  Icons.verified_rounded,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCopilotChatView() {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
            'Portal Pilot Copilot',
            'Agente inteligente autónomo especializado en optimización fiscal.',
            icon: Icons.smart_toy_rounded,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 50,
                    offset: const Offset(0, 25),
                  ),
                  BoxShadow(
                    color: accentPurple.withOpacity(0.05),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: successGreen.withOpacity(0.6),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'COPILOT IA · ONLINE',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: successGreen,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.shield_rounded, color: accentPurple, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          'CIFRADO E2E',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: textMuted,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildChatMessage(
                          'Copilot IA',
                          'Bienvenido al centro neurálgico financiero. He detectado un ahorro potencial del 4.2% si optimizamos las amortizaciones pendientes este mes. ¿Quieres ver la proyección?',
                          false,
                          '14:32',
                        ),
                        _buildChatMessage(
                          'Tú (Developer)',
                          'Sí, muéstrame el desglose por categorías e infraestructura.',
                          true,
                          '14:33',
                        ),
                        _buildChatMessage(
                          'Copilot IA',
                          'Procesando matrices de datos... [OK]\n\n▸ Infraestructura AWS: -\$380.00 deducible al 100%\n▸ Servicios Externos: Optimizables mediante relocalización fiscal\n▸ Amortizaciones: \$2,400 pendientes de aplicación',
                          false,
                          '14:33',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgTertiary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderLight),
                          ),
                          child: TextField(
                            style: GoogleFonts.dmSans(color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Pregúntale a la IA corporativa...',
                              hintStyle: GoogleFonts.dmSans(color: textDark),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              prefixIcon: const Icon(Icons.add_circle_outline_rounded, color: textMuted, size: 20),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accentPurple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.mic_rounded, color: accentPurple, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [accentPurple, accentPurpleDark],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentPurple.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: textPrimary, size: 20),
                          onPressed: () {},
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ── COMPONENTES PREMIUM ────────────────────────────────────────────────────

  Widget _buildHeaderSection(String title, String subtitle, {required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accentPurple, accentPurpleDark],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accentPurple.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: textPrimary, size: 26),
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
                  color: textPrimary,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: GoogleFonts.dmSans(fontSize: 14, color: textMuted, height: 1.5)),
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
        _buildKpiCard(
          'FLUJO NETO MENSUAL',
          '\$425,890.00',
          '+14.2%',
          Icons.account_balance_wallet_outlined,
          successGreen,
          [40, 55, 48, 62, 58, 72, 68, 85, 78, 92, 88, 95],
        ),
        _buildKpiCard(
          'CUENTAS POR COBRAR',
          '\$18,230.00',
          'Crítico',
          Icons.assignment_late_outlined,
          errorRed,
          [80, 75, 82, 70, 65, 58, 62, 55, 50, 48, 45, 42],
        ),
        _buildKpiCard(
          'CONCILIACIONES',
          '4 Pendientes',
          'Acción Req.',
          Icons.fact_check_outlined,
          accentPurple,
          [30, 45, 40, 55, 50, 60, 58, 65, 62, 70, 68, 75],
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String badgeText,
    IconData icon,
    Color statusColor,
    List<int> sparklineData,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 25,
            spreadRadius: -8,
          ),
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
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                  letterSpacing: 1.8,
                ),
              ),
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
                    Text(
                      value,
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 95,
                height: 42,
                child: CustomPaint(
                  painter: SparklinePainter(
                    data: sparklineData,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsAndLogsRow(double width) {
    final bool useRow = width > 1200;
    final children = [
      Expanded(flex: useRow ? 2 : 0, child: _buildVisualAnalyticsCard()),
      if (useRow) const SizedBox(width: 26),
      if (!useRow) const SizedBox(height: 26),
      Expanded(flex: useRow ? 1 : 0, child: _buildTerminalStatusAlerts()),
    ];
    return useRow ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children) : Column(children: children);
  }

  Widget _buildVisualAnalyticsCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: accentPurple.withOpacity(0.06),
            blurRadius: 25,
            spreadRadius: -8,
          ),
        ],
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
                  Text(
                    'Métricas de Absorción',
                    style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Q2 · 2026',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: accentPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accentPurple.withOpacity(0.3)),
                ),
                child: const Icon(Icons.insights_rounded, color: accentPurple, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildCustomProgressBar('Infraestructura Cloud', 0.72, accentPurple),
          _buildCustomProgressBar('Gastos Operativos', 0.45, accentPurpleLight),
          _buildCustomProgressBar('Margen de Reserva Fiscal', 0.88, successGreen),
          const SizedBox(height: 24),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: bgTertiary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderLight),
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: AreaChartPainter(
                accentPurpleColor: accentPurple,
                accentPurpleLightColor: accentPurpleLight,
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
              Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 9,
                decoration: BoxDecoration(
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: borderLight),
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
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
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

  Widget _buildTerminalStatusAlerts() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: accentPurple.withOpacity(0.06),
            blurRadius: 25,
            spreadRadius: -8,
          ),
        ],
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
                      color: accentPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentPurple.withOpacity(_pulseAnimation.value * 0.7),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                'COPILOT LIVE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: successGreen.withOpacity(0.3)),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: successGreen,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderLight),
            ),
            child: Column(
              children: [
                _buildTerminalLine('[OK] CORE_NET_CONNECTED // PORT 8080', successGreen),
                _buildTerminalLine('[INFO] SYNCHRONIZING_NOCODB_LEDGER', accentPurple),
                _buildTerminalLine('[WARN] AWS_ANOMALY_DETECTION: \$380.00', warningAmber),
                _buildTerminalLine('[SYSTEM] AGENT_INTELLIGENCE_ONLINE', accentPurpleLight),
                _buildTerminalLine('[OK] BLOCKCHAIN_HASH: 0x82f4a1b9...', textMuted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentPurple.withOpacity(0.12), accentPurpleDark.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: accentPurple, size: 15),
                    const SizedBox(width: 9),
                    Text(
                      'AI INSIGHT',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentPurple,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Se detectó un patrón de gasto inusual en servicios cloud. Se recomienda revisión.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary, height: 1.6),
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
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 5)],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTransactionItem(
    String title,
    String desc,
    String value,
    Color valueColor,
    String status,
    IconData icon,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [valueColor.withOpacity(0.2), valueColor.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: valueColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: valueColor, size: 21),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      desc,
                      style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '· $time',
                      style: GoogleFonts.spaceGrotesk(fontSize: 10, color: textDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: valueColor.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: GoogleFonts.dmSans(fontSize: 10, color: valueColor, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTimelineCard(
    String day,
    String month,
    String title,
    String desc,
    bool alert,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alert ? accentPurple.withOpacity(0.4) : borderLight,
        ),
        boxShadow: alert
            ? [
                BoxShadow(
                  color: accentPurple.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: alert
                    ? [accentPurple.withOpacity(0.25), accentPurpleDark.withOpacity(0.1)]
                    : [accentPurple.withOpacity(0.15), accentPurpleDark.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: alert ? accentPurple.withOpacity(0.5) : accentPurple.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  day,
                  style: GoogleFonts.syne(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  month.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                    letterSpacing: 1.8,
                  ),
                ),
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
                    Icon(icon, color: alert ? accentPurple : textMuted, size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  desc,
                  style: GoogleFonts.dmSans(fontSize: 13, color: textMuted, height: 1.6),
                ),
              ],
            ),
          ),
          if (alert)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accentPurple, accentPurpleDark],
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: accentPurple.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                'URGENTE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 1.2,
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accentPurple, accentPurpleDark],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: accentPurple.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: textPrimary, size: 15),
                  ),
                Text(
                  sender,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMe ? accentPurple : textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  time,
                  style: GoogleFonts.spaceGrotesk(fontSize: 10, color: textDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accentPurple.withOpacity(0.2), accentPurpleDark.withOpacity(0.08)],
                      )
                    : null,
                color: isMe ? null : bgTertiary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isMe ? accentPurple.withOpacity(0.4) : borderLight,
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DESKTOP HEADER ─────────────────────────────────────────────────────────
  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: BoxDecoration(
        color: bgSecondary,
        border: Border(bottom: BorderSide(color: borderLight, width: 1)),
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
                  color: bgTertiary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: textMuted, size: 15),
                    const SizedBox(width: 10),
                    Text(
                      'Buscar módulos...',
                      style: GoogleFonts.dmSans(fontSize: 12, color: textDark, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bgPrimary,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: borderLight),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.spaceGrotesk(fontSize: 10, color: textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNotificationButton(),
              const SizedBox(width: 14),
              _buildIconButton(
                icon: Icons.bolt_rounded,
                color: accentPurple,
                onTap: () {},
              ),
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentPurple, accentPurpleDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentPurple.withOpacity(0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: bgSecondary,
                  child: const Text(
                    'CF',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, Color color = textMuted, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bgTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderLight),
        ),
        child: Icon(icon, size: 19, color: color),
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
              color: accentPurple,
              shape: BoxShape.circle,
              border: Border.all(color: bgSecondary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: accentPurple.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── SIDEBAR ────────────────────────────────────────────────────────────────
  Widget _buildSidebar({required bool isDrawer}) {
    final bool showFullText = _isSidebarExpanded || isDrawer;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: bgSecondary,
        border: Border(right: BorderSide(color: borderLight, width: 1)),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentPurple, accentPurpleDark],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: accentPurple.withOpacity(0.5),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.blur_on_rounded, color: textPrimary, size: 23),
                ),
                if (showFullText) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PORTAL PILOT',
                          style: GoogleFonts.syne(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'v2.4.1 · Enterprise',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: textMuted,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
              child: Text(
                'MÓDULOS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: 2.2,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _buildSidebarMenuItem(0, Icons.dashboard_customize_rounded, 'Dashboard General', showFullText, false),
                _buildSidebarMenuItem(1, Icons.receipt_long_rounded, 'Libro Mayor Ledger', showFullText, false),
                _buildSidebarMenuItem(2, Icons.code_rounded, 'Facturación XML', showFullText, false),
                _buildSidebarMenuItem(3, Icons.calendar_month_rounded, 'Calendario Fiscal', showFullText, true),
                _buildSidebarMenuItem(4, Icons.smart_toy_rounded, 'Copilot Live IA', showFullText, true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26.0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bgTertiary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: accentPurple.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accentPurple, accentPurpleDark],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.security_rounded, color: textPrimary, size: 17),
                  ),
                  if (showFullText) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cyberyx Tech',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          Text(
                            'ENTERPRISE PRO',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              color: accentPurple,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
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
          if (MediaQuery.of(context).size.width < 1024) {
            Navigator.pop(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentPurple.withOpacity(0.18), accentPurpleDark.withOpacity(0.08)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? accentPurple.withOpacity(0.4) : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentPurple.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accentPurple, accentPurpleDark],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(color: accentPurple.withOpacity(0.7), blurRadius: 8),
                    ],
                  ),
                ),
              Icon(
                icon,
                color: isSelected ? accentPurple : textMuted,
                size: 21,
              ),
              if (showFull) ...[
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? textPrimary : textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: warningAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: warningAmber, size: 12),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTERS ──────────────────────────────────────────────────────────

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

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.35), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

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
      ..shader = LinearGradient(
        colors: [accentPurpleColor, accentPurpleLightColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
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

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentPurpleColor.withOpacity(0.25), accentPurpleLightColor.withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height * 0.8 - size.height * 0.1;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = accentPurpleColor);
      canvas.drawCircle(
        Offset(x, y),
        7,
        Paint()..color = accentPurpleColor.withOpacity(0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}