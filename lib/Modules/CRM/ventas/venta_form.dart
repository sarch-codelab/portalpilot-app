import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VentaForm extends StatefulWidget {
  const VentaForm({super.key});

  @override
  State<VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<VentaForm> {
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String _estado = 'cotizacion';

  @override
  void dispose() { _clienteCtrl.dispose(); _descripcionCtrl.dispose(); _montoCtrl.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_crm') ?? '[]'));
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'cliente': _clienteCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
      'monto': double.tryParse(_montoCtrl.text) ?? 0.0,
      'estado': _estado,
      'fecha': DateTime.now().toIso8601String(),
    });
    await prefs.setString('ventas_crm', jsonEncode(list));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venta guardada correctamente', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('NUEVA VENTA', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(_clienteCtrl, 'Cliente *', Icons.person_rounded),
            const SizedBox(height: 12),
            _buildField(_descripcionCtrl, 'Descripción *', Icons.description_rounded, maxLines: 3),
            const SizedBox(height: 12),
            _buildField(_montoCtrl, 'Monto (L.) *', Icons.attach_money_rounded, type: TextInputType.number),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Color(0xFF737373), size: 18),
                  const SizedBox(width: 12),
                  Text('Estado', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _estado, dropdownColor: const Color(0xFF1A1A1A), underline: const SizedBox(),
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'cotizacion', child: Text('Cotización')),
                      DropdownMenuItem(value: 'en_proceso', child: Text('En Proceso')),
                    ],
                    onChanged: (v) => setState(() => _estado = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                label: Text('Guardar Venta', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl, keyboardType: type, maxLines: maxLines,
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
      validator: label.contains('*') ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
      decoration: InputDecoration(
        labelText: label.replaceAll(' *', ''), labelStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
        prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 18),
        filled: true, fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
      ),
    );
  }
}
