import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  bool _isModelLoaded = false;
  double _downloadProgress = 0.0;
  String _status = 'Inicializando...';

  bool get isModelLoaded => _isModelLoaded;
  double get downloadProgress => _downloadProgress;
  String get status => _status;

  Future<void> initializeModel() async {
    _status = 'Inicializando IA local...';
    await Future.delayed(const Duration(seconds: 1));
    _isModelLoaded = true;
    _status = 'IA lista (Gemma 3N simulada)';
  }

  Future<bool> isModelAvailable() async => true;

  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    onStatus('Modelo listo para usar (modo demo)');
    onProgress(1.0);
    _isModelLoaded = true;
  }

  Future<String> generateResponse({
    required String userMessage,
    required List<ChatMessage> history,
    required Function(String thought) onThought,
    required Function(String action, Map<String, dynamic> params) onAction,
    required Function(String result) onResult,
  }) async {
    history.add(ChatMessage(role: 'user', content: userMessage));
    final intent = _analyzeIntent(userMessage);

    onThought('Analizando solicitud...');
    await Future.delayed(const Duration(milliseconds: 300));

    onThought('Identificando herramienta necesaria: ${intent.tool}');
    await Future.delayed(const Duration(milliseconds: 300));

    onAction(intent.tool, intent.params);

    final result = await _executeTool(intent.tool, intent.params);
    onResult(result);

    final response = _generateResponseFromResult(intent.tool, result);
    history.add(ChatMessage(role: 'assistant', content: response));

    return response;
  }

  Intent _analyzeIntent(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('hola') || lower.contains('buenos días')) {
      return Intent(tool: 'greeting', params: {});
    }

    if (lower.contains('archivo') &&
        (lower.contains('buscar') || lower.contains('encontrar'))) {
      return Intent(tool: 'search_files', params: {'query': message});
    }

    if (lower.contains('nota') && lower.contains('crear')) {
      return Intent(tool: 'write_note', params: {'content': message});
    }

    if (lower.contains('estado') ||
        lower.contains('información') ||
        lower.contains('sistema')) {
      return Intent(tool: 'system_info', params: {});
    }

    if (lower.contains('ayuda') || lower.contains('qué puedes hacer')) {
      return Intent(tool: 'help', params: {});
    }

    return Intent(tool: 'chat', params: {'message': message});
  }

  Future<String> _executeTool(String tool, Map<String, dynamic> params) async {
    switch (tool) {
      case 'greeting':
        return _getGreeting();
      case 'search_files':
        return await _searchFiles(params['query'] ?? '');
      case 'write_note':
        return await _writeNote(params['content'] ?? '');
      case 'system_info':
        return await _getSystemInfo();
      case 'help':
        return _getHelp();
      default:
        return _getDefaultResponse(params['message'] ?? '');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String saludo;
    if (hour < 12)
      saludo = 'Buenos días';
    else if (hour < 18)
      saludo = 'Buenas tardes';
    else
      saludo = 'Buenas noches';
    return '$saludo. Soy la IA de PortalPilot. ¿En qué puedo ayudarte?';
  }

  Future<String> _searchFiles(String query) async {
    try {
      final dir = Directory.current;
      final files = await dir.list().toList();
      final matches = files
          .where((f) => f.path.toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (matches.isEmpty) {
        return 'No se encontraron archivos coincidentes con "$query" en ${dir.path}';
      }

      return 'Encontrados ${matches.length} archivo(s):\n${matches.take(5).map((f) => '• ${f.path.split(Platform.pathSeparator).last}').join('\n')}';
    } catch (e) {
      return 'Error al buscar archivos: $e';
    }
  }

  Future<String> _writeNote(String content) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/nota_$timestamp.txt');
      await file.writeAsString(content);
      return 'Nota guardada en: ${file.path}';
    } catch (e) {
      return 'Error al guardar nota: $e';
    }
  }

  Future<String> _getSystemInfo() async {
    return '''
📊 INFORMACIÓN DEL SISTEMA
• OS: ${Platform.operatingSystem}
• Versión OS: ${Platform.operatingSystemVersion}
• Arquitectura: ${Platform.numberOfProcessors} núcleos
• Directorio actual: ${Directory.current.path}
''';
  }

  String _getHelp() {
    return '''
🤖 COMANDOS DISPONIBLES:

📁 ARCHIVOS:
• "Buscar archivo [nombre]" - Busca archivos en el sistema
• "Crear nota [texto]" - Guarda una nota

💻 SISTEMA:
• "Estado del sistema" - Muestra información del PC
• "Hola" / "Buenos días" - Saludo personalizado
• "Ayuda" - Muestra este mensaje

💬 CHAT:
• Cualquier otro mensaje - Conversación normal
''';
  }

  String _getDefaultResponse(String message) {
    return '''
Entendí tu mensaje: "$message"

Puedo ayudarte con:
• Búsqueda de archivos
• Creación de notas
• Información del sistema
• Saludos personalizados

¿Qué deseas hacer?
''';
  }

  String _generateResponseFromResult(String tool, String result) {
    switch (tool) {
      case 'greeting':
        return result;
      case 'search_files':
        return '🔍 Resultado de búsqueda:\n$result';
      case 'write_note':
        return '📝 $result';
      case 'system_info':
        return '💻 $result';
      case 'help':
        return result;
      default:
        return result;
    }
  }
}

class Intent {
  final String tool;
  final Map<String, dynamic> params;

  Intent({required this.tool, required this.params});
}
