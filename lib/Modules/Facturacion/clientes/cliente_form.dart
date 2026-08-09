import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Shared/services/db_service.dart';

class ClienteForm extends StatefulWidget {
  const ClienteForm({super.key});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _nombreController = TextEditingController();
  final _rtnController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  List<Map<String, dynamic>> _clientes = [];
  Map<String, dynamic>? _editando;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('clientes_facturacion') ?? '[]';
    final locales = List<Map<String, dynamic>>.from(jsonDecode(json));
    setState(() => _clientes = locales);

    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isEmpty) return;
      final remotas = await PortalPilotDB.getClientes(empresa);
      if (remotas.isNotEmpty) {
        final mapa = <String, Map<String, dynamic>>{};
        for (final c in locales) {
          mapa[(c['nombre'] ?? '').toString()] = Map.from(c);
        }
        for (final r in remotas) {
          final row = Map<String, dynamic>.from(r);
          final key = (row['nombre'] ?? '').toString();
          if (key.isNotEmpty) mapa[key] = row;
        }
        final fusion = mapa.values.toList();
        await prefs.setString('clientes_facturacion', jsonEncode(fusion));
        if (mounted) setState(() => _clientes = fusion);
      }
    } catch (_) {}
  }

  Future<void> _guardarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clientes_facturacion', jsonEncode(_clientes));
    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isNotEmpty) {
        for (final c in _clientes) {
          if (c['server_id'] == null) {
            await PortalPilotDB.insertCliente(cliente: c, empresaCodigo: empresa);
          }
        }
      }
    } catch (_) {}
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _rtnController.clear();
    _direccionController.clear();
    _telefonoController.clear();
    _emailController.clear();
    setState(() => _editando = null);
  }

  void _guardarCliente() {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El nombre es obligatorio', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final cliente = {
      'id': _editando != null ? _editando!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': _nombreController.text,
      'rtn': _rtnController.text,
      'direccion': _direccionController.text,
      'telefono': _telefonoController.text,
      'email': _emailController.text,
      'fecha_registro': _editando != null ? _editando!['fecha_registro'] : DateTime.now().toIso8601String(),
    };

    setState(() {
      if (_editando != null) {
        final idx = _clientes.indexWhere((c) => c['id'] == _editando!['id']);
        if (idx >= 0) _clientes[idx] = cliente;
      } else {
        _clientes.add(cliente);
      }
    });

    _guardarClientes();
    _limpiarFormulario();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editando != null ? 'Cliente actualizado' : 'Cliente guardado',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _editarCliente(Map<String, dynamic> cliente) {
    setState(() {
      _editando = cliente;
      _nombreController.text = cliente['nombre'] ?? '';
      _rtnController.text = cliente['rtn'] ?? '';
      _direccionController.text = cliente['direccion'] ?? '';
      _telefonoController.text = cliente['telefono'] ?? '';
      _emailController.text = cliente['email'] ?? '';
    });
  }

  void _eliminarCliente(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar cliente?', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text('Esta acción no se puede deshacer.', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _clientes.removeWhere((c) => c['id'] == id));
              _guardarClientes();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CLIENTES',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editando != null ? 'EDITAR CLIENTE' : 'NUEVO CLIENTE',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                _buildTextField('Nombre / Razón Social *', _nombreController),
                const SizedBox(height: 10),
                _buildTextField('RTN', _rtnController, hint: '0801-1999-12345'),
                const SizedBox(height: 10),
                _buildTextField('Dirección', _direccionController),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Teléfono', _telefonoController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('Email', _emailController)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardarCliente,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _editando != null ? 'Actualizar' : 'Guardar',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                    if (_editando != null) ...[
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _limpiarFormulario,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF262626),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CLIENTES REGISTRADOS (${_clientes.length})',
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF737373),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (_clientes.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Center(
                child: Text(
                  'No hay clientes registrados',
                  style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
                ),
              ),
            )
          else
            ..._clientes.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    child: Text(
                      (c['nombre'] ?? '?')[0].toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['nombre'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'RTN: ${c['rtn'] ?? 'N/A'}',
                          style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                        ),
                        if ((c['direccion'] ?? '').isNotEmpty)
                          Text(
                            c['direccion']!,
                            style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF525252)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 18),
                        onPressed: () => _editarCliente(c),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(height: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18),
                        onPressed: () => _eliminarCliente(c['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF262626)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF262626)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
