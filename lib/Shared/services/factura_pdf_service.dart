// lib/Shared/services/factura_pdf_service.dart
// Generación de Factura Legal PDF (A4) con todos los requisitos SAR Honduras:
// RTN, razón social, CAI, rango, fecha límite, resolución, correlativo,
// desglose ISV y total en letras.

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';

class FacturaPdfService {
  FacturaPdfService._();
  static final FacturaPdfService instance = FacturaPdfService._();

  static const PdfColor _verde = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _oscuro = PdfColor.fromInt(0xFF0A0A0A);
  static const PdfColor _gris = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _borde = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _fondo = PdfColor.fromInt(0xFFF9FAFB);

  /// Genera el PDF legal de una factura.
  Future<Uint8List> generarPdf({
    required Map<String, dynamic> factura,
    required SarConfiguracionData config,
    SarCorrelativoData? correlativo,
  }) async {
    final doc = pw.Document(
      title: 'Factura ${factura['correlativo'] ?? ''}',
      author: config.razonSocial ?? 'Portal Pilot',
    );

    final items = List<Map<String, dynamic>>.from(factura['items'] ?? []);
    final subtotal = _num(factura['subtotal']);
    final isv15 = _num(factura['isv_15']);
    final isv18 = _num(factura['isv_18']);
    final descuento = _num(factura['descuento']);
    final total = _num(factura['total']);
    final contingencia = factura['contingencia'] == true;

    final tipo = factura['tipo_documento'] ?? 'Factura';
    final regimen = (factura['regimen'] as String?) ?? config.regimen;
    final rst = regimen == 'simplificado';
    final cai = (factura['cai'] as String? ?? correlativo?.cai ?? '')
        .replaceAll(RegExp(r'[\s-]'), '');
    final rangoInicio =
        factura['rango_inicio'] as String? ?? correlativo?.rangoInicio;
    final rangoFin = factura['rango_fin'] as String? ?? correlativo?.rangoFin;
    final fechaLimite = factura['fecha_limite_emision'] != null
        ? DateTime.tryParse(factura['fecha_limite_emision'] as String)
        : correlativo?.fechaLimiteEmision;
    final resolucion =
        (factura['resolucion'] as String?) ??
        correlativo?.numeroResolucion ??
        '';

    final fecha =
        DateTime.tryParse(factura['fecha'] as String? ?? '') ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: _borde, thickness: 0.6),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    rst
                        ? 'Documento emitido en el Régimen Simplificado de Tributación (RST) de Honduras.'
                        : 'Documento autorizado por la Dirección Ejecutiva de Ingresos (DEI/SAR) de Honduras.',
                    style: const pw.TextStyle(fontSize: 7.5, color: _gris),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            if (!rst)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'CAI: ${cai.isEmpty ? '-' : cai}    |    Fecha límite de emisión: ${fechaLimite != null ? SarService.fmtFecha(fechaLimite) : '-'}',
                      style: const pw.TextStyle(fontSize: 7.5, color: _gris),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
          ],
        ),
        build: (ctx) => [
          _header(
            config,
            tipo,
            factura['correlativo'] ?? '',
            contingencia,
            rst: rst,
          ),
          pw.SizedBox(height: 8),
          if (rst)
            _rstBox(resolucion)
          else
            _caiBox(cai, rangoInicio, rangoFin, fechaLimite, resolucion),
          pw.SizedBox(height: 8),
          _clienteBox(factura, fecha),
          pw.SizedBox(height: 8),
          _itemsTable(items),
          pw.SizedBox(height: 8),
          _totales(subtotal, isv15, isv18, descuento, total),
          pw.SizedBox(height: 8),
          _letras(total),
          pw.SizedBox(height: 8),
          if (contingencia) _contingenciaBox(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(
    SarConfiguracionData config,
    String tipo,
    String correlativo,
    bool contingencia, {
    bool rst = false,
  }) {
    final razonSocial = config.razonSocial ?? config.nombreComercial ?? '';
    final rtn = SarService.formatearRTN(config.rtn ?? '');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _verde, width: 1.2),
        color: _fondo,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      (config.nombreComercial ?? razonSocial).toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _oscuro,
                      ),
                    ),
                    if (razonSocial.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Razón Social: ${razonSocial.toUpperCase()}',
                        style: const pw.TextStyle(fontSize: 8, color: _oscuro),
                      ),
                    ],
                    if (rtn.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'RTN: $rtn',
                        style: const pw.TextStyle(fontSize: 8, color: _oscuro),
                      ),
                    ],
                    if ((config.direccion ?? '').isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Dirección: ${config.direccion}',
                          style: const pw.TextStyle(fontSize: 8, color: _gris),
                        ),
                      ),
                    if ((config.telefono ?? '').isNotEmpty ||
                        (config.email ?? '').isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Tel: ${config.telefono ?? ''}  ${config.email != null ? '| Email: ${config.email}' : ''}',
                          style: const pw.TextStyle(fontSize: 8, color: _gris),
                        ),
                      ),
                    if ((config.representanteLegal ?? '').isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Representante Legal: ${config.representanteLegal}',
                          style: const pw.TextStyle(fontSize: 8, color: _gris),
                        ),
                      ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: contingencia
                      ? const PdfColor.fromInt(0xFFEF4444)
                      : _verde,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      tipo.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      rst
                          ? 'RÉGIMEN SIMPLIFICADO'
                          : contingencia
                              ? 'CONTINGENCIA'
                              : 'DOCUMENTO FISCAL',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        color: const PdfColor.fromInt(0xFFF0F0F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _borde, thickness: 0.6),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'NUMERO DE DOCUMENTO',
                style: const pw.TextStyle(fontSize: 7, color: _gris),
              ),
              pw.Text(
                correlativo,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _verde,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _caiBox(
    String cai,
    String? inicio,
    String? fin,
    DateTime? fechaLimite,
    String resolucion,
  ) {
    pw.Widget item(String label, String value) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 6.5, color: _gris),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _oscuro,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borde, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          item('CAI', cai.isEmpty ? '-' : cai),
          pw.SizedBox(width: 8),
          item('Rango', '${inicio ?? '-'} / ${fin ?? '-'}'),
          pw.SizedBox(width: 8),
          item(
            'Vence',
            fechaLimite != null ? SarService.fmtFecha(fechaLimite) : '-',
          ),
          pw.SizedBox(width: 8),
          item('Resolución', resolucion.isEmpty ? '-' : resolucion),
        ],
      ),
    );
  }

  pw.Widget _rstBox(String resolucion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF0FDF4),
        border: pw.Border.all(color: _verde, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RÉGIMEN SIMPLIFICADO DE TRIBUTACIÓN (RST)',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF059669),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Comprobante Fiscal emitido sin CAI. '
            'Resolución: ${resolucion.isEmpty ? '-' : resolucion}',
            style: const pw.TextStyle(fontSize: 8, color: _oscuro, height: 1.4),
          ),
        ],
      ),
    );
  }

  pw.Widget _clienteBox(Map<String, dynamic> factura, DateTime fecha) {
    final nombre = factura['cliente_nombre'] ?? 'Cliente General';
    final rtn = SarService.formatearRTN(
      (factura['cliente_rtn'] ?? '').toString(),
    );
    final condicion = factura['condicion_pago'] ?? 'Contado';
    final tipoVenta = factura['tipo_venta'] ?? 'Gravada';

    pw.Widget dato(String label, String value) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8, color: _oscuro),
            ),
          ),
        ],
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borde, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                dato('Comprador', nombre),
                dato(
                  'RTN Comprador',
                  rtn == '-' || rtn.isEmpty ? 'Consumidor Final' : rtn,
                ),
                dato(
                  'Dirección',
                  (factura['cliente_direccion'] ?? '') as String,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                dato(
                  'Fecha Emisión',
                  '${_fmt2(fecha.day)}/${_fmt2(fecha.month)}/${fecha.year}',
                ),
                dato('Condición', condicion),
                dato('Tipo de Venta', tipoVenta),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borde, width: 0.8),
        ),
        child: pw.Text(
          'Sin conceptos',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
        children: [
          _celda('CANT.', header: true),
          _celda('DESCRIPCIÓN', header: true),
          _celda('P. UNIT.', header: true, align: pw.Alignment.centerRight),
          _celda('ISV', header: true, align: pw.Alignment.centerRight),
          _celda('TOTAL', header: true, align: pw.Alignment.centerRight),
        ],
      ),
    ];

    for (final item in items) {
      final cant = (item['cantidad'] as num?)?.toDouble() ?? 0;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0;
      final isvRate = (item['isv'] as num?)?.toDouble() ?? 15.0;
      final totalLinea = cant * precio;
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.4)),
          ),
          children: [
            _celda(
              cant == cant.roundToDouble()
                  ? cant.toInt().toString()
                  : cant.toStringAsFixed(2),
            ),
            _celda(
              (item['descripcion'] ?? '') as String,
              align: pw.Alignment.centerLeft,
            ),
            _celda(
              'L. ${SarService.formatearMonto(precio)}',
              align: pw.Alignment.centerRight,
            ),
            _celda(
              '${isvRate.toStringAsFixed(0)}%',
              align: pw.Alignment.centerRight,
            ),
            _celda(
              'L. ${SarService.formatearMonto(totalLinea)}',
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borde, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.8),
      },
      children: rows,
    );
  }

  pw.Widget _totales(
    double subtotal,
    double isv15,
    double isv18,
    double descuento,
    double total,
  ) {
    pw.Widget fila(
      String label,
      String value, {
      bool total = false,
      bool negativo = false,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: total ? 11 : 8.5,
                fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: _oscuro,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: total ? 12 : 8.5,
                fontWeight: pw.FontWeight.bold,
                color: negativo ? const PdfColor.fromInt(0xFFEF4444) : _oscuro,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TOTAL EN LETRAS',
                style: const pw.TextStyle(fontSize: 6.5, color: _gris),
              ),
              pw.SizedBox(height: 2),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borde, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  'L. ${SarService.numeroALetras(total)}',
                  style: const pw.TextStyle(fontSize: 8, color: _oscuro),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(
          width: 230,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _verde, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              fila('SUBTOTAL', 'L. ${SarService.formatearMonto(subtotal)}'),
              fila('ISV 15%', 'L. ${SarService.formatearMonto(isv15)}'),
              fila('ISV 18%', 'L. ${SarService.formatearMonto(isv18)}'),
              if (descuento > 0)
                fila(
                  'DESCUENTO',
                  'L. ${SarService.formatearMonto(descuento)}',
                  negativo: true,
                ),
              pw.Divider(color: _borde, thickness: 0.8),
              fila(
                'TOTAL',
                'L. ${SarService.formatearMonto(total)}',
                total: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _letras(double total) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _fondo,
        border: pw.Border.all(color: _borde, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'IMPORTE EN LETRAS: ',
            style: pw.TextStyle(fontSize: 7.5, color: _gris),
          ),
          pw.Expanded(
            child: pw.Text(
              SarService.numeroALetras(total),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _oscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _contingenciaBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFEE2E2),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFEF4444),
          width: 0.8,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            '!',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFB91C1C),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              'DOCUMENTO EMITIDO EN RÉGIMEN DE CONTINGENCIA. Debe ser reportado a la SAR al normalizar el sistema.',
              style: pw.TextStyle(
                fontSize: 8,
                color: const PdfColor.fromInt(0xFFB91C1C),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _celda(
    String texto, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      alignment: align,
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : _oscuro,
        ),
      ),
    );
  }

  /// Imprime el PDF usando el diálogo del sistema.
  Future<void> imprimir({
    required Map<String, dynamic> factura,
    required SarConfiguracionData config,
    SarCorrelativoData? correlativo,
  }) async {
    final bytes = await generarPdf(
      factura: factura,
      config: config,
      correlativo: correlativo,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  /// Comparte/guarda el PDF.
  Future<void> compartir({
    required Map<String, dynamic> factura,
    required SarConfiguracionData config,
    SarCorrelativoData? correlativo,
  }) async {
    final bytes = await generarPdf(
      factura: factura,
      config: config,
      correlativo: correlativo,
    );
    final nombre =
        'factura_${factura['correlativo'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: nombre);
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static String _fmt2(int v) => v.toString().padLeft(2, '0');
}
