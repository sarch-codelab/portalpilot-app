import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Membresias/plan_screen.dart';
import 'package:portal_pilot_app/Modules/Membresias/precio_screen.dart';
import 'package:portal_pilot_app/Modules/Membresias/socio_screen.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/membresia_service.dart';

/// Hub del módulo de Membresías: socios, planes y precios preferenciales.
class MembresiaHome extends StatefulWidget {
  const MembresiaHome({super.key});

  @override
  State<MembresiaHome> createState() => _MembresiaHomeState();
}

class _MembresiaHomeState extends State<MembresiaHome> {
  final _service = MembresiaService.instance;

  DashboardMembresias? _dashboard;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final d = await _service.getDashboard();
    if (!mounted) return;
    setState(() => _dashboard = d);
  }

  @override
  Widget build(BuildContext context) {
    final d = _dashboard;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'MEMBRESÍAS',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF8B5CF6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildBanner(d),
            const SizedBox(height: 16),
            _buildStats(d),
            const SizedBox(height: 20),
            Text(
              'GESTIÓN',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildAccion(
              Icons.groups_rounded,
              'Socios',
              'Registro de miembros y sus membresías vigentes',
              const Color(0xFF8B5CF6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocioScreen()),
              ).then((_) => _cargar()),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.card_membership_rounded,
              'Planes',
              'Membresías con precio, descuento y vigencia',
              const Color(0xFF3B82F6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlanScreen()),
              ).then((_) => _cargar()),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.local_offer_rounded,
              'Precios Preferenciales',
              'Precios especiales por socio y producto',
              const Color(0xFF10B981),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrecioScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(DashboardMembresias? d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_membership_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INGRESO POR MEMBRESÍAS',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'L.${_format((d?.ingresoMembresias ?? 0).toDouble())}',
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(DashboardMembresias? d) {
    return Row(
      children: [
        _buildStatCard('Socios', '${d?.totalSocios ?? 0}', Icons.groups_rounded, const Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        _buildStatCard('Activas', '${d?.sociosActivos ?? 0}', Icons.verified_rounded, const Color(0xFF10B981)),
        const SizedBox(width: 10),
        _buildStatCard('Vencidas', '${d?.sociosVencidos ?? 0}', Icons.warning_amber_rounded, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccion(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  String _format(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
