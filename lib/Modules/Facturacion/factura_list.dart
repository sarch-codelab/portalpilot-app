import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/Facturacion/factura_form.dart';
import 'package:portal_pilot_app/Modules/Facturacion/factura_detalle.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

class FacturaList extends StatefulWidget {
  const FacturaList({super.key});

  @override
  State<FacturaList> createState() => _FacturaListState();
}

class _FacturaListState extends State<FacturaList> {
  List<Map<String, dynamic>> _facturas = [];
  List<Map<String, dynamic>> _facturasFiltradas = [];
  String _filtroEstado = 'Todos';
  String _busqueda = '';
  String _ordenarPor = 'fecha_desc';

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    final locales = List<Map<String, dynamic>>.from(jsonDecode(facturasJson));

    for (final f in locales) {
      f.putIfAbsent('contingencia', () => false);
    }

    setState(() {
      _facturas = locales;
      _aplicarFiltros();
    });

    // Dispara la cola de sincronización offline (pendientes -> Supabase).
    try {
      await LocalDatabaseService.instance.forceSyncNow();
    } catch (_) {}

    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isEmpty) return;
      final remotas = await PortalPilotDB.getFacturas(empresa);
      if (remotas.isNotEmpty) {
        final sincronizadas = _fusionarFacturas(locales, remotas);
        await prefs.setString('facturas', jsonEncode(sincronizadas));
        if (mounted) {
          setState(() {
            _facturas = sincronizadas;
            _aplicarFiltros();
          });
        }
      }
    } catch (_) {}
  }

  /// Fusiona locales (fuente de verdad) con remotas de Supabase:
  /// las remotas reemplazan por correlativo y las locales no sincronizadas se conservan.
  List<Map<String, dynamic>> _fusionarFacturas(
    List<Map<String, dynamic>> locales,
    List<Map<String, dynamic>> remotas,
  ) {
    final mapa = <String, Map<String, dynamic>>{};
    for (final f in locales) {
      mapa[(f['correlativo'] ?? '').toString()] = Map.from(f);
    }
    for (final r in remotas) {
      final row = Map<String, dynamic>.from(r);
      row['fecha'] = row['created_at'] ?? row['fecha'];
      row['server_id'] = row['id'];
      final key = (row['correlativo'] ?? '').toString();
      if (key.isNotEmpty) mapa[key] = row;
    }
    return mapa.values.toList();
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_facturas);

    if (_filtroEstado != 'Todos') {
      resultado = resultado
          .where((f) => f['estado'] == _filtroEstado.toLowerCase())
          .toList();
    }

    if (_busqueda.isNotEmpty) {
      resultado = resultado.where((f) {
        final correlativo = (f['correlativo'] ?? '').toString().toLowerCase();
        final cliente = (f['cliente_nombre'] ?? '').toString().toLowerCase();
        final rtn = (f['cliente_rtn'] ?? '').toString().toLowerCase();
        return correlativo.contains(_busqueda.toLowerCase()) ||
            cliente.contains(_busqueda.toLowerCase()) ||
            rtn.contains(_busqueda.toLowerCase());
      }).toList();
    }

    resultado.sort((a, b) {
      switch (_ordenarPor) {
        case 'fecha_desc':
          return (b['fecha'] ?? '').compareTo(a['fecha'] ?? '');
        case 'fecha_asc':
          return (a['fecha'] ?? '').compareTo(b['fecha'] ?? '');
        case 'monto_desc':
          return ((b['total'] as num?) ?? 0).compareTo(
            (a['total'] as num?) ?? 0,
          );
        case 'monto_asc':
          return ((a['total'] as num?) ?? 0).compareTo(
            (b['total'] as num?) ?? 0,
          );
        default:
          return 0;
      }
    });

    setState(() => _facturasFiltradas = resultado);
  }

  Future<void> _anularFactura(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    final List<dynamic> facturas = jsonDecode(facturasJson);

    for (final f in facturas) {
      if (f['id'] == id) {
        f['estado'] = 'anulada';
        f['fecha_anulacion'] = DateTime.now().toIso8601String();
        break;
      }
    }

    await prefs.setString('facturas', jsonEncode(facturas));

    try {
      final prefsEmpresa = await SharedPreferences.getInstance();
      final empresa = prefsEmpresa.getString('company_code') ?? '';
      final serverId = facturas.firstWhere(
        (f) => f['id'] == id,
        orElse: () => {},
      )['server_id'];
      if (empresa.isNotEmpty && serverId != null) {
        await PortalPilotDB.anularFactura(
          id: serverId.toString(),
          empresaCodigo: empresa,
        );
      }
    } catch (_) {}

    _cargarFacturas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
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
          'FACTURAS',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.sort_rounded,
              color: Color(0xFF737373),
              size: 20,
            ),
            onSelected: (v) {
              setState(() => _ordenarPor = v);
              _aplicarFiltros();
            },
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'fecha_desc',
                child: Text(
                  'Más recientes',
                  style: GoogleFonts.dmSans(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'fecha_asc',
                child: Text(
                  'Más antiguas',
                  style: GoogleFonts.dmSans(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'monto_desc',
                child: Text(
                  'Mayor monto',
                  style: GoogleFonts.dmSans(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'monto_asc',
                child: Text(
                  'Menor monto',
                  style: GoogleFonts.dmSans(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                setState(() => _busqueda = v);
                _aplicarFiltros();
              },
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por correlativo, cliente o RTN...',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF404040),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          _buildFiltroChips(),
          const SizedBox(height: 8),
          Expanded(
            child: _facturasFiltradas.isEmpty
                ? _buildEmptyState()
                : _buildFacturasList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: ['Todos', 'Emitida', 'Pendiente', 'Anulada'].map((estado) {
          final selected = _filtroEstado == estado;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _filtroEstado = estado);
                _aplicarFiltros();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF262626),
                  ),
                ),
                child: Text(
                  estado,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF737373),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF10B981),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay facturas',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _busqueda.isNotEmpty || _filtroEstado != 'Todos'
                ? 'No se encontraron resultados para este filtro'
                : 'Creá tu primera factura desde el módulo de facturación',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF737373),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFacturasList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _facturasFiltradas.length,
      itemBuilder: (_, i) {
        final factura = _facturasFiltradas[i];
        final estado = factura['estado'] ?? 'emitida';
        final total = (factura['total'] as num?)?.toDouble() ?? 0.0;
        final fecha = factura['fecha'] ?? '';

        Color estadoColor;
        IconData estadoIcon;
        switch (estado) {
          case 'anulada':
            estadoColor = const Color(0xFFEF4444);
            estadoIcon = Icons.cancel_rounded;
            break;
          case 'pendiente':
            estadoColor = const Color(0xFFF59E0B);
            estadoIcon = Icons.schedule_rounded;
            break;
          default:
            estadoColor = const Color(0xFF10B981);
            estadoIcon = Icons.check_circle_rounded;
        }

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FacturaDetalle(factura: factura),
              ),
            );
            _cargarFacturas();
          },
          onLongPress: () {
            if (estado != 'anulada') {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1A1A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF404040),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        factura['correlativo'] ?? '',
                        style: GoogleFonts.dmMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                        title: Text(
                          'Editar',
                          style: GoogleFonts.dmSans(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FacturaForm(facturaExistente: factura),
                            ),
                          ).then((_) => _cargarFacturas());
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                        title: Text(
                          'Anular',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmarAnulacion(factura['id']);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: estado == 'anulada'
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : const Color(0xFF262626),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(estadoIcon, color: estadoColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              factura['correlativo'] ?? '',
                              style: GoogleFonts.dmMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: estadoColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (factura['contingencia'] == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'CONTINGENCIA',
                                style: GoogleFonts.dmSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF59E0B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        factura['cliente_nombre'] ?? 'Sin cliente',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFFA3A3A3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatearFecha(fecha),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF525252),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'L.${total.toStringAsFixed(2)}',
                  style: GoogleFonts.dmMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: estado == 'anulada'
                        ? const Color(0xFF737373)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmarAnulacion(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Anular factura?',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer. La factura quedará marcada como anulada.',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.dmSans(color: const Color(0xFF737373)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _anularFactura(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(
              'Anular',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String fecha) {
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return fecha;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
