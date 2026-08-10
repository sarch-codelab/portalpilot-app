import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/fiscal_compliance.dart';
import 'package:portal_pilot_app/Shared/utils/validation_helper.dart';

class FiscalSettings extends StatefulWidget {
  const FiscalSettings({super.key});

  @override
  State<FiscalSettings> createState() => _FiscalSettingsState();
}

class _FiscalSettingsState extends State<FiscalSettings> {
  final _rtnController = TextEditingController();
  final _nombreEmpresaController = TextEditingController();
  final _establecimientoController = TextEditingController();
  final _puntoEmisionController = TextEditingController();
  final _caiController = TextEditingController();
  
  FiscalConfig _config = FiscalConfig.defaultConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
    _rtnController.dispose();
    _nombreEmpresaController.dispose();
    _establecimientoController.dispose();
    _puntoEmisionController.dispose();
    _caiController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    await FiscalCompliance().loadConfig();
    setState(() {
      _config = FiscalCompliance().config;
      _rtnController.text = _config.rtnEmpresa;
      _nombreEmpresaController.text = _config.nombreEmpresa;
      _establecimientoController.text = _config.establecimiento;
      _puntoEmisionController.text = _config.puntoEmision;
      _caiController.text = _config.cai ?? '';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Configuración Fiscal', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF10B981),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('DATOS DE LA EMPRESA'),
                const SizedBox(height: 12),
                _buildTextField('RTN', _rtnController, hintText: '14 dígitos', validator: ValidationHelper.validateRTN),
                const SizedBox(height: 12),
                _buildTextField('Nombre de la Empresa', _nombreEmpresaController, validator: (value) => ValidationHelper.validateRequired(value, fieldName: 'Nombre')),
                const SizedBox(height: 12),
                _buildSectionHeader('PUNTOS DE EMISIÓN'),
                const SizedBox(height: 12),
                _buildTextField('Establecimiento', _establecimientoController, hintText: '0000', maxLength: 4),
                const SizedBox(height: 12),
                _buildTextField('Punto de Emisión', _puntoEmisionController, hintText: '0000', maxLength: 4),
                const SizedBox(height: 12),
                _buildSectionHeader('CONFIGURACIÓN SAR'),
                const SizedBox(height: 12),
                _buildTextField('CAI', _caiController, hintText: '37 caracteres alfanuméricos', validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    return FiscalCompliance().validateCAI(value) ? null : 'CAI inválido';
                  }
                  return null;
                }),
                const SizedBox(height: 12),
                _buildSwitch(
                  'Emitir Factura Electrónica',
                  'Activar facturación electrónica SAR',
                  _config.emitirFacturaElectronica,
                  (value) => setState(() => _config = _config.copyWith(emitirFacturaElectronica: value)),
                ),
                const SizedBox(height: 12),
                _buildSectionHeader('TASAS DE IMPUESTOS'),
                const SizedBox(height: 12),
                _buildNumberField('Tasa ISV (%)', _config.tasaISV, (value) => setState(() => _config = _config.copyWith(tasaISV: value))),
                const SizedBox(height: 12),
                _buildNumberField('Límite Exento ISV (L.)', _config.limiteExentoISV, (value) => setState(() => _config = _config.copyWith(limiteExentoISV: value))),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Guardar Configuración', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hintText, int? maxLength, String? Function(String?)? validator}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
        border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
        counterText: '',
      ),
      style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black),
    );
  }

  Widget _buildNumberField(String label, double value, Function(double) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
          Text(value.toStringAsFixed(2), style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig() async {
    final updatedConfig = _config.copyWith(
      rtnEmpresa: _rtnController.text,
      nombreEmpresa: _nombreEmpresaController.text,
      establecimiento: _establecimientoController.text,
      puntoEmision: _puntoEmisionController.text,
      cai: _caiController.text.isEmpty ? null : _caiController.text,
    );

    final saved = await FiscalCompliance().saveConfig(updatedConfig);
    
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración fiscal guardada'), backgroundColor: Color(0xFF10B981)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar configuración'), backgroundColor: Color(0xFFEF4444)),
      );
    }
  }
}