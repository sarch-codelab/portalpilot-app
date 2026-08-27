import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracionSeguridad extends StatefulWidget {
  const ConfiguracionSeguridad({super.key});

  @override
  State<ConfiguracionSeguridad> createState() => _ConfiguracionSeguridadState();
}

class _ConfiguracionSeguridadState extends State<ConfiguracionSeguridad> {
  bool _2FAHabilitado = false;
  bool _sesionUnica = true;
  bool _bloqueoIntentos = true;
  int _intentosMaximos = 5;
  int _tiempoBloqueo = 15;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarConfig();
  }

  Future<void> _cargarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _2FAHabilitado = prefs.getBool('seg_2fa') ?? false;
      _sesionUnica = prefs.getBool('seg_sesion_unica') ?? true;
      _bloqueoIntentos = prefs.getBool('seg_bloqueo') ?? true;
      _intentosMaximos = prefs.getInt('seg_intentos') ?? 5;
      _tiempoBloqueo = prefs.getInt('seg_tiempo') ?? 15;
    });
  }

  Future<void> _guardarConfig(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
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
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuracion de Seguridad',
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
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSecurityCard(
            Icons.verified_user_rounded,
            'Autenticacion de Dos Factores (2FA)',
            'Proteccion adicional para iniciar sesion',
            _2FAHabilitado,
            (value) { setState(() => _2FAHabilitado = value); _guardarConfig('seg_2fa', value); },
          ),
          const SizedBox(height: 12),
          _buildSecurityCard(
            Icons.devices_rounded,
            'Sesion Unica',
            'Permitir solo una sesion activa por usuario',
            _sesionUnica,
            (value) { setState(() => _sesionUnica = value); _guardarConfig('seg_sesion_unica', value); },
          ),
          const SizedBox(height: 12),
          _buildSecurityCard(
            Icons.lock_rounded,
            'Bloqueo por Intentos',
            'Bloquear cuenta tras intentos fallidos',
            _bloqueoIntentos,
            (value) { setState(() => _bloqueoIntentos = value); _guardarConfig('seg_bloqueo', value); },
          ),
          const SizedBox(height: 20),
          if (_bloqueoIntentos) ...[
            _buildSettingsCard(
              'Intentos Maximos',
              '$_intentosMaximos intentos',
              Icons.numbers_rounded,
              () => _showIntentosDialog(),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              'Tiempo de Bloqueo',
              '$_tiempoBloqueo minutos',
              Icons.timer_rounded,
              () => _showTiempoDialog(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityCard(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: appThemeNotifier.isDark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark
              ? const Color(0xFF111111)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appThemeNotifier.isDark
                ? const Color(0xFF262626)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appThemeNotifier.isDark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark
                          ? const Color(0xFFA3A3A3)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark
                  ? const Color(0xFF525252)
                  : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showIntentosDialog() {
    final controller = TextEditingController(text: _intentosMaximos.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Intentos Maximos',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Numero de intentos',
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
              final val = int.tryParse(controller.text) ?? 5;
              setState(() => _intentosMaximos = val);
              _guardarConfig('seg_intentos', val);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
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

  void _showTiempoDialog() {
    final controller = TextEditingController(text: _tiempoBloqueo.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Tiempo de Bloqueo',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Minutos',
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
              final val = int.tryParse(controller.text) ?? 15;
              setState(() => _tiempoBloqueo = val);
              _guardarConfig('seg_tiempo', val);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
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
