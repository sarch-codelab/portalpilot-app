import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class RolesUsuario extends StatefulWidget {
  const RolesUsuario({super.key});

  @override
  State<RolesUsuario> createState() => _RolesUsuarioState();
}

class _RolesUsuarioState extends State<RolesUsuario> {
  final List<Map<String, dynamic>> _roles = [
    {
      'id': '1',
      'nombre': 'Administrador',
      'permisos': 'Acceso total a todos los módulos',
      'usuarios': 2,
    },
    {
      'id': '2',
      'nombre': 'Gerente Comercial',
      'permisos': 'Ventas, CRM, Inventarios',
      'usuarios': 5,
    },
    {
      'id': '3',
      'nombre': 'Contador',
      'permisos': 'Contabilidad, Facturación, Reportes',
      'usuarios': 3,
    },
    {
      'id': '4',
      'nombre': 'Cajero',
      'permisos': 'POS, Clientes básicos',
      'usuarios': 8,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Los roles deben provenir del servicio de permisos; nunca de fixtures.
    _roles.clear();
    appThemeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF6366F1),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Roles de Usuario',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _roles.length,
        itemBuilder: (context, index) {
          final rol = _roles[index];
          return _buildRolCard(rol, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: const Color(0xFF6366F1),
        icon: Icon(Icons.add_rounded, color: appPalette.cardColor),
        label: Text(
          'Integración pendiente',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: appPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRolCard(Map<String, dynamic> rol, ThemePalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appPalette.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rol['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${rol['usuarios']} usuarios',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rol['permisos'],
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: appThemeNotifier.isDark
                  ? appPalette.textMuted
                  : appPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
