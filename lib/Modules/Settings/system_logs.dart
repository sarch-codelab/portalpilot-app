import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class SystemLogs extends StatefulWidget {
  const SystemLogs({super.key});

  @override
  State<SystemLogs> createState() => _SystemLogsState();
}

class _LogEntry {
  final DateTime? timestamp;
  final String level;
  final String module;
  final String message;
  final Map<String, dynamic>? metadata;

  const _LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.metadata,
  });
}

class _SystemLogsState extends State<SystemLogs> {
  List<_LogEntry> _logs = [];
  bool _isLoading = true;

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
    if (mounted) setState(() => _isLoading = true);
    final entries = <_LogEntry>[];

    // 1) Logs locales (archivo del dispositivo).
    final rawLines = await Logger().getRecentLogs(lines: 100);
    for (final line in rawLines) {
      final e = _parseLogLine(line);
      if (e != null) entries.add(e);
    }

    // 2) Logs remotos (tabla de auditoría en la BD).
    try {
      final remote =
          await ApiService.instance.get('/api/audit', queryParams: {'limit': '100'});
      final remoteRows = remote['logs'];
      if (ApiService.instance.isSuccess(remote) && remoteRows is List) {
        for (final row in remoteRows) {
          if (row is Map) {
            final nivel = (row['nivel'] ?? 'INFO').toString().toUpperCase();
            final mensaje = (row['mensaje'] ?? '').toString();
            final modulo = (row['modulo'] ?? 'sistema').toString();
            final meta = row['metadata'];
            DateTime? ts = DateTime.tryParse((row['created_at'] ?? '').toString());
            entries.add(_LogEntry(
              timestamp: ts?.toLocal(),
              level: nivel,
              module: modulo,
              message: mensaje,
              metadata: meta is Map ? Map<String, dynamic>.from(meta) : null,
            ));
          }
        }
      }
    } catch (_) {
      // Sin conexión: los locales bastan.
    }

    // Locales primero (más recientes arriba), remotos después, sin duplicados.
    final seen = <String>{};
    final unicos = <_LogEntry>[];
    for (final e in entries) {
      final firma =
          '${e.timestamp?.toIso8601String() ?? ''}|${e.module}|${e.message}';
      if (seen.add(firma)) unicos.add(e);
    }

