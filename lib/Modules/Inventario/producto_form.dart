import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/image_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

class ProductoForm extends StatefulWidget {
  final Map<String, dynamic>? productoExistente;

  const ProductoForm({super.key, this.productoExistente});

  @override
  State<ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<ProductoForm> {
  final _codigoController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _stockActualController = TextEditingController();
  final _stockMinimoController = TextEditingController();
  final _marcaController = TextEditingController();
  final _presentacionController = TextEditingController();

  String _categoria = 'General';
  String _unidadMedida = 'Unidad';
  String _bodega = 'General';
  double _isvRate = 15.0;
  bool _exento = false;
  String? _imagenBase64;
  String? _imagenUrl; // URL real de Supabase Storage
  bool _isUploadingImage = false;
  bool _isAiAnalyzing = false;
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  bool _torchOn = false;

  List<String> _bodegas = ['General'];

  final List<String> _categorias = [
    'General', 'Electrónica', 'Ropa', 'Alimentos', 'Bebidas', 'Farmacia',
    'Herramientas', 'Materiales', 'Papelería', 'Limpieza', 'Otros'
  ];

  final List<String> _unidades = [
    'Unidad', 'Pieza', 'Kilogramo', 'Libra', 'Litro', 'Metro',
    'Caja', 'Paquete', 'Docena', 'Par', 'Juego'
  ];

  @override
  void initState() {
    super.initState();
    _cargarBodegas();
    if (widget.productoExistente != null) _cargarProducto();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _cargarBodegas() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('bodegas') ?? '["General"]';
    try {
      setState(() => _bodegas = List<String>.from(jsonDecode(json)));
    } catch (_) {
      setState(() => _bodegas = ['General']);
    }
  }

  void _cargarProducto() {
    final p = widget.productoExistente!;
    _codigoController.text = p['codigo'] ?? '';
    _barcodeController.text = p['barcode'] ?? '';
    _nombreController.text = p['nombre'] ?? '';
    _descripcionController.text = p['descripcion'] ?? '';
    _precioCompraController.text = (p['precio_compra'] as num?)?.toString() ?? '';
    _precioVentaController.text = (p['precio_venta'] as num?)?.toString() ?? '';
    _stockActualController.text = (p['stock_actual'] as num?)?.toString() ?? '0';
    _stockMinimoController.text = (p['stock_minimo'] as num?)?.toString() ?? '0';
    _categoria = p['categoria'] ?? 'General';
    _unidadMedida = p['unidad_medida'] ?? 'Unidad';
    _bodega = p['bodega'] ?? 'General';
    _isvRate = (p['isv_rate'] as num?)?.toDouble() ?? 15.0;
    _exento = p['exento'] == true;
    _imagenBase64 = _normalizarBase64(p['imagen_base64'] as String?);
    _imagenUrl = p['imagen_url'] as String? ?? p['imagenUrl'] as String?;
    _marcaController.text = p['marca'] ?? '';
    _presentacionController.text = p['presentacion'] ?? '';
    // Si no hay base64 local pero la URL es una data URL, derivarla para el preview
    if ((_imagenBase64 == null || _imagenBase64!.isEmpty) &&
        (_imagenUrl ?? '').isNotEmpty &&
        !(_imagenUrl ?? '').startsWith('http')) {
      _imagenBase64 = _normalizarBase64(_imagenUrl);
    }
  }

  /// Extrae el base64 "puro" de un valor que puede ser base64 plano o una data URL.
  String? _normalizarBase64(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    final idx = valor.indexOf(',');
    if (valor.startsWith('data:') && idx >= 0) return valor.substring(idx + 1);
    return valor;
  }

  Future<void> _seleccionarImagen() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null) return;
      
      setState(() => _isUploadingImage = true);
      
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.length > 400 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen muy pesada (máx ~400 KB). Usa una más pequeña.', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      }
      
      // Guardar base64 localmente para visualización
      setState(() => _imagenBase64 = base64Encode(bytes));
      
