import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/RRHH/empleados/empleado_form.dart';

class EmpleadoList extends StatefulWidget {
  const EmpleadoList({super.key});

  @override
  State<EmpleadoList> createState() => _EmpleadoListState();
}

class _EmpleadoListState extends State<EmpleadoList> {
  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> _filtrados = [];
  String _busqueda = '';
  String _filtroEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('empleados') ?? '[]';
    setState(() {
      _empleados = List<Map<String, dynamic>>.from(jsonDecode(json));
      _aplicarFiltros();
    });
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> r = List.from(_empleados);

    if (_busqueda.isNotEmpty) {
      r = r.where((e) {
        final nombre = '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.toLowerCase();
        final email = (e['email'] ?? '').toString().toLowerCase();
        final cargo = (e['cargo'] ?? '').toString().toLowerCase();
        return nombre.contains(_busqueda.toLowerCase()) ||
            email.contains(_busqueda.toLowerCase()) ||
            cargo.contains(_busqueda.toLowerCase());
      }).toList();
    }

    if (_filtroEstado == 'Activos') {
      r = r.where((e) => e['activo'] == true).toList();
    } else if (_filtroEstado == 'Inactivos') {
      r = r.where((e) => e['activo'] != true).toList();
    }

    setState(() => _filtrados = r);
  }

  Future<void> _eliminarEmpleado(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('empleados') ?? '[]';
    final List<dynamic> empleados = jsonDecode(json);
    empleados.removeWhere((e) => e['id'] == id);
    await prefs.setString('empleados', jsonEncode(empleados));
    _cargarEmpleados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFEC4899), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CATÁLOGO DE EMPLEADOS',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) { setState(() => _busqueda = v); _aplicarFiltros(); },
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email o cargo...',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF404040), size: 20),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEC4899))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', _filtroEstado == 'Todos', () { setState(() => _filtroEstado = 'Todos'); _aplicarFiltros(); }),
                const SizedBox(width: 8),
                _buildFilterChip('Activos', _filtroEstado == 'Activos', () { setState(() => _filtroEstado = 'Activos'); _aplicarFiltros(); }),
                const SizedBox(width: 8),
                _buildFilterChip('Inactivos', _filtroEstado == 'Inactivos', () { setState(() => _filtroEstado = 'Inactivos'); _aplicarFiltros(); }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(
                    child: Text(
                      _busqueda.isNotEmpty ? 'Sin resultados' : 'No hay empleados',
                      style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final e = _filtrados[i];
                      final activo = e['activo'] ?? true;
                      final nombre = '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.trim();
                      final cargo = e['cargo'] ?? 'Sin cargo';
                      final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
                      final email = e['email'] ?? '';

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => EmpleadoForm(empleadoExistente: e)));
                          _cargarEmpleados();
                        },
                        onLongPress: () => _showOptions(e),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: activo ? const Color(0xFF262626) : const Color(0xFFEF4444).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (activo ? const Color(0xFFEC4899) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: activo ? const Color(0xFFEC4899) : const Color(0xFFEF4444),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          nombre.isNotEmpty ? nombre : 'Sin nombre',
                                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                        if (!activo) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                            child: Text('INACTIVO', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$cargo  •  $email',
                                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'L.${salario.toStringAsFixed(0)}',
                                style: GoogleFonts.dmMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEC4899).withValues(alpha: 0.15) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFEC4899) : const Color(0xFF262626)),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFFEC4899) : const Color(0xFF737373),
          ),
        ),
      ),
    );
  }

  void _showOptions(Map<String, dynamic> empleado) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF404040), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('${empleado['nombre'] ?? ''} ${empleado['apellido'] ?? ''}', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 22),
              title: Text('Editar', style: GoogleFonts.dmSans(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => EmpleadoForm(empleadoExistente: empleado)));
                _cargarEmpleados();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 22),
              title: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(ctx);
                _eliminarEmpleado(empleado['id']);
              },
            ),
          ],
        ),
      ),
    );
  }
}
