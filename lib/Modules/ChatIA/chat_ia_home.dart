import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';

// ────────────────────────────────────────────────────────────────
// Modelos locales
// ────────────────────────────────────────────────────────────────
class ChatIAMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isError;
  bool isStreaming;
  ChatIAMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
    this.isStreaming = false,
  });
}

class ChatConversation {
  final String id;
  String title;
  final DateTime createdAt;
  final List<ChatIAMessage> messages;
  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    List<ChatIAMessage>? messages,
  }) : messages = messages ?? [];
}

// ────────────────────────────────────────────────────────────────
// Chat IA – Módulo completo profesional
// ────────────────────────────────────────────────────────────────
class ChatIAHome extends StatefulWidget {
  const ChatIAHome({super.key});
  @override
  State<ChatIAHome> createState() => _ChatIAHomeState();
}

class _ChatIAHomeState extends State<ChatIAHome> with TickerProviderStateMixin {
  // Estado chat
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _focused = false;
  bool _sending = false;
  String? _errorBanner;

  // Conversaciones
  final List<ChatConversation> _conversations = [];
  late ChatConversation _current;

  // Animaciones header
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onTheme);
    _focusNode.addListener(_onFocus);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _current = ChatConversation(id: _id(), title: 'Nueva conversación', createdAt: DateTime.now());
    _conversations.add(_current);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _onTheme() { if (mounted) setState(() {}); }
  void _onFocus() { if (mounted) setState(() => _focused = _focusNode.hasFocus); }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onTheme);
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    _controller.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  void _newChat() {
    setState(() {
      _current = ChatConversation(id: _id(), title: 'Nueva conversación', createdAt: DateTime.now());
      _conversations.insert(0, _current);
      _errorBanner = null;
    });
    _scrollToBottom(animate: false);
  }

  void _switchConversation(ChatConversation c) {
    setState(() => _current = c);
    Navigator.maybePop(context);
    _scrollToBottom(animate: false);
  }

  void _clearCurrent() {
    setState(() => _current.messages.clear());
  }

  void _deleteConversation(ChatConversation c) {
    setState(() {
      _conversations.remove(c);
      if (_conversations.isEmpty) {
        _current = ChatConversation(id: _id(), title: 'Nueva conversación', createdAt: DateTime.now());
        _conversations.add(_current);
      } else if (_current.id == c.id) {
        _current = _conversations.first;
      }
    });
    Navigator.maybePop(context);
  }

  Future<void> _send([String? override]) async {
    final raw = (override ?? _controller.text).trim();
    if (raw.isEmpty || _sending) return;
    final userMsg = ChatIAMessage(id: _id(), text: raw, isUser: true, time: DateTime.now());
    setState(() {
      _current.messages.add(userMsg);
      if (_current.messages.length == 1 && _current.title == 'Nueva conversación') {
        _current.title = raw.length > 36 ? '${raw.substring(0, 36)}…' : raw;
      }
      _controller.clear();
      _sending = true;
      _errorBanner = null;
      _current.messages.add(ChatIAMessage(id: 'typing', text: 'Escribiendo…', isUser: false, time: DateTime.now(), isStreaming: true));
    });
    _scrollToBottom();

    try {
      // Contexto del sistema opcional para respuestas más ricas
      // Usamos el gateway central: AIManager.generate
      final ai = AIManager.instance;
      final res = await ai.generate(prompt: raw, maxTokens: 1600, temperature: 0.7);
      if (!mounted) return;
      setState(() {
        _current.messages.removeWhere((m) => m.id == 'typing');
        if (res.success) {
          _current.messages.add(ChatIAMessage(id: _id(), text: res.text, isUser: false, time: DateTime.now()));
        } else {
          _current.messages.add(ChatIAMessage(id: _id(), text: res.error ?? 'No pude responder. Intenta de nuevo.', isUser: false, time: DateTime.now(), isError: true));
          _errorBanner = res.error;
        }
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _current.messages.removeWhere((m) => m.id == 'typing');
        _current.messages.add(ChatIAMessage(id: _id(), text: 'Error de conexión: $e', isUser: false, time: DateTime.now(), isError: true));
        _sending = false;
        _errorBanner = e.toString();
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(pos, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      } else {
        _scrollCtrl.jumpTo(pos);
      }
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copiado al portapapeles', style: GoogleFonts.dmSans(fontSize: 12)),
      backgroundColor: const Color(0xFF1B1B1B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 1400),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.isDark;
    final palette = ThemePalette(isDark: isDark);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF0F0F5),
      drawer: isWide ? null : Drawer(child: _buildHistoryDrawer(palette)),
      appBar: _buildAppBar(palette),
      body: Stack(
        children: [
          // fondo radial sutil
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.9),
                    radius: 1.4,
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.08 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              if (isWide)
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF080808) : Colors.white,
                    border: Border(right: BorderSide(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB))),
                  ),
                  child: _buildHistoryDrawer(palette),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (_errorBanner != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFF7F1D1D).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorBanner!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white))),
                          IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16), onPressed: () => setState(() => _errorBanner = null)),
                        ]),
                      ),
                    Expanded(
                      child: _current.messages.isEmpty ? _buildEmptyState(palette, isDark) : _buildMessageList(palette, isDark),
                    ),
                    _buildInputArea(palette, isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemePalette p) {
    final isDark = p.isDark;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF080808) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(builder: (ctx) {
        final wide = MediaQuery.of(ctx).size.width >= 900;
        if (wide) {
          return IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF8B5CF6)),
            onPressed: () => Navigator.maybePop(context),
          );
        }
        return IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF8B5CF6)),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        );
      }),
      titleSpacing: 0,
      title: Row(
        children: [
          // avatar con pulso
          Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.5, end: 0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut)),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.8).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut)),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B5CF6).withValues(alpha: 0.25))),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 16)],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Chat IA', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('En línea', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                  ]),
                ),
              ]),
              Text('Groq • openai/gpt-oss-20b • Portal Pilot', style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
            ]),
          ),
        ],
      ),
      actions: [
        Tooltip(
          message: 'Nueva conversación',
          child: IconButton(
            icon: const Icon(Icons.add_comment_rounded, color: Color(0xFF8B5CF6), size: 20),
            onPressed: _newChat,
          ),
        ),
        Tooltip(
          message: 'Limpiar chat actual',
          child: IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF6B7280), size: 18),
            onPressed: _current.messages.isEmpty ? null : _clearCurrent,
          ),
        ),
        const SizedBox(width: 4),
        Container(width: 1, height: 22, color: p.borderLight),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFF8B5CF6), size: 18),
          onPressed: () => appThemeNotifier.toggle(),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _buildHistoryDrawer(ThemePalette p) {
    final isDark = p.isDark;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Text('Historial', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
              const Spacer(),
              Text('${_conversations.length}', style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _newChat,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text('Nuevo chat', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.borderLight),
          Expanded(
            child: _conversations.isEmpty
                ? Center(child: Text('Sin conversaciones', style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final c = _conversations[i];
                      final selected = c.id == _current.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _switchConversation(c),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF8B5CF6).withValues(alpha: 0.12) : (isDark ? const Color(0xFF111111) : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? const Color(0xFF8B5CF6).withValues(alpha: 0.35) : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB))),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: selected ? const Color(0xFF8B5CF6) : p.textMuted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: selected ? Colors.white : p.textMuted),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                                const SizedBox(height: 2),
                                Text('${c.messages.length} mensajes • ${_fmtTime(c.createdAt)}', style: GoogleFonts.dmSans(fontSize: 10.5, color: p.textMuted)),
                              ]),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_horiz_rounded, size: 16, color: p.textMuted),
                              onSelected: (v) { if (v == 'delete') _deleteConversation(c); },
                              itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text('Eliminar', style: GoogleFonts.dmSans(fontSize: 12)))],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          Divider(height: 1, color: p.borderLight),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(child: Text('Tus chats se guardan solo en este dispositivo.', style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted))),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}';
  }

  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState(ThemePalette p, bool isDark) {
    final suggestions = [
      _Suggestion(Icons.trending_up_rounded, 'Analiza mis ventas', 'Resumen del mes, ticket promedio y por canal', const Color(0xFF6366F1)),
      _Suggestion(Icons.auto_awesome_rounded, 'Crea una imagen', 'Genera visuales para tu negocio', const Color(0xFFEC4899)),
      _Suggestion(Icons.analytics_rounded, 'Resumen ejecutivo', 'Estado del sistema y KPIs', const Color(0xFF8B5CF6)),
      _Suggestion(Icons.help_center_rounded, 'Ayuda con el sistema', 'Cómo usar cada módulo', const Color(0xFF10B981)),
    ];
    final prompts = [
      'Analiza mis ventas del mes',
      'Crea una imagen de un producto premium',
      'Genera un resumen ejecutivo del dashboard',
      '¿Cómo registro una venta en el POS?',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Image.asset(
              'assets/img/robot_logo.png',
              width: 68,
              height: 68,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.blur_on_rounded, color: Colors.white, size: 32),
            ),
          const SizedBox(height: 18),
          Text('¿En qué puedo ayudarte hoy?', style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text('Pregunta, analiza, crea. Tu asistente conoce tu empresa, tus módulos y tu contexto.',
              textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted, height: 1.5)),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 560 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 92,
              ),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _send(prompts[i]),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: s.color.withValues(alpha: 0.22)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(s.icon, color: s.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(s.title, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 2),
                          Text(s.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted, height: 1.3)),
                        ]),
                      ),
                      const Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFFA3A3A3)),
                    ]),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _quickChip('📊 Estado del sistema', () => _send('Necesito saber cómo va el sistema')),
              _quickChip('💰 Gastos por categoría', () => _send('Muéstrame los gastos por categoría de este mes')),
              _quickChip('📦 Stock bajo', () => _send('¿Qué productos tienen stock bajo?')),
              _quickChip('🧾 Últimas facturas', () => _send('Muéstrame las últimas facturas')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white)),
      backgroundColor: const Color(0xFF1B1B1B),
      side: const BorderSide(color: Color(0xFF2A2A2A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }

  // ── Lista de mensajes ─────────────────────────────────────────
  Widget _buildMessageList(ThemePalette p, bool isDark) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: _current.messages.length,
      itemBuilder: (ctx, i) {
        final m = _current.messages[i];
        if (m.isStreaming) return _buildTypingBubble(p, isDark);
        return m.isUser ? _buildUserBubble(m, p, isDark) : _buildAssistantBubble(m, p, isDark);
      },
    );
  }

  Widget _buildUserBubble(ChatIAMessage m, ThemePalette p, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.25), blurRadius: 12)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(m.text, style: GoogleFonts.dmSans(fontSize: 13.5, color: Colors.white, height: 1.45)),
          const SizedBox(height: 6),
          Text(_fmtClock(m.time), style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white.withValues(alpha: 0.75))),
        ]),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatIAMessage m, ThemePalette p, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 32),
        decoration: BoxDecoration(
          color: m.isError ? const Color(0xFF7F1D1D).withValues(alpha: 0.14) : (isDark ? const Color(0xFF111111) : Colors.white),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
          border: Border.all(color: m.isError ? const Color(0xFFDC2626).withValues(alpha: 0.35) : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB))),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              Text('Portal Pilot IA', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: p.textMuted)),
              const Spacer(),
              Text(_fmtClock(m.time), style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: MarkdownBody(
              data: m.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white : Colors.black, height: 1.5),
                strong: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                em: GoogleFonts.dmSans(fontSize: 13.5, fontStyle: FontStyle.italic, color: isDark ? Colors.white : Colors.black),
                h1: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                h2: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                h3: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                blockquote: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted),
                blockquoteDecoration: BoxDecoration(color: p.textMuted.withValues(alpha: 0.06), border: Border(left: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), width: 3))),
                code: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFFA78BFA), backgroundColor: Colors.black.withValues(alpha: 0.35)),
                codeblockDecoration: BoxDecoration(color: const Color(0xFF0B0B0B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F1F1F))),
                listBullet: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white : Colors.black),
                tableHead: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                tableBody: GoogleFonts.dmSans(fontSize: 12, color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _bubbleAction(Icons.copy_rounded, 'Copiar', () => _copy(m.text)),
              _bubbleAction(Icons.share_rounded, 'Compartir', () => _copy(m.text)),
              _bubbleAction(Icons.refresh_rounded, 'Reintentar', () => _send(m.text)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubbleAction(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Icon(icon, size: 14, color: const Color(0xFFA3A3A3))),
      ),
    );
  }

  Widget _buildTypingBubble(ThemePalette p, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
          border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(0),
          const SizedBox(width: 4),
          _dot(1),
          const SizedBox(width: 4),
          _dot(2),
          const SizedBox(width: 10),
          Text('Pensando…', style: GoogleFonts.dmSans(fontSize: 12, color: p.textMuted, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = (_pulseCtrl.value + index * 0.22) % 1.0;
        final scale = 0.7 + 0.6 * (0.5 + 0.5 * (1 - (2 * t - 1).abs() * 2).clamp(0, 1));
        return Transform.scale(
          scale: scale,
          child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle)),
        );
      },
    );
  }

  String _fmtClock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ── Input premium (mismo lenguaje del diseño que aprobaste) ──
  Widget _buildInputArea(ThemePalette p, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080808) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGradientInput(p, isDark),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Expanded(child: Text('La IA puede cometer errores. Verifica información importante.', style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted))),
              Text('Portal Pilot • v2', style: GoogleFonts.dmSans(fontSize: 10, color: p.textMuted.withValues(alpha: 0.7))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientInput(ThemePalette p, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E7E7E), Color(0xFF363636), Color(0xFF363636), Color(0xFF363636), Color(0xFF363636)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFF000000).withValues(alpha: 0.55)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Imagina algo extraordinario… ✦',
                    hintStyle: GoogleFonts.dmSans(fontSize: 12.5, color: _focused ? const Color(0xFF3A3A3A) : const Color(0xFFF3F6FD)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _ChatToolBtn(icon: Icons.attach_file_rounded, tip: 'Adjuntar', onTap: _sending ? null : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adjuntos próximamente', style: GoogleFonts.dmSans(fontSize: 12)), backgroundColor: const Color(0xFF1B1B1B)))),
                        const SizedBox(width: 8),
                        _ChatToolBtn(icon: Icons.dashboard_customize_rounded, tip: 'Crear imagen', onTap: _sending ? null : () => _send('Crea una imagen de un producto premium para catálogo')),
                        const SizedBox(width: 8),
                        _ChatToolBtn(icon: Icons.public_rounded, tip: 'Analizar', onTap: _sending ? null : () => _send('Analiza mis métricas de hoy')),
                      ]),
                      _ChatSendBtn(loading: _sending, onTap: _sending ? null : () => _send()),
                    ],
                  ),
                ),
              ]),
            ),
            Positioned(
              top: -10,
              left: -8,
              child: IgnorePointer(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Colors.white, Color(0x4DFFFFFF), Color(0x1AFFFFFF), Colors.transparent],
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ),
                    boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  _Suggestion(this.icon, this.title, this.subtitle, this.color);
}

