import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatLog extends StatelessWidget {
  final List<ChatMessage> messages;

  const ChatLog({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E17),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_alt,
                    size: 18, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                Text(
                  'TACTICAL AGENT LOG',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'REASONING ENGINE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            msg.type == ChatMessageType.reasoning
                                ? '🤔'
                                : msg.type == ChatMessageType.action
                                    ? '🛠️'
                                    : msg.type == ChatMessageType.success
                                        ? '✅'
                                        : '📸',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            msg.typeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getTypeColor(msg.type),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            msg.time,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg.content,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask the AI to do anything...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'EXECUTE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(ChatMessageType type) {
    switch (type) {
      case ChatMessageType.reasoning:
        return Colors.white.withOpacity(0.5);
      case ChatMessageType.action:
        return const Color(0xFFF59E0B);
      case ChatMessageType.success:
        return const Color(0xFF10B981);
      case ChatMessageType.evidence:
        return const Color(0xFF0EA5E9);
    }
  }
}

enum ChatMessageType { reasoning, action, success, evidence }

class ChatMessage {
  final String content;
  final String time;
  final ChatMessageType type;
  final String typeLabel;

  ChatMessage({
    required this.content,
    required this.time,
    required this.type,
  }) : typeLabel = type == ChatMessageType.reasoning
            ? 'REASONING'
            : type == ChatMessageType.action
                ? 'ACTION'
                : type == ChatMessageType.success
                    ? 'SUCCESS'
                    : 'EVIDENCE';
}
