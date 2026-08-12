import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/CRM/clientes/cliente_form.dart';

class ClienteList extends StatefulWidget {
  const ClienteList({super.key});

  @override
  State<ClienteList> createState() => _ClienteListState();
}

class _ClienteListState extends State<ClienteList> {
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _filtrados = [];
  String _busqueda = '';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _clientes = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('clientes') ?? '[]'));
      _filtrados = List.from(_clientes);
    });
  }

  void _filtrar() {
    final q = _busqueda.toLowerCase();
    setState(() => _filtrados = _clientes.where((c) {
      final nombre = '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final empresa = (c['empresa'] ?? '').toString().toLowerCase();
      return nombre.contains(q) || email.contains(q) || empresa.contains(q);
    }).toList());
  }

  Future<void> _eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('clientes') ?? '[]'));
    list.removeWhere((c) => c['id'] == id);
    await prefs.setString('clientes', jsonEncode(list));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF06B6D4), size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('DIRECTORIO DE CLIENTES', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) { _busqueda = v; _filtrar(); },
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email o empresa...',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF404040), size: 20),
                filled: true, fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(child: Text(_busqueda.isNotEmpty ? 'Sin resultados' : 'No hay clientes', style: GoogleFonts.dmSans(color: const Color(0xFF525252))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final c = _filtrados[i];
                      final nombre = '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim();
                      return GestureDetector(
                        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ClienteForm(clienteExistente: c))); _cargar(); },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.business_rounded, color: Color(0xFF06B6D4), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(nombre.isNotEmpty ? nombre : 'Sin nombre', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if ((c['dni'] ?? '').toString().isNotEmpty) c['dni'],
                                    c['email'],
                                    c['empresa'],
                                  ].whereType<String>().where((x) => x.isNotEmpty).join('  •  '),
                                  style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ])),
                              IconButton(icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18), onPressed: () => _eliminar(c['id'])),
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
}
