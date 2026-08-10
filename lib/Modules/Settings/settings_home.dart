import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/fiscal_compliance.dart';
import 'package:portal_pilot_app/Shared/utils/backup_manager.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/utils/cache_manager.dart';
import 'package:portal_pilot_app/Modules/Settings/fiscal_settings.dart';
import 'package:portal_pilot_app/Modules/Settings/backup_settings.dart';
import 'package:portal_pilot_app/Modules/Settings/system_logs.dart';

class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    FiscalCompliance().loadConfig();
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6B7280), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('CONFIGURACIÓN', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF6B7280),
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
          _buildSectionHeader('SISTEMA'),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.settings_rounded,
            'Configuración Fiscal',
            'RTN, CAI, tasas de impuestos SAR',
            const Color(0xFF10B981),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FiscalSettings())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.backup_rounded,
            'Backup y Restauración',
            'Gestión de backups de datos',
            const Color(0xFF3B82F6),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSettings())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.bug_report_rounded,
            'Logs del Sistema',
            'Visualización de logs y auditoría',
            const Color(0xFFF59E0B),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemLogs())),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('RENDIMIENTO'),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.speed_rounded,
            'Optimización de Caché',
            'Gestión de caché local',
            const Color(0xFF8B5CF6),
            () => _showCacheOptions(),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.storage_rounded,
            'Limpieza de Datos',
            'Eliminar datos temporales y logs antiguos',
            const Color(0xFFEF4444),
            () => _showCleanupOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark ? const Color(0xFF525252) : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showCacheOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Opciones de Caché', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
              title: Text('Limpiar caché expirado', style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
              onTap: () async {
                await CacheManager().clearExpired();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Caché expirado limpiado'), backgroundColor: Color(0xFF10B981)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
              title: Text('Limpiar todo el caché', style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
              onTap: () async {
                await CacheManager().clearAll();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Caché limpiado completamente'), backgroundColor: Color(0xFF10B981)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
          ),
        ],
      ),
    );
  }

  void _showCleanupOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Limpieza de Datos', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFF59E0B)),
              title: Text('Limpiar logs antiguos (7 días)', style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
              onTap: () async {
                await Logger().cleanOldLogs(daysToKeep: 7);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs antiguos limpiados'), backgroundColor: Color(0xFF10B981)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
              title: Text('Limpiar todos los logs', style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
              onTap: () async {
                final logger = Logger();
                await logger.cleanOldLogs(daysToKeep: 0);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todos los logs limpiados'), backgroundColor: Color(0xFF10B981)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
          ),
        ],
      ),
    );
  }
}