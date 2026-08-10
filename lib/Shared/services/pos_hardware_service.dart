import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Servicio para manejo de hardware POS: impresoras térmicas, cajón de dinero, escáner
/// Nota: La implementación Bluetooth depende del paquete bluetooth_print
/// Esta es una versión simplificada que define la interfaz
class PosHardwareService {
  PosHardwareService._();
  static final PosHardwareService instance = PosHardwareService._();

  bool _isInitialized = false;
  dynamic _connectedPrinter; // BluetoothDevice del paquete bluetooth_print
  String? _connectedPrinterName;
  String? _connectedPrinterAddress;

  // Configuración por defecto
  int _paperWidth = 80; // mm

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ PosHardwareService initialized (Bluetooth requiere configuración específica)');
  }

  // ═══════════════════════════════════════════════════════════════
  // IMPRESORA BLUETOOTH - Interfaz genérica
  // ═══════════════════════════════════════════════════════════════

  /// Escanear impresoras - implementación depende del paquete bluetooth_print
  Future<List<dynamic>> scanPrinters() async {
    if (!_isInitialized) await initialize();
    debugPrint('⚠️ scanPrinters: Requiere implementación específica del paquete bluetooth_print');
    return [];
  }

  /// Conectar impresora - implementación depende del paquete bluetooth_print
  Future<bool> connectPrinter(dynamic device) async {
    if (!_isInitialized) await initialize();
    debugPrint('⚠️ connectPrinter: Requiere implementación específica del paquete bluetooth_print');
    _connectedPrinter = device;
    _connectedPrinterName = device?.name ?? 'Desconocida';
    _connectedPrinterAddress = device?.address ?? 'unknown';
    return true;
  }

  Future<void> disconnectPrinter() async {
    _connectedPrinter = null;
    _connectedPrinterName = null;
    _connectedPrinterAddress = null;
  }

  bool get isPrinterConnected => _connectedPrinter != null;
  String? get connectedPrinterName => _connectedPrinterName;
  String? get connectedPrinterAddress => _connectedPrinterAddress;

  // ═══════════════════════════════════════════════════════════════
  // IMPRESIÓN TICKETS (ESC/POS) - Genera bytes listos para enviar
  // ═══════════════════════════════════════════════════════════════

  /// Genera los bytes ESC/POS para un ticket
  Uint8List generateTicketBytes({
    required String empresaNombre,
    required String empresaRtn,
    required String empresaDireccion,
    required String terminalId,
    required String correlativo,
    required DateTime fecha,
    required List<PosTicketItem> items,
    required double subtotal,
    required double descuento,
    required double isv15,
    required double isv18,
    required double total,
    required String metodoPago,
    String? clienteNombre,
    String? clienteRtn,
    String? cajero,
    Uint8List? logoBytes,
    bool abrirCajon = true,
  }) {
    final List<int> bytes = [];
    final encoder = utf8.encoder;

    void add(List<int> data) => bytes.addAll(data);
    void addText(String text, {bool bold = false, bool underline = false, int align = 0, int width = 1, int height = 1}) {
      if (bold) add([0x1B, 0x45, 0x01]); else add([0x1B, 0x45, 0x00]);
      if (underline) add([0x1B, 0x2D, 0x01]); else add([0x1B, 0x2D, 0x00]);
      add([0x1B, 0x61, align]); // 0=left, 1=center, 2=right
      add([0x1D, 0x21, (width - 1) << 4 | (height - 1)]);
      add(encoder.convert(text));
      add([0x0A]);
    }
    void addLine({String char = '-', int count = 48}) => addText(char * count);
    void addEmptyLine() => add([0x0A]);
    void cutPaper() => add([0x1D, 0x56, 0x00]); // Corte parcial
    void openDrawer() => add([0x1B, 0x70, 0x00, 0x19, 0xFA]); // Pin 2, 50ms, 50ms

    // Configuración inicial
    add([0x1B, 0x40]); // Inicializar impresora
    add([0x1B, 0x74, 0x00]); // Tabla de códigos PC437

    // Logo
    if (logoBytes != null) {
      addImage(logoBytes, bytes);
      addEmptyLine();
    }

    // Encabezado
    addText(empresaNombre, bold: true, align: 1, width: 2, height: 2);
    addText('RTN: $empresaRtn', align: 1);
    addText(empresaDireccion, align: 1);
    addLine();
    
    // Info ticket
    addText('TERMINAL: $terminalId', align: 1);
    addText('TICKET: $correlativo', align: 1, bold: true);
    addText('FECHA: ${_formatDateTime(fecha)}', align: 1);
    if (cajero != null) addText('CAJERO: $cajero', align: 1);
    if (clienteNombre != null) {
      addLine();
      addText('CLIENTE: $clienteNombre', bold: true);
      if (clienteRtn != null) addText('RTN: $clienteRtn');
    }
    addLine();

    // Encabezado items
    addText('${'DESCRIPCIÓN'.padRight(24)} ${'CANT'.padLeft(4)} ${'PRECIO'.padLeft(8)} ${'TOTAL'.padLeft(10)}', bold: true);
    addLine(char: '=');

    // Items
    for (final item in items) {
      final desc = item.nombre.length > 22 ? '${item.nombre.substring(0, 22)}' : item.nombre.padRight(22);
      final cant = item.cantidad.toString().padLeft(4);
      final precio = _formatCurrency(item.precioUnitario).padLeft(8);
      final totalItem = _formatCurrency(item.precioUnitario * item.cantidad).padLeft(10);
      
      addText('$desc $cant $precio $totalItem');
      
      if (item.descuento > 0) {
        addText('  Desc: -${_formatCurrency(item.descuento)}', align: 2);
      }
      if (item.promocionAplicada != null) {
        addText('  Promo: ${item.promocionAplicada}', align: 2);
      }
    }

    addLine(char: '=');

    // Totales
    addText('${'SUBTOTAL'.padRight(30)} ${_formatCurrency(subtotal).padLeft(16)}');
    if (descuento > 0) addText('${'DESCUENTO'.padRight(30)} -${_formatCurrency(descuento).padLeft(15)}');
    if (isv15 > 0) addText('${'ISV 15%'.padRight(30)} ${_formatCurrency(isv15).padLeft(16)}');
    if (isv18 > 0) addText('${'ISV 18%'.padRight(30)} ${_formatCurrency(isv18).padLeft(16)}');
    addLine(char: '=');
    addText('${'TOTAL'.padRight(30)} ${_formatCurrency(total).padLeft(16)}', bold: true, width: 2, height: 2);
    addLine();

    // Método de pago
    addText('MÉTODO: ${metodoPago.toUpperCase()}', align: 1, bold: true);
    addEmptyLine();

    // Pie
    addText('¡GRACIAS POR SU COMPRA!', align: 1, bold: true);
    addText('Válido como comprobante de compra', align: 1);
    addText('Conserve su ticket para garantías', align: 1);
    addEmptyLine();
    addText('Portal Pilot POS', align: 1);
    addText('www.portalpilot.app', align: 1);
    addEmptyLine();
    addEmptyLine();

    if (abrirCajon) openDrawer();
    cutPaper();

    return Uint8List.fromList(bytes);
  }

  void addImage(Uint8List imageBytes, List<int> bytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return;

      // Redimensionar a ancho de papel (384px para 80mm, 256px para 58mm)
      final targetWidth = _paperWidth == 80 ? 384 : 256;
      final resized = img.copyResize(image, width: targetWidth);
      
      // Convertir a ESC/POS raster
      final imageData = _imageToEscPosRaster(resized);
      bytes.addAll(imageData);
    } catch (e) {
      debugPrint('Error procesando imagen: $e');
    }
  }

  List<int> _imageToEscPosRaster(img.Image image) {
    final List<int> bytes = [];
    final int width = image.width;
    final int height = image.height;
    final int bytesPerLine = (width + 7) ~/ 8;

    // GS v 0 - Imprimir imagen raster
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.addAll([
      bytesPerLine & 0xFF,
      (bytesPerLine >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
    ]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < bytesPerLine; x++) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          final px = x * 8 + b;
          if (px < width) {
            final pixel = image.getPixel(px, y);
            final luminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).round();
            if (luminance < 128) {
              byte |= (1 << (7 - b));
            }
          }
        }
        bytes.add(byte);
      }
    }

    return bytes;
  }

  String _formatCurrency(double value) => value.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatDateTime(DateTime dt) => 
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ════════════════════════════════════════════════════════════════
  // CAJÓN DE DINERO
  // ═══════════════════════════════════════════════════════════════

  /// Genera bytes para abrir cajón de dinero
  Uint8List generateOpenDrawerBytes() {
    return Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]); // Pin 2, 50ms, 50ms
  }

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════

Future<void> loadConfig(String empresaId, String terminalId) async {
    final config = await LocalDatabaseService.instance.database.select(
      LocalDatabaseService.instance.database.posConfig
    )
      ..where((c) => c.empresaId.equals(empresaId))
      ..where((c) => c.terminalId.equals(terminalId));
    
    final result = await config.getSingleOrNull();
    if (result != null) {
      _paperWidth = int.tryParse(result.impresoraAncho ?? '80') ?? 80;
      // La conexión Bluetooth se debe hacer manualmente con el paquete bluetooth_print
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}

class PosTicketItem {
  final String productoId;
  final String codigo;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double descuento;
  final double isvRate;
  final String? promocionAplicada;

  PosTicketItem({
    required this.productoId,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0,
    this.isvRate = 15,
    this.promocionAplicada,
  });

  double get subtotal => precioUnitario * cantidad - descuento;
}