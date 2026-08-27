import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _defaultApiRoot = 'https://portalpilot-app.vercel.app';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  String _token = '';
  String _empresaCodigo = 'ROOT';
  String _apiRoot = _defaultApiRoot;
  bool _initialized = false;

  String get empresaCodigo => _empresaCodigo;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final newToken = prefs.getString('auth_token') ?? '';
    final newEmpresa = prefs.getString('company_code') ?? 'ROOT';

    if (_initialized && newToken == _token && newEmpresa == _empresaCodigo) return;

    _token = newToken;
    _empresaCodigo = newEmpresa;
    _apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultApiRoot);
    _initialized = true;
    debugPrint('[ApiService] initialized for empresa=$_empresaCodigo');
  }

  void reset() {
    _initialized = false;
    _token = '';
    _empresaCodigo = 'ROOT';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('$_apiRoot$path');

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    await initialize();
    final uri = queryParams != null ? _uri(path).replace(queryParameters: queryParams) : _uri(path);
    try {
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    await initialize();
    try {
      final response = await http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    await initialize();
    try {
      final response = await http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    await initialize();
    try {
      final response = await http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    await initialize();
    try {
      final response = await http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      return {'error': data['error'] ?? 'Error ${response.statusCode}', 'statusCode': response.statusCode};
    } catch (e) {
      return {'error': 'Error parsing response: $e', 'statusCode': response.statusCode};
    }
  }

  bool isSuccess(Map<String, dynamic> result) => !result.containsKey('error');
  String? getError(Map<String, dynamic> result) => result['error'] as String?;

  void setToken(String token) {
    _token = token;
  }

  void setEmpresaCodigo(String codigo) {
    _empresaCodigo = codigo;
  }
}