      // Subir a Supabase Storage para obtener URL real
      final imageUrl = await ImageService.instance.uploadImage(
        base64OrPath: picked.path,
        bucketName: 'productos',
        folder: 'imagenes',
      );
      
      if (imageUrl != null) {
        setState(() => _imagenUrl = imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen subida exitosamente', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Fallback: usar data URL si Supabase Storage falla
        setState(() => _imagenUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen guardada localmente (sin URL pública)', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
      }
      
      setState(() => _isUploadingImage = false);
      
    } on PlatformException catch (e) {
      debugPrint('❌ ImagePicker error: ${e.message}');
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la galería en este dispositivo', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      debugPrint('❌ ImagePicker error: $e');
      setState(() => _isUploadingImage = false);
    }
  }
  
  Future<void> _escanearCodigo() async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        _scannerController?.dispose();
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.code93,
            BarcodeFormat.itf,
            BarcodeFormat.dataMatrix,
            BarcodeFormat.qrCode,
          ],
        );
        setState(() {
          _showScanner = true;
          _torchOn = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permiso de cámara denegado', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } else {
      _mostrarDialogoCodigoManual();
    }
  }
  
  void _cerrarScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() {
      _showScanner = false;
      _torchOn = false;
    });
  }

  Future<void> _toggleLinterna() async {
    final controller = _scannerController;
    if (controller == null) return;
    setState(() => _torchOn = !_torchOn);
    try {
      await controller.toggleTorch();
    } catch (_) {
      if (mounted) setState(() => _torchOn = !_torchOn);
    }
  }

  /// AI-powered product identification: captures image → AI analyzes → fills fields
  bool _aiAnalysisInProgress = false;

  Future<void> _identificarProductoConIA() async {
    if (_isAiAnalyzing || _aiAnalysisInProgress) return;
    _aiAnalysisInProgress = true;

    // Check camera permission first
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo acceder a la cámara. Puedes ingresar el producto manualmente.', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }
    }

    // Pick image from camera or gallery
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() => _isAiAnalyzing = true);

    try {
      final bytes = await picked.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      // Show analyzing indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Text('IA analizando producto...', style: GoogleFonts.dmSans()),
              ],
            ),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 60),
          ),
        );
      }

      // Step 1: If barcode exists, try Supabase lookup first
      BarcodeLookupResult? barcodeResult;
      final existingBarcode = _barcodeController.text.trim();
      if (existingBarcode.isNotEmpty) {
        barcodeResult = await AIManager.instance.lookupBarcode(existingBarcode);
        if (barcodeResult.found && barcodeResult.products.isNotEmpty) {
          _applyProductData(barcodeResult.products.first, source: 'base de datos');
          return;
        }
      }

      // Step 2: AI Vision analysis
      final visionResult = await AIManager.instance.identifyProductFromImage(imageBase64: imageBase64);
      if (!visionResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo analizar: ${visionResult.error ?? "Error desconocido"}', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final identification = AIManager.instance.parseProductIdentification(visionResult.text);
      if (identification.nombre == null || identification.nombre!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo identificar el producto. Intenta con otra imagen.', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }

      // Show confirmation dialog with AI results
      if (mounted) {
        final confirmed = await _showAIConfirmationDialog(identification);
        if (confirmed == true) {
          _applyAIIdentification(identification);
        }
      }
    } catch (e) {
      debugPrint('[AI] Product identification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error durante el análisis. Puedes intentar de nuevo o completar manualmente.', style: GoogleFonts.dmSans()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
      }
    } finally {
      _aiAnalysisInProgress = false;
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
  }

  void _applyProductData(Map<String, dynamic> p, {required String source}) {
    setState(() {
      if (p['nombre'] != null) _nombreController.text = p['nombre'].toString();
      if (p['descripcion'] != null) _descripcionController.text = p['descripcion'].toString();
      if (p['categoria'] != null && _categorias.contains(p['categoria'])) _categoria = p['categoria'].toString();
      if (p['unidad_medida'] != null && _unidades.contains(p['unidad_medida'])) _unidadMedida = p['unidad_medida'].toString();
      if (p['barcode'] != null) _barcodeController.text = p['barcode'].toString();
      if (p['marca'] != null) _marcaController.text = p['marca'].toString();
      if (p['presentacion'] != null) _presentacionController.text = p['presentacion'].toString();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Datos cargados desde $source', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _applyAIIdentification(ProductIdentification id) {
    setState(() {
      if (id.nombre != null) _nombreController.text = id.nombre!;
      if (id.descripcion != null) _descripcionController.text = id.descripcion!;
      
      // Categoría: mapear valor IA a lista permitida o agregar dinámicamente
      if (id.categoria != null && id.categoria!.isNotEmpty) {
        final cat = id.categoria!.trim();
        if (_categorias.contains(cat)) {
          _categoria = cat;
        } else {
          final mapped = _mapearCategoriaIA(cat);
          if (_categorias.contains(mapped)) {
            _categoria = mapped;
          } else {
            // Agregar dinámicamente para que se muestre en dropdown
            _categorias.add(cat);
            _categoria = cat;
          }
        }
      }
      
      // Unidad: mapear valor IA a lista permitida o agregar dinámicamente
      if (id.unidadMedida != null && id.unidadMedida!.isNotEmpty) {
        final uni = id.unidadMedida!.trim();
        if (_unidades.contains(uni)) {
          _unidadMedida = uni;
        } else {
          final mapped = _mapearUnidadIA(uni);
          if (_unidades.contains(mapped)) {
            _unidadMedida = mapped;
          } else {
            // Agregar dinámicamente para que se muestre en dropdown
            _unidades.add(uni);
            _unidadMedida = uni;
          }
        }
      }
      
      if (id.barcode != null && id.barcode!.isNotEmpty) _barcodeController.text = id.barcode!;
      if (id.marca != null && id.marca!.isNotEmpty) _marcaController.text = id.marca!;
      if (id.presentacion != null && id.presentacion!.isNotEmpty) _presentacionController.text = id.presentacion!;
    });
  }

  String _mapearCategoriaIA(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('agua') || lower.contains('bebida') || lower.contains('refresco') || lower.contains('jugo') || lower.contains('cerveza') || lower.contains('vino') || lower.contains('licor')) return 'Bebidas';
    if (lower.contains('lacteo') || lower.contains('leche') || lower.contains('queso') || lower.contains('yogur') || lower.contains('mantequilla') || lower.contains('crema')) return 'Alimentos';
    if (lower.contains('snack') || lower.contains('papas') || lower.contains('chips') || lower.contains('gallet') || lower.contains('dulce') || lower.contains('chocolate') || lower.contains('caramelo')) return 'Alimentos';
    if (lower.contains('limpieza') || lower.contains('detergente') || lower.contains('jabon') || lower.contains('suaviz') || lower.contains('desinfect') || lower.contains('cloro')) return 'Limpieza';
    if (lower.contains('farmacia') || lower.contains('medicamento') || lower.contains('vitamina') || lower.contains('jarabe') || lower.contains('pastilla') || lower.contains('curita') || lower.contains('alcohol')) return 'Farmacia';
    if (lower.contains('electron') || lower.contains('celular') || lower.contains('cargador') || lower.contains('audifono') || lower.contains('tablet') || lower.contains('laptop') || lower.contains('comput')) return 'Electrónica';
    if (lower.contains('ropa') || lower.contains('camisa') || lower.contains('pantalon') || lower.contains('vestido') || lower.contains('zapato') || lower.contains('tenis') || lower.contains('calcetin')) return 'Ropa';
    if (lower.contains('herramienta') || lower.contains('taladro') || lower.contains('martillo') || lower.contains('llave') || lower.contains('tornillo') || lower.contains('clavo')) return 'Herramientas';
    if (lower.contains('material') || lower.contains('cemento') || lower.contains('arena') || lower.contains('block') || lower.contains('varilla') || lower.contains('pintura') || lower.contains('tubo')) return 'Materiales';
    if (lower.contains('papeler') || lower.contains('cuaderno') || lower.contains('lapiz') || lower.contains('boligrafo') || lower.contains('hoja') || lower.contains('carpeta') || lower.contains('goma')) return 'Papelería';
    return 'General';
  }

  String _mapearUnidadIA(String uni) {
    final lower = uni.toLowerCase();
    if (lower == 'ml' || lower == 'mililitro' || lower == 'mililitros' || lower == 'milliliter') return 'Litro';
    if (lower == 'gr' || lower == 'g' || lower == 'gramo' || lower == 'gramos' || lower == 'gram') return 'Kilogramo';
    if (lower == 'kg' || lower == 'kilogramo' || lower == 'kilogramos' || lower == 'kilo') return 'Kilogramo';
    if (lower == 'lb' || lower == 'libra' || lower == 'libras' || lower == 'pound') return 'Libra';
    if (lower == 'lt' || lower == 'l' || lower == 'litro' || lower == 'litros' || lower == 'liter') return 'Litro';
    if (lower == 'm' || lower == 'metro' || lower == 'metros' || lower == 'meter') return 'Metro';
    if (lower == 'unidad' || lower == 'und' || lower == 'unid' || lower == 'unit' || lower == 'piece' || lower == 'pieza') return 'Unidad';
    if (lower == 'pza' || lower == 'pieza' || lower == 'piezas') return 'Pieza';
    if (lower == 'caja' || lower == 'box' || lower == 'cajas') return 'Caja';
    if (lower == 'paquete' || lower == 'pack' || lower == 'paq' || lower == 'packs') return 'Paquete';
    if (lower == 'docena' || lower == 'doc' || lower == 'dozen') return 'Docena';
    if (lower == 'par' || lower == 'pareja' || lower == 'pair') return 'Par';
    if (lower == 'juego' || lower == 'set' || lower == 'kit') return 'Juego';
    if (lower == 'botella' || lower == 'bottle') return 'Unidad';
    if (lower == 'lata' || lower == 'can') return 'Unidad';
    if (lower == 'sobre' || lower == 'paquete' || lower == 'sachet') return 'Paquete';
    return 'Unidad';
  }

  Future<bool?> _showAIConfirmationDialog(ProductIdentification id) {
    final confianza = id.confianza ?? 0;
    final confianzaPercent = (confianza * 100).round();
    final confianzaColor = confianza >= 0.7 ? const Color(0xFF10B981) : confianza >= 0.4 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final confianzaLabel = confianza >= 0.7 ? 'Alta' : confianza >= 0.4 ? 'Media' : 'Baja';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Text('Producto Detectado', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: confianzaColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: confianzaColor.withValues(alpha: 0.4)),
              ),
              child: Text('Confianza: $confianzaPercent% — $confianzaLabel', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: confianzaColor)),
            ),
            const SizedBox(height: 12),
            if (id.nombre != null) _aiField('Nombre', id.nombre!),
            if (id.marca != null) _aiField('Marca', id.marca!),
            if (id.categoria != null) _aiField('Categoría', id.categoria!),
            if (id.presentacion != null) _aiField('Presentación', id.presentacion!),
            if (id.unidadMedida != null) _aiField('Unidad', id.unidadMedida!),
            if (id.descripcion != null) ...[
              const SizedBox(height: 8),
              Text('Descripción:', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
              Text(id.descripcion!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white)),
            ],
            if (confianza < 0.4) ...[
              const SizedBox(height: 12),
              Text('No estamos seguros de qué producto es. Verifica la información antes de confirmar.', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFF59E0B))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('Usar datos', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _aiField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF737373))),
          Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white))),
        ],
      ),
    );
  }
  
  void _onBarcodeDetected(BarcodeCapture capture) {
    String? code;
    if (capture.raw is String && (capture.raw as String).isNotEmpty) {
      code = capture.raw as String;
    } else if (capture.barcodes.isNotEmpty) {
      code = capture.barcodes.first.rawValue;
    }
    
    if (code != null && code.isNotEmpty) {
      _barcodeController.text = code;
      _cerrarScanner();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código de barras escaneado: $code', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }
  
  void _mostrarDialogoCodigoManual() {
    final codigoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text('Ingresar Código', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        content: TextField(
          controller: codigoController,
          autofocus: true,
          style: GoogleFonts.dmSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: 04130305444',
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              _codigoController.text = v.trim();
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          ElevatedButton(
            onPressed: () {
              if (codigoController.text.trim().isNotEmpty) {
                _barcodeController.text = codigoController.text.trim();
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            child: Text('Agregar', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarProducto() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El nombre es obligatorio', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    // Validar stock: enteros no negativos (vacío = 0)
    final stockActual = _stockActualController.text.trim().isEmpty
        ? 0
        : int.tryParse(_stockActualController.text);
    final stockMinimo = _stockMinimoController.text.trim().isEmpty
        ? 0
        : int.tryParse(_stockMinimoController.text);

    if (stockActual == null || stockActual < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock Actual debe ser un número entero mayor o igual a 0', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }
    if (stockMinimo == null || stockMinimo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock Mínimo debe ser un número entero mayor o igual a 0', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    // Aviso (no bloquea): stock actual por debajo del mínimo activa la alerta
    // de "stock bajo" en Inventario. Se informa para que no tome por sorpresa.
    if (stockMinimo > 0 && stockActual < stockMinimo) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text(
            'Stock bajo el mínimo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'El stock actual ($stockActual) está por debajo del mínimo ($stockMinimo). '
            'Este producto aparecerá en la alerta de stock bajo. ¿Deseas continuar?',
            style: const TextStyle(color: Color(0xFFA3A3A3)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFFA3A3A3)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Guardar de todos modos',
                style: TextStyle(color: Color(0xFFF59E0B)),
              ),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final empresaCodigo = prefs.getString('empresa_codigo') ?? 'ROOT';
    final localDb = LocalDatabaseService.instance;
    
    // Generar ID si es nuevo producto
    final id = widget.productoExistente != null 
        ? widget.productoExistente!['id'] 
        : DateTime.now().millisecondsSinceEpoch.toString();
    
    final codigo = _codigoController.text.isNotEmpty 
        ? _codigoController.text 
        : 'P${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final producto = {
      'id': id,
      'codigo': codigo,
      'nombre': _nombreController.text,
      'descripcion': _descripcionController.text,
      'categoria': _categoria,
      'unidad_medida': _unidadMedida,
      'precio_compra': double.tryParse(_precioCompraController.text) ?? 0,
      'precio_venta': double.tryParse(_precioVentaController.text) ?? 0,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'bodega': _bodega,
      'isv_rate': _isvRate,
      'exento': _exento,
      'barcode': _barcodeController.text,
      'marca': _marcaController.text,
      'presentacion': _presentacionController.text,
      'imagen_url': _imagenUrl ?? _imagenBase64,
      'imagen_base64': _imagenBase64,
      'created_at': widget.productoExistente != null ? widget.productoExistente!['created_at'] : DateTime.now().toIso8601String(),
    };

    // Guardar en base de datos local Drift
    await localDb.upsertProductosLocal(
      empresaId: empresaCodigo,
      productos: [producto],
    );

    // También mantener en SharedPreferences para compatibilidad con POS
    List<dynamic> productos = [];
    try {
      final json = prefs.getString('productos') ?? '[]';
      productos = List<dynamic>.from(jsonDecode(json));
    } catch (_) {
      productos = [];
    }

    final idx = productos.indexWhere((p) =>
        (codigo.isNotEmpty && p['codigo'] == codigo) || p['id'] == producto['id']);
    if (idx >= 0) {
      productos[idx] = producto;
    } else {
      productos.add(producto);
    }

    await prefs.setString('productos', jsonEncode(productos));
    
    // También guardar en 'productos_pos' para que el Terminal POS los encuentre
    List<dynamic> productosPos = [];
    try {
      final productosPosJson = prefs.getString('productos_pos') ?? '[]';
      productosPos = List<dynamic>.from(jsonDecode(productosPosJson));
    } catch (_) {
      productosPos = [];
    }
    
    final productoPos = {
      'id': producto['id'],
      'codigo': producto['codigo'],
      'nombre': producto['nombre'],
      'descripcion': producto['descripcion'],
      'categoria': producto['categoria'],
      'unidad_medida': producto['unidad_medida'],
      'precio_compra': producto['precio_compra'],
      'precio_venta': producto['precio_venta'],
      'stock_actual': producto['stock_actual'],
      'stock_minimo': producto['stock_minimo'],
      'bodega': producto['bodega'],
      'isv_rate': producto['isv_rate'],
      'exento': producto['exento'],
      'imagen_base64': producto['imagen_url'],
      'created_at': producto['created_at'],
    };
    
    final idxPos = productosPos.indexWhere((p) =>
        (codigo.isNotEmpty && p['codigo'] == codigo) || p['id'] == producto['id']);
    if (idxPos >= 0) {
      productosPos[idxPos] = productoPos;
    } else {
      productosPos.add(productoPos);
    }
    
    await prefs.setString('productos_pos', jsonEncode(productosPos));

    // Registrar acción en el log de auditoría
    final esEdicion = widget.productoExistente != null;
    Logger().audit(
      esEdicion ? 'editar' : 'crear',
      'producto',
      codigo,
      userId: AuthController.instance.email,
      module: 'inventario',
      changes: {
        'nombre': _nombreController.text,
        'precio_venta': producto['precio_venta'],
        'stock_actual': producto['stock_actual'],
      },
    );

    // La sincronización ya se maneja automáticamente por LocalDatabaseService

    // Sincronizar con backend (Supabase) — no bloquea UI
    try {
      final api = ApiService.instance;
      await api.initialize();
      final backendBody = {
        'codigo': codigo,
        'nombre': producto['nombre'],
        'descripcion': producto['descripcion'],
        'categoria': producto['categoria'],
        'unidad_medida': producto['unidad_medida'],
        'precio_compra': producto['precio_compra'],
        'precio_venta': producto['precio_venta'],
        'stock_actual': producto['stock_actual'],
        'stock_minimo': producto['stock_minimo'],
        'bodega': producto['bodega'],
        'isv_rate': producto['isv_rate'],
        'exento': producto['exento'],
        'barcode': producto['barcode'],
        'marca': producto['marca'],
        'presentacion': producto['presentacion'],
        'imagen_url': _imagenUrl,
      };
      final result = esEdicion
          ? await api.put('/api/productos/$id', body: backendBody)
          : await api.post('/api/productos', body: backendBody);
      if (api.isSuccess(result)) {
        debugPrint('[ProductoForm] Synced to backend: $codigo');
      } else {
        debugPrint('[ProductoForm] Backend sync failed: ${api.getError(result)}');
      }
    } catch (e) {
      debugPrint('[ProductoForm] Backend sync error: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.productoExistente != null ? 'Producto actualizado' : 'Producto guardado', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildImagenPicker() {
    final esUrlRemota = (_imagenUrl ?? '').startsWith('http');
    final base64 = _normalizarBase64(
      _imagenBase64 ?? (esUrlRemota ? null : _imagenUrl),
    );
    final tieneImagen = esUrlRemota || (base64 != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tieneImagen)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFF0F0F0F),
                child: esUrlRemota
                    ? Image.network(
                        _imagenUrl!,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 160,
                          height: 160,
                          color: const Color(0xFF0F0F0F),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFF404040), size: 40),
                        ),
                      )
                    : Image.memory(
                        base64Decode(base64!),
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 160,
                          height: 160,
                          color: const Color(0xFF0F0F0F),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFF404040), size: 40),
                        ),
                      ),
              ),
            ),
          )
        else
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, color: const Color(0xFF404040), size: 36),
                  const SizedBox(height: 6),
                  Text('Sin imagen', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF525252))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isAiAnalyzing ? null : _identificarProductoConIA,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAiAnalyzing)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                    else
                      const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 6),
                    Text(_isAiAnalyzing ? 'Analizando...' : 'IA Identificar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 6),
                    Text(tieneImagen ? 'Cambiar imagen' : 'Agregar imagen', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                  ],
                ),
              ),
            ),
            if (tieneImagen) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() {
                  _imagenBase64 = null;
                  _imagenUrl = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 6),
                      Text('Quitar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.productoExistente != null ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO',
          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: _showScanner ? _buildScannerView() : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Información Básica'),
              const SizedBox(height: 8),
              _buildImagenPicker(),
              const SizedBox(height: 16),
Row(
                children: [
                  Expanded(
                    child: _buildField('Código / SKU', _codigoController, hint: 'Se genera automáticamente si está vacío'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.barcode_reader, color: Color(0xFFF97316), size: 22),
                    onPressed: _escanearCodigo,
                    tooltip: 'Escanear código de barras',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildField('Código de barras', _barcodeController, hint: 'EAN/UPC/GTIN (opcional)'),
              const SizedBox(height: 12),
              _buildField('Nombre del Producto *', _nombreController),
          const SizedBox(height: 12),
          _buildField('Descripción', _descripcionController),
          const SizedBox(height: 16),
          _buildSection('Clasificación'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDropdown('Categoría', _categoria, _categorias, (v) => setState(() => _categoria = v!))),
              const SizedBox(width: 10),
              Expanded(child: _buildDropdown('Unidad', _unidadMedida, _unidades, (v) => setState(() => _unidadMedida = v!))),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdown('Bodega', _bodega, _bodegas, (v) => setState(() => _bodega = v!)),
          const SizedBox(height: 16),
          _buildSection('Precios e ISV'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Precio Compra (L.)', _precioCompraController, keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _buildField('Precio Venta (L.)', _precioVentaController, keyboard: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown('ISV', _isvRate == 15 ? '15%' : _isvRate == 18 ? '18%' : '0%', ['15%', '18%', '0%'], (v) {
                  setState(() {
                    if (v == '18%') {
                      _isvRate = 18;
                    } else if (v == '0%') { _isvRate = 0; _exento = true; }
                    else { _isvRate = 15; _exento = false; }
                  });
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exento de ISV', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: _exento,
                            onChanged: (v) => setState(() {
                              _exento = v;
                              if (v) _isvRate = 0;
                              else if (_isvRate == 0) _isvRate = 15;
                            }),
                            activeThumbColor: const Color(0xFFF59E0B),
                          ),
                          Text(_exento ? 'Sí' : 'No', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection('Stock'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Stock Actual', _stockActualController, keyboard: TextInputType.number,
                help: 'Cantidad que tienes actualmente en bodega.')),
              const SizedBox(width: 10),
              Expanded(child: _buildField('Stock Mínimo', _stockMinimoController, keyboard: TextInputType.number,
                help: 'Umbral de alerta: cuando el stock actual baja de este número, el producto aparece en "stock bajo" para que repongas.')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardarProducto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.productoExistente != null ? 'Actualizar Producto' : 'Guardar Producto',
                style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error de cámara: $error',
                    style: GoogleFonts.dmSans(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cerrarScanner,
                    child: Text('Cerrar', style: GoogleFonts.dmSans()),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Apunte al código de barras del producto',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            onPressed: _cerrarScanner,
            icon: const Icon(Icons.close_rounded),
            label: Text('Cerrar Escáner', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 20,
          child: FloatingActionButton.small(
            heroTag: 'linterna',
            backgroundColor: _torchOn
                ? const Color(0xFFF59E0B)
                : Colors.black.withValues(alpha: 0.6),
            onPressed: _toggleLinterna,
            child: Icon(
              _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF737373), letterSpacing: 0.8),
    );
  }

  void _mostrarAyuda(String titulo, String texto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(titulo, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(texto, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFA3A3A3), height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String hint = '', TextInputType keyboard = TextInputType.text, String? help}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
            ),
            if (help != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _mostrarAyuda(label, help),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF404040)),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 11,
                    color: Color(0xFF737373),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF262626))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
