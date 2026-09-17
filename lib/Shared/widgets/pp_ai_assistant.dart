// lib/Shared/widgets/pp_ai_assistant.dart
// Asistente IA por módulo — Portal Pilot.
//
// Un bottom sheet estilo Sileo que lleva IA útil a TODOS los módulos con
// cero trabajo por módulo: PPModuleScaffold lo monta automáticamente y este
// archivo define las sugerencias por módulo y arma el contexto de negocio
// (productos, facturas, clientes locales) para que las respuestas sean
// accionables y no genéricas.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';

/// Sugerencias por módulo (moduleId → lista de preguntas útiles).
const Map<String, List<String>> _sugerenciasPorModulo = {
  'facturacion': [
    'Resumen de mis ventas de hoy',
    '¿Qué clientes me deben más?',
    '¿Cuáles son mis productos más vendidos?',
    'Redacta una nota de cobro amable',
  ],
  'inventario': [
    '¿Qué productos están en stock bajo?',
    '¿Qué me conviene reordenar hoy y cuánto?',
    'Detecta precios mal puestos en mi inventario',
    'Sugiere un código y precio para un producto nuevo',
  ],
  'pos': [
    '¿Qué producto ofrecer como complemento en el mostrador?',
    '¿Cómo manejo un ticket anulado sin perder el control?',
    '3 técnicas rápidas de upsell para el mostrador',
    'Resumen de lo vendido hoy en el POS',
  ],
  'contabilidad': [
    'Resumen de ingresos vs gastos de mi negocio',
    '¿Qué impuestos debo tener listos para declarar?',
    'Explica mis gastos del mes en palabras simples',
    '¿Cómo mejorar mi flujo de caja este mes?',
  ],
  'crm': [
    '¿A qué clientes no les he vendido este mes?',
    'Prioriza mis seguimientos de hoy',
    'Guion corto para reconectar un cliente dormido',
    'Redacta un mensaje de post-venta que fidelice',
  ],
  'comercial': [
    'Ideas de promoción para esta semana',
    '¿Qué zonas conviene reforzar y por qué?',
    'Plan de ruta de ventas para mañana',
    '¿Cómo negocio con un cliente que pide mucho descuento?',
  ],
  'cotizaciones': [
    'Redacta una cotización persuasiva',
    '¿Cómo doy seguimiento a cotizaciones viejas?',
    '¿Qué descuento es seguro ofrecer sin perder margen?',
    'Checklist antes de enviar una cotización',
  ],
  'compras_proveedores': [
    '¿Qué me conviene comprar hoy según el stock?',
    'Compara mis proveedores y sugiere ahorros',
    'Preguntas clave para negociar mejor precio',
    '¿Cómo evitar quedarme sin producto estrella?',
  ],
  'rrhh': [
    'Resumen de asistencia de mi equipo',
    'Redacta una amonestación en tono profesional',
    '¿Cómo calculo vacaciones y aguinaldo?',
    'Ideas para reducir la rotación de personal',
  ],
  'membresias': [
    '¿Qué membresías vencen pronto?',
    'Mensaje efectivo para renovar una membresía',
    'Ideas para reactivar socios inactivos',
    '¿Cómo estructuro un plan de referidos?',
  ],
  'canal_tradicional': [
    'Plan de visita de hoy tienda por tienda',
    '¿Qué llevarle a cada tienda según su historial?',
    '¿Cómo cobro cuentas vencidas sin perder al cliente?',
    'Ideas para rotar producto estancado en tiendas',
  ],
  'canal_moderno': [
    '¿Cómo entro a una cadena sin morir en el intento?',
    'Negociación de exhibición y surtido mínimo',
    '¿Qué categorías exigen las cadenas este año?',
    'Checklist para una junta con comprador',
  ],
  'analytics': [
    '¿Qué tendencia debo mirar esta semana?',
    'Explica mis KPIs en palabras simples',
    '¿Qué métrica está mal y cómo la arreglo?',
    'Proyección de cierre de mes si sigo así',
  ],
  'soporte': [
    'Redacta una respuesta clara a un ticket',
    'Checklist de diagnóstico rápido',
    '¿Cómo explico un error técnico sin tecnicismos?',
    'Prioriza tickets por impacto en el negocio',
  ],
};

/// Sugerencias genéricas para módulos sin set específico.
const List<String> _sugerenciasGenericas = [
  'Resumen de mi negocio hoy',
  '3 acciones para vender más esta semana',
  '¿Qué problema debo resolver primero?',
  'Organiza mi día en prioridades claras',
];

