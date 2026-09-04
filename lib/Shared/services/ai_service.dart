// lib/Shared/services/ai_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/navi_rules.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

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

class ProductIdentification {
  final String? nombre;
  final String? marca;
  final String? categoria;
  final String? descripcion;
  final String? presentacion;
  final String? unidadMedida;
  final double? confianza;
  final String? barcode;

  ProductIdentification({
    this.nombre, this.marca, this.categoria, this.descripcion,
    this.presentacion, this.unidadMedida, this.confianza, this.barcode,
  });

  factory ProductIdentification.fromJson(Map<String, dynamic> json) {
    return ProductIdentification(
      nombre: json['nombre']?.toString(),
      marca: json['marca']?.toString(),
      categoria: json['categoria']?.toString(),
      descripcion: json['descripcion']?.toString(),
      presentacion: json['presentacion']?.toString(),
      unidadMedida: json['unidad_medida']?.toString(),
      confianza: (json['confianza'] as num?)?.toDouble(),
      barcode: json['barcode']?.toString() ?? json['codigo_barras']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (nombre != null) 'nombre': nombre,
    if (marca != null) 'marca': marca,
    if (categoria != null) 'categoria': categoria,
    if (descripcion != null) 'descripcion': descripcion,
    if (presentacion != null) 'presentacion': presentacion,
    if (unidadMedida != null) 'unidad_medida': unidadMedida,
    if (confianza != null) 'confianza': confianza,
    if (barcode != null) 'barcode': barcode,
  };
}

class UpsellSugerencia {
  final String codigo;
  final String nombre;
  final String motivo;

  UpsellSugerencia({required this.codigo, required this.nombre, required this.motivo});

  factory UpsellSugerencia.fromJson(Map<String, dynamic> json) {
    return UpsellSugerencia(
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      motivo: json['motivo']?.toString() ?? '',
    );
  }
}

class BarcodeLookupResult {
  final bool found;
  final List<Map<String, dynamic>> products;
  final String source;
  final String? message;

  BarcodeLookupResult({required this.found, required this.products, required this.source, this.message});

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      found: json['found'] == true,
      products: (json['products'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      source: json['source']?.toString() ?? 'unknown',
      message: json['message']?.toString(),
    );
  }
}

class AIManager {
  AIManager._privateConstructor();
  static final AIManager instance = AIManager._privateConstructor();

  String _nombreUsuario = 'Usuario';
  String _rolUsuario = 'admin';
  String _empresaCodigo = 'ROOT';
  String _empresaPlan = 'Prueba';
  String? _token;

  String get nombreUsuario => _nombreUsuario;
  String get rolUsuario => _rolUsuario;
  String get empresaCodigo => _empresaCodigo;
  String get empresaPlan => _empresaPlan;

  bool _isInitialized = false;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final newToken = prefs.getString('auth_token');

    if (_isInitialized && newToken == _token) return;

    _nombreUsuario = prefs.getString('user_nombre') ?? 'Usuario';
    _rolUsuario = prefs.getString('user_role') ?? 'admin';
    _empresaCodigo = prefs.getString('company_code') ?? 'ROOT';
    _empresaPlan = AuthController.normalizarPlan(prefs.getString('empresa_plan') ?? '');
    _token = newToken;

    _isInitialized = true;
    debugPrint('AIManager inicializado para: $_nombreUsuario ($_rolUsuario) plan=$_empresaPlan');
  }

  void reset() {
    _isInitialized = false;
    _token = null;
    _nombreUsuario = 'Usuario';
    _rolUsuario = 'admin';
    _empresaCodigo = 'ROOT';
    _empresaPlan = 'Prueba';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// General chat generation via centralized AI gateway
  Future<AIResponse> generate({
    required String prompt,
    String? contextoAdicional,
    String modelId = 'openai/gpt-oss-20b',
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized) await initialize();

    final systemPrompt = NaviRules.generarPromptMaestro(
      nombreUsuario: _nombreUsuario,
      rolUsuario: _rolUsuario,
      empresaCodigo: _empresaCodigo,
      contextoAdicional: contextoAdicional,
      plan: _empresaPlan,
    );

    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot/api/ai/chat');
    final startTime = DateTime.now();

    try {
      final response = await http.post(url, headers: _headers, body: jsonEncode({
        'message': prompt,
        'systemPrompt': systemPrompt,
        'temperature': temperature,
      })).timeout(const Duration(seconds: 30));

      final duration = DateTime.now().difference(startTime);
      final body = utf8.decode(response.bodyBytes);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body);
      } catch (_) {
        return AIResponse(text: '', modelId: modelId, provider: 'unknown',
          tokensUsed: 0, duration: duration, success: false,
          error: 'Respuesta inválida del servidor (HTTP ${response.statusCode})');
      }

      if (response.statusCode != 200 || data['reply'] == null) {
        return AIResponse(text: '', modelId: modelId, provider: 'unknown',
          tokensUsed: 0, duration: duration, success: false,
          error: data['error']?.toString() ?? 'Error en IA');
      }

      return AIResponse(
        text: data['reply']?.toString() ?? '',
        modelId: data['model']?.toString() ?? modelId,
        provider: data['provider']?.toString() ?? 'groq',
        tokensUsed: 0, duration: duration, success: true,
      );
    } catch (e) {
      return AIResponse(text: '', modelId: modelId, provider: 'error',
        tokensUsed: 0, duration: DateTime.now().difference(startTime),
        success: false, error: e.toString());
    }
  }

  /// Vision analysis: identify product from image via AI gateway
  Future<AIResponse> identifyProductFromImage({
    required String imageBase64,
    String? customPrompt,
  }) async {
    if (!_isInitialized) await initialize();

    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot/api/ai/vision');
    final startTime = DateTime.now();

    final prompt = customPrompt ?? 'Identifica este producto y devuelve un JSON con: nombre, marca, categoria, descripcion, presentacion, unidad_medida, confianza (0-1). Si no puedes determinar algo, deja el campo como null. Responde SOLO con el JSON.';

    try {
      final response = await http.post(url, headers: _headers, body: jsonEncode({
        'image': imageBase64.startsWith('data:') ? imageBase64 : 'data:image/jpeg;base64,$imageBase64',
        'prompt': prompt,
        'maxTokens': 800,
      })).timeout(const Duration(seconds: 45));

      final duration = DateTime.now().difference(startTime);
      final body = utf8.decode(response.bodyBytes);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body);
      } catch (_) {
        return AIResponse(text: '', modelId: 'vision', provider: 'unknown',
          tokensUsed: 0, duration: duration, success: false,
          error: 'Respuesta inválida del servidor (HTTP ${response.statusCode})');
      }

      if (response.statusCode != 200 || data['reply'] == null) {
        return AIResponse(text: '', modelId: 'vision', provider: 'unknown',
          tokensUsed: 0, duration: duration, success: false,
          error: data['error']?.toString() ?? 'No se pudo analizar la imagen');
      }

      return AIResponse(
        text: data['reply']?.toString() ?? '',
        modelId: data['model']?.toString() ?? 'vision',
        provider: data['provider']?.toString() ?? 'groq',
        tokensUsed: 0, duration: duration, success: true,
      );
    } catch (e) {
      return AIResponse(text: '', modelId: 'vision', provider: 'error',
        tokensUsed: 0, duration: DateTime.now().difference(startTime),
        success: false, error: e.toString());
    }
  }

  /// Parse vision response into ProductIdentification
  ProductIdentification parseProductIdentification(String aiResponse) {
    try {
      String jsonStr = aiResponse.trim();
      // Extract JSON from markdown code blocks if present
      if (jsonStr.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)!.trim();
      }
      // Try to find JSON object in the response
      final jsonStart = jsonStr.indexOf('{');
      final jsonEnd = jsonStr.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);
      }
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) {
        return ProductIdentification.fromJson(parsed);
      }
    } catch (e) {
      debugPrint('[AI] Failed to parse product identification: $e');
    }
    return ProductIdentification();
  }

  /// Barcode lookup: search products in Supabase by barcode
  Future<BarcodeLookupResult> lookupBarcode(String code) async {
    if (!_isInitialized) await initialize();

    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot/api/ai/barcode/${Uri.encodeComponent(code)}');

    try {
      final response = await http.get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return BarcodeLookupResult.fromJson(data);
    } catch (e) {
      return BarcodeLookupResult(found: false, products: [], source: 'error', message: 'Error al buscar código de barras');
    }
  }

  /// Full product identification flow: barcode first, then vision fallback
  Future<({BarcodeLookupResult? barcode, AIResponse? vision, ProductIdentification? identification})>
  identifyProduct({String? imageBase64, String? barcode}) async {
    BarcodeLookupResult? barcodeResult;
    AIResponse? visionResult;
    ProductIdentification? identification;

    // Step 1: If barcode provided, try database lookup first
    if (barcode != null && barcode.isNotEmpty) {
      barcodeResult = await lookupBarcode(barcode);
      if (barcodeResult.found && barcodeResult.products.isNotEmpty) {
        final p = barcodeResult.products.first;
        identification = ProductIdentification(
          nombre: p['nombre']?.toString(),
          marca: p['marca']?.toString(),
          categoria: p['categoria']?.toString(),
          descripcion: p['descripcion']?.toString(),
          presentacion: p['presentacion']?.toString(),
          unidadMedida: p['unidad_medida']?.toString(),
          confianza: 1.0,
          barcode: p['barcode']?.toString() ?? p['codigo']?.toString(),
        );
        return (barcode: barcodeResult, vision: null, identification: identification);
      }
    }

    // Step 2: If image provided, try vision analysis
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      visionResult = await identifyProductFromImage(imageBase64: imageBase64);
      if (visionResult.success && visionResult.text.isNotEmpty) {
        identification = parseProductIdentification(visionResult.text);
      }
    }

    return (barcode: barcodeResult, vision: visionResult, identification: identification);
  }

  Future<AIResponse> _callGateway(String path, Map<String, dynamic> body) async {
    if (!_isInitialized) await initialize();
    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot$path');
    final startTime = DateTime.now();
    try {
      final response = await http.post(url, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      final duration = DateTime.now().difference(startTime);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || data['reply'] == null) {
        return AIResponse(text: '', modelId: '', provider: 'unknown', tokensUsed: 0, duration: duration, success: false, error: data['error']?.toString() ?? 'Error en IA');
      }
      return AIResponse(text: data['reply']?.toString() ?? '', modelId: data['model']?.toString() ?? '', provider: data['provider']?.toString() ?? 'groq', tokensUsed: 0, duration: duration, success: true);
    } catch (e) {
      return AIResponse(text: '', modelId: '', provider: 'error', tokensUsed: 0, duration: DateTime.now().difference(startTime), success: false, error: e.toString());
    }
  }

  Future<AIResponse> dashboardQuery(String message) async {
    final result = await _callGateway('/api/ai/dashboard', {'message': message});
    await logUsage('dashboard_query', result);
    return result;
  }

  Future<AIResponse> posAnalysis(String message, {Map<String, String>? dateRange, String? empresaCodigo}) async {
    final body = <String, dynamic>{'message': message};
    if (dateRange != null) body['dateRange'] = dateRange;
    if (empresaCodigo != null && empresaCodigo.isNotEmpty) body['empresaCodigo'] = empresaCodigo;
    final result = await _callGateway('/api/ai/pos/analyze', body);
    await logUsage('pos_analysis', result);
    return result;
  }

  /// Recomendaciones de upsell/cross-sell basadas en el carrito actual.
  /// El backend solo devuelve productos existentes en [catalogo] y que no
  /// estén ya en [carrito]. Devuelve lista vacía si algo falla (no bloquea).
  Future<List<UpsellSugerencia>> obtenerSugerenciasUpsell({
    required List<Map<String, dynamic>> carrito,
    required List<Map<String, dynamic>> catalogo,
  }) async {
    if (!_isInitialized) await initialize();

    final apiRoot = const String.fromEnvironment('API_ROOT', defaultValue: _defaultAiApiRoot);
    final url = Uri.parse('$apiRoot/api/ai/pos/upsell');

    try {
      final response = await http.post(url, headers: _headers, body: jsonEncode({
        'carrito': carrito,
        'catalogo': catalogo,
      })).timeout(const Duration(seconds: 20));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || data['sugerencias'] == null) {
        debugPrint('[AI] Upsell sin resultados: ${data['error'] ?? 'status ${response.statusCode}'}');
        return [];
      }
      final arr = data['sugerencias'] as List<dynamic>? ?? [];
      return arr
          .whereType<Map>()
          .map((e) => UpsellSugerencia.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[AI] Error en upsell: $e');
      return [];
    }
  }

  Future<AIResponse> crmCustomer(String message, {String? customerId}) async {
    final body = <String, dynamic>{'message': message};
    if (customerId != null) body['customerId'] = customerId;
    final result = await _callGateway('/api/ai/crm/customer', body);
    await logUsage('crm_customer', result);
    return result;
  }

  Future<AIResponse> supportAssist(String message, {String? ticketId}) async {
    final body = <String, dynamic>{'message': message};
    if (ticketId != null) body['ticketId'] = ticketId;
    final result = await _callGateway('/api/ai/support', body);
    await logUsage('support_assist', result);
    return result;
  }

  Future<void> logUsage(String funcion, AIResponse result) async {
    debugPrint('[AI/USAGE] $funcion: success=${result.success}, provider=${result.provider}, model=${result.modelId}');
  }

  String getMensajeBienvenida() {
    return NaviRules.mensajeBienvenida(_nombreUsuario, _rolUsuario, _empresaPlan);
  }

  bool tienePermiso(String recurso) {
    return NaviRules.puedeAccederA(_rolUsuario, recurso);
  }
}
