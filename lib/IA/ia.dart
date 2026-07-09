// lib/Areas/IA/ia.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// MODELOS DE IA DISPONIBLES
// ═══════════════════════════════════════════════════════════

/// Categoría de uso para cada modelo
enum AICategory {
  general,        // Chat general, resúmenes
  education,      // Educación, calificaciones, boletas
  health,         // Salud, diagnósticos, pacientes
  documents,      // OCR, extracción de documentos
  translation,    // Traducción de idiomas
  image,          // Generación/análisis de imágenes
  code,           // Generación de código
}

/// Representa un modelo de IA disponible
class AIModel {
  final String id;
  final String name;
  final String provider;
  final AICategory category;
  final String description;
  final String version;
  final bool isFree;
  final int maxTokens;
  final List<String> capabilities;
  final String icon;

  AIModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.category,
    required this.description,
    required this.version,
    required this.isFree,
    required this.maxTokens,
    required this.capabilities,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'category': category.name,
    'description': description,
    'version': version,
    'isFree': isFree,
    'maxTokens': maxTokens,
    'capabilities': capabilities,
    'icon': icon,
  };
}

// ═══════════════════════════════════════════════════════════
// RESPUESTA DE IA
// ═══════════════════════════════════════════════════════════

class AIResponse {
  final String text;
  final String modelId;
  final int tokensUsed;
  final Duration duration;
  final bool success;
  final String? error;

  AIResponse({
    required this.text,
    required this.modelId,
    required this.tokensUsed,
    required this.duration,
    required this.success,
    this.error,
  });
}

// ═══════════════════════════════════════════════════════════
// PROVEEDOR BASE (ABSTRACTO)
// ═══════════════════════════════════════════════════════════

/// Interfaz que todos los proveedores de IA deben implementar
abstract class AIProvider {
  final String name;
  final String apiKey;

  AIProvider({required this.name, required this.apiKey});

  /// Envía un prompt al modelo y retorna la respuesta
  Future<AIResponse> generate({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1000,
    double temperature = 0.7,
  });

  /// Verifica si el proveedor está disponible
  Future<bool> isAvailable();
}

// ═══════════════════════════════════════════════════════════
// GOOGLE GEMINI
// ═══════════════════════════════════════════════════════════

class GeminiProvider extends AIProvider {
  GeminiProvider({required String apiKey})
      : super(name: 'Google Gemini', apiKey: apiKey);

  @override
  Future<AIResponse> generate({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1000,
    double temperature = 0.7,
  }) async {
    final startTime = DateTime.now();

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey'
      );