/// Abre el asistente IA del módulo.
void showPPAiAssistant({
  required BuildContext context,
  required String moduleId,
  required String screenTitle,
  required Color moduleColor,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PPAiAssistantSheet(
      moduleId: moduleId,
      screenTitle: screenTitle,
      moduleColor: moduleColor,
    ),
  );
}

class _PPAiAssistantSheet extends StatefulWidget {
  final String moduleId;
  final String screenTitle;
  final Color moduleColor;

  const _PPAiAssistantSheet({
    required this.moduleId,
    required this.screenTitle,
    required this.moduleColor,
  });

  @override
  State<_PPAiAssistantSheet> createState() => _PPAiAssistantSheetState();
}

class _PPAiAssistantSheetState extends State<_PPAiAssistantSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_MensajeIA> _mensajes = [];
  bool _enviando = false;
  String? _contextoNegocio;
  bool _cargandoContexto = true;

  @override
  void initState() {
    super.initState();
    _cargarContexto();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Arma contexto compacto con datos reales del negocio (BD local) para que
  /// la IA responda con datos y no con frases genéricas.
  Future<void> _cargarContexto() async {
    final partes = <String>[];
    try {
      final empresa = AuthController.instance.empresaCodigo;
      final productos = await PortalPilotDB.getProductos(empresa);
      if (productos.isNotEmpty) {
        final bajoStock = productos
            .where((p) {
              final s = (p['stock_actual'] as num?)?.toInt() ?? 0;
              final m = (p['stock_minimo'] as num?)?.toInt() ?? 0;
              return m > 0 && s <= m;
            })
            .take(8)
            .map((p) => '${p['nombre']} (${p['stock_actual']}/${p['stock_minimo']})')
            .toList();
        partes.add('PRODUCTOS (${productos.length} en catálogo):');
        for (final p in productos.take(25)) {
          partes.add(
            '- ${p['nombre']}: stock ${p['stock_actual']}, precio venta ${p['precio_venta']}',
          );
        }
        if (bajoStock.isNotEmpty) {
          partes.add('EN/A BAJO MÍNIMO: ${bajoStock.join('; ')}');
        }
      }
      final facturas = await PortalPilotDB.getFacturas(empresa);
      if (facturas.isNotEmpty) {
        final total = facturas.fold<double>(
          0, (acc, f) => acc + ((f['total'] as num?)?.toDouble() ?? 0));
        final mesActual = DateTime.now().month;
        final delMes = facturas.where((f) {
          final d = DateTime.tryParse(f['created_at']?.toString() ?? '');
          return d != null && d.month == mesActual;
        }).toList();
        partes.add(
          'FACTURAS: ${facturas.length} registradas, total ${total.toStringAsFixed(2)}, '
          '${delMes.length} este mes.',
        );
        final topProductos = <String, int>{};
        for (final f in facturas.take(80)) {
          final items = f['items'];
          if (items is List) {
            for (final it in items) {
              if (it is Map && it['descripcion'] != null) {
                final nombre = it['descripcion'].toString();
                final cant = (it['cantidad'] as num?)?.toInt() ?? 1;
                topProductos[nombre] = (topProductos[nombre] ?? 0) + cant;
              }
            }
          }
        }
        if (topProductos.isNotEmpty) {
          final ordenados = topProductos.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          partes.add(
            'MÁS VENDIDOS: ${ordenados.take(5).map((e) => '${e.key} (x${e.value})').join(', ')}',
          );
        }
      }
      final clientes = await PortalPilotDB.getClientes(empresa);
      if (clientes.isNotEmpty) {
        partes.add(
          'CLIENTES: ${clientes.length}. Algunos: ${clientes.take(10).map((c) => c['nombre']).join(', ')}.',
        );
      }
    } catch (e) {
      debugPrint('[PPAiAssistant] contexto local no disponible: $e');
    }
    if (!mounted) return;
    setState(() {
      _contextoNegocio = partes.isEmpty
          ? 'El usuario aún no tiene datos locales registrados en este módulo.'
          : partes.join('\n');
      _cargandoContexto = false;
    });
  }

  List<String> get _sugerencias =>
      _sugerenciasPorModulo[widget.moduleId] ?? _sugerenciasGenericas;

  Future<void> _enviar(String texto) async {
    final prompt = texto.trim();
    if (prompt.isEmpty || _enviando || _cargandoContexto) return;
    setState(() {
      _enviando = true;
      _mensajes.add(_MensajeIA(rol: 'user', texto: prompt));
      _input.clear();
    });
    _scrollAlFinal();

    final resp = await AIManager.instance.generate(
      prompt: prompt,
      contextoAdicional:
          'CONTEXTO DEL MÓDULO "${widget.screenTitle}" DEL NEGOCIO:\n'
          '$_contextoNegocio\n\n'
          'Responde breve (máx 150 palabras), en español, con pasos o números '
          'concretos basados en el contexto. Si un dato no está en el contexto, dilo.',
      temperature: 0.4,
      maxTokens: 500,
    );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _mensajes.add(_MensajeIA(
        rol: 'ai',
        texto: resp.success
            ? (resp.text.trim().isEmpty ? '(sin respuesta)' : resp.text.trim())
            : '⚠️ ${resp.error ?? "No pude responder. Intenta de nuevo."}',
        error: !resp.success,
      ));
    });
    _scrollAlFinal();
  }

  /// Un toque = análisis accionable del módulo sin escribir nada.
  Future<void> _insightRapido() async {
    await _enviar(
      'Dame un diagnóstico rápido de este módulo con 3 hallazgos accionables '
      'basados en los datos del contexto. Para cada uno: qué hacer hoy, y el '
      'impacto esperado. Sé directo y numera los hallazgos.',
    );
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: palette.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: palette.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(palette),
            Flexible(child: _buildCuerpo(palette)),
            _buildInput(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette.brandGradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente IA',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  widget.screenTitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _cargandoContexto
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.moduleColor,
                  ),
                )
              : Tooltip(
                  message: 'Los datos de tu negocio están incluidos en las respuestas',
                  child: Icon(Icons.verified_rounded,
                      size: 20, color: palette.successGreen),
                ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCuerpo(ThemePalette palette) {
    if (_mensajes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          _buildTarjetaInsight(palette),
          const SizedBox(height: 16),
          Text(
            'SUGERENCIAS PARA ESTE MÓDULO',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: palette.textDim,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sugerencias
                .map((s) => _chipSugerencia(s, palette))
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            _cargandoContexto
                ? 'Cargando datos de tu negocio…'
                : 'Con datos reales de tu negocio · responde en segundos',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: palette.textDim,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _mensajes.length + (_enviando ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _mensajes.length) {
          return _burbujaTyping(palette);
        }
        return _burbuja(_mensajes[i], palette);
      },
    );
  }

  Widget _buildTarjetaInsight(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette.brandGradientSoft),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: palette.brand, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diagnóstico en 1 toque',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'La IA revisa tus datos de ${widget.screenTitle} y te dice qué '
            'hacer hoy para que el negocio pese menos.',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: palette.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _cargandoContexto || _enviando ? null : _insightRapido,
              style: FilledButton.styleFrom(
                backgroundColor: palette.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                'Analizar ${widget.screenTitle} ahora',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipSugerencia(String texto, ThemePalette palette) {
    return ActionChip(
      backgroundColor: palette.bgSecondary,
      side: BorderSide(color: palette.borderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      label: Text(
        texto,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _enviar(texto),
    );
  }

  Widget _burbuja(_MensajeIA m, ThemePalette palette) {
    final esUser = m.rol == 'user';
    return Align(
      alignment: esUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: esUser
              ? palette.brand
              : (m.error ? palette.errorRed.withValues(alpha: 0.10) : palette.bgSecondary),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esUser ? 16 : 4),
            bottomRight: Radius.circular(esUser ? 4 : 16),
          ),
        ),
        child: GestureDetector(
          onLongPress: esUser
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: m.texto));
                  PPNotifications.show(
                    context,
                    message: 'Respuesta copiada',
                    type: PPNotificationType.success,
                  );
                },
          child: SelectableText(
            m.texto,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              height: 1.45,
              color: esUser
                  ? Colors.white
                  : (m.error ? palette.errorRedDeep : palette.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _burbujaTyping(ThemePalette palette) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.bgSecondary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              decoration: BoxDecoration(
                color: palette.textMuted,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInput(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: _enviar,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Pregúntale algo de ${widget.screenTitle}…',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: palette.textDim,
                ),
                filled: true,
                fillColor: palette.bgSecondary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.brand, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _enviando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: palette.brandGradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: () => _enviar(_input.text),
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MensajeIA {
  final String rol; // 'user' | 'ai'
  final String texto;
  final bool error;

  _MensajeIA({required this.rol, required this.texto, this.error = false});
}
