import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _addMessage('Bienvenido a PortalPilot + Cyberyx Vantage', 'system');
    _addMessage(
        'Soy tu asistente IA. ¿En qué puedo ayudarte hoy?', 'assistant');
  }

  void _addMessage(String content, String type) {
    setState(() {
      _messages.add({
        'content': content,
        'type': type,
        'time': DateTime.now().toString().substring(11, 16),
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _chatController.clear();
    _addMessage(text, 'user');

    setState(() => _isProcessing = true);

    // Simular respuesta de IA
    await Future.delayed(const Duration(seconds: 1));

    String response;
    if (text.toLowerCase().contains('hola')) {
      response = '¡Hola! ¿Cómo puedo ayudarte?';
    } else if (text.toLowerCase().contains('ayuda')) {
      response =
          'Puedo ayudarte con: automatización de tareas, auditoría de seguridad, gestión de archivos y más.';
    } else if (text.toLowerCase().contains('auditoría')) {
      response =
          'La cadena de auditoría está intacta. Todos los hashes son válidos.';
    } else {
      response = 'He recibido tu mensaje: "$text". Procesando solicitud...';
    }

    _addMessage(response, 'assistant');
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Tarjetas de métricas
          Row(
            children: [
              _buildMetricCard(
                  'IA Status', 'Gemma 3N', 'Activo', const Color(0xFF10B981)),
              _buildMetricCard('Auditoría', 'Chain Valid',
                  'Último hash: 0x7D4...F3A', const Color(0xFF0EA5E9)),
              _buildMetricCard(
                  'Tareas', '12', 'Completadas hoy', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 24),

          // Chat
          Container(
            height: 450,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat,
                          size: 20, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      const Text('Asistente IA',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        'CONECTADO',
                        style: TextStyle(
                            fontSize: 10, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['type'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF0EA5E9)
                                : const Color(0xFF0A0E17),
                            borderRadius: BorderRadius.circular(12),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: Colors.white.withOpacity(0.05)),
                          ),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['content'],
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['time'],
                                style: TextStyle(
                                  fontSize: 9,
                                  color:
                                      isUser ? Colors.white70 : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Escribe tu mensaje...',
                            hintStyle:
                                TextStyle(fontSize: 13, color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isProcessing ? null : _sendMessage,
                        icon: const Icon(Icons.send, color: Color(0xFF0EA5E9)),
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

  Widget _buildMetricCard(
      String title, String value, String subtitle, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
