import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

class SystemLogs extends StatefulWidget {
  const SystemLogs({super.key});

  @override
  State<SystemLogs> createState() => _SystemLogsState();
}

class _SystemLogsState extends State<SystemLogs> {
  List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await Logger().getRecentLogs(lines: 100);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Logs del Sistema', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bug_report_rounded,
                        size: 64,
                        color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay logs disponibles',
                        style: GoogleFonts.dmSans(
                          color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _buildLogCard(log, palette);
                  },
                ),
    );
  }

  Widget _buildLogCard(String log, ThemePalette palette) {
    try {
      final logData = log.contains('{') ? log : '{}';
      final logMap = logData.startsWith('{') ? null : null;
      
      final level = log.contains('ERROR') ? 'ERROR' : 
                   log.contains('WARNING') ? 'WARNING' : 
                   log.contains('DEBUG') ? 'DEBUG' : 'INFO';
      
      final levelColor = level == 'ERROR' ? const Color(0xFFEF4444) : 
                       level == 'WARNING' ? const Color(0xFFF59E0B) : 
                       level == 'DEBUG' ? const Color(0xFF8B5CF6) : 
                       const Color(0xFF10B981);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: levelColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    level,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: levelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.substring(0, log.length > 100 ? 100 : log.length),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          log,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
          ),
        ),
      );
    }
  }
}