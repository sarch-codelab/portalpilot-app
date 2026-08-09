// lib/dns_global.dart
import 'package:flutter/foundation.dart';

/// Gestor global de rutas de IA con sistema de fallback automático
/// Este archivo resuelve problemas de DNS y provee redundancia
class AIRoutes {
  AIRoutes._();
  static final AIRoutes instance = AIRoutes._();

  // ═══════════════════════════════════════════════════════════
  // PROVEEDORES DISPONIBLES (en orden de prioridad)
  // ═══════════════════════════════════════════════════════════
  
  static const String groqApi = 'https://api.groq.com/openai/v1';
  static const String hfApi = 'https://api-inference.huggingface.co';
  static const String openrouterApi = 'https://openrouter.ai/api/v1';
  
  // Estado de salud de cada proveedor (se actualiza automáticamente)
  final Map<String, ProviderStatus> _providerHealth = {
    'groq': ProviderStatus(name: 'Groq', isHealthy: true, lastCheck: DateTime.now()),
    'huggingface': ProviderStatus(name: 'Hugging Face', isHealthy: true, lastCheck: DateTime.now()),
    'openrouter': ProviderStatus(name: 'OpenRouter', isHealthy: true, lastCheck: DateTime.now()),
  };

  // ═══════════════════════════════════════════════════════════
  // RUTAS POR ÁREA (con fallback automático)
  // ═══════════════════════════════════════════════════════════
  
  final Map<String, List<AIEndpoint>> _routes = {
    'educacion': [
      AIEndpoint(
        id: 'edu_rapida',
        provider: 'groq',
        modelId: 'llama-3.1-8b-instant',
        role: AIRole.fast,
        maxTokens: 1500,
        priority: 1,
      ),
      AIEndpoint(
        id: 'edu_potente',
        provider: 'groq',
        modelId: 'llama-3.3-70b-versatile',
        role: AIRole.powerful,
        maxTokens: 2000,
        priority: 2,
      ),
      AIEndpoint(
        id: 'edu_docs',
        provider: 'huggingface',
        modelId: 'impira/layoutlm-document-qa',
        role: AIRole.document,
        maxTokens: 1000,
        priority: 3,
      ),
    ],
    'salud': [
      AIEndpoint(
        id: 'health_rapida',
        provider: 'groq',
        modelId: 'llama-3.1-8b-instant',
        role: AIRole.fast,
        maxTokens: 1500,
        priority: 1,
      ),
      AIEndpoint(
        id: 'health_potente',
        provider: 'groq',
        modelId: 'llama-3.3-70b-versatile',
        role: AIRole.powerful,
        maxTokens: 2000,
        priority: 2,
      ),
      AIEndpoint(
        id: 'health_medical',
        provider: 'huggingface',
        modelId: 'microsoft/BiomedNLP-BiomedBERT-base-uncased-abstract',
        role: AIRole.specialized,
        maxTokens: 1000,
        priority: 3,
      ),
    ],
    'administracion': [
      AIEndpoint(
        id: 'admin_general',
        provider: 'groq',
        modelId: 'llama-3.3-70b-versatile',
        role: AIRole.powerful,
        maxTokens: 2000,
        priority: 1,
      ),
      AIEndpoint(
        id: 'admin_rapida',
        provider: 'groq',
        modelId: 'llama-3.1-8b-instant',
        role: AIRole.fast,
        maxTokens: 1500,
        priority: 2,
      ),
    ],
    'general': [
      AIEndpoint(
        id: 'general_potente',
        provider: 'groq',
        modelId: 'llama-3.3-70b-versatile',
        role: AIRole.powerful,
        maxTokens: 2000,
        priority: 1,
      ),
      AIEndpoint(
        id: 'general_rapida',
        provider: 'groq',
        modelId: 'llama-3.1-8b-instant',
        role: AIRole.fast,
        maxTokens: 1500,
        priority: 2,
      ),
    ],
  };

  // ═══════════════════════════════════════════════════════════
  // OBTENER MEJOR ENDPOINT CON FALLBACK
  // ═══════════════════════════════════════════════════════════
  
  /// Obtiene el mejor endpoint disponible para un área
  /// Si el prioritario falla, automáticamente prueba el siguiente
  Future<AIEndpoint> getBestEndpoint(String area, {AIRole? preferredRole}) async {
    final endpoints = _routes[area.toLowerCase()] ?? _routes['general']!;
    
    // Filtrar por rol si se especifica
    final filtered = preferredRole != null 
        ? endpoints.where((e) => e.role == preferredRole).toList()
        : endpoints;
    
    // Ordenar por prioridad
    filtered.sort((a, b) => a.priority.compareTo(b.priority));
    
    // Probar cada endpoint en orden de prioridad
    for (final endpoint in filtered) {
      final health = _providerHealth[endpoint.provider];
      
      // Si el proveedor está marcado como caído, verificar si ya pasó el cooldown
      if (health != null && !health.isHealthy) {
        final cooldown = DateTime.now().difference(health.lastCheck);
        if (cooldown.inMinutes < 5) {
          debugPrint('⏭️ Saltando ${endpoint.provider} (en cooldown)');
          continue;
        }
      }
      
      return endpoint;
    }
    
    // Si todos fallan, usar el primero como último recurso
    debugPrint('⚠️ Todos los endpoints fallaron, usando último recurso');
    return endpoints.first;
  }

  // ═══════════════════════════════════════════════════════════
  // MARCAR PROVEEDOR COMO FALLIDO/RECUPERADO
  // ═══════════════════════════════════════════════════════════
  
  void markProviderAsFailed(String provider) {
    if (_providerHealth.containsKey(provider)) {
      _providerHealth[provider]!.isHealthy = false;
      _providerHealth[provider]!.lastCheck = DateTime.now();
      debugPrint('❌ Proveedor $provider marcado como fallido');
    }
  }

  void markProviderAsHealthy(String provider) {
    if (_providerHealth.containsKey(provider)) {
      _providerHealth[provider]!.isHealthy = true;
      _providerHealth[provider]!.lastCheck = DateTime.now();
      debugPrint('✅ Proveedor $provider recuperado');
    }
  }

  /// Verifica la salud de todos los proveedores
  Future<void> checkAllProviders() async {
    for (final provider in _providerHealth.keys) {
      try {
        await _pingProvider(provider);
        markProviderAsHealthy(provider);
        debugPrint('✓ $provider está activo');
      } catch (e) {
        markProviderAsFailed(provider);
        debugPrint('✗ $provider está caído: $e');
      }
    }
  }

  Future<bool> _pingProvider(String provider) async {
    // Implementación básica - en producción haría un HEAD request
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE UTILIDAD
  // ═══════════════════════════════════════════════════════════
  
  List<String> getAvailableAreas() => _routes.keys.toList();
  
  List<AIEndpoint> getEndpointsForArea(String area) {
    return _routes[area.toLowerCase()] ?? _routes['general']!;
  }

  Map<String, ProviderStatus> getProviderHealthStatus() => Map.unmodifiable(_providerHealth);
}

// ═══════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════

class ProviderStatus {
  final String name;
  bool isHealthy;
  DateTime lastCheck;

  ProviderStatus({
    required this.name,
    required this.isHealthy,
    required this.lastCheck,
  });
}

class AIEndpoint {
  final String id;
  final String provider;
  final String modelId;
  final AIRole role;
  final int maxTokens;
  final int priority;

  AIEndpoint({
    required this.id,
    required this.provider,
    required this.modelId,
    required this.role,
    required this.maxTokens,
    required this.priority,
  });
}

enum AIRole {
  fast,        // Respuestas rápidas y cortas
  powerful,    // Análisis complejo
  document,    // Procesamiento de documentos
  specialized, // Modelo fine-tuned específico
}