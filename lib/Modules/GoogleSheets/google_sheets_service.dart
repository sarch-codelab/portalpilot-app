import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Modules/GoogleSheets/google_sheets_models.dart';

class GoogleSheetsService {
  GoogleSheetsService._();
  static final GoogleSheetsService instance = GoogleSheetsService._();

  static const String _baseUrl = 'https://api.portal-pilot.vercel.app';
  static const Duration _timeout = Duration(seconds: 30);

  // Cache local
  GoogleSheetsConfig? _cachedConfig;
  DateTime? _cacheExpiry;

  Future<GoogleSheetsConfig> getConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedConfig != null && _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedConfig!;
    }

    final auth = AuthController.instance;
    if (!auth.isLoggedIn || auth.empresaCodigo.isEmpty) {
      return GoogleSheetsConfig();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/empresa/integrations'),
        headers: _authHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final integraciones = data['integraciones'] as List<dynamic>? ?? [];
        final sheets = integraciones.firstWhere(
          (i) => i['key'] == 'sheets',
          orElse: () => <String, dynamic>{},
        );

        if (sheets.isNotEmpty && sheets['enabled'] == true) {
          _cachedConfig = GoogleSheetsConfig(
            spreadsheetId: sheets['spreadsheetId'] as String?,
            spreadsheetUrl: sheets['spreadsheetUrl'] as String?,
            sheetName: sheets['sheetName'] as String?,
            autoSyncEnabled: sheets['autoSyncEnabled'] as bool? ?? false,
            lastSyncAt: sheets['lastSyncAt'] as String?,
            lastSyncRows: sheets['lastSyncRows'] as int? ?? 0,
            errorMessage: sheets['errorMessage'] as String?,
          );
        } else {
          _cachedConfig = GoogleSheetsConfig();
        }
      } else {
        _cachedConfig = GoogleSheetsConfig();
      }
    } catch (e) {
      _cachedConfig = GoogleSheetsConfig(errorMessage: 'Error: $e');
    }

    _cacheExpiry = DateTime.now().add(const Duration(minutes: 5));
    return _cachedConfig!;
  }

  Future<String?> getAuthorizeUrl() async {
    final auth = AuthController.instance;
    if (!auth.isLoggedIn || auth.empresaCodigo.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/integrations/google/authorize'),
        headers: _authHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<SyncResult> syncNow({String? spreadsheetId}) async {
    final auth = AuthController.instance;
    if (!auth.isLoggedIn || auth.empresaCodigo.isEmpty) {
      return SyncResultFailure(errorMessage: 'No autenticado', sheetName: '');
    }

    try {
      final config = await getConfig(forceRefresh: true);
      final targetSpreadsheetId = spreadsheetId ?? config.spreadsheetId;
      if (targetSpreadsheetId == null || targetSpreadsheetId.isEmpty) {
        return SyncResultFailure(errorMessage: 'No hay Spreadsheet ID configurado', sheetName: '');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/empresa/integrations/sheets/sync'),
        headers: {
          ..._authHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'spreadsheetId': targetSpreadsheetId}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _invalidateCache();
        return SyncResultSuccess(
          rowsSynced: data['rows'] as int? ?? 0,
          sheetName: data['sheet'] as String? ?? 'Desconocido',
        );
      } else {
        final data = jsonDecode(response.body);
        return SyncResultFailure(
          errorMessage: data['error'] as String? ?? 'Error desconocido',
          sheetName: '',
        );
      }
    } catch (e) {
      return SyncResultFailure(errorMessage: 'Error de red: $e', sheetName: '');
    }
  }

  Future<void> disconnect() async {
    final auth = AuthController.instance;
    if (!auth.isLoggedIn || auth.empresaCodigo.isEmpty) return;

    try {
      await http.delete(
        Uri.parse('$_baseUrl/api/empresa/integrations/sheets'),
        headers: _authHeaders(),
      ).timeout(_timeout);
      await _invalidateCache();
    } catch (_) {}
  }

  Future<void> updateConfig({
    String? spreadsheetId,
    String? spreadsheetUrl,
    String? sheetName,
    bool? autoSyncEnabled,
  }) async {
    final auth = AuthController.instance;
    if (!auth.isLoggedIn || auth.empresaCodigo.isEmpty) return;

    final currentConfig = await getConfig(forceRefresh: true);
    final newConfig = currentConfig.copyWith(
      spreadsheetId: spreadsheetId,
      spreadsheetUrl: spreadsheetUrl,
      sheetName: sheetName,
      autoSyncEnabled: autoSyncEnabled,
    );

    // Nota: La actualización de config se hace vía backend en la próxima sync
    // Por ahora guardamos localmente para UI
    _cachedConfig = newConfig;
    _cacheExpiry = DateTime.now().add(const Duration(minutes: 5));
  }

  Future<void> _invalidateCache() async {
    _cachedConfig = null;
    _cacheExpiry = null;
  }

  Map<String, String> _authHeaders() {
    final auth = AuthController.instance;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${auth.token}',
    };
  }

  // Extrae Spreadsheet ID de una URL de Google Sheets
  static String? extractSpreadsheetId(String url) {
    if (url.isEmpty) return null;
    final patterns = [
      RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)'),
      RegExp(r'/d/([a-zA-Z0-9-_]+)'),
      RegExp(r'id=([a-zA-Z0-9-_]+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    // Si parece un ID directo (solo alfanuméricos, guiones, guiones bajos)
    if (RegExp(r'^[a-zA-Z0-9-_]{20,}$').hasMatch(url)) return url;
    return null;
  }
}