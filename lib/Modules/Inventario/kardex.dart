import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _productos = [];
  String _filtroTipo = 'Todos';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (mounted) setState(() => _cargando = true);

    try {
      final api = ApiService.instance;

      final movResult = await api.get('/api/kardex', queryParams: {'limit': '200'});
      final prodResult = await api.get('/api/productos', queryParams: {'limit': '500'});

      if (movResult != null && api.isSuccess(movResult)) {
        final movs = movResult['movimientos'] ?? [];
        _movimientos = (movs is List) ? movs.map((m) => Map<String, dynamic>.from(m)).toList() : [];
      }

      if (prodResult != null && api.isSuccess(prodResult)) {
        final prods = prodResult['productos'] ?? [];
        _productos = (prods is List) ? prods.map((p) => Map<String, dynamic>.from(p)).toList() : [];
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando kardex: $e');
      // Fallback a SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _movimientos = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('kardex') ?? '[]'));
        _productos = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('productos') ?? '[]'));
      } catch (_) {}
    }

    if (mounted) setState(() => _cargando = false);
  }

  void _agregarMovimiento() {
    final cantidadController = TextEditingController(text: '1');
    final referenciaController = TextEditingController();
    String? productoId;
    String tipo = 'entrada';
    String motivo = 'Compra';

    final motivos = {
      'entrada': ['Compra', 'Devolución', 'Ajuste +', 'Producción', 'Otro'],
      'salida': ['Venta', 'Devolución cliente', 'Ajuste -', 'Merma', 'Otro'],
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF404040), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Text('Nuevo Movimiento', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { tipo = 'entrada'; motivo = motivos['entrada']!.first; }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tipo == 'entrada' ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: tipo == 'entrada' ? const Color(0xFF10B981) : const Color(0xFF262626)),
                              ),
                              child: Column(children: [
                                Icon(Icons.arrow_downward_rounded, color: tipo == 'entrada' ? const Color(0xFF10B981) : const Color(0xFF737373), size: 22),
                                const SizedBox(height: 4),
                                Text('Entrada', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: tipo == 'entrada' ? const Color(0xFF10B981) : const Color(0xFF737373))),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { tipo = 'salida'; motivo = motivos['salida']!.first; }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tipo == 'salida' ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: tipo == 'salida' ? const Color(0xFFEF4444) : const Color(0xFF262626)),
                              ),
                              child: Column(children: [
                                Icon(Icons.arrow_upward_rounded, color: tipo == 'salida' ? const Color(0xFFEF4444) : const Color(0xFF737373), size: 22),
                                const SizedBox(height: 4),
                                Text('Salida', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: tipo == 'salida' ? const Color(0xFFEF4444) : const Color(0xFF737373))),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Producto', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF262626))),
                      child: DropdownButton<String>(
                        value: productoId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1A),
                        underline: const SizedBox(),
                        hint: Text('Seleccionar producto', style: GoogleFonts.dmSans(color: const Color(0xFF404040))),
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                        items: _productos.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text('${p['codigo'] ?? ''} - ${p['nombre'] ?? ''}'))).toList(),
                        onChanged: (v) => setModalState(() => productoId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Cantidad', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: cantidadController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                filled: true, fillColor: const Color(0xFF0F0F0F),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Motivo', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF262626))),
                              child: DropdownButton<String>(
                                value: motivo,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1A1A1A),
                                underline: const SizedBox(),
                                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                                items: (motivos[tipo] ?? []).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (v) => setModalState(() => motivo = v ?? motivo),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildModalField('Referencia (opcional)', referenciaController),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (productoId == null || cantidadController.text.isEmpty) return;
                          final cant = int.tryParse(cantidadController.text) ?? 0;
                          if (cant <= 0) return;

                          // Registrar en backend
                          try {
                            final api = ApiService.instance;
                            await api.post('/api/kardex', body: {
                              'producto_id': productoId,
                              'tipo_movimiento': tipo,
                              'cantidad': cant,
                              'referencia': motivo,
                              'notas': referenciaController.text,
                            });
                          } catch (e) {
                            debugPrint('⚠️ Error guardando kardex en backend: $e');
                            // Fallback a SharedPreferences
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final kardex = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('kardex') ?? '[]'));
                              kardex.add({
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'producto_id': productoId,
                                'tipo_movimiento': tipo,
                                'cantidad': cant,
                                'referencia': motivo,
                                'notas': referenciaController.text,
                                'created_at': DateTime.now().toIso8601String(),
                              });
                              await prefs.setString('kardex', jsonEncode(kardex));
                            } catch (_) {}
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _cargarDatos();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text('Registrar Movimiento', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtroTipo == 'Todos'
        ? _movimientos
        : _movimientos.where((m) => (m['tipo_movimiento'] ?? m['tipo'] ?? '') == _filtroTipo.toLowerCase()).toList();
    filtrados.sort((a, b) => (b['created_at'] ?? b['fecha'] ?? '').compareTo(a['created_at'] ?? a['fecha'] ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('KARDEX', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarMovimiento,
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text('Movimiento', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['Todos', 'Entrada', 'Salida'].map((t) {
                final sel = _filtroTipo == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filtroTipo = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? const Color(0xFFF59E0B) : const Color(0xFF262626)),
                      ),
                      child: Text(t, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? const Color(0xFFF59E0B) : const Color(0xFF737373))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : filtrados.isEmpty
                    ? Center(child: Text('No hay movimientos registrados', style: GoogleFonts.dmSans(color: const Color(0xFF525252))))
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) {
                            final m = filtrados[i];
                            final tipoMov = m['tipo_movimiento'] ?? m['tipo'] ?? '';
                            final esEntrada = tipoMov == 'entrada';
                            final color = esEntrada ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                            final fecha = DateTime.tryParse(m['created_at'] ?? m['fecha'] ?? '');
                            final producto = m['productos'];
                            final nombre = producto != null ? producto['nombre'] : (m['producto_nombre'] ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF262626))),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${m['referencia'] ?? m['notas'] ?? ''}',
                                          style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (fecha != null)
                                          Text(
                                            '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                                            style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF525252)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${esEntrada ? '+' : '-'}${m['cantidad']} uds',
                                    style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildModalField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true, fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
