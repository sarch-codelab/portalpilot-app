import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class LibrosContables extends StatefulWidget {
  const LibrosContables({super.key});

  @override
  State<LibrosContables> createState() => _LibrosContablesState();
}

class _LibrosContablesState extends State<LibrosContables> {
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
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Libros Contables',
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
              color: const Color(0xFF8B5CF6),
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
          _buildLibroCard(
            'Libro Diario',
            'Registro cronolÃ³gico de operaciones',
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildLibroCard(
            'Libro Mayor',
            'ClasificaciÃ³n por cuentas contables',
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildLibroCard(
            'Libro de Inventarios',
            'Control de activos y existencias',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _buildLibroCard(
            'Libro de Ventas',
            'Registro de facturas emitidas',
            const Color(0xFFEC4899),
          ),
          const SizedBox(height: 12),
          _buildLibroCard(
            'Libro de Compras',
            'Registro de facturas recibidas',
            const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildLibroCard(String titulo, String descripcion, Color color) {
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.menu_book_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
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
                  descripcion,
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
    );
  }
}
