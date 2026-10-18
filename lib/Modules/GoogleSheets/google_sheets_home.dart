import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Modules/GoogleSheets/google_sheets_service.dart';
import 'package:portal_pilot_app/Modules/GoogleSheets/google_sheets_models.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';

class GoogleSheetsHome extends StatefulWidget {
  const GoogleSheetsHome({super.key});

  @override
  State<GoogleSheetsHome> createState() => _GoogleSheetsHomeState();
}

class _GoogleSheetsHomeState extends State<GoogleSheetsHome> {
  final _spreadsheetIdController = TextEditingController();
  final _sheetNameController = TextEditingController();

  GoogleSheetsConfig _config = GoogleSheetsConfig();
  bool _loading = true;
  bool _syncing = false;
  SyncResult? _lastSyncResult;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _loadConfig();
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    _spreadsheetIdController.dispose();
    _sheetNameController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await GoogleSheetsService.instance.getConfig(forceRefresh: true);
    if (mounted) {
      setState(() {
        _config = config;
        _loading = false;
        if (config.spreadsheetId != null) {
          _spreadsheetIdController.text = config.spreadsheetId!;
        }
        if (config.sheetName != null) {
          _sheetNameController.text = config.sheetName!;
        }
      });
    }
  }

  Future<void> _startOAuth() async {
    final url = await GoogleSheetsService.instance.getAuthorizeUrl();
    if (!mounted) return;
    if (url != null) {
      PPNotifications.info(context, 'Abre este enlace en tu navegador:\n$url', title: 'Autorizar Google Sheets');
    } else {
      PPNotifications.error(context, 'No se pudo iniciar la autorización. Verifica GOOGLE_CLIENT_ID en el backend.');
    }
  }

  Future<void> _syncNow() async {
    final spreadsheetId = _spreadsheetIdController.text.trim();
    if (!mounted) return;
    if (spreadsheetId.isEmpty) {
      PPNotifications.error(context, 'Ingresa un Spreadsheet ID válido');
      return;
    }

    setState(() => _syncing = true);
    final result = await GoogleSheetsService.instance.syncNow(spreadsheetId: spreadsheetId);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastSyncResult = result;
    });

    if (result.success) {
      PPNotifications.success(context, 'Se sincronizaron ${result.rowsSynced} filas a "${result.sheetName}"');
      _loadConfig();
    } else {
      PPNotifications.error(context, result.errorMessage ?? 'Error al sincronizar');
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar Google Sheets'),
        content: const Text('¿Seguro que quieres desconectar? Se perderán los tokens y la configuración.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desconectar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await GoogleSheetsService.instance.disconnect();
      await _loadConfig();
      if (mounted) PPNotifications.info(context, 'Google Sheets desconectado');
    }
  }

  void _saveSpreadsheetId() {
    final id = _spreadsheetIdController.text.trim();
    if (id.isNotEmpty) {
      GoogleSheetsService.instance.updateConfig(spreadsheetId: id);
      if (mounted) PPNotifications.success(context, 'Spreadsheet ID guardado localmente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);

    return PPModuleScaffold(
      moduleId: 'google_sheets',
      screenTitle: 'Google Sheets',
      moduleIcon: Icons.table_chart_rounded,
      moduleColor: const Color(0xFF34A853),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildConnectionCard(palette),
                const SizedBox(height: 16),
                _buildSpreadsheetConfigCard(palette),
                const SizedBox(height: 16),
                _buildSyncCard(palette),
                const SizedBox(height: 16),
                _buildAdvancedConfigCard(palette),
                const SizedBox(height: 16),
                if (_lastSyncResult != null) _buildLastResultCard(palette),
              ],
            ),
    );
  }

  Widget _buildConnectionCard(ThemePalette palette) {
    final isConnected = _config.isConnected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF34A853).withValues(alpha: 0.1) : palette.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isConnected ? const Color(0xFF34A853) : palette.borderLight),
            ),
            child: Icon(
              Icons.table_chart_rounded,
              size: 32,
              color: isConnected ? const Color(0xFF34A853) : palette.textDim,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Google Sheets Conectado' : 'Google Sheets Desconectado',
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected
                      ? 'Exporta tus ventas e inventario automáticamente'
                      : 'Conecta tu cuenta de Google para exportar datos a Sheets',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: palette.textDim,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            ElevatedButton.icon(
              onPressed: _startOAuth,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Conectar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34A853),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Desconectar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.errorRed,
                side: BorderSide(color: palette.errorRed),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetConfigCard(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: palette.brand, size: 22),
              const SizedBox(width: 10),
              Text(
                'Configuración del Spreadsheet',
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _spreadsheetIdController,
            style: GoogleFonts.dmSans(fontSize: 14, color: palette.textPrimary),
            decoration: InputDecoration(
              labelText: 'Spreadsheet ID',
              hintText: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
              labelStyle: GoogleFonts.dmSans(color: palette.textDim),
              hintStyle: GoogleFonts.dmSans(color: palette.textMuted, fontSize: 12),
              prefixIcon: Icon(Icons.credit_card_rounded, color: palette.brand),
              filled: true,
              fillColor: palette.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.brand, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.save_rounded, color: palette.brand),
                onPressed: _saveSpreadsheetId,
                tooltip: 'Guardar ID',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sheetNameController,
            style: GoogleFonts.dmSans(fontSize: 14, color: palette.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nombre de la hoja (opcional)',
              hintText: 'Ventas 2026-10-04',
              labelStyle: GoogleFonts.dmSans(color: palette.textDim),
              hintStyle: GoogleFonts.dmSans(color: palette.textMuted, fontSize: 12),
              prefixIcon: Icon(Icons.description_rounded, color: palette.brand),
              filled: true,
              fillColor: palette.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.brand, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El Spreadsheet ID es el código largo en la URL:\nhttps://docs.google.com/spreadsheets/d/{ID}/edit',
            style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, color: palette.brand, size: 22),
              const SizedBox(width: 10),
              Text(
                'Sincronización',
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded, size: 20),
              label: Text(_syncing ? 'Sincronizando...' : 'Sincronizar ventas de hoy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_config.lastSyncAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.borderLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: palette.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Última sincronización',
                          style: GoogleFonts.dmSans(fontSize: 11, color: palette.textDim),
                        ),
                        Text(
                          _formatLastSync(_config.lastSyncAt!),
                          style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                        if (_config.lastSyncRows > 0)
                          Text(
                            '${_config.lastSyncRows} filas exportadas',
                            style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedConfigCard(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: palette.brand, size: 22),
              const SizedBox(width: 10),
              Text(
                'Configuración Avanzada',
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(_showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                label: Text(_showAdvanced ? 'Ocultar' : 'Mostrar'),
              ),
            ],
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('Sincronización automática diaria', style: GoogleFonts.dmSans(color: palette.textPrimary)),
              subtitle: Text('Exporta ventas al cierre del día', style: GoogleFonts.dmSans(fontSize: 12, color: palette.textDim)),
              value: _config.autoSyncEnabled,
              onChanged: (val) => GoogleSheetsService.instance.updateConfig(autoSyncEnabled: val),
              activeThumbColor: palette.brand,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.help_outline_rounded, color: palette.brand),
              title: Text('Cómo obtener el Spreadsheet ID', style: GoogleFonts.dmSans(color: palette.textPrimary)),
              subtitle: Text(
                '1. Abre tu Google Sheets\n'
                '2. Copia el ID de la URL: https://docs.google.com/spreadsheets/d/{ID}/edit\n'
                '3. Pégalo en el campo de arriba',
                style: GoogleFonts.dmSans(fontSize: 12, color: palette.textDim),
              ),
              onTap: () => _showAdvanced = false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastResultCard(ThemePalette palette) {
    final result = _lastSyncResult!;
    final isSuccess = result.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? palette.successGreen.withValues(alpha: 0.1) : palette.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSuccess ? palette.successGreen : palette.errorRed),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isSuccess ? palette.successGreen : palette.errorRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuccess ? 'Sincronización exitosa' : 'Error en sincronización',
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: isSuccess ? palette.successGreen : palette.errorRed),
                ),
                const SizedBox(height: 4),
                Text(
                  isSuccess
                      ? '${result.rowsSynced} filas → "${result.sheetName}"'
                      : result.errorMessage ?? 'Error desconocido',
                  style: GoogleFonts.dmSans(fontSize: 12, color: palette.textDim),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hace unos segundos',
                  style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: isSuccess ? palette.successGreen : palette.errorRed),
            onPressed: () => setState(() => _lastSyncResult = null),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}