import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

typedef PPDataCell = Widget Function(Map<String, dynamic> row);
typedef PPDataRowTap = void Function(Map<String, dynamic> row);

/// Grid de datos responsivo de Portal Pilot.
///
/// - **Desktop/Tablet**: `DataTable` con columnas ordenables y selección.
/// - **Móvil**: Lista de tarjetas (el código de listas existente se mantiene).
///
/// Permite reutilizar la misma fuente de datos en ambos dispositivos.
class PPDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final List<PPDataColumn> columns;
  final PPDataRowTap? onRowTap;
  final PPDataRowTap? onRowLongPress;
  final bool sortable;
  final EdgeInsets padding;
  final double minRowHeight;

  const PPDataGrid({
    super.key,
    required this.rows,
    required this.columns,
    this.onRowTap,
    this.onRowLongPress,
    this.sortable = true,
    this.padding = const EdgeInsets.all(4),
    this.minRowHeight = 48,
  });

  @override
  State<PPDataGrid> createState() => _PPDataGridState();
}

class _PPDataGridState extends State<PPDataGrid> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  Set<int> _selectedRows = {};

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    if (MobileUtils.isDesktop(context)) {
      return _buildTable(palette);
    }
    return _buildCards(palette);
  }

  List<Map<String, dynamic>> get _sortedRows {
    final col = widget.columns;
    if (_sortColumnIndex == null || !widget.sortable) return widget.rows;
    final column = col[_sortColumnIndex!];
    final rows = List<Map<String, dynamic>>.from(widget.rows);
    rows.sort((a, b) {
      final cmp = _compareValues(column.value(a), column.value(b));
      return _sortAscending ? cmp : -cmp;
    });
    return rows;
  }

  int _compareValues(dynamic av, dynamic bv) {
    final an = _asNum(av);
    final bn = _asNum(bv);
    if (an != null && bn != null) return an.compareTo(bn);
    final as = av?.toString() ?? '';
    final bs = bv?.toString() ?? '';
    return as.toLowerCase().compareTo(bs.toLowerCase());
  }

  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v == null) return null;
    return num.tryParse(v.toString());
  }

  Widget _buildTable(ThemePalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        headingRowColor: WidgetStatePropertyAll(
          palette.bgSecondary.withValues(alpha: 0.4),
        ),
        headingTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.textMuted,
          letterSpacing: 0.6,
        ),
        dataTextStyle: GoogleFonts.dmSans(fontSize: 13, color: palette.textPrimary),
        dataRowMinHeight: widget.minRowHeight,
        dataRowMaxHeight: widget.minRowHeight + 12,
        horizontalMargin: 16,
        columnSpacing: 28,
        showCheckboxColumn: widget.onRowLongPress != null,
        columns: [
          if (widget.onRowLongPress != null)
            DataColumn(label: const SizedBox()),
          ...widget.columns.map((c) => DataColumn(
                label: Row(
                  children: [
                    if (c.icon != null) ...[
                      Icon(c.icon, size: 14, color: c.color ?? palette.textDim),
                      const SizedBox(width: 6),
                    ],
                    Text(c.label),
                  ],
                ),
                numeric: c.numeric,
                onSort: widget.sortable
                    ? (i, asc) => setState(() {
                          _sortColumnIndex = i + (widget.onRowLongPress != null ? 1 : 0);
                          _sortAscending = asc;
                        })
                    : null,
              )),
        ],
        rows: _sortedRows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          final selected = _selectedRows.contains(idx);
          return DataRow(
            color: WidgetStatePropertyAll(
              selected ? palette.brand.withValues(alpha: 0.08) : Colors.transparent,
            ),
            onSelectChanged: widget.onRowLongPress != null
                ? (sel) => setState(() {
                      if (sel == true) {
                        _selectedRows.add(idx);
                      } else {
                        _selectedRows.remove(idx);
                      }
                    })
                : null,
            onLongPress: widget.onRowLongPress != null ? () => widget.onRowLongPress!(row) : null,
            cells: [
              ...widget.columns.map((c) => DataCell(
                    c.cellBuilder(row),
                    onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
                  )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCards(ThemePalette palette) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _sortedRows.length,
      itemBuilder: (context, i) {
        final row = _sortedRows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: palette.cardColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => widget.onRowTap?.call(row),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _firstText(widget.columns.first, row),
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (widget.columns.length > 1)
                            Text(
                              _firstText(widget.columns[1], row),
                              style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF5D5672)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _firstText(PPDataColumn col, Map<String, dynamic> row) {
    final v = col.value(row);
    return v?.toString() ?? '';
  }
}

class PPDataColumn {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool numeric;
  final Object? Function(Map<String, dynamic>) value;
  final PPDataCell cellBuilder;

  PPDataColumn({
    required this.label,
    required this.value,
    required this.cellBuilder,
    this.icon,
    this.color,
    this.numeric = false,
  });
}

/// Chips / badges para celdas de la tabla (estados, categorías).
class PPBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool outline;

  const PPBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: outline ? 0.45 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}