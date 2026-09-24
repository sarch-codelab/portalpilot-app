// lib/Modules/Reportes/historial_reportes_screen.dart
// Historial local de reportes generados (solo meta-datos en SharedPreferences;
// los PDF/HTML viven en Documentos/PortalPilot/Reportes).
// Cada item permite abrir el archivo, compartirlo o borrarlo.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';
import 'package:portal_pilot_app/Shared/services/report_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class HistorialReportesScreen extends StatefulWidget {
  const HistorialReportesScreen({super.key});

  @override
  State<HistorialReportesScreen> createState() => _HistorialReportesScreenState();
}

class _HistorialReportesScreenState extends State<HistorialReportesScreen> {
  List<ReportHistorialItem> _items = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await ReportService.obtenerHistorial();
    if (!mounted) return;
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  void _snack(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto, style: GoogleFonts.dmSans(fontSize: 12.5)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 1800),
    ));
  }

  Future<void> _abrir(ReportHistorialItem it) async {
    if (it.rutaLocal.isEmpty) {
      _snack('El archivo guardado no se encontró.');
      return;
    }
    try {
      await ReportService.abrir(it.rutaLocal);
    } catch (_) {
      _snack('No se pudo abrir el archivo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.isDark;
    final p = ThemePalette(isDark: isDark);
    return Scaffold(
      backgroundColor: appPalette.bgSecondary,
      appBar: AppBar(
        backgroundColor: isDark ? appPalette.bgSecondary : appPalette.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: p.brandOnSurface),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Historial de reportes', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: p.textPrimary)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _items.isEmpty
              ? _vacio(p)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      return _item(it, p);
                    },
                  ),
                ),
    );
  }

  Widget _item(ReportHistorialItem it, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderLight),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.description_rounded, size: 20, color: Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 2),
            Text('${it.tipo} • ${it.fecha}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
            Text(it.rutaLocal, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 9.5, color: p.textMuted.withValues(alpha: 0.7))),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Abrir',
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          color: p.brandOnSurface,
          onPressed: () => _abrir(it),
        ),
        IconButton(
          tooltip: 'Compartir',
          icon: const Icon(Icons.share_rounded, size: 17),
          color: p.textMuted,
          onPressed: () async {
            try {
              final ruta = it.rutaLocal.isEmpty ? null : it.rutaLocal;
              await ReportService.compartir(
                ReportData(
                  report: ReportMeta(
                    number: it.id.isEmpty ? 'REP-000001' : it.id,
                    type: it.tipo,
                    title: it.titulo,
                  ),
                ),
                path: ruta,
              );
            } catch (_) {
              _snack('No se pudo compartir el reporte.');
            }
          },
        ),
        IconButton(
          tooltip: 'Eliminar del historial',
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: p.textMuted,
          onPressed: () async {
            setState(() {
              _items = _items.where((e) => e.id != it.id).toList();
            });
            await ReportService.guardarHistorial(_items);
            _snack('Reporte eliminado del historial.');
          },
        ),
      ]),
    );
  }

  Widget _vacio(ThemePalette p) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, size: 44, color: p.textMuted.withValues(alpha: 0.35)),
        const SizedBox(height: 10),
        Text('Aún no hay reportes guardados', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
        const SizedBox(height: 4),
        Text('Pide un reporte en el Chat IA y guárdalo para verlo aquí.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)),
      ]),
    );
  }
}