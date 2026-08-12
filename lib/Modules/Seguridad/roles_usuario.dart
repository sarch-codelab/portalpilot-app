import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class RolesUsuario extends StatefulWidget {
  const RolesUsuario({super.key});

  @override
  State<RolesUsuario> createState() => _RolesUsuarioState();
}

class _RolesUsuarioState extends State<RolesUsuario> {
  List<Map<String, dynamic>> _roles = [
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
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
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
        onPressed: () => _showAddRolDialog(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nuevo Rol',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E7EB),
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
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
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
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRolDialog() {
    final nombreController = TextEditingController();
    final permisosController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Nuevo Rol',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del rol',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: permisosController,
              decoration: InputDecoration(
                labelText: 'Permisos',
                labelStyle: TextStyle(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _roles.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'permisos': permisosController.text,
                  'usuarios': 0,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