      final body = {
        'contents': [
          {
            'parts': [
              {'text': systemPrompt != null ? '$systemPrompt\n\n$prompt' : prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final duration = DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        final tokens = data['usageMetadata']?['totalTokenCount'] ?? 0;

        return AIResponse(
          text: text,
          modelId: modelId,
          tokensUsed: tokens,
          duration: duration,
          success: true,
        );
      } else {
        return AIResponse(
          text: '',
          modelId: modelId,
          tokensUsed: 0,
          duration: duration,
          success: false,
          error: 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AIResponse(
        text: '',
        modelId: modelId,
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey')
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// HUGGING FACE
// ═══════════════════════════════════════════════════════════

class HuggingFaceProvider extends AIProvider {
  HuggingFaceProvider({required String apiKey})
      : super(name: 'Hugging Face', apiKey: apiKey);

  @override
  Future<AIResponse> generate({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1000,
    double temperature = 0.7,
  }) async {
    final startTime = DateTime.now();

    try {
      final url = Uri.parse('https://api-inference.huggingface.co/models/$modelId');

      final body = {
        'inputs': systemPrompt != null ? '$systemPrompt\n\n$prompt' : prompt,
        'parameters': {
          'max_new_tokens': maxTokens,
          'temperature': temperature,
          'return_full_text': false,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final duration = DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = '';
        
        if (data is List && data.isNotEmpty) {
          text = data[0]['generated_text'] ?? '';
        } else if (data is Map) {
          text = data['generated_text'] ?? data.toString();
        }

        return AIResponse(
          text: text,
          modelId: modelId,
          tokensUsed: text.length ~/ 4, // Estimación
          duration: duration,
          success: true,
        );
      } else {
        return AIResponse(
          text: '',
          modelId: modelId,
          tokensUsed: 0,
          duration: duration,
          success: false,
          error: 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AIResponse(
        text: '',
        modelId: modelId,
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://huggingface.co/api/whoami-v2'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// OPENAI (GPT)
// ═══════════════════════════════════════════════════════════

class OpenAIProvider extends AIProvider {
  OpenAIProvider({required String apiKey})
      : super(name: 'OpenAI', apiKey: apiKey);

  @override
  Future<AIResponse> generate({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1000,
    double temperature = 0.7,
  }) async {
    final startTime = DateTime.now();

    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');

      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final body = {
        'model': modelId,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final duration = DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'] ?? '';
        final tokens = data['usage']?['total_tokens'] ?? 0;

        return AIResponse(
          text: text,
          modelId: modelId,
          tokensUsed: tokens,
          duration: duration,
          success: true,
        );
      } else {
        return AIResponse(
          text: '',
          modelId: modelId,
          tokensUsed: 0,
          duration: duration,
          success: false,
          error: 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AIResponse(
        text: '',
        modelId: modelId,
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// GROQ (Ultra rápido - Llama, Mixtral)
// ═══════════════════════════════════════════════════════════

class GroqProvider extends AIProvider {
  GroqProvider({required String apiKey})
      : super(name: 'Groq', apiKey: apiKey);

  @override
  Future<AIResponse> generate({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1000,
    double temperature = 0.7,
  }) async {
    final startTime = DateTime.now();

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final body = {
        'model': modelId,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final duration = DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'] ?? '';
        final tokens = data['usage']?['total_tokens'] ?? 0;

        return AIResponse(
          text: text,
          modelId: modelId,
          tokensUsed: tokens,
          duration: duration,
          success: true,
        );
      } else {
        return AIResponse(
          text: '',
          modelId: modelId,
          tokensUsed: 0,
          duration: duration,
          success: false,
          error: 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AIResponse(
        text: '',
        modelId: modelId,
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// GESTOR PRINCIPAL DE IA (SINGLETON)
// ═══════════════════════════════════════════════════════════

class AIManager {
  AIManager._privateConstructor();
  static final AIManager instance = AIManager._privateConstructor();

  // ═══ APIs CONFIGURADAS (REEMPLAZA CON LAS TUYAS) ═══
  static const String GEMINI_API_KEY = 'TU_GEMINI_API_KEY_AQUI';
  static const String HUGGINGFACE_API_KEY = 'TU_HF_API_KEY_AQUI';
  static const String OPENAI_API_KEY = 'TU_OPENAI_API_KEY_AQUI';
  static const String GROQ_API_KEY = 'TU_GROQ_API_KEY_AQUI';

  // ═══ PROVEEDORES REGISTRADOS ═══
  late final Map<String, AIProvider> _providers = {
    'gemini': GeminiProvider(apiKey: GEMINI_API_KEY),
    'huggingface': HuggingFaceProvider(apiKey: HUGGINGFACE_API_KEY),
    'openai': OpenAIProvider(apiKey: OPENAI_API_KEY),
    'groq': GroqProvider(apiKey: GROQ_API_KEY),
  };

  // ═══ CATÁLOGO DE MODELOS DISPONIBLES ═══
  final List<AIModel> _availableModels = [
    // ─── GOOGLE GEMINI ───
    AIModel(
      id: 'gemini-2.0-flash-exp',
      name: 'Gemini 2.0 Flash',
      provider: 'gemini',
      category: AICategory.general,
      description: 'Modelo rápido y eficiente para tareas generales. Excelente para chat y resúmenes.',
      version: '2.0',
      isFree: true,
      maxTokens: 8192,
      capabilities: ['Chat', 'Resúmenes', 'Traducción', 'Análisis'],
      icon: '⚡',
    ),
    AIModel(
      id: 'gemini-1.5-pro',
      name: 'Gemini 1.5 Pro',
      provider: 'gemini',
      category: AICategory.general,
      description: 'Modelo avanzado con ventana de contexto de 1M tokens. Ideal para documentos largos.',
      version: '1.5',
      isFree: true,
      maxTokens: 8192,
      capabilities: ['Documentos largos', 'Análisis profundo', 'Razonamiento'],
      icon: '🧠',
    ),
    AIModel(
      id: 'gemini-1.5-flash',
      name: 'Gemini 1.5 Flash',
      provider: 'gemini',
      category: AICategory.education,
      description: 'Rápido y económico. Perfecto para educación y tareas diarias.',
      version: '1.5',
      isFree: true,
      maxTokens: 8192,
      capabilities: ['Educación', 'Chat rápido', 'Boletas'],
      icon: '📚',
    ),

    // ─── HUGGING FACE ───
    AIModel(
      id: 'mistralai/Mistral-7B-Instruct-v0.3',
      name: 'Mistral 7B Instruct',
      provider: 'huggingface',
      category: AICategory.general,
      description: 'Modelo open-source potente. Ideal para instrucciones y chat.',
      version: '7B',
      isFree: true,
      maxTokens: 2048,
      capabilities: ['Chat', 'Instrucciones', 'Código'],
      icon: '🌬️',
    ),
    AIModel(
      id: 'meta-llama/Llama-3.1-8B-Instruct',
      name: 'Llama 3.1 8B',
      provider: 'huggingface',
      category: AICategory.general,
      description: 'Modelo de Meta, excelente para razonamiento y tareas complejas.',
      version: '3.1',
      isFree: true,
      maxTokens: 2048,
      capabilities: ['Razonamiento', 'Análisis', 'Multilingüe'],
      icon: '🦙',
    ),
    AIModel(
      id: 'HuggingFaceH4/zephyr-7b-beta',
      name: 'Zephyr 7B',
      provider: 'huggingface',
      category: AICategory.education,
      description: 'Modelo fine-tuneado para chat educativo y asistencias.',
      version: '7B',
      isFree: true,
      maxTokens: 2048,
      capabilities: ['Educación', 'Chat', 'Tutoría'],
      icon: '🎓',
    ),
    AIModel(
      id: 'microsoft/BiomedNLP-BiomedBERT-base-uncased-abstract',
      name: 'BioMedBERT',
      provider: 'huggingface',
      category: AICategory.health,
      description: 'Modelo especializado en lenguaje biomédico y salud.',
      version: 'Base',
      isFree: true,
      maxTokens: 512,
      capabilities: ['Salud', 'Diagnósticos', 'Documentos médicos'],
      icon: '🏥',
    ),
    AIModel(
      id: 'impira/layoutlm-document-qa',
      name: 'LayoutLM Document QA',
      provider: 'huggingface',
      category: AICategory.documents,
      description: 'Extrae información de documentos escaneados (actas, CURP, certificados).',
      version: 'v1',
      isFree: true,
      maxTokens: 512,
      capabilities: ['OCR', 'Documentos', 'Extracción'],
      icon: '📄',
    ),

    // ─── OPENAI ───
    AIModel(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      provider: 'openai',
      category: AICategory.general,
      description: 'Versión económica de GPT-4. Rápido y capaz.',
      version: '4o-mini',
      isFree: false,
      maxTokens: 4096,
      capabilities: ['Chat', 'Análisis', 'Código'],
      icon: '💎',
    ),
    AIModel(
      id: 'gpt-4o',
      name: 'GPT-4o',
      provider: 'openai',
      category: AICategory.general,
      description: 'Modelo más avanzado de OpenAI. Multimodal y potente.',
      version: '4o',
      isFree: false,
      maxTokens: 4096,
      capabilities: ['Multimodal', 'Razonamiento', 'Premium'],
      icon: '👑',
    ),

    // ─── GROQ (Ultra rápido) ───
    AIModel(
      id: 'llama-3.3-70b-versatile',
      name: 'Llama 3.3 70B (Groq)',
      provider: 'groq',
      category: AICategory.general,
      description: 'Ultra rápido gracias a Groq. Ideal para respuestas instantáneas.',
      version: '3.3',
      isFree: true,
      maxTokens: 8192,
      capabilities: ['Ultra rápido', 'Chat', 'Análisis'],
      icon: '⚡',
    ),
    AIModel(
      id: 'mixtral-8x7b-32768',
      name: 'Mixtral 8x7B (Groq)',
      provider: 'groq',
      category: AICategory.education,
      description: 'Modelo Mixture of Experts. Excelente para educación.',
      version: '8x7B',
      isFree: true,
      maxTokens: 32768,
      capabilities: ['Educación', 'Ventana grande', 'Rápido'],
      icon: '🔥',
    ),
    AIModel(
      id: 'gemma2-9b-it',
      name: 'Gemma 2 9B (Groq)',
      provider: 'groq',
      category: AICategory.general,
      description: 'Modelo de Google optimizado para instrucciones.',
      version: '2',
      isFree: true,
      maxTokens: 8192,
      capabilities: ['Instrucciones', 'Chat', 'Rápido'],
      icon: '💎',
    ),
  ];

  // ═══ MODELO SELECCIONADO ACTUALMENTE ═══
  AIModel? _currentModel;
  AIModel? get currentModel => _currentModel;

  // ═══ INICIALIZACIÓN ═══
  Future<void> initialize() async {
    await _loadSelectedModel();
    debugPrint('✅ AIManager inicializado con ${_availableModels.length} modelos');
  }

  // ═══ LISTAR MODELOS ═══
  
  /// Obtiene todos los modelos disponibles
  List<AIModel> getAllModels() => List.unmodifiable(_availableModels);

  /// Obtiene modelos filtrados por categoría
  List<AIModel> getModelsByCategory(AICategory category) {
    return _availableModels.where((m) => m.category == category).toList();
  }

  /// Obtiene modelos filtrados por proveedor
  List<AIModel> getModelsByProvider(String provider) {
    return _availableModels.where((m) => m.provider == provider).toList();
  }

  /// Obtiene solo modelos gratuitos
  List<AIModel> getFreeModels() {
    return _availableModels.where((m) => m.isFree).toList();
  }

  /// Busca modelos por nombre o descripción
  List<AIModel> searchModels(String query) {
    final q = query.toLowerCase();
    return _availableModels.where((m) =>
      m.name.toLowerCase().contains(q) ||
      m.description.toLowerCase().contains(q) ||
      m.capabilities.any((c) => c.toLowerCase().contains(q))
    ).toList();
  }

  /// Obtiene modelos recomendados para un área específica
  List<AIModel> getRecommendedModels(String area) {
    final areaLower = area.toLowerCase();
    
    if (areaLower.contains('educación') || areaLower.contains('educacion')) {
      return getModelsByCategory(AICategory.education);
    } else if (areaLower.contains('salud')) {
      return getModelsByCategory(AICategory.health);
    } else {
      return getModelsByCategory(AICategory.general);
    }
  }

  // ═══ SELECCIÓN DE MODELO ═══
  
  /// Selecciona un modelo como el actual
  Future<void> selectModel(AIModel model) async {
    _currentModel = model;
    await _saveSelectedModel(model.id);
    debugPrint('✅ Modelo seleccionado: ${model.name}');
  }

  /// Selecciona modelo por ID
  Future<bool> selectModelById(String modelId) async {
    final model = _availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => _availableModels.first,
    );
    await selectModel(model);
    return true;
  }

  Future<void> _saveSelectedModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_ai_model', modelId);
  }

  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString('selected_ai_model');
    
    if (modelId != null) {
      _currentModel = _availableModels.firstWhere(
        (m) => m.id == modelId,
        orElse: () => _availableModels.first,
      );
    } else {
      _currentModel = _availableModels.first;
    }
  }

  // ═══ GENERACIÓN DE RESPUESTAS ═══
  
  /// Genera una respuesta usando el modelo actual
  Future<AIResponse> generate({
    required String prompt,
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
  }) async {
    if (_currentModel == null) {
      return AIResponse(
        text: '',
        modelId: '',
        tokensUsed: 0,
        duration: Duration.zero,
        success: false,
        error: 'No hay modelo seleccionado',
      );
    }

    final provider = _providers[_currentModel!.provider];
    if (provider == null) {
      return AIResponse(
        text: '',
        modelId: _currentModel!.id,
        tokensUsed: 0,
        duration: Duration.zero,
        success: false,
        error: 'Proveedor ${_currentModel!.provider} no disponible',
      );
    }

    return await provider.generate(
      modelId: _currentModel!.id,
      prompt: prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens ?? _currentModel!.maxTokens,
      temperature: temperature ?? 0.7,
    );
  }

  /// Genera usando un modelo específico (sin cambiar el actual)
  Future<AIResponse> generateWithModel({
    required String modelId,
    required String prompt,
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
  }) async {
    final model = _availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw Exception('Modelo $modelId no encontrado'),
    );

    final provider = _providers[model.provider];
    if (provider == null) {
      return AIResponse(
        text: '',
        modelId: modelId,
        tokensUsed: 0,
        duration: Duration.zero,
        success: false,
        error: 'Proveedor ${model.provider} no disponible',
      );
    }

    return await provider.generate(
      modelId: modelId,
      prompt: prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens ?? model.maxTokens,
      temperature: temperature ?? 0.7,
    );
  }

  // ═══ VERIFICACIÓN DE DISPONIBILIDAD ═══
  
  /// Verifica qué proveedores están disponibles
  Future<Map<String, bool>> checkProvidersAvailability() async {
    final results = <String, bool>{};
    
    for (final entry in _providers.entries) {
      results[entry.key] = await entry.value.isAvailable();
    }
    
    return results;
  }

  // ═══ PROMPTS PREDEFINIDOS POR ÁREA ═══
  
  String getEducationPrompt(String context) {
    return '''
Eres un asistente educativo experto de Portal Pilot. Tu función es ayudar a profesores y administradores escolares.

Contexto: $context

Responde de forma clara, profesional y útil. Si te preguntan sobre calificaciones, asistencia o matrículas, proporciona información precisa basada en los datos proporcionados.
''';
  }

  String getHealthPrompt(String context) {
    return '''
Eres un asistente médico de Portal Pilot. Tu función es ayudar a profesionales de la salud con gestión de pacientes y documentación.

⚠️ IMPORTANTE: No proporciones diagnósticos médicos definitivos. Solo ayuda con gestión administrativa y documentación.

Contexto: $context
''';
  }

  String getDocumentExtractionPrompt() {
    return '''
Eres un experto en extracción de datos de documentos oficiales mexicanos.
Extrae la siguiente información del documento proporcionado:
- Nombre completo
- Fecha de nacimiento (formato DD/MM/AAAA)
- CURP
- Lugar de nacimiento
- Género

Si algún dato no está presente, indica "No disponible".
Responde en formato JSON.
''';
  }
}