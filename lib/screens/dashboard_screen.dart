import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ollama_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final OllamaService _ollama = OllamaService();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _isProcessing = false;
  bool _isOllamaReady = false;
  String _userName = "JOSEPH";
  String _connectionStatus = "Verificando...";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkOllamaConnection();
    _addWelcomeMessage();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _userName = prefs.getString('userName')?.toUpperCase() ?? 'JOSEPH';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _checkOllamaConnection() async {
    setState(() {
      _connectionStatus = "Verificando conexión con Ollama...";
    });

    final isRunning = await _ollama.isRunning();

    if (!isRunning) {
      setState(() {
        _isOllamaReady = false;
        _connectionStatus = "❌ Ollama no está ejecutándose";
      });
      _addMessage(
          "⚠️ **Ollama no está ejecutándose**\n\nPor favor, abre una terminal y ejecuta:\n```\nollama serve\n```\n\nLuego vuelve a abrir PortalPilot.",
          false);
      return;
    }

    setState(() {
      _connectionStatus = "✅ Ollama conectado, verificando modelo...";
    });

    final isModelInstalled = await _ollama.isModelInstalled();

    if (!isModelInstalled) {
      setState(() {
        _isOllamaReady = false;
        _connectionStatus = "❌ Modelo Gemma 3 no encontrado";
      });
      _addMessage(
          "⚠️ **Modelo Gemma 3 no está instalado**\n\nEjecuta en terminal:\n```\nollama pull gemma3:1b\n```\n\n(Esto tomará unos minutos la primera vez)",
          false);
      return;
    }

    setState(() {
      _isOllamaReady = true;
      _connectionStatus = "✅ Gemma 3 1B lista";
    });

    _addMessage(
        "✅ **Gemma 3 1B está lista**\n\nPuedes preguntarme cualquier cosa. ¡La IA funciona completamente offline y sin costos!",
        false);
  }

  void _addWelcomeMessage() {
    _addMessage("✨ ¡Hola $_userName! Bienvenido a PortalPilot.", false);
    _addMessage("Escribe 'Ayuda' para ver los comandos disponibles.", false);
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'time': _getCurrentTime(),
      });
    });
    _scrollToBottom();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _messageController.clear();
    _addMessage(text, true);
    setState(() => _isProcessing = true);

    try {
      final lower = text.toLowerCase();

      // Comandos especiales
      if (lower.contains('ayuda') || lower.contains('help')) {
        _addMessage(_getHelp(), false);
        setState(() => _isProcessing = false);
        return;
      }

      if (lower.contains('estado') || lower.contains('status')) {
        _addMessage(_getStatus(), false);
        setState(() => _isProcessing = false);
        return;
      }

      if (lower.contains('limpiar') || lower.contains('clear')) {
        setState(() {
          _messages.clear();
        });
        _addWelcomeMessage();
        setState(() => _isProcessing = false);
        return;
      }

      // Verificar si la IA está lista
      if (!_isOllamaReady) {
        _addMessage(
            "⚠️ **IA no disponible**\n\n$_connectionStatus\n\nEjecuta 'ollama serve' en una terminal y reinicia la app.",
            false);
        setState(() => _isProcessing = false);
        return;
      }

      // Usar IA real con streaming
      String fullResponse = '';
      bool firstChunk = true;

      await for (final chunk in _ollama.chatStream(text)) {
        fullResponse += chunk;
        if (firstChunk) {
          setState(() {
            _messages.add({
              'text': fullResponse,
              'isUser': false,
              'time': _getCurrentTime(),
            });
            firstChunk = false;
          });
        } else {
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.last['text'] = fullResponse;
            }
          });
        }
        _scrollToBottom();
      }

      if (fullResponse.isEmpty) {
        _addMessage(
            "No se pudo generar una respuesta. Intenta de nuevo.", false);
      }
    } catch (e) {
      _addMessage(
          "❌ **Error:** $e\n\nVerifica que Ollama esté ejecutándose.", false);
    }

    setState(() => _isProcessing = false);
  }

  String _getHelp() {
    return '''
📋 **PortalPilot - Comandos disponibles**

🤖 **IA Gemma 3:**
• Cualquier pregunta será respondida por IA local

📊 **Sistema:**
• "Estado" - Ver estado del sistema
• "Ayuda" - Muestra este mensaje
• "Limpiar" - Limpia el chat

✨ **Gemma 3 1B** es un modelo de IA que corre localmente. Es gratuito, privado y no requiere internet.

💡 **Ejemplos:**
• "¿Qué es PortalPilot?"
• "Explícame qué es la IA local"
• "Cómo funciona Ollama"
''';
  }

  String _getStatus() {
    return '''
📊 **Estado de PortalPilot**

• 🤖 **IA**: ${_isOllamaReady ? 'Gemma 3 1B ✅' : 'No disponible'}
• 👤 **Usuario**: $_userName
• 💬 **Mensajes**: ${_messages.length}

${!_isOllamaReady ? '\n⚠️ Para usar la IA, ejecuta: ollama serve' : ''}

✨ **Todo listo para usar la IA local!**
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0B0F),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111827),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
                const SizedBox(width: 12),
                const Text(
                  'PortalPilot AI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOllamaReady
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOllamaReady ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOllamaReady ? 'GEMMA 3 ACTIVO' : 'IA OFFLINE',
                        style: TextStyle(
                          color: _isOllamaReady ? Colors.green : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF7C3AED).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111827),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Pregúntale a Gemma 3...",
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
