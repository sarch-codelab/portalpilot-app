import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/DB/db.dart';

// ═══════════════════════════════════════════════════════════
// Areas/Educacion/Matricula/nueva_matricula.dart
// ═══════════════════════════════════════════════════════════




const Color accentPurple = Color(0xFF8B5CF6);
const Color textDark = Color(0xFF1E293B);

class NuevaMatriculaScreen extends StatefulWidget {
  const NuevaMatriculaScreen({super.key});

  @override
  State<NuevaMatriculaScreen> createState() => _NuevaMatriculaScreenState();
}

class _NuevaMatriculaScreenState extends State<NuevaMatriculaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _contactoController = TextEditingController();
  String? _nivelSeleccionado;
  bool _isLoading = false;

  final List<String> _niveles = [
    'Preescolar', 'Primaria', 'Secundaria', 'Bachillerato'
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _contactoController.dispose();
    super.dispose();
  }

  Future<void> _guardarMatricula() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nivelSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un nivel educativo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaCodigo = prefs.getString('company_code') ?? 'ROOT';

      await PortalPilotDB.insertMatricula(
        alumnoNombre: _nombreController.text.trim(),
        alumnoApellido: _apellidoController.text.trim(),
        nivelEducativo: _nivelSeleccionado!,
        encargadoContacto: _contactoController.text.trim(),
        empresaCodigo: empresaCodigo,
      );

      if (mounted) {
        _nombreController.clear();
        _apellidoController.clear();
        _contactoController.clear();
        setState(() => _nivelSeleccionado = null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Matrícula guardada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Matrícula',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: accentPurple))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('Datos del Alumno'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre del Alumno',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _apellidoController,
                        label: 'Apellidos del Alumno',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Detalles Académicos'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _nivelSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Nivel Educativo',
                          prefixIcon: Icon(Icons.school_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _niveles
                            .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                            .toList(),
                        onChanged: (v) => setState(() => _nivelSeleccionado = v),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Datos de Contacto'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _contactoController,
                        label: 'Correo del Encargado / Padre',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _guardarMatricula,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Guardar Matrícula',
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: GoogleFonts.outfit(
            fontSize: 20, fontWeight: FontWeight.bold, color: textDark));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator ??
          (v) => v == null || v.isEmpty ? 'Requerido' : null,
    );
  }
}