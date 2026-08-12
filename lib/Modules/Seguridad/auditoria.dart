import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

class Auditoria extends StatefulWidget {
  const Auditoria({super.key});

  @override
  State<Auditoria> createState() => _AuditoriaState();
}

class _AuditoriaState extends State<Auditoria> {
  List<_LogEntry> _logs = [];
  bool _isLoading = true;
  String _filtro = 'todos'; // todos | auditoria | errores

  @override
  void initState() {
    super.initState();
    _loadLogs();
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

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final lines = await Logger().getRecentLogs(lines: 300);
    final entries = lines.map(_LogEntry.fromLine).whereType<_LogEntry>().toList();
    if (mounted) {
      setState(() {
        _logs = entries;
        _isLoading = false;
      });
    }
  }

  List<_LogEntry> get _filtrados {
    switch (_filtro) {
      case 'auditoria':
        return _logs.where((e) => e.esAuditoria).toList();
      case 'errores':
        return _logs
            .where((e) => e.level == 'ERROR' || e.level == 'CRITICAL')
            .toList();
      default:
        return _logs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final filtrados = _filtrados;
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Auditoría de Acciones',
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
              color: const Color(0xFF10B981),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
            onPressed: _loadLogs,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _buildFilterChip('Todos', 'todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Auditoría', 'auditoria'),
                const SizedBox(width: 8),
                _buildFilterChip('Errores', 'errores'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? _buildEmpty(palette)
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        color: const Color(0xFF10B981),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            return _buildLogCard(filtrados[index], palette);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filtro == value;
    return GestureDetector(
      onTap: () => setState(() => _filtro = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : appThemeNotifier.isDark
                  ? const Color(0xFF141414)
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF10B981)
                : appThemeNotifier.isDark
                    ? const Color(0xFF262626)
                    : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? const Color(0xFF10B981)
                : appThemeNotifier.isDark
                    ? const Color(0xFFA3A3A3)
                    : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemePalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: appThemeNotifier.isDark
                ? const Color(0xFF262626)
                : const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin registros de auditoría',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las acciones del sistema aparecerán aquí',
            style: GoogleFonts.dmSans(
              color: appThemeNotifier.isDark
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(_LogEntry e, ThemePalette palette) {
    final levelColor = e.level == 'ERROR' || e.level == 'CRITICAL'
        ? const Color(0xFFEF4444)
        : e.level == 'WARNING'
            ? const Color(0xFFF59E0B)
            : e.level == 'DEBUG'
                ? const Color(0xFF8B5CF6)
                : e.esAuditoria
                    ? const Color(0xFF10B981)
                    : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                  e.level,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: levelColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (e.fecha != null)
                Text(
                  e.fecha!,
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF737373)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              const Spacer(),
              if (e.module != null && e.module!.isNotEmpty)
                Text(
                  e.module!,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF737373)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            e.descripcion,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: appThemeNotifier.isDark
                  ? const Color(0xFFE5E5E5)
                  : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String timestamp;
  final String level;
  final String message;
  final String? module;
  final Map<String, dynamic>? metadata;

  _LogEntry._({
    required this.timestamp,
    required this.level,
    required this.message,
    this.module,
    this.metadata,
  });

  static _LogEntry? fromLine(String line) {
    try {
      final m = line.trim().startsWith('{') ? (jsonDecode(line) as Map<String, dynamic>) : null;
      if (m == null) return null;
      return _LogEntry._(
        timestamp: (m['timestamp'] ?? '').toString(),
        level: (m['level'] ?? 'INFO').toString().toUpperCase(),
        message: (m['message'] ?? '').toString(),
        module: m['module'] as String?,
        metadata: m['metadata'] as Map<String, dynamic>?,
      );
    } catch (_) {
      return null;
    }
  }

  String? get fecha {
    final t = DateTime.tryParse(timestamp);
    if (t == null) return null;
    return DateFormat('dd/MM/yy HH:mm:ss').format(t.toLocal());
  }

  bool get esAuditoria => message.contains('AUDIT');

  String get descripcion {
    if (!esAuditoria) return message;
    final action = metadata?['action'] ?? '';
    final entity = metadata?['entity'] ?? '';
    final entityId = metadata?['entity_id'] ?? '';
    final detalle = <String>[
      if ((action ?? '').toString().isNotEmpty) 'Acción: $action',
      if ((entity ?? '').toString().isNotEmpty) 'Entidad: $entity',
      if ((entityId ?? '').toString().isNotEmpty) 'ID: $entityId',
    ].join('  •  ');
    return detalle.isEmpty ? message : detalle;
  }
}
