import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _chatController = TextEditingController();
  final List<ChatBubble> _messages = [];
  bool _isProcessing = false;
  bool _isModelReady = false;
  double _downloadProgress = 0.0;
  String _aiStatus = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    setState(() {
      _aiStatus = 'Verificando modelo...';
    });

    final isAvailable = await _aiService.isModelAvailable();

    if (!isAvailable) {
      setState(() {
        _aiStatus = 'Modelo no encontrado. Descargando...';
      });

      try {
        await _aiService.downloadModel(
          onProgress: (progress) {
            setState(() {
              _downloadProgress = progress;
              _aiStatus =
                  'Descargando modelo: ${(progress * 100).toStringAsFixed(0)}%';
            });
          },
          onStatus: (status) {
            setState(() {
              _aiStatus = status;
            });
          },
        );
      } catch (e) {
        setState(() {
          _aiStatus = 'Error: $e. Usando modo demo.';
        });
      }
    }

    await _aiService.initializeModel();

    setState(() {
      _isModelReady = true;
      _aiStatus = 'IA lista (Gemma 3N)';
    });

    // Mensaje de bienvenida
    _addMessage(ChatBubble(
      content: '''
¡Hola! Soy la IA de PortalPilot + Cyberyx.

Puedo ayudarte con:
• 📁 Buscar archivos
• 📄 Leer documentos
• 📝 Escribir notas
• 💻 Información del sistema
• 🌐 Buscar en internet (simulado)

¿En qué puedo ayudarte hoy?
''',
      isUser: false,
      type: 'success',
    ));
  }

  void _addMessage(ChatBubble message) {
    setState(() {
      _messages.add(message);
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _chatController.clear();

    // Agregar mensaje del usuario
    _addMessage(ChatBubble(
      content: text,
      isUser: true,
      type: 'user',
    ));

    setState(() {
      _isProcessing = true;
    });

    // Agregar mensaje de "pensando"
    final thinkingId = DateTime.now().millisecondsSinceEpoch.toString();
    _addMessage(ChatBubble(
      content: '🤔 Pensando...',
      isUser: false,
      type: 'thinking',
      id: thinkingId,
    ));

    try {
      final response = await _aiService.generateResponse(
        userMessage: text,
        history: [],
        onThought: (thought) {
          // Actualizar el mensaje de pensamiento
          setState(() {
            final index = _messages.indexWhere((m) => m.id == thinkingId);
            if (index != -1) {
              _messages[index] = ChatBubble(
                content: '🤔 $thought',
                isUser: false,
                type: 'reasoning',
                id: thinkingId,
              );
            }
          });
        },
        onAction: (action, params) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == thinkingId);
            if (index != -1) {
              _messages[index] = ChatBubble(
                content:
                    '🛠️ $action: ${params.isNotEmpty ? params.toString() : ''}',
                isUser: false,
                type: 'action',
                id: thinkingId,
              );
            }
          });
        },
        onResult: (result) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == thinkingId);
            if (index != -1) {
              _messages[index] = ChatBubble(
                content: result,
                isUser: false,
                type: 'success',
                id: thinkingId,
              );
            }
          });
        },
      );

      // Si por alguna razón no se actualizó, agregamos la respuesta
      final exists =
          _messages.any((m) => m.id == thinkingId && m.content != response);
      if (!exists) {
        _addMessage(ChatBubble(
          content: response,
          isUser: false,
          type: 'success',
        ));
      }
    } catch (e) {
      _addMessage(ChatBubble(
        content: '❌ Error: $e',
        isUser: false,
        type: 'error',
      ));
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado de IA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isModelReady ? Icons.check_circle : Icons.downloading,
                  color: _isModelReady
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _aiStatus,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_downloadProgress > 0 && _downloadProgress < 1)
                  SizedBox(
                    width: 50,
                    child: LinearProgressIndicator(value: _downloadProgress),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chat principal
          Container(
            height: 500,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                // Header del chat
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat,
                          size: 18, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      const Text(
                        'TACTICAL AGENT LOG',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isModelReady
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isModelReady ? 'AI ACTIVE' : 'INITIALIZING',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _isModelReady
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de mensajes
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _getIconForType(msg.type),
                                const SizedBox(width: 8),
                                Text(
                                  _getLabelForType(msg.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _getColorForType(msg.type),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _getTime(),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white38),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? const Color(0xFF0EA5E9).withOpacity(0.1)
                                    : const Color(0xFF0A0E17),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                msg.content,
                                style:
                                    const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Ask the AI to do anything...',
                            hintStyle:
                                TextStyle(fontSize: 13, color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isProcessing,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('EXECUTE',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type) {
      case 'user':
        return const Icon(Icons.person, size: 14, color: Colors.white70);
      case 'reasoning':
        return const Text('🤔', style: TextStyle(fontSize: 14));
      case 'action':
        return const Text('🛠️', style: TextStyle(fontSize: 14));
      case 'success':
        return const Text('✅', style: TextStyle(fontSize: 14));
      case 'error':
        return const Text('❌', style: TextStyle(fontSize: 14));
      case 'thinking':
        return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2));
      default:
        return const Icon(Icons.chat, size: 14, color: Color(0xFF0EA5E9));
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case 'user':
        return 'USUARIO';
      case 'reasoning':
        return 'RAZONAMIENTO';
      case 'action':
        return 'ACCIÓN';
      case 'success':
        return 'ÉXITO';
      case 'error':
        return 'ERROR';
      default:
        return 'SISTEMA';
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'reasoning':
        return Colors.white70;
      case 'action':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF10B981);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  String _getTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}

class ChatBubble {
  final String id;
  final String content;
  final bool isUser;
  final String type;

  ChatBubble({
    String? id,
    required this.content,
    required this.isUser,
    required this.type,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}