    if (!mounted) return;
    setState(() {
      _logs = unicos;
      _isLoading = false;
    });
  }

  /// Parsea una línea de log tolerando JSON malformado o incompleto (escrituras
  /// concurrentes). Nunca lanza: si no hay nada útil devuelve null.
  _LogEntry? _parseLogLine(String line) {
    final raw = line.trim();
    if (raw.isEmpty) return null;
    Map<String, dynamic>? map;
    try {
      final ini = raw.indexOf('{');
      final fin = raw.lastIndexOf('}');
      if (ini >= 0 && fin > ini) {
        final decoded = jsonDecode(raw.substring(ini, fin + 1));
        if (decoded is Map<String, dynamic>) map = decoded;
      }
    } catch (_) {
      map = null;
    }

    String level = 'INFO';
    String message = raw;
    String module = 'sistema';
    Map<String, dynamic>? metadata;
    DateTime? timestamp;

    if (map != null) {
      level = (map['level'] ?? 'INFO').toString().toUpperCase();
      message = (map['message'] ?? '').toString();
      module = (map['module'] ?? 'sistema').toString();
      final m = map['metadata'];
      metadata = m is Map ? Map<String, dynamic>.from(m) : null;
      timestamp = DateTime.tryParse((map['timestamp'] ?? '').toString());
    } else {
      // Recuperación por regex para líneas rotas.
      final nivelMatch = RegExp(r'"level"\s*:\s*"([A-Z]+)"').firstMatch(raw);
      if (nivelMatch != null) level = nivelMatch.group(1)!;
      final msgMatch = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(raw);
      if (msgMatch != null) message = msgMatch.group(1)!;
      final modMatch = RegExp(r'"module"\s*:\s*"([^"]*)"').firstMatch(raw);
      if (modMatch != null) module = modMatch.group(1)!;
      final tsMatch = RegExp(r'"timestamp"\s*:\s*"([^"]*)"').firstMatch(raw);
      if (tsMatch != null) timestamp = DateTime.tryParse(tsMatch.group(1)!);
      if (message == raw) return null; // nada rescatable
    }
    return _LogEntry(
      timestamp: timestamp?.toLocal(),
      level: level,
      module: module,
      message: message,
      metadata: metadata,
    );
  }

  // ── Humanización de mensajes de auditoría ──

  static const _accionEspanol = {
    'login': 'Inició sesión',
    'logout': 'Cerró sesión',
    'crear': 'Creó',
    'editar': 'Editó',
    'eliminar': 'Eliminó',
    'venta': 'Registró venta',
    'compra': 'Registró compra',
    'anular': 'Anuló',
    'pagar': 'Pagó',
    'enviar': 'Envió',
    'aceptar': 'Aceptó',
    'rechazar': 'Rechazó',
    'cancelar': 'Canceló',
    'sincronizar': 'Sincronizó',
    'exportar': 'Exportó',
    'respaldar': 'Respaldó',
    'restaurar': 'Restauró',
  };

  static const _entidadEspanol = {
    'producto': 'producto',
    'venta': 'venta',
    'compra': 'compra',
    'cliente': 'cliente',
    'proveedor': 'proveedor',
    'factura': 'factura',
    'cotizacion': 'cotización',
    'orden_compra': 'orden de compra',
    'usuario': 'usuario',
    'empresa': 'empresa',
    'bodega': 'bodega',
    'arqueo': 'arqueo de caja',
    'transaccion': 'transacción',
    'sesion': 'sesión',
    'config': 'configuración',
  };

  /// "AUDIT: crear on producto:P123" → "Creó producto · P123".
  String _humanizarMensaje(String message, String module) {
    var msg = message.trim();
    if (!msg.startsWith('AUDIT:')) {
      // Mensajes no-audit: traducciones puntuales.
      final mapa = {
        'Sesión iniciada': 'Sesión iniciada',
        'Sesión cerrada': 'Sesión cerrada',
        'Respaldado completado': 'Respaldo completado',
        'Error de sincronización': 'Error de sincronización',
      };
      return mapa[msg] ?? msg;
    }
    final cuerpo = msg.substring(6).trim(); // quita "AUDIT:"
    final m = RegExp(r'^(.+?)\s+on\s+(.+?)(?::(.+))?$').firstMatch(cuerpo);
    if (m == null) return cuerpo;
    final accion = (m.group(1) ?? '').trim();
    final entidad = (m.group(2) ?? '').trim();
    final idEntidad = (m.group(3) ?? '').trim();
    final accionTxt = _accionEspanol[accion] ?? accion;
    final entidadTxt = _entidadEspanol[entidad] ?? entidad;
    final buffer = StringBuffer(accionTxt);
    if (!accionTxt.toLowerCase().contains(entidadTxt.toLowerCase())) {
      buffer.write(' ');
      buffer.write(entidadTxt);
    }
    if (idEntidad.isNotEmpty) buffer.write(' · $idEntidad');
    if (module.isNotEmpty && module != 'sistema') buffer.write('  ($module)');
    return buffer.toString();
  }

  String _detalles(_LogEntry e) {
    final meta = e.metadata;
    if (meta == null || meta.isEmpty) return '';
    final cambios = meta['changes'];
    if (cambios is Map && cambios.isNotEmpty) {
      return cambios.entries.map((x) => '${x.key}: ${x.value}').join('  ·  ');
    }
    final otros = Map<String, dynamic>.from(meta)
      ..remove('action')
      ..remove('entity')
      ..remove('entity_id')
      ..remove('changes');
    return otros.entries.map((x) => '${x.key}: ${x.value}').join('  ·  ');
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
          'Logs del Sistema',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
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
                        color: appPalette.borderLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay logs disponibles',
                        style: GoogleFonts.dmSans(color: appPalette.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return _buildLogCard(_logs[index], palette);
                  },
                ),
    );
  }

  Widget _buildLogCard(_LogEntry entry, ThemePalette palette) {
    final nivel = entry.level;
    final levelColor = nivel == 'ERROR' || nivel == 'CRITICAL'
        ? const Color(0xFFEF4444)
        : nivel == 'WARNING'
            ? const Color(0xFFF59E0B)
            : nivel == 'DEBUG'
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF10B981);

    final fecha = entry.timestamp != null
        ? DateFormat('dd/MM/yyyy  HH:mm:ss').format(entry.timestamp!)
        : '—';
    final titulo = _humanizarMensaje(entry.message, entry.module);
    final detalles = _detalles(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
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
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  nivel,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: levelColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: appPalette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF737373)),
              const SizedBox(width: 4),
              Text(
                fecha,
                style: GoogleFonts.dmMono(fontSize: 10.5, color: const Color(0xFF737373)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  detalles.isEmpty ? '' : detalles,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: const Color(0xFF8A8A8E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