class _ChatToolBtn extends StatefulWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  const _ChatToolBtn({required this.icon, required this.tip, this.onTap});
  @override
  State<_ChatToolBtn> createState() => _ChatToolBtnState();
}

class _ChatToolBtnState extends State<_ChatToolBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        child: Tooltip(
          message: widget.tip,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(widget.icon, size: 20, color: enabled ? (_hover ? Colors.white : Colors.white.withValues(alpha: 0.15)) : Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatSendBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _ChatSendBtn({required this.loading, this.onTap});
  @override
  State<_ChatSendBtn> createState() => _ChatSendBtnState();
}

class _ChatSendBtnState extends State<_ChatSendBtn> {
  bool _hover = false;
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF292929), Color(0xFF555555), Color(0xFF292929)]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _hover ? Colors.white.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12), blurRadius: _hover ? 8 : 3, offset: const Offset(0, -1))],
          ),
          child: Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: widget.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF3F6FD)))
                : AnimatedRotation(
                    turns: _down ? 0.125 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: AnimatedScale(
                      scale: _down ? 1.2 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: Transform.translate(
                        offset: Offset(_down ? -2 : 0, _down ? 1 : 0),
                        child: Icon(Icons.send_rounded, size: 20, color: _hover || _down ? const Color(0xFFF3F6FD) : const Color(0xFF8B8B8B)),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
