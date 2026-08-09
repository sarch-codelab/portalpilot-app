import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmpleadoForm extends StatefulWidget {
  final Map<String, dynamic>? empleadoExistente;

  const EmpleadoForm({super.key, this.empleadoExistente});

  @override
  State<EmpleadoForm> createState() => _EmpleadoFormState();
}

class _EmpleadoFormState extends State<EmpleadoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _departamentoCtrl = TextEditingController();
  final _salarioCtrl = TextEditingController();
  final _telefonoEmergenciaCtrl = TextEditingController();
  final _contactoEmergenciaCtrl = TextEditingController();
  String _estado = 'Activo';
  DateTime? _fechaIngreso;

  @override
  void initState() {
    super.initState();
    if (widget.empleadoExistente != null) {
      final e = widget.empleadoExistente!;
      _nombreCtrl.text = e['nombre'] ?? '';
      _apellidoCtrl.text = e['apellido'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _telefonoCtrl.text = e['telefono'] ?? '';
      _cargoCtrl.text = e['cargo'] ?? '';
      _departamentoCtrl.text = e['departamento'] ?? '';
      _salarioCtrl.text = (e['salario'] as num?)?.toString() ?? '';
      _telefonoEmergenciaCtrl.text = e['telefono_emergencia'] ?? '';
      _contactoEmergenciaCtrl.text = e['contacto_emergencia'] ?? '';
      _estado = e['activo'] == true ? 'Activo' : 'Inactivo';
      _fechaIngreso = DateTime.tryParse(e['fecha_ingreso'] ?? '');
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _cargoCtrl.dispose();
    _departamentoCtrl.dispose();
    _salarioCtrl.dispose();
    _telefonoEmergenciaCtrl.dispose();
    _contactoEmergenciaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('empleados') ?? '[]';
    final List<dynamic> empleados = jsonDecode(json);

    final empleado = {
      'id': widget.empleadoExistente?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'cargo': _cargoCtrl.text.trim(),
      'departamento': _departamentoCtrl.text.trim(),
      'salario': double.tryParse(_salarioCtrl.text) ?? 0.0,
      'telefono_emergencia': _telefonoEmergenciaCtrl.text.trim(),
      'contacto_emergencia': _contactoEmergenciaCtrl.text.trim(),
      'activo': _estado == 'Activo',
      'fecha_ingreso': _fechaIngreso?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': widget.empleadoExistente?['created_at'] ?? DateTime.now().toIso8601String(),
    };

    if (widget.empleadoExistente != null) {
      final idx = empleados.indexWhere((e) => e['id'] == empleado['id']);
      if (idx != -1) empleados[idx] = empleado;
    } else {
      empleados.add(empleado);
    }

    await prefs.setString('empleados', jsonEncode(empleados));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.empleadoExistente != null;

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
          esEdicion ? 'EDITAR EMPLEADO' : 'NUEVO EMPLEADO',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Información Personal'),
            const SizedBox(height: 12),
            _buildTextField(_nombreCtrl, 'Nombre *', Icons.person_rounded),
            const SizedBox(height: 10),
            _buildTextField(_apellidoCtrl, 'Apellido *', Icons.person_rounded),
            const SizedBox(height: 10),
            _buildTextField(_emailCtrl, 'Email *', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildTextField(_telefonoCtrl, 'Teléfono', Icons.phone_rounded, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _buildSectionHeader('Información Laboral'),
            const SizedBox(height: 12),
            _buildTextField(_cargoCtrl, 'Cargo *', Icons.work_rounded),
            const SizedBox(height: 10),
            _buildTextField(_departamentoCtrl, 'Departamento', Icons.business_rounded),
            const SizedBox(height: 10),
            _buildTextField(_salarioCtrl, 'Salario Mensual (L.)', Icons.attach_money_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _buildDatePicker(),
            const SizedBox(height: 10),
            _buildEstadoSelector(),
            const SizedBox(height: 20),
            _buildSectionHeader('Contacto de Emergencia'),
            const SizedBox(height: 12),
            _buildTextField(_contactoEmergenciaCtrl, 'Nombre del contacto', Icons.contact_phone_rounded),
            const SizedBox(height: 10),
            _buildTextField(_telefonoEmergenciaCtrl, 'Teléfono de emergencia', Icons.emergency_rounded, keyboardType: TextInputType.phone),
            const SizedBox(height: 30),
            _buildSaveButton(esEdicion),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFEC4899), letterSpacing: 0.8),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
      validator: label.contains('*') ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
      decoration: InputDecoration(
        labelText: label.replaceAll(' *', ''),
        labelStyle: GoogleFonts.dmSans(color: const Color(0xFF737373)),
        prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 18),
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEC4899))),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _fechaIngreso ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFEC4899))), child: child!);
          },
        );
        if (picked != null) setState(() => _fechaIngreso = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF737373), size: 18),
            const SizedBox(width: 12),
            Text(
              _fechaIngreso != null ? '${_fechaIngreso!.day}/${_fechaIngreso!.month}/${_fechaIngreso!.year}' : 'Fecha de ingreso',
              style: GoogleFonts.dmSans(color: _fechaIngreso != null ? Colors.white : const Color(0xFF737373), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          const Icon(Icons.toggle_on_rounded, color: Color(0xFF737373), size: 18),
          const SizedBox(width: 12),
          Text('Estado', style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 14)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Activo', label: Text('Activo', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 'Inactivo', label: Text('Inactivo', style: TextStyle(fontSize: 11))),
            ],
            selected: {_estado},
            onSelectionChanged: (v) => setState(() => _estado = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return const Color(0xFFEC4899).withValues(alpha: 0.2);
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return const Color(0xFFEC4899);
                return const Color(0xFF737373);
              }),
              side: WidgetStateProperty.all(BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool esEdicion) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _guardar,
        icon: Icon(esEdicion ? Icons.save_rounded : Icons.person_add_rounded, color: Colors.white, size: 20),
        label: Text(
          esEdicion ? 'Guardar Cambios' : 'Registrar Empleado',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEC4899),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
