// lib/Modules/Reportes/report_viewer.dart
// Visor universal de reportes de Portal Pilot.
//
// Refleja el diseño de reporte.html en Flutter nativo (sin webview):
// cabecera de la empresa, metadatos del reporte, KPIs, resumen, tabla con
// encabezado fijo y total, nota y acciones (guardar / abrir / compartir /
// imprimir). Si `noData` es true muestra el estado vacío y oculta la tabla.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';
import 'package:portal_pilot_app/Shared/services/report_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ReportViewer extends StatefulWidget {
  final ReportData data;
  final String? rutaPrevia;

  const ReportViewer({super.key, required this.data, this.rutaPrevia});

  @override
  State<ReportViewer> createState() => _ReportViewerState();
}

class _ReportViewerState extends State<ReportViewer> {
  String? _ruta;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _ruta = widget.rutaPrevia;
  }

  ReportData get data => widget.data;
  ReportMeta get meta => data.report;

  void _snack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto, style: GoogleFonts.dmSans(fontSize: 12.5)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 2200),
    ));
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    _snack('Preparando PDF...');
    try {
      final ruta = await ReportService.guardarLocal(data);
      if (!mounted) return;
      setState(() => _ruta = ruta);
      _snack('Reporte guardado correctamente.');
    } catch (e) {
      _snack('No se pudo guardar el reporte. Revisa la carpeta de documentos.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir() async {
    if (_ruta == null) {
      await _guardar();
    }
    final ruta = _ruta;
    if (ruta == null || !mounted) return;
    try {
      await ReportService.abrir(ruta);
    } catch (_) {
      _snack('No se pudo abrir el archivo.');
    }
  }

  Future<void> _compartir() async {
    setState(() => _ocupado = true);
    _snack('Preparando PDF...');
    try {
      await ReportService.compartir(data, path: _ruta);
    } catch (_) {
      _snack('No se pudo compartir el reporte.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _imprimir() async {
    setState(() => _ocupado = true);
    _snack('Preparando PDF...');
    try {
      await ReportService.imprimir(data);
    } catch (_) {
      _snack('No se pudo imprimir el reporte.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
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
        title: Text('Visor de reporte', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: p.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            icon: const Icon(Icons.save_rounded, size: 20),
            color: p.brandOnSurface,
            onPressed: _ocupado ? null : _guardar,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _cabecera(p),
              const SizedBox(height: 12),
              _metadatos(p),
              const SizedBox(height: 12),
              if (data.kpis.isNotEmpty) _kpis(p),
              if (data.kpiCaption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(data.kpiCaption, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
              ],
              if (data.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                _resumen(p),
              ],
              const SizedBox(height: 14),
              if (data.noData)
                _sinDatos(p)
              else
                _tabla(p),
              if (data.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                _nota(p),
              ],
            ]),
          ),
        ),
        _acciones(p),
      ]),
    );
  }

  Widget _cabecera(ThemePalette p) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.company.name.toUpperCase(), style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.w800, color: p.textPrimary)),
          const SizedBox(height: 2),
          Text(data.company.tagline, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
          const SizedBox(height: 8),
          Text(meta.title, style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
          if (meta.description.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta.description, style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted, height: 1.4))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: meta.number.startsWith('REP-') ? const Color(0xFF10B981) : const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text('REPORTE', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(meta.type.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 8.5, color: Colors.white)),
        ]),
      ),
    ]);
  }

  Widget _metadatos(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: appPalette.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
      child: LayoutBuilder(builder: (ctx, c) {
        final wid = c.maxWidth >= 480;
        final items = [
          _dato('No. REPORTE', meta.number),
          _dato('PERÍODO', meta.period.isEmpty ? '—' : meta.period),
          _dato('GENERADO', meta.generatedAt),
          _dato('MONEDA', meta.currency),
        ];
        if (wid) {
          return Row(children: [for (final it in items) Expanded(child: it)]);
        }
        return Wrap(spacing: 10, runSpacing: 8, children: [for (final it in items) SizedBox(width: c.maxWidth / 2 - 12, child: it)]);
      }),
    );
  }

  Widget _dato(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 9.5, color: appPalette.textMuted, letterSpacing: 0.4)),
      const SizedBox(height: 1),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: appPalette.textPrimary)),
    ]);
  }

  Widget _kpis(ThemePalette p) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth >= 720 ? 4 : (c.maxWidth >= 420 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.kpis.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 84,
        ),
        itemBuilder: (_, i) {
          final k = data.kpis[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: appPalette.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 9.5, color: p.textMuted, letterSpacing: 0.4)),
              const SizedBox(height: 3),
              Text(k.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
              if (k.detail.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(k.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted))),
            ]),
          );
        },
      );
    });
  }

  Widget _resumen(ThemePalette p) {
    return Wrap(spacing: 16, runSpacing: 6, children: [
      for (final s in data.summary)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${s.label}: ', style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)),
          Text(s.value, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.textPrimary)),
        ]),
    ]);
  }

  Widget _tabla(ThemePalette p) {
    final cols = data.table.columns;
    final rows = data.table.rows;
    if (cols.isEmpty) return _sinDatos(p);
    if (rows.isEmpty) return _sinDatos(p);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data.table.title.isNotEmpty)
        Text(data.table.title, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: p.textPrimary)),
      if (data.table.caption.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(data.table.caption, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
      ],
      const SizedBox(height: 8),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(const Color(0xFF2563EB)),
            dividerThickness: 0,
            horizontalMargin: 12,
            columnSpacing: 22,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 40,
            headingTextStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            dataTextStyle: GoogleFonts.dmSans(fontSize: 11.5, color: p.textPrimary),
            columns: [
              for (final c in cols)
                DataColumn(
                  label: Align(alignment: c.align == 'right' ? Alignment.centerRight : Alignment.centerLeft, child: Text(c.label)),
                ),
            ],
            rows: [
              for (final (i, fila) in rows.indexed)
                DataRow(
                  color: i.isEven ? WidgetStatePropertyAll(appPalette.bgSecondary) : null,
                  cells: [
                    for (final c in cols)
                      DataCell(Align(
                        alignment: c.align == 'right' ? Alignment.centerRight : Alignment.centerLeft,
                        child: Text(fila[c.key]?.toString() ?? '', textAlign: c.align == 'right' ? TextAlign.right : TextAlign.left),
                      )),
                  ],
                ),
            ],
          ),
        ),
      ),
      if (data.table.totalValue.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: appPalette.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(data.table.totalLabel, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: p.textPrimary)),
            Text(data.table.totalValue, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
          ]),
        ),
      ],
    ]);
  }

  Widget _nota(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF059669)),
        const SizedBox(width: 8),
        Expanded(child: Text(data.note, style: GoogleFonts.dmSans(fontSize: 11.5, color: const Color(0xFF065F46), height: 1.45))),
      ]),
    );
  }

  Widget _sinDatos(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(color: appPalette.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.borderLight)),
      child: Column(children: [
        Icon(Icons.inbox_rounded, size: 34, color: p.textMuted.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text('No hay registros para mostrar.', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: p.textPrimary)),
        const SizedBox(height: 3),
        Text('Registra movimientos en el módulo correspondiente y vuelve a intentarlo.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
      ]),
    );
  }

  Widget _acciones(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(color: appThemeNotifier.isDark ? appPalette.bgSecondary : appPalette.cardColor, border: Border(top: BorderSide(color: p.borderLight))),
      child: SafeArea(
        top: false,
        child: _ocupado
            ? const Center(child: Padding(padding: EdgeInsets.all(6), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))))
            : Wrap(spacing: 10, runSpacing: 8, children: [
                _boton(Icons.save_rounded, 'Guardar', _guardar, const Color(0xFF10B981)),
                _boton(Icons.folder_open_rounded, 'Abrir', _abrir, const Color(0xFF2563EB)),
                _boton(Icons.share_rounded, 'Compartir', _compartir, const Color(0xFF8B5CF6)),
                _boton(Icons.print_rounded, 'Imprimir', _imprimir, p.brandOnSurface),
              ]),
      ),
    );
  }

  Widget _boton(IconData icon, String label, VoidCallback onTap, Color color) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}