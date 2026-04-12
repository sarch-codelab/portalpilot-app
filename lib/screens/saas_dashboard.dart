import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

class SaasDashboard extends StatefulWidget {
  const SaasDashboard({super.key});

  @override
  State<SaasDashboard> createState() => _SaasDashboardState();
}

class _SaasDashboardState extends State<SaasDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;

  // Datos de empresas
  final List<Map<String, dynamic>> _companies = [
    {
      'name': 'Tech Solutions',
      'code': 'TECH01',
      'plan': 'Enterprise',
      'users': 24,
      'status': 'Activo'
    },
    {
      'name': 'Logistics Corp',
      'code': 'LOG02',
      'plan': 'Pro',
      'users': 12,
      'status': 'Activo'
    },
    {
      'name': 'Global Retail',
      'code': 'GLB03',
      'plan': 'Free',
      'users': 5,
      'status': 'Prueba'
    },
    {
      'name': 'Consulting Group',
      'code': 'CNS04',
      'plan': 'Pro',
      'users': 8,
      'status': 'Activo'
    },
    {
      'name': 'Health Systems',
      'code': 'HLT05',
      'plan': 'Enterprise',
      'users': 32,
      'status': 'Activo'
    },
    {
      'name': 'FinTech Corp',
      'code': 'FIN06',
      'plan': 'Pro',
      'users': 18,
      'status': 'Activo'
    },
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.business_outlined, 'label': 'Empresas', 'index': 1},
    {'icon': Icons.people_outline, 'label': 'Usuarios', 'index': 2},
    {'icon': Icons.credit_card_outlined, 'label': 'Planes', 'index': 3},
    {'icon': Icons.bar_chart_outlined, 'label': 'Analytics', 'index': 4},
    {'icon': Icons.settings_outlined, 'label': 'Configuración', 'index': 5},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation =
        Tween<double>(begin: 1.0, end: 0.7).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SplashScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // En móvil, la sidebar se colapsa automáticamente
    if (isMobile && !_isSidebarCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isSidebarCollapsed = true);
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF0A0E17), Color(0xFF0F1118), Color(0xFF05080F)],
          ),
        ),
        child: Row(
          children: [
            // Sidebar colapsable
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidebarCollapsed
                  ? (isMobile ? 60 : 70)
                  : (isMobile ? 220 : 260),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: const Color(0xFF0F1118),
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Logo colapsable
                  _buildLogo(isMobile),
                  const SizedBox(height: 30),
                  // Menú items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        return _buildMenuItem(
                            _menuItems[index], index, isMobile);
                      },
                    ),
                  ),
                  // Botón colapsar (solo en desktop/tablet)
                  if (!isMobile) _buildCollapseButton(),
                  const SizedBox(height: 16),
                  // Perfil y logout
                  _buildProfileSection(isMobile),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Column(
                children: [
                  // Header responsive
                  _buildHeader(isMobile, isTablet, screenWidth),
                  // Contenido según índice seleccionado
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildDashboardContent(isMobile),
                        _buildCompaniesContent(isMobile),
                        _buildUsersContent(isMobile),
                        _buildPlansContent(isMobile),
                        _buildAnalyticsContent(isMobile),
                        _buildSettingsContent(isMobile),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isMobile) {
    if (_isSidebarCollapsed) {
      return Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome, size: 24, color: Colors.white),
        ),
      );
    }
    return Column(
      children: [
        Text(
          'PORTALPILOT',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0EA5E9),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SaaS CONTROL',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, int index, bool isMobile) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item['icon'],
                size: 20,
                color: isSelected ? const Color(0xFF0EA5E9) : Colors.white54,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['label'],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _isSidebarCollapsed = !_isSidebarCollapsed;
            if (_isSidebarCollapsed) {
              _animationController.forward();
            } else {
              _animationController.reverse();
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 20,
                color: Colors.white54,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  'Colapsar menú',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => _logout(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Admin',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'admin@portalpilot.com',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.logout, size: 16, color: Colors.white54),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isTablet, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      color: const Color(0xFF111827),
      child: Row(
        children: [
          // Botón para móvil (mostrar/ocultar sidebar)
          if (isMobile)
            IconButton(
              onPressed: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
          Expanded(
            child: Text(
              _getTitle(),
              style: GoogleFonts.inter(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge de estado
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isMobile ? 'ONLINE' : 'SISTEMA OPERATIVO',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 9 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    const titles = [
      'Dashboard Global',
      'Gestión de Empresas',
      'Usuarios del Sistema',
      'Planes y Facturación',
      'Analytics',
      'Configuración',
    ];
    return titles[_selectedIndex];
  }

  // Dashboard content
  Widget _buildDashboardContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          // Stats cards grid responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : (constraints.maxWidth > 500 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard('Empresas', '12', '+2 este mes',
                      const Color(0xFF0EA5E9), Icons.business),
                  _buildStatCard('Usuarios', '156', '+23%',
                      const Color(0xFF10B981), Icons.people),
                  _buildStatCard('Ingresos', 'L.45,200', '+12%',
                      const Color(0xFFF59E0B), Icons.trending_up),
                  _buildStatCard('Planes Pro', '8/12', '66% ocupación',
                      const Color(0xFF8B5CF6), Icons.credit_card),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Gráfico de ingresos (simulado)
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresos Mensuales',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      final height = [45, 65, 80, 70, 90, 75][index];
                      return Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: 30,
                              height: height.toDouble(),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF3B82F6)
                                  ],
                                ),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'][index],
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String trend, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(trend, style: GoogleFonts.inter(fontSize: 10, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Companies content
  Widget _buildCompaniesContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business,
                          size: 20, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      const Text('EMPRESAS REGISTRADAS',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nueva Empresa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMobile)
                  ..._companies
                      .map((company) => _buildCompanyCardMobile(company))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 32,
                      headingRowColor: WidgetStateProperty.all(
                          Colors.white.withOpacity(0.03)),
                      headingTextStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54),
                      dataTextStyle: const TextStyle(fontSize: 12),
                      columns: const [
                        DataColumn(label: Text('EMPRESA')),
                        DataColumn(label: Text('CÓDIGO')),
                        DataColumn(label: Text('PLAN')),
                        DataColumn(label: Text('USUARIOS')),
                        DataColumn(label: Text('ESTADO')),
                        DataColumn(label: Text('ACCIONES')),
                      ],
                      rows: _companies
                          .map((company) => _buildCompanyRow(company))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCardMobile(Map<String, dynamic> company) {
    Color planColor;
    switch (company['plan']) {
      case 'Enterprise':
        planColor = const Color(0xFF8B5CF6);
        break;
      case 'Pro':
        planColor = const Color(0xFF0EA5E9);
        break;
      default:
        planColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(company['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(company['plan'],
                    style: TextStyle(fontSize: 10, color: planColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Código: ${company['code']}',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          Text('Usuarios: ${company['users']}',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(company['status'],
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF10B981))),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {},
                  color: Colors.white54),
              IconButton(
                  icon: const Icon(Icons.more_vert, size: 16),
                  onPressed: () {},
                  color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _buildCompanyRow(Map<String, dynamic> company) {
    Color planColor;
    switch (company['plan']) {
      case 'Enterprise':
        planColor = const Color(0xFF8B5CF6);
        break;
      case 'Pro':
        planColor = const Color(0xFF0EA5E9);
        break;
      default:
        planColor = const Color(0xFFF59E0B);
    }

    return DataRow(cells: [
      DataCell(Text(company['name'],
          style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(company['code'],
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: planColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(company['plan'],
            style: TextStyle(fontSize: 10, color: planColor)),
      )),
      DataCell(Text('${company['users']}')),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(company['status'],
            style: const TextStyle(fontSize: 10, color: Color(0xFF10B981))),
      )),
      DataCell(Row(
        children: [
          IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () {},
              color: Colors.white54),
          IconButton(
              icon: const Icon(Icons.more_vert, size: 16),
              onPressed: () {},
              color: Colors.white54),
        ],
      )),
    ]);
  }

  // Users content
  Widget _buildUsersContent(bool isMobile) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Text(
          'Gestión de Usuarios - Próximamente',
          style: GoogleFonts.inter(fontSize: 18, color: Colors.white54),
        ),
      ),
    );
  }

  // Plans content
  Widget _buildPlansContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
        children: [
          _buildPlanCard('Free', 'L.0', 'Para pruebas', const Color(0xFFF59E0B),
              ['1 empresa', '5 usuarios', 'Soporte básico']),
          _buildPlanCard('Pro', 'L.1,500/mes', 'Para profesionales',
              const Color(0xFF0EA5E9), [
            '5 empresas',
            '50 usuarios',
            'Soporte prioritario',
            'API acceso'
          ]),
          _buildPlanCard(
              'Enterprise',
              'Personalizado',
              'Para grandes corporaciones',
              const Color(0xFF8B5CF6),
              ['Ilimitado', 'Soporte 24/7', 'On-premise', 'SLA garantizado']),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String name, String price, String description,
      Color color, List<String> features) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(price,
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: color),
                      const SizedBox(width: 8),
                      Text(f, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Seleccionar'),
            ),
          ],
        ),
      ),
    );
  }

  // Analytics content
  Widget _buildAnalyticsContent(bool isMobile) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Text(
          'Analytics y Reportes - Próximamente',
          style: GoogleFonts.inter(fontSize: 18, color: Colors.white54),
        ),
      ),
    );
  }

  // Settings content
  Widget _buildSettingsContent(bool isMobile) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Text(
          'Configuración del Sistema - Próximamente',
          style: GoogleFonts.inter(fontSize: 18, color: Colors.white54),
        ),
      ),
    );
  }
}
