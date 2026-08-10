// lib/Home/multi_area_config_screen.dart
// Configuración Multi-Área: permite al admin definir el área de negocio de la
// empresa y activar/desactivar módulos (feature flags) por empresa.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';

class MultiAreaConfigScreen extends StatefulWidget {
  const MultiAreaConfigScreen({super.key});

  @override
  State<MultiAreaConfigScreen> createState() => _MultiAreaConfigScreenState();
}

class _MultiAreaConfigScreenState extends State<MultiAreaConfigScreen> {
  final MultiAreaConfig _config = MultiAreaConfig.instance;
  bool _cargando = true;
  bool _autorizado = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final esAdmin = AuthController.instance.esRoot;
    if (!esAdmin) {
      if (mounted) setState(() => _autorizado = false);
      return;
    }
    if (!_config.inicializado) {
      await _config.cargar();
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cambiarArea(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          'Cambiar área de negocio',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Se restablecerán los módulos a los valores por defecto de la nueva área. ¿Continuar?',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFFA3A3A3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFFA3A3A3)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cambiar',
              style: TextStyle(color: Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _config.setAreaNegocio(id);
    if (mounted) setState(() {});
  }

  Future<void> _restablecer() async {
    await _config.restablecerPorArea();
    if (mounted) setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Módulos restablecidos según el área ${_config.areaInfo.nombre}',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'CONFIGURACIÓN MULTI-ÁREA',
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_autorizado) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 12),
            Text(
              'Acceso restringido',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Solo el administrador puede configurar las áreas.',
              style: GoogleFonts.dmSans(fontSize: 13, color: Color(0xFFA3A3A3)),
            ),
          ],
        ),
      );
    }

    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    final area = _config.areaInfo;
    final empresa = AuthController.instance.empresaNombre.isNotEmpty
        ? AuthController.instance.empresaNombre
        : AuthController.instance.empresaCodigo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMPRESA',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA3A3A3),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                empresa,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Código: ${_config.empresaCodigo}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFFA3A3A3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection('ÁREA DE NEGOCIO'),
        const SizedBox(height: 10),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: area.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(area.icono, color: area.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.nombre,
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          area.descripcion,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: area.id,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF111111),
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                  items: AreasNegocio.catalogo
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(
                            children: [
                              Icon(a.icono, color: a.color, size: 16),
                              const SizedBox(width: 8),
                              Text(a.nombre),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) _cambiarArea(id);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection('MÓDULOS ACTIVOS'),
        const SizedBox(height: 10),
        _buildCard(
          child: Column(
            children: Modulo.modulosDisponibles
                .map(
                  (m) => SwitchListTile(
                    value: _config.moduloActivo(m.id),
                    onChanged: (v) => _toggleModulo(m.id, v),
                    activeTrackColor: m.color,
                    activeThumbColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(m.icono, color: m.color, size: 18),
                    ),
                    title: Text(
                      m.nombre,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      m.descripcion,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFFA3A3A3),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _buildRestablecerButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _toggleModulo(String id, bool activo) async {
    await _config.setModuloActivo(id, activo);
    if (mounted) setState(() {});
  }

  Widget _buildSection(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFA3A3A3),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildRestablecerButton() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _restablecer,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Restablecer módulos por área',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
