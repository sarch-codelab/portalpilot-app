// lib/Modules/Educacion/ia/edu_ia.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Educacion/educacion_home.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Modules/Educacion/ia/reglas_ia.dart';
import 'package:portal_pilot_app/Modules/Educacion/ia/document_processor.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/system_context.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/rpa_executor.dart';
import 'package:share_plus/share_plus.dart';

// ═══════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════

class AttachedFile {
  final String name;
  final String path;
  final int size;
  final String type;

  AttachedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'doc':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'image':
        return const Color(0xFF10B981);
      case 'doc':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

class ChatMessage {
  final String sender;
  String text;
  final bool isMe;
  final String time;
  final List<AttachedFile> files;
  bool isStreaming;
  final Map<String, dynamic>? metadata; // ← NUEVO: metadata del mensaje

  ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
    required this.time,
    this.files = const [],
    this.isStreaming = false,
    this.metadata,
  });
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

class PromptSuggestion {
  final String icon;
  final String title;
  final String prompt;
  final Color color;
  final List<String> roles; // ← NUEVO: roles que pueden ver esta sugerencia

  const PromptSuggestion({
    required this.icon,
    required this.title,
    required this.prompt,
    required this.color,
    this.roles = const ['admin', 'profesor', 'secretaria'],
  });
}

// ═══════════════════════════════════════════════════════════
// EDU IA SCREEN CON CONTEXTO COMPLETO
// ═══════════════════════════════════════════════════════════

