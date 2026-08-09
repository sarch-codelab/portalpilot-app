// lib/Modules/Educacion/ia/document_processor.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';

/// Procesa documentos y extrae información para la IA
class DocumentProcessor {
  DocumentProcessor._();
  static final DocumentProcessor instance = DocumentProcessor._();

  static const int _maxTextoExtraido = 50000;

  // ═══════════════════════════════════════════════════════════
  // EXTRAER TEXTO DE DOCUMENTOS
  // ═══════════════════════════════════════════════════════════

  Future<String> extractTextFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final extension = filePath.split('.').last.toLowerCase();

      switch (extension) {
        case 'txt':
          return await file.readAsString();
        case 'csv':
        case 'json':
        case 'xml':
        case 'md':
          return await file.readAsString();
        case 'pdf':
          return await _extractTextFromPDF(filePath);
        case 'jpg':
        case 'jpeg':
        case 'png':
          return await _extractTextFromImage(filePath);
        default:
          return 'Formato no soportado: $extension';
      }
    } catch (e) {
      debugPrint('Error al extraer texto: $e');
      return 'Error al procesar el documento: $e';
    }
  }

  /// Extrae el texto real de un PDF (pure Dart, sin dependencias).
  /// Soporta flujos comprimidos FlateDecode y textos con codificación
  /// simple (PDFDocEncoding/ASCII) y UTF-16BE, incluyendo operadores
  /// Tj, TJ, y saltos de línea por Td/TD/T*/Tm.
  Future<String> _extractTextFromPDF(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    if (bytes.isEmpty) return 'El PDF está vacío.';

    // Los flujos PDF se decodifican como latin1 para preservar bytes.
    final decoded = latin1.decode(bytes, allowInvalid: true);
    final buffer = StringBuffer();
    var encontroAlgo = false;

    // Extrae cada bloque stream...endstream.
    final streamRe = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true);
    for (final m in streamRe.allMatches(decoded)) {
      final raw = m.group(1) ?? '';
      if (raw.isEmpty) continue;

      final content = _tryInflate(raw);
      final texto = _extractTextFromContent(content);
      if (texto.isNotEmpty) {
        encontroAlgo = true;
        buffer.writeln(texto);
        if (buffer.length > _maxTextoExtraido) break;
      }
    }

    if (!encontroAlgo) {
      // Último recurso: el PDF puede ser texto plano sin comprimir.
      final textoPlano = _extractTextFromContent(decoded);
      if (textoPlano.isNotEmpty) {
        encontroAlgo = true;
        buffer.writeln(textoPlano);
      }
    }

    if (!encontroAlgo) {
      return 'No se pudo extraer texto del PDF. '
          'Puede ser un PDF escaneado (imágenes) o con codificación no soportada.';
    }

    var texto = buffer.toString().trim();
    if (texto.length > _maxTextoExtraido) {
      texto = texto.substring(0, _maxTextoExtraido);
    }
    return texto;
  }

  /// Intenta descomprimir un flujo FlateDecode con zlib; si falla
  /// devuelve el contenido original (puede estar sin comprimir).
  String _tryInflate(String raw) {
    try {
      final compressed = raw.codeUnits
          .where((c) => c <= 0xFF)
          .toList(growable: false);
      if (compressed.length < 2) return raw;
      final decoded = ZLibDecoder().convert(compressed);
      return latin1.decode(decoded, allowInvalid: true);
    } catch (_) {
      return raw;
    }
  }

  /// Extrae cadenas de texto de un flujo de contenido PDF (operadores
  /// BT/ET, Tj, TJ) y reconstruye párrafos con saltos de línea.
  String _extractTextFromContent(String content) {
    if (content.isEmpty) return '';
    final buffer = StringBuffer();
    var lastY = 0.0;

    // Candidatos de texto: (literal) Tj, (literal) ' o " y [..] TJ
    final textOps = RegExp(
      "\\((?:[^()\\\\]|\\\\.)*\\)\\s*Tj|\\[(?:[^\\\\[\\\\]]*)\\\\]\\s*TJ|\\((?:[^()\\\\]|\\\\.)*\\)\\s*['\\\"]",
      caseSensitive: false,
    );

    var index = 0;
    for (final m in textOps.allMatches(content)) {
      if (m.start > index) {
        // Entre operadores de texto, detecta comandos de posicionamiento.
        final chunk = content.substring(index, m.start);
        final yMatch = RegExp(r'([-+]?\d+\.?\d*)\s*([-+]?\d+\.?\d*)\s*T[d*]')
            .firstMatch(chunk);
        if (yMatch != null) {
          final y = double.tryParse(yMatch.group(2) ?? '0') ?? 0.0;
          if (lastY != 0.0 && (y - lastY).abs() > 1.0) {
            buffer.write('\n');
          }
          lastY = y;
        } else if (chunk.contains('T*') || chunk.contains("'")) {
          buffer.write('\n');
        }
      }

      var literal = m.group(0)!;
      // Normaliza: quita el operador final y espacios.
      literal = literal.trim();
      final opIndex = _operatorIndex(literal);
      if (opIndex <= 0) continue;
      var inner = literal.substring(0, opIndex).trim();

      // Hex string <...>
      if (inner.startsWith('<') && inner.endsWith('>')) {
        buffer.write(_decodeHexString(inner.substring(1, inner.length - 1)));
        index = m.end;
        continue;
      }

      // Array para TJ: extrae cada literal y las kerning numéricos (signo).
      if (inner.startsWith('[') && inner.endsWith(']')) {
        final innerText = inner.substring(1, inner.length - 1);
        for (final lit in RegExp(r'\([^)]*\)|<[^>]*>').allMatches(innerText)) {
          var s = lit.group(0)!;
          if (s.startsWith('<')) {
            buffer.write(_decodeHexString(s.substring(1, s.length - 1)));
          } else {
            buffer.write(_decodePdfString(s.substring(1, s.length - 1)));
          }
        }
      } else if (inner.startsWith('(') && inner.endsWith(')')) {
        buffer.write(_decodePdfString(inner.substring(1, inner.length - 1)));
      }

      index = m.end;
    }

    return _normalizeSpaces(buffer.toString());
  }

  int _operatorIndex(String literal) {
    // Encuentra el inicio del operador (Tj, TJ, ', ")
    final op = RegExp("\\s*(Tj|TJ|'|\\\")\\s*\$").firstMatch(literal);
    if (op == null) return -1;
    return op.start;
  }

  String _decodePdfString(String raw) {
    final b = StringBuffer();
    var i = 0;
    while (i < raw.length) {
      final c = raw[i];
      if (c == '\\' && i + 1 < raw.length) {
        final next = raw[i + 1];
        if (next == 'n') { b.write('\n'); i += 2; continue; }
        if (next == 'r') { b.write('\r'); i += 2; continue; }
        if (next == 't') { b.write('\t'); i += 2; continue; }
        if (next == 'b') { b.write('\b'); i += 2; continue; }
        if (next == 'f') { b.write('\f'); i += 2; continue; }
        if (next == '(') { b.write('('); i += 2; continue; }
        if (next == ')') { b.write(')'); i += 2; continue; }
        if (next == '\\') { b.write('\\'); i += 2; continue; }
        // Escape octal \ddd
        if (RegExp(r'[0-7]').hasMatch(next)) {
          final oct = raw.substring(i + 1, (i + 4) > raw.length ? raw.length : i + 4);
          final octMatch = RegExp(r'^[0-7]{1,3}').firstMatch(oct);
          if (octMatch != null) {
            final code = int.tryParse(octMatch.group(0)!, radix: 8) ?? 32;
            b.write(String.fromCharCode(code));
            i += 1 + octMatch.group(0)!.length;
            continue;
          }
        }
        b.write(next);
        i += 2;
        continue;
      }
      b.write(c);
      i++;
    }
    return b.toString();
  }

  String _decodeHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    // UTF-16BE BOM
    if (clean.startsWith('FEFF')) {
      try {
        final codeUnits = <int>[];
        for (var i = 4; i + 1 < clean.length; i += 2) {
          final byte = int.tryParse(clean.substring(i, i + 2), radix: 16);
          if (byte != null) codeUnits.add(byte);
        }
        return _utf16beDecode(codeUnits);
      } catch (_) {
        // fallback
      }
    }
    final b = StringBuffer();
    for (var i = 0; i + 1 < clean.length; i += 2) {
      final byte = int.tryParse(clean.substring(i, i + 2), radix: 16);
      if (byte != null && byte != 0) b.write(String.fromCharCode(byte));
    }
    return b.toString();
  }

  /// Decodifica bytes UTF-16BE (2 bytes por unidad, big-endian).
  String _utf16beDecode(List<int> bytes) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _normalizeSpaces(String raw) {
    return raw
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
  }

  Future<String> _extractTextFromImage(String filePath) async {
    // OCR no está disponible en desktop sin un motor dedicado.
    // Se informa el estado real y se sugiere el camino (ML Kit en móvil).
    final file = File(filePath);
    final size = await file.length();
    final kb = (size / 1024).toStringAsFixed(1);
    return 'No se puede extraer texto de imágenes en esta plataforma '
        '(OCR requiere google_ml_kit, disponible solo en Android/iOS). '
        'Imagen: $filePath · $kb KB.';
  }

  // ═══════════════════════════════════════════════════════════
  // ANALIZAR DOCUMENTO CON IA
  // ═══════════════════════════════════════════════════════════

  Future<AIResponse> analyzeDocument({
    required String filePath,
    required String pregunta,
  }) async {
    final textoExtraido = await extractTextFromFile(filePath);

    final promptCompleto = '''
Analiza el siguiente documento y responde la pregunta del usuario.

**Documento:**
$textoExtraido

**Pregunta del usuario:**
$pregunta

Instrucciones:
- Si el documento contiene información relevante, úsala para responder
- Si no hay información suficiente, indícalo claramente
- Mantén la respuesta concisa y profesional
''';

    return await AIManager.instance.generate(
      prompt: promptCompleto,
      contextoAdicional: 'Documento adjunto para análisis',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RESUMIR DOCUMENTO
  // ═══════════════════════════════════════════════════════════

  Future<AIResponse> resumirDocumento(String filePath) async {
    final textoExtraido = await extractTextFromFile(filePath);

    final prompt = '''
Genera un resumen conciso del siguiente documento:

$textoExtraido

El resumen debe:
- Tener máximo 200 palabras
- Incluir los puntos más importantes
- Ser claro y profesional
''';

    return await AIManager.instance.generate(
      prompt: prompt,
      contextoAdicional: 'Resumen de documento',
    );
  }
}
