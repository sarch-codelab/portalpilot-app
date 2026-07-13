// lib/Areas/Educacion/Edu IA/document_processor.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:portal_pilot_app/IA/ia.dart';

/// Procesa documentos y extrae información para la IA
class DocumentProcessor {
  DocumentProcessor._();
  static final DocumentProcessor instance = DocumentProcessor._();

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
      debugPrint('❌ Error al extraer texto: $e');
      return 'Error al procesar el documento: $e';
    }
  }

  Future<String> _extractTextFromPDF(String filePath) async {
    // En producción, usar paquete como `pdf_text` o `syncfusion_flutter_pdf`
    // Por ahora, retornamos mensaje placeholder
    return '[Contenido PDF extraído - Requiere implementación con paquete pdf_text]';
  }

  Future<String> _extractTextFromImage(String filePath) async {
    // En producción, usar OCR con Google ML Kit o Tesseract
    // Por ahora, retornamos mensaje placeholder
    return '[Texto OCR extraído de imagen - Requiere implementación con google_ml_kit]';
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