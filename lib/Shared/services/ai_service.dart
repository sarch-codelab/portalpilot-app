// lib/Shared/services/ai_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/Educacion/ia/reglas_ia.dart';

const String _defaultAiApiRoot = 'https://portalpilot-app.vercel.app';

class AIResponse {
  final String text;
  final String modelId;
  final String provider;
  final int tokensUsed;
  final Duration duration;
  final bool success;
  final String? error;

  AIResponse({
    required this.text,
    required this.modelId,
    required this.provider,
    required this.tokensUsed,
    required this.duration,
    required this.success,
    this.error,
  });
}

class AIManager {
  AIManager._privateConstructor();
  static final AIManager instance = AIManager._privateConstructor();

  String _nombreUsuario = 'Usuario';
  String _rolUsuario = 'profesor';
  String _empresaCodigo = 'ROOT';

  String get nombreUsuario => _nombreUsuario;
  String get rolUsuario => _rolUsuario;
  String get empresaCodigo => _empresaCodigo;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _nombreUsuario = prefs.getString('user_nombre') ?? 'Usuario';
    _rolUsuario = prefs.getString('user_rol') ?? 'profesor';
    _empresaCodigo = prefs.getString('company_code') ?? 'ROOT';

    _isInitialized = true;
    debugPrint('AIManager inicializado para: $_nombreUsuario ($_rolUsuario)');
  }

  Future<AIResponse> generate({
    required String prompt,
    String? contextoAdicional,
    String modelId = 'llama-3.3-70b-versatile',
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized) await initialize();

    final systemPrompt = EduIARules.generarPromptMaestro(
      nombreUsuario: _nombreUsuario,
      rolUsuario: _rolUsuario,
      empresaCodigo: _empresaCodigo,
      contextoAdicional: contextoAdicional,
    );

    return await _callGroq(
      modelId: modelId,
      prompt: prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  Future<AIResponse> _callGroq({
    required String modelId,
    required String prompt,
    required String systemPrompt,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    final startTime = DateTime.now();
    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot/api/ai/groq');

    try {
      final body = {
        'modelId': modelId,
        'systemPrompt': systemPrompt,
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final duration = DateTime.now().difference(startTime);
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode != 200 || data['success'] != true) {
        return AIResponse(
          text: '',
          modelId: modelId,
          provider: 'groq',
          tokensUsed: 0,
          duration: duration,
          success: false,
          error: data['error']?.toString() ?? 'Error en la respuesta del servicio de IA',
        );
      }

      return AIResponse(
        text: data['text']?.toString() ?? '',
        modelId: data['modelId']?.toString() ?? modelId,
        provider: data['provider']?.toString() ?? 'groq',
        tokensUsed: data['tokensUsed'] is int ? data['tokensUsed'] as int : int.tryParse(data['tokensUsed']?.toString() ?? '0') ?? 0,
        duration: duration,
        success: true,
      );
    } catch (e) {
      return AIResponse(
        text: '',
        modelId: modelId,
        provider: 'groq',
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  String getMensajeBienvenida() {
    return EduIARules.mensajeBienvenida(_nombreUsuario, _rolUsuario);
  }

  bool tienePermiso(String recurso) {
    return EduIARules.puedeAccederA(_rolUsuario, recurso);
  }
}
