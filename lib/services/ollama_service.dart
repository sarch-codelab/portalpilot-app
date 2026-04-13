import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  static const String baseUrl = 'http://localhost:11434';
  static const String model = 'gemma3:1b';

  // Verificar si Ollama está corriendo
  Future<bool> isRunning() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tags'),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking Ollama: $e');
      return false;
    }
  }

  // Verificar si Gemma 3 está instalado
  Future<bool> isModelInstalled() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags'));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      final models = data['models'] as List;
      return models.any((m) => m['name'].toString().contains('gemma3'));
    } catch (e) {
      print('Error checking model: $e');
      return false;
    }
  }

  // Streaming (efecto "escribiendo")
  Stream<String> chatStream(String message) async* {
    try {
      final request = http.Client().send(
        http.Request('POST', Uri.parse('$baseUrl/api/generate'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'model': model,
            'prompt': message,
            'stream': true,
            'options': {
              'temperature': 0.7,
              'num_predict': 512,
            }
          }),
      );

      final streamedResponse = await request;
      final stream = streamedResponse.stream.transform(utf8.decoder);

      String buffer = '';
      await for (final chunk in stream) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (var i = 0; i < lines.length - 1; i++) {
          if (lines[i].trim().isNotEmpty) {
            try {
              final data = jsonDecode(lines[i]);
              if (data['response'] != null &&
                  data['response'].toString().isNotEmpty) {
                yield data['response'];
              }
            } catch (e) {}
          }
        }
      }
    } catch (e) {
      print('Error in chatStream: $e');
      yield 'Error al conectar con Ollama. Asegúrate de que esté ejecutándose.';
    }
  }

  String getCurrentModel() => model;
}
