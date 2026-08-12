import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

class ClienteForm extends StatefulWidget {
  final Map<String, dynamic>? clienteExistente;
  const ClienteForm({super.key, this.clienteExistente});

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _fuente = 'Directo';

  @override
  void initState() {
    super.initState();
    if (widget.clienteExistente != null) {
      final c = widget.clienteExistente!;
      _nombreCtrl.text = c['nombre'] ?? '';
      _apellidoCtrl.text = c['apellido'] ?? '';
      _dniCtrl.text = c['dni'] ?? '';
      _emailCtrl.text = c['email'] ?? '';
      _telefonoCtrl.text = c['telefono'] ?? '';
      _empresaCtrl.text = c['empresa'] ?? '';
      _cargoCtrl.text = c['cargo'] ?? '';
      _direccionCtrl.text = c['direccion'] ?? '';
      _notasCtrl.text = c['notas'] ?? '';
      _fuente = c['fuente'] ?? 'Directo';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _apellidoCtrl.dispose(); _dniCtrl.dispose(); _emailCtrl.dispose();
    _telefonoCtrl.dispose(); _empresaCtrl.dispose(); _cargoCtrl.dispose();
    _direccionCtrl.dispose(); _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('clientes') ?? '[]'));
    final id = widget.clienteExistente?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final dni = _dniCtrl.text.trim();
    final cliente = {
      'id': id,
      'nombre': _nombreCtrl.text.trim(), 'apellido': _apellidoCtrl.text.trim(),
      'dni': dni,
      'email': _emailCtrl.text.trim(), 'telefono': _telefonoCtrl.text.trim(),
      'empresa': _empresaCtrl.text.trim(), 'cargo': _cargoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(), 'notas': _notasCtrl.text.trim(),
      'fuente': _fuente, 'activo': true,
      'created_at': widget.clienteExistente?['created_at'] ?? DateTime.now().toIso8601String(),
    };
    if (widget.clienteExistente != null) {
      final idx = list.indexWhere((c) => c['id'] == cliente['id']);
      if (idx != -1) list[idx] = cliente;
    } else {
      list.add(cliente);
    }
    await prefs.setString('clientes', jsonEncode(list));

    // Encolar sincronización con el backend (nuevo cliente)
    if (widget.clienteExistente == null) {
      final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
      await SyncService.instance.enqueueSync(
        tabla: 'clientes',
        operacion: SyncOperation.insert,
        datos: {
          'empresa_codigo': empresaCodigo,
          'cliente': {
            'id': id,
            'nombre': '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}'.trim(),
            'dni': dni.isEmpty ? null : dni,
            'direccion': _direccionCtrl.text.trim(),
            'telefono': _telefonoCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'notas': _notasCtrl.text.trim(),
          },
        },
        empresaId: empresaCodigo,
      );
      Logger().audit(
        'crear',
        'cliente',
        id,
        userId: AuthController.instance.email,
        module: 'crm',
        changes: {'nombre': cliente['nombre'], 'dni': dni},
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.clienteExistente != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF06B6D4), size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(esEdicion ? 'EDITAR CLIENTE' : 'NUEVO CLIENTE', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Datos Personales'),
            const SizedBox(height: 12),
            _buildField(_nombreCtrl, 'Nombre *', Icons.person_rounded),
            const SizedBox(height: 10),
            _buildField(_apellidoCtrl, 'Apellido', Icons.person_rounded),
            const SizedBox(height: 10),
            _buildField(_dniCtrl, 'DNI / Identidad', Icons.badge_rounded,
                type: TextInputType.number, digitsOnly: true),
            const SizedBox(height: 10),
            _buildField(_emailCtrl, 'Email *', Icons.email_rounded, type: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildField(_telefonoCtrl, 'Teléfono', Icons.phone_rounded, type: TextInputType.phone),
            const SizedBox(height: 20),
            _buildSection('Información Comercial'),
            const SizedBox(height: 12),
            _buildField(_empresaCtrl, 'Empresa', Icons.business_rounded),
            const SizedBox(height: 10),
            _buildField(_cargoCtrl, 'Cargo', Icons.work_rounded),
            const SizedBox(height: 10),
            _buildField(_direccionCtrl, 'Dirección', Icons.location_on_rounded),
            const SizedBox(height: 10),
            _buildFuenteSelector(),
            const SizedBox(height: 10),
            _buildField(_notasCtrl, 'Notas', Icons.notes_rounded, maxLines: 3),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardar,
                icon: Icon(esEdicion ? Icons.save_rounded : Icons.person_add_rounded, color: Colors.white, size: 20),
                label: Text(esEdicion ? 'Guardar Cambios' : 'Registrar Cliente', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String t) => Text(t, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF06B6D4), letterSpacing: 0.8));

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1, bool digitsOnly = false}) {
    return TextFormField(
      controller: ctrl, keyboardType: type, maxLines: maxLines,
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      validator: label.contains('*')
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : label.startsWith('DNI')
              ? (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return RegExp(r'^\d{6,20}$').hasMatch(v.trim())
                      ? null
                      : 'Ingresa un DNI válido';
                }
              : null,
      decoration: InputDecoration(
        labelText: label.replaceAll(' *', ''), labelStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
        prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 18),
        filled: true, fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
      ),
    );
  }

  Widget _buildFuenteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFF737373), size: 18),
          const SizedBox(width: 12),
          Text('Fuente', style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 14)),
          const Spacer(),
          DropdownButton<String>(
            value: _fuente, dropdownColor: const Color(0xFF1A1A1A), underline: const SizedBox(),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
            items: ['Directo', 'Referido', 'Web', 'Redes Sociales', 'Otro'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _fuente = v!),
          ),
        ],
      ),
    );
  }
}
