import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class _SupportMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isError;
  _SupportMessage({required this.text, required this.isUser, this.isLoading = false, this.isError = false});
}

class SoporteHome extends StatefulWidget {
  const SoporteHome({super.key});

  @override
  State<SoporteHome> createState() => _SoporteHomeState();
}

class _SoporteHomeState extends State<SoporteHome> {
  final _queryController = TextEditingController();
  final List<_SupportMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isLoading) return;
    setState(() {
      _isLoading = true;
      _messages.add(_SupportMessage(text: query, isUser: true));
      _messages.add(_SupportMessage(text: 'Procesando...', isUser: false, isLoading: true));
      _queryController.clear();
    });
    try {
      final result = await AIManager.instance.supportAssist(query);
      if (mounted) {
        setState(() {
          _messages.removeLast();
          if (result.success) {
            _messages.add(_SupportMessage(text: result.text, isUser: false));
          } else {
            _messages.add(_SupportMessage(
              text: 'Error: ${result.error ?? "No se pudo procesar tu solicitud"}',
              isUser: false,
              isError: true,
            ));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(_SupportMessage(text: 'Error de conexión', isUser: false, isError: true));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF3B82F6), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Soporte IA',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF3B82F6),
              size: 20,
            ),
            onPressed: () async => await appThemeNotifier.toggle(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: LinearProgressIndicator(color: Color(0xFF3B82F6)),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final topics = [
      ('Configuración del sistema', Icons.settings_rounded, 'Ayuda con módulos y preferencias'),
      ('Problemas con facturación', Icons.receipt_rounded, 'Errores SAR, timbrado, formato'),
      ('Inventario y productos', Icons.inventory_2_rounded, 'Sincronización, códigos, stock'),
      ('POS y cobros', Icons.point_of_sale_rounded, 'Terminal, pagos, cierre de día'),
      ('Cuentas por cobrar', Icons.account_balance_wallet_rounded, 'Fiado, abonos, límites'),
      ('General', Icons.help_outline_rounded, 'Otras preguntas sobre Portal Pilot'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asistente de Soporte', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Resuelve tus dudas sobre Portal Pilot', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('¿En qué puedo ayudarte?', style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          ...topics.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                _queryController.text = 'Necesito ayuda con: ${t.$1}';
                _sendMessage();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(t.$2, color: const Color(0xFF3B82F6), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.$1, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          Text(t.$3, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(_SupportMessage msg) {
    if (msg.isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            Text(msg.text, style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 12)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser
              ? const Color(0xFF3B82F6)
              : (msg.isError
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(12),
          border: msg.isUser
              ? null
              : Border.all(
                  color: msg.isError
                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                      : const Color(0xFF262626),
                ),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: msg.isUser
                ? Colors.white
                : (msg.isError ? const Color(0xFFEF4444) : const Color(0xFFE5E5E5)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        border: Border(top: BorderSide(color: const Color(0xFF262626))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF262626)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF262626)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