class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key});

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatSession> _sessions = [];
  String _currentSessionId = '';
  final List<AttachedFile> _pendingFiles = [];
  bool _isSidebarOpen = true;
  bool _isTyping = false;

  // ═══ DATOS DEL USUARIO ═══
  String _nombreUsuario = 'Usuario';
  String _rolUsuario = 'profesor';
  String _empresaCodigo = 'ROOT';
  bool _isUserLoaded = false;

  late AnimationController _typingController;
  late AnimationController _micController;

  // ═══ SUGERENCIAS FILTRADAS POR ROL ═══
  final List<PromptSuggestion> _allSuggestions = const [
    PromptSuggestion(
      icon: 'ðŸ“š',
      title: 'Resumen de matrículas',
      prompt: 'Genera un resumen de las matrículas registradas este mes',
      color: Color(0xFF8B5CF6),
      roles: ['admin', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ“Š',
      title: 'Reporte de asistencia',
      prompt: 'Muéstrame el reporte de asistencia de esta semana',
      color: Color(0xFF3B82F6),
      roles: ['admin', 'profesor'],
    ),
    PromptSuggestion(
      icon: 'ðŸ‘¨â€ðŸŽ“',
      title: 'Alumnos en riesgo',
      prompt: 'Identifica alumnos con promedio menor a 7 y sugiere acciones',
      color: Color(0xFFEF4444),
      roles: ['admin', 'profesor'],
    ),
    PromptSuggestion(
      icon: 'ðŸ“',
      title: 'Plan de clase',
      prompt: 'Ayúdame a crear un plan de clase de matemáticas para 5° grado',
      color: Color(0xFF10B981),
      roles: ['profesor'],
    ),
    PromptSuggestion(
      icon: 'ðŸ’°',
      title: 'Estado de pagos',
      prompt: '¿Cuál es el estado de los pagos de colegiaturas pendientes?',
      color: Color(0xFFF59E0B),
      roles: ['admin', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ“„',
      title: 'Generar constancia',
      prompt: 'Ayúdame a redactar una constancia de estudios para un alumno',
      color: Color(0xFF6366F1),
      roles: ['admin', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ–¥ï¸',
      title: 'Estado del sistema',
      prompt: '¿Cómo está mi equipo? Dame un resumen del estado de mi sistema',
      color: Color(0xFF06B6D4),
      roles: ['admin', 'profesor', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ”§',
      title: 'Ayuda técnica',
      prompt: 'Tengo problemas con mi equipo, ¿puedes ayudarme a diagnosticarlo?',
      color: Color(0xFFF97316),
      roles: ['admin', 'profesor', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ“',
      title: 'Organizar Descargas',
      prompt: 'Organiza mi carpeta de Descargas por tipo de archivo',
      color: Color(0xFF06B6D4),
      roles: ['admin', 'profesor', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ”',
      title: 'Buscar archivos',
      prompt: 'Busca todos los archivos PDF en mi carpeta de Documentos',
      color: Color(0xFF8B5CF6),
      roles: ['admin', 'profesor', 'secretaria'],
    ),
    PromptSuggestion(
      icon: 'ðŸ“Š',
      title: 'Crear reporte HTML',
      prompt: 'Crea un reporte HTML con los datos de mis alumnos matriculados',
      color: Color(0xFF10B981),
      roles: ['admin', 'secretaria'],
    ),
  ];

  List<PromptSuggestion> get _suggestions {
    return _allSuggestions.where((s) => s.roles.contains(_rolUsuario.toLowerCase())).toList();
  }

  @override
  void initState() {
    super.initState();
    _initSession();

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    _micController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Cargar datos del usuario y mostrar bienvenida
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    await AuthController.instance.restore();
    setState(() {
      _nombreUsuario = AuthController.instance.nombreCompleto;
      _rolUsuario = AuthController.instance.rol;
      _empresaCodigo = AuthController.instance.empresaCodigo;
      _isUserLoaded = true;
    });

    // Mostrar mensaje de bienvenida personalizado
    final bienvenida = EduIARules.mensajeBienvenida(_nombreUsuario, _rolUsuario);
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    setState(() {
      _currentSession.messages.add(ChatMessage(
        sender: EduIARules.nombre,
        text: bienvenida,
        isMe: false,
        time: time,
        metadata: {'type': 'welcome'},
      ));
    });
    
    _scrollToBottom();
  }

  void _initSession() {
    final initialSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Nueva conversación',
      createdAt: DateTime.now(),
      messages: [],
    );
    _sessions = [initialSession];
    _currentSessionId = initialSession.id;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingController.dispose();
    _micController.dispose();
    super.dispose();
  }

  ChatSession get _currentSession {
    if (_sessions.isEmpty) _initSession();
    return _sessions.firstWhere(
      (s) => s.id == _currentSessionId,
      orElse: () => _sessions.first,
    );
  }

  bool get _hasMessages => _currentSession.messages.isNotEmpty;

  ThemePalette _palette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ThemePalette(isDark: isDark);
  }

  Widget _buildAILogo({double size = 32}) {
    return ClipOval(
      child: Image.asset(
        'assets/img/robot_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth > 900;

    return Scaffold(
      backgroundColor: p.bgPrimary,
      appBar: AppBar(
        backgroundColor: p.bgSecondary,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        leading: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.accentPurple, size: 18),
              tooltip: 'Volver a Educación',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const EducacionScreen()),
                );
              },
            ),
            if (showSidebar)
              IconButton(
                icon: Icon(_isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded),
                color: p.accentPurple,
                onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
              ),
          ],
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAILogo(size: 28),
            const SizedBox(width: 10),
            Text(EduIARules.nombre,
                style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w900, color: p.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('v${EduIARules.version}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        actions: [
          // ═══ NUEVO: Indicador de rol ═══
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.accentPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRolIcon(), color: p.accentPurple, size: 14),
                const SizedBox(width: 4),
                Text(_rolUsuario.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.bold, color: p.accentPurple)),
              ],
            ),
          ),
          if (_hasMessages)
            IconButton(
              icon: Icon(Icons.ios_share_rounded, color: p.accentPurple),
              tooltip: 'Compartir chat',
              onPressed: _compartirChat,
            ),
          if (_hasMessages)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: p.errorRed),
              tooltip: 'Limpiar conversación',
              onPressed: _limpiarConversacion,
            ),
          IconButton(
            icon: Icon(appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            color: p.accentPurple,
            onPressed: () async {
              await appThemeNotifier.toggle();
              if (mounted) setState(() {});
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.accentPurple, width: 2),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: p.bgTertiary,
              child: Text(_getInicialesUsuario(), 
                  style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (showSidebar && _isSidebarOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 280,
              decoration: BoxDecoration(
                color: p.bgSecondary,
                border: Border(right: BorderSide(color: p.borderLight, width: 1)),
              ),
              child: _buildSidebar(p),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    p.accentPurple.withValues(alpha: p.isDark ? 0.05 : 0.08),
                    p.bgPrimary,
                  ],
                ),
              ),
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _hasMessages ? _buildChatView(p) : _buildWelcomeView(p),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MÉTODOS AUXILIARES
  // ═══════════════════════════════════════════════════════════

  IconData _getRolIcon() {
    switch (_rolUsuario.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'profesor':
        return Icons.school_rounded;
      case 'secretaria':
        return Icons.support_agent_rounded;
      case 'padre':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getInicialesUsuario() {
    final partes = _nombreUsuario.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return _nombreUsuario.substring(0, 2).toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════
  // PANTALLA DE BIENVENIDA
  // ═══════════════════════════════════════════════════════════

  Widget _buildWelcomeView(ThemePalette p) {
    if (!_isUserLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      key: const ValueKey('welcome'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAILogo(size: 80),
          const SizedBox(height: 24),
          Text('¡Hola, ${_nombreUsuario.split(' ')[0]}! ðŸ‘‹',
              style: GoogleFonts.syne(fontSize: 36, fontWeight: FontWeight.w900, color: p.textPrimary)),
          const SizedBox(height: 8),
          Text('Soy ${EduIARules.nombre}, tu asistente ${_rolUsuario.toLowerCase()}',
              style: GoogleFonts.dmSans(fontSize: 16, color: p.textMuted)),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿QUÉ TE GUSTARÍA HACER?',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: p.textDark,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _suggestions.map((s) => _buildSuggestionCard(s, p)).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildInputArea(p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(PromptSuggestion suggestion, ThemePalette p) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _messageController.text = suggestion.prompt;
          _focusNode.requestFocus();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: suggestion.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(suggestion.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 10),
              Text(suggestion.title,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary)),
              const SizedBox(height: 4),
              Text(suggestion.prompt,
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: p.textMuted,
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTA DE CHAT
  // ═══════════════════════════════════════════════════════════

  Widget _buildChatView(ThemePalette p) {
    return Column(
      key: const ValueKey('chat'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: p.bgSecondary.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: p.borderLight, width: 1)),
          ),
          child: Row(
            children: [
              _buildAILogo(size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentSession.title,
                        style: GoogleFonts.dmSans(
                            fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: p.successGreen.withValues(alpha: 0.6), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('En línea · $_nombreUsuario ($_rolUsuario)',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 11, color: p.successGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildModelButton(p),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: _currentSession.messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _currentSession.messages.length && _isTyping) {
                return _buildTypingIndicator(p);
              }
              return _buildChatMessage(_currentSession.messages[index], p);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildInputArea(p),
          ),
        ),
      ],
    );
  }

  Widget _buildModelButton(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.accentPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accentPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ðŸ¤–', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('Llama 3.3 70B',
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: p.accentPurple)),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemePalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingFiles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.borderLight),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pendingFiles.map((f) => _buildFileChip(f, p)).toList(),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: p.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                style: GoogleFonts.dmSans(color: p.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Pregúntame lo que necesites...',
                  hintStyle: GoogleFonts.dmSans(color: p.textDark, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: IconButton(
                    icon: Icon(Icons.attach_file_rounded, color: p.textMuted, size: 20),
                    tooltip: 'Adjuntar archivo',
                    onPressed: _adjuntarArchivo,
                  ),
                ),
                onSubmitted: (_) => _enviarMensaje(_messageController.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.borderLight, width: 1)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${EduIARules.nombre} puede cometer errores. Verifica información importante.',
                          style: GoogleFonts.dmSans(fontSize: 10, color: p.textDark, fontStyle: FontStyle.italic)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                        onPressed: () => _enviarMensaje(_messageController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileChip(AttachedFile file, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: file.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: file.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(file.icon, color: file.color, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(file.name,
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: p.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text(file.formattedSize, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: p.textMuted)),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _pendingFiles.remove(file)),
            child: Icon(Icons.close_rounded, color: p.textMuted, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage msg, ThemePalette p) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!msg.isMe) ...[
                  _buildAILogo(size: 26),
                  const SizedBox(width: 8),
                ],
                Text(msg.sender,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: msg.isMe ? p.accentPurple : p.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(color: p.textMuted, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(msg.time,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, color: p.textMuted, fontWeight: FontWeight.w500)),
                if (msg.isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accentPurple.withValues(alpha: 0.2),
                      border: Border.all(color: p.accentPurple.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                        child: Text(_getInicialesUsuario(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: msg.isMe ? p.accentPurple.withValues(alpha: 0.1) : p.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: msg.isMe ? p.accentPurple.withValues(alpha: 0.25) : p.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.files.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.files.map((f) => _buildFileDisplay(f, p)).toList(),
                    ),
                    if (msg.text.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (msg.text.isNotEmpty)
                    MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary, height: 1.55),
                        strong: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary, fontWeight: FontWeight.bold),
                        em: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary, fontStyle: FontStyle.italic),
                        listBullet: GoogleFonts.dmSans(fontSize: 14, color: p.textPrimary),
                        code: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: p.accentPurple,
                            backgroundColor: p.bgTertiary),
                        codeblockDecoration: BoxDecoration(
                          color: p.bgTertiary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.borderLight),
                        ),
                      ),
                      selectable: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMessageAction(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copiar mensaje',
                  onTap: () => _copiarMensaje(msg.text),
                  p: p,
                ),
                const SizedBox(width: 4),
                if (!msg.isMe && msg.metadata?['type'] != 'welcome') ...[
                  _buildMessageAction(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Regenerar respuesta',
                    onTap: () => _regenerarRespuesta(msg),
                    p: p,
                  ),
                  const SizedBox(width: 4),
                ],
                _buildMessageAction(
                  icon: Icons.thumb_up_outlined,
                  tooltip: 'Útil',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('ðŸ‘ Gracias por tu feedback'),
                        backgroundColor: p.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  p: p,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemePalette p,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: p.textMuted, size: 14),
        ),
      ),
    );
  }

  void _copiarMensaje(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('✓ Mensaje copiado'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _regenerarRespuesta(ChatMessage msg) {
    final index = _currentSession.messages.indexOf(msg);
    if (index > 0) {
      final userMsg = _currentSession.messages[index - 1];
      _currentSession.messages.removeAt(index);
      setState(() {});
      _enviarMensaje(userMsg.text, regenerate: true);
    }
  }

  Widget _buildFileDisplay(AttachedFile file, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: file.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: file.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(file.icon, color: file.color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(file.name,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: p.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(file.formattedSize, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: p.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemePalette p) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAILogo(size: 26),
                const SizedBox(width: 8),
                Text(EduIARules.nombre,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.textPrimary)),
                const SizedBox(width: 8),
                Text('escribiendo...',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, color: p.successGreen, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: p.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.borderLight),
              ),
              child: AnimatedBuilder(
                animation: _typingController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i * 0.25;
                      final progress = (_typingController.value + delay) % 1.0;
                      final bounce = (progress < 0.5) ? progress * 2 : 2 - (progress * 2);
                      final opacity = 0.3 + (0.7 * bounce);
                      final yOffset = -4 * bounce;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        child: Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.accentPurple.withValues(alpha: opacity),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: p.accentPurple.withValues(alpha: opacity * 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(ThemePalette p) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nuevoChat,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: p.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, color: p.accentPurple, size: 16),
                    const SizedBox(width: 8),
                    Text('Nuevo chat',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: p.textPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('RECIENTES',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.bold, color: p.textDark, letterSpacing: 1)),
              ),
              ..._sessions.map((s) => _buildSessionItem(s, p)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionItem(ChatSession session, ThemePalette p) {
    final isActive = session.id == _currentSessionId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentSessionId = session.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? p.accentPurple.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    color: isActive ? p.accentPurple : p.textMuted, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(session.title,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isActive ? p.textPrimary : p.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
                if (_sessions.length > 1)
                  InkWell(
                    onTap: () => _confirmarEliminarChat(session, p),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: p.textMuted, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarEliminarChat(ChatSession session, ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: p.errorRed),
            const SizedBox(width: 10),
            Text('Eliminar chat',
                style: GoogleFonts.dmSans(color: p.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Eliminar "${session.title}"?',
            style: GoogleFonts.dmSans(color: p.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: p.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sessions.remove(session);
                if (_currentSessionId == session.id) {
                  _currentSessionId = _sessions.first.id;
                }
              });
              Navigator.pop(context);
            },
            child: Text('Eliminar',
                style: GoogleFonts.dmSans(color: p.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _nuevoChat() {
    setState(() {
      _sessions.insert(0, ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Nueva conversación',
        createdAt: DateTime.now(),
        messages: [],
      ));
      _currentSessionId = _sessions.first.id;
    });
  }

  void _limpiarConversacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _palette(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: _palette(context).errorRed),
            const SizedBox(width: 10),
            Text('Limpiar conversación',
                style: GoogleFonts.dmSans(color: _palette(context).textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Borrar todos los mensajes?',
            style: GoogleFonts.dmSans(color: _palette(context).textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: _palette(context).textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentSession.messages.clear();
                _currentSession.title = 'Nueva conversación';
              });
              Navigator.pop(context);
              _cargarDatosUsuario(); // Recargar bienvenida
            },
            child: Text('Limpiar',
                style: GoogleFonts.dmSans(color: _palette(context).errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _compartirChat() {
    final buffer = StringBuffer();
    buffer.writeln('Chat de ${EduIARules.nombre} - ${_currentSession.title}');
    buffer.writeln('Usuario: $_nombreUsuario ($_rolUsuario)');
    buffer.writeln('Empresa: $_empresaCodigo');
    buffer.writeln('Fecha: ${DateTime.now().toString().substring(0, 10)}\n');
    buffer.writeln('─' * 40);

    for (final msg in _currentSession.messages) {
      buffer.writeln('\n[${msg.time}] ${msg.sender}:');
      buffer.writeln(msg.text);
    }

    Share.share(buffer.toString(), subject: 'Chat ${EduIARules.nombre}');
  }

  Future<void> _adjuntarArchivo() async {
    try {
      // File picker disabled on Windows desktop release. Attach files by drag/drop or paste instead.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Adjuntar archivos no está disponible en este modo de compilación.'),
      ));
      return;

      // final result = await FilePicker.platform.pickFiles(
      //   allowMultiple: true,
      //   type: FileType.custom,
      //   allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      // );
      //
      // if (result != null && result.files.isNotEmpty) {
      //   setState(() {
      //     for (final file in result.files) {
      //       final ext = file.name.split('.').last.toLowerCase();
      //       String type = 'other';
      //       if (ext == 'pdf') {
      //         type = 'pdf';
      //       } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      //         type = 'image';
      //       } else if (['doc', 'docx', 'txt'].contains(ext)) {
      //         type = 'doc';
      //       }
      //
      //       _pendingFiles.add(AttachedFile(
      //         name: file.name,
      //         path: file.path ?? '',
      //         size: file.size,
      //         type: type,
      //       ));
      //     }
      //   });
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _enviarMensaje(String texto, {bool regenerate = false}) {
    final text = texto.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;

    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (!regenerate && _currentSession.messages.isEmpty && text.isNotEmpty) {
        _currentSession.title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
      }

      if (!regenerate) {
        _currentSession.messages.add(ChatMessage(
          sender: _nombreUsuario,
          text: text,
          isMe: true,
          time: time,
          files: List.from(_pendingFiles),
        ));
      }

      _pendingFiles.clear();
      _messageController.clear();
    });

    _scrollToBottom();
    setState(() => _isTyping = true);

    _generarRespuestaReal(text).then((respuesta) async {
      if (!mounted) return;

      final now2 = DateTime.now();
      final time2 = '${now2.hour.toString().padLeft(2, '0')}:${now2.minute.toString().padLeft(2, '0')}';

      String textoFinal = respuesta;
      final rpaResults = await _tryExecuteRPAActions(respuesta);
      if (rpaResults.isNotEmpty) {
        textoFinal = '$respuesta\n\n$rpaResults';
      }

      setState(() {
        _isTyping = false;
        _currentSession.messages.add(ChatMessage(
          sender: EduIARules.nombre,
          text: textoFinal,
          isMe: false,
          time: time2,
        ));
      });
      _scrollToBottom();
    });
  }

  Future<String> _generarRespuestaReal(String pregunta) async {
  try {
    // ═══ 0. CONTEXTO DEL SISTEMA ═══
    String contextoSistema = '';
    try {
      contextoSistema = await SystemContext.instance.getFullContext();
    } catch (_) {}

    // ═══ 1. CONSULTAR BASE DE DATOS SI ES NECESARIO ═══
    String contextoDB = '';
    if (_debeConsultarDB(pregunta)) {
      contextoDB = await _consultarBaseDatos();
    }

    // ═══ 2. PROCESAR ARCHIVOS ADJUNTOS ═══
    String contextoArchivos = '';
    if (_pendingFiles.isNotEmpty) {
      contextoArchivos = await _procesarArchivosAdjuntos();
    }

    // ═══ 3. GENERAR CONTEXTO COMPLETO ═══
    final contextoCompleto = '''
$contextoSistema

$contextoDB

$contextoArchivos

**Información del usuario actual:**
- Nombre: $_nombreUsuario
- Rol: $_rolUsuario
- Empresa: $_empresaCodigo

**Instrucciones especiales:**
- Responde en español
- Usa markdown para formatear
- Si te preguntan sobre datos específicos, usa la información de la base de datos proporcionada
- Puedes usar la información del sistema para ayudar al usuario con su equipo
- Mantén respuestas concisas (máximo 500 palabras)

## CAPACIDADES DE GESTIÓN DE ARCHIVOS
Puedes ejecutar acciones RPA para gestionar archivos del usuario. Cuando te pidan:
- **Organizar carpeta**: Usa organize_folder con method "type", "date" o "name"
- **Crear carpetas**: Usa create_directory con name o path (absoluto o relativo)
- **Buscar archivos**: Usa search_files con path, extension, name_contains
- **Mover/Renombrar archivos**: Usa move_file o rename_file
- **Listar carpeta**: Usa list_directory para ver qué hay en una carpeta
- **Crear documentos**: Usa create_file, create_html, create_csv
- **Ver info del disco**: Usa get_disk_info

Las rutas absolutas como "C:\\Users\\Sami\\Downloads" se usan directamente.
Las rutas relativas se resuelven respecto a la carpeta Descargas.
Usa ~ para la carpeta del usuario: "~/Desktop" = "C:\\Users\\Sami\\Desktop"
''';

    // ═══ 4. GENERAR RESPUESTA CON IA ═══
    final response = await AIManager.instance.generate(
      prompt: pregunta,
      contextoAdicional: contextoCompleto,
    );

    if (response.success) {
      return response.text;
    } else {
      return '⚠ï¸ **Error al generar respuesta**\n\n${response.error}\n\nPor favor, intenta de nuevo.';
    }
  } catch (e) {
    return '⚠ï¸ **Error de conexión**\n\n$e\n\nVerifica tu conexión a internet.';
  }
}

  bool _debeConsultarDB(String pregunta) {
    final keywords = ['matrícula', 'matricula', 'alumno', 'estudiante', 'calificación', 'asistencia', 'pago'];
    return keywords.any((k) => pregunta.toLowerCase().contains(k));
  }

  Future<String> _tryExecuteRPAActions(String aiResponse) async {
    try {
      final jsonBlocks = RegExp(r'```json\s*([\s\S]*?)\s*```').allMatches(aiResponse);
      if (jsonBlocks.isEmpty) {
        final singleJson = RegExp(r'\{[\s\S]*"type"[\s\S]*\}').firstMatch(aiResponse);
        if (singleJson != null) {
          return _executeSingleOrMultiple(singleJson.group(0)!);
        }
        return '';
      }

      final results = StringBuffer();
      for (final block in jsonBlocks) {
        final jsonStr = block.group(1)!;
        final result = await _executeSingleOrMultiple(jsonStr);
        if (result.isNotEmpty) results.write(result);
      }
      return results.toString();
    } catch (_) {
      return '';
    }
  }

  Future<String> _executeSingleOrMultiple(String jsonStr) async {
    try {
      final parsed = jsonDecode(jsonStr);
      final results = StringBuffer();

      if (parsed is List) {
        for (final action in parsed) {
          if (action is Map<String, dynamic>) {
            final result = await RPAExecutor.instance.execute(action);
            results.writeln(result.success ? '✅ ${result.message}' : '❌ ${result.message}');
          }
        }
      } else if (parsed is Map<String, dynamic>) {
        final result = await RPAExecutor.instance.execute(parsed);
        results.writeln(result.success ? '✅ ${result.message}' : '❌ ${result.message}');
      }

      return results.toString();
    } catch (_) {
      return '';
    }
  }

  Future<String> _consultarBaseDatos() async {
  try {
    final matriculas = await PortalPilotDB.getMatriculasByEmpresa(_empresaCodigo);
    
    if (matriculas.isEmpty) {
      return '**Base de datos:** No hay matrículas registradas para tu empresa.';
    }

    final buffer = StringBuffer();
    buffer.writeln('## ðŸ“Š Base de Datos de Matrículas');
    buffer.writeln('**Empresa:** $_empresaCodigo');
    buffer.writeln('**Total de matrículas:** ${matriculas.length}\n');
    
    // ═══ PASAR LOS DATOS REALES DE CADA ALUMNO ═══
    buffer.writeln('### Lista de Alumnos:');
    for (var i = 0; i < matriculas.length; i++) {
      final m = matriculas[i];
      buffer.writeln('\n**Alumno ${i + 1}:**');
      buffer.writeln('- **Nombre:** ${m['alumno_nombre'] ?? 'N/A'} ${m['alumno_apellido'] ?? ''}');
      buffer.writeln('- **Folio:** ${m['folio_matricula'] ?? 'N/A'}');
      buffer.writeln('- **Nivel:** ${m['nivel_educativo'] ?? 'N/A'}');
      buffer.writeln('- **Grado:** ${m['grado'] ?? 'N/A'}');
      buffer.writeln('- **Sección:** ${m['seccion'] ?? 'N/A'}');
      buffer.writeln('- **Turno:** ${m['turno'] ?? 'N/A'}');
      buffer.writeln('- **Estado:** ${m['estado'] ?? 'N/A'}');
      buffer.writeln('- **Fecha Nacimiento:** ${m['alumno_fecha_nacimiento'] ?? 'N/A'}');
      buffer.writeln('- **Lugar Nacimiento:** ${m['alumno_lugar_nacimiento'] ?? 'N/A'}');
      buffer.writeln('- **Nacionalidad:** ${m['alumno_nacionalidad'] ?? 'N/A'}');
      buffer.writeln('- **Tutor:** ${m['tutor_nombre'] ?? 'N/A'} (${m['tutor_parentesco'] ?? 'N/A'})');
      buffer.writeln('- **Teléfono Tutor:** ${m['tutor_telefono'] ?? 'N/A'}');
      buffer.writeln('- **Email Tutor:** ${m['tutor_email'] ?? 'N/A'}');
      buffer.writeln('- **Dirección:** ${m['direccion_calle'] ?? 'N/A'}, ${m['direccion_municipio'] ?? ''}, ${m['direccion_departamento'] ?? ''}');
      buffer.writeln('- **Observaciones Salud:** ${m['observaciones_salud'] ?? 'Ninguna'}');
      buffer.writeln('- **Fecha Registro:** ${m['created_at'] ?? 'N/A'}');
    }
    
    // ═══ ESTADÍSTICAS ═══
    buffer.writeln('\n### ðŸ“ˆ Estadísticas:');
    buffer.writeln('- **Por nivel:** ${_contarPorCampo(matriculas, 'nivel_educativo')}');
    buffer.writeln('- **Por estado:** ${_contarPorCampo(matriculas, 'estado')}');
    buffer.writeln('- **Por turno:** ${_contarPorCampo(matriculas, 'turno')}');
    
    return buffer.toString();
  } catch (e) {
    return '**Base de datos:** Error al consultar: $e';
  }
}

String _contarPorCampo(List<Map<String, dynamic>> lista, String campo) {
  final conteo = <String, int>{};
  for (final item in lista) {
    final valor = item[campo]?.toString() ?? 'N/A';
    conteo[valor] = (conteo[valor] ?? 0) + 1;
  }
  return conteo.entries.map((e) => '${e.key}: ${e.value}').join(', ');
}

  Future<String> _procesarArchivosAdjuntos() async {
    final buffer = StringBuffer();
    buffer.writeln('**Archivos adjuntos para análisis:**\n');
    
    for (final file in _pendingFiles) {
      try {
        final contenido = await DocumentProcessor.instance.extractTextFromFile(file.path);
        buffer.writeln('ðŸ“„ ${file.name}:');
        buffer.writeln(contenido.substring(0, contenido.length > 500 ? 500 : contenido.length));
        buffer.writeln('---\n');
      } catch (e) {
        buffer.writeln('❌ Error al procesar ${file.name}: $e\n');
      }
    }
    
    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════
// THEME PALETTE
// ═══════════════════════════════════════════════════════════

class ThemePalette {
  final bool isDark;
  ThemePalette({required this.isDark});

  Color get bgPrimary => isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  Color get bgSecondary => isDark ? const Color(0xFF080808) : const Color(0xFFEDEDED);
  Color get bgTertiary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE5E5EA);
  Color get cardColor => isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textMuted => isDark ? const Color(0xFFA3A3A3) : const Color(0xFF64748B);
  Color get textDark => isDark ? const Color(0xFF525252) : const Color(0xFF94A3B8);
  Color get borderLight => isDark ? const Color(0x29FFFFFF) : const Color(0x1A000000);
  Color get successGreen => const Color(0xFF10B981);
  Color get errorRed => const Color(0xFFEF4444);
}