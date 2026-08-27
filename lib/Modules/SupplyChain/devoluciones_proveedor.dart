import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class DevolucionesProveedor extends StatefulWidget {
  const DevolucionesProveedor({super.key});

  @override
  State<DevolucionesProveedor> createState() => _DevolucionesProveedorState();
}

class _DevolucionesProveedorState extends State<DevolucionesProveedor> {
  List<dynamic> _compras = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/compras');
      if (api.isSuccess(result)) {
        if (mounted) {
          setState(() {
            _compras = result['compras'] ?? [];
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
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
            color: Color(0xFFEF4444),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Devoluciones a Proveedor',
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
              color: const Color(0xFFEF4444),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
          : _compras.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_return_rounded, size: 64,
                        color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),
                      Text('No hay compras registradas',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                        )),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _compras.length,
                  itemBuilder: (context, index) {
                    final c = _compras[index];
                    final estado = c['estado'] ?? 'pendiente';
                    final colorEstado = estado == 'recibida'
                        ? const Color(0xFF10B981)
                        : estado == 'anulada'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorEstado.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shopping_cart_rounded, color: colorEstado, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['correlativo'] ?? 'S/N',
                                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
                                const SizedBox(height: 4),
                                Text(c['proveedor_nombre'] ?? 'Sin proveedor',
                                  style: GoogleFonts.dmSans(fontSize: 12,
                                    color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('L.${(c['total'] ?? 0).toStringAsFixed(0)}',
                                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: colorEstado)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorEstado.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(estado.toUpperCase(),
                                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: colorEstado)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
