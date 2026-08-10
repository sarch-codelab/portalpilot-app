import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de compliance fiscal para Honduras (SAR)
class FiscalCompliance {
  static final FiscalCompliance _instance = FiscalCompliance._internal();
  factory FiscalCompliance() => _instance;
  FiscalCompliance._internal();

  static const String _configKey = 'fiscal_config';

  /// Configuración fiscal
  FiscalConfig? _config;

  /// Cargar configuración
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);
      
      if (configJson != null) {
        _config = FiscalConfig.fromJson(jsonDecode(configJson));
      } else {
        _config = FiscalConfig.defaultConfig();
      }
    } catch (e) {
      print('Error al cargar configuración fiscal: $e');
      _config = FiscalConfig.defaultConfig();
    }
  }

  /// Guardar configuración
  Future<bool> saveConfig(FiscalConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(config.toJson());
      _config = config;
      return await prefs.setString(_configKey, configJson);
    } catch (e) {
      print('Error al guardar configuración fiscal: $e');
      return false;
    }
  }

  /// Obtener configuración actual
  FiscalConfig get config => _config ?? FiscalConfig.defaultConfig();

  /// Validar RTN (Registro Tributario Nacional)
  bool validateRTN(String rtn) {
    // RTN formato: 14 dígitos
    final rtnRegex = RegExp(r'^\d{14}$');
    if (!rtnRegex.hasMatch(rtn)) {
      return false;
    }

    // Validar dígito verificador (algoritmo simplificado)
    // En producción, implementar el algoritmo completo del SAR
    return true;
  }

  /// Validar CAI (Código de Autorización de Impresión)
  bool validateCAI(String cai) {
    // CAI formato: 37 caracteres alfanuméricos
    final caiRegex = RegExp(r'^[A-Z0-9]{37}$');
    return caiRegex.hasMatch(cai);
  }

  /// Validar número de factura
  bool validateInvoiceNumber(String invoiceNumber) {
    // Formato: Efectivo: 0000-0000-00000000
    // Crédito: 0000-0000-00000000-00000000
    final efectivoRegex = RegExp(r'^\d{4}-\d{4}-\d{8}$');
    final creditoRegex = RegExp(r'^\d{4}-\d{4}-\d{8}-\d{8}$');
    
    return efectivoRegex.hasMatch(invoiceNumber) || creditoRegex.hasMatch(invoiceNumber);
  }

  /// Generar número de factura
  String generateInvoiceNumber(bool isCredit) {
    final prefix = config.establecimiento;
    final point = config.puntoEmision;
    final type = isCredit ? '01' : '00'; // 01 = Crédito, 00 = Efectivo
    final sequence = _getNextSequence(type);
    
    if (isCredit) {
      return '$prefix-$point-$type-$sequence';
    } else {
      return '$prefix-$point-$sequence';
    }
  }

  /// Obtener siguiente secuencia
  String _getNextSequence(String type) {
    // En producción, esto debería venir de la base de datos
    // Por ahora, generamos un número aleatorio
    final random = DateTime.now().millisecondsSinceEpoch % 99999999;
    return random.toString().padLeft(8, '0');
  }

  /// Validar límite para exento de ISV
  bool isExemptFromISV(double amount) {
    return amount <= config.limiteExentoISV;
  }

  /// Calcular ISV (Impuesto Sobre Ventas)
  double calculateISV(double amount, {bool isExempt = false}) {
    if (isExempt || isExemptFromISV(amount)) {
      return 0.0;
    }
    return amount * (config.tasaISV / 100);
  }

  /// Validar que una factura cumpla con requisitos fiscales
  Map<String, String> validateInvoiceForFiscal(Map<String, dynamic> invoice) {
    final errors = <String, String>{};

    // Validar RTN del cliente
    if (invoice['cliente_rtn'] != null && !validateRTN(invoice['cliente_rtn'])) {
      errors['cliente_rtn'] = 'RTN inválido';
    }

    // Validar CAI
    if (invoice['cai'] == null || !validateCAI(invoice['cai'])) {
      errors['cai'] = 'CAI inválido o requerido';
    }

    // Validar número de factura
    if (invoice['numero_factura'] == null || !validateInvoiceNumber(invoice['numero_factura'])) {
      errors['numero_factura'] = 'Número de factura inválido';
    }

    // Validar que el CAI no esté expirado
    if (invoice['cai'] != null && config.caiExpiration != null) {
      final now = DateTime.now();
      if (now.isAfter(config.caiExpiration!)) {
        errors['cai'] = 'CAI expirado';
      }
    }

    return errors;
  }

  /// Obtener tasa de ISV según tipo de producto
  double getISVRate(String productType) {
    switch (productType.toLowerCase()) {
      case 'medicinas':
      case 'alimentos_basicos':
        return config.tasaISVExento; // 0%
      case 'tabaco':
      case 'alcohol':
        return config.tasaISVAlto; // 15% o más
      default:
        return config.tasaISV; // 15%
    }
  }
}

/// Configuración fiscal
class FiscalConfig {
  final String rtnEmpresa;
  final String nombreEmpresa;
  final String establecimiento;
  final String puntoEmision;
  final String? cai;
  final DateTime? caiExpiration;
  final double tasaISV;
  final double tasaISVExento;
  final double tasaISVAlto;
  final double limiteExentoISV;
  final bool emitirFacturaElectronica;
  final String regimenTributario;

  FiscalConfig({
    required this.rtnEmpresa,
    required this.nombreEmpresa,
    required this.establecimiento,
    required this.puntoEmision,
    this.cai,
    this.caiExpiration,
    this.tasaISV = 15.0,
    this.tasaISVExento = 0.0,
    this.tasaISVAlto = 15.0,
    this.limiteExentoISV = 1000.0,
    this.emitirFacturaElectronica = false,
    this.regimenTributario = 'QR',
  });

  factory FiscalConfig.defaultConfig() {
    return FiscalConfig(
      rtnEmpresa: '',
      nombreEmpresa: '',
      establecimiento: '0000',
      puntoEmision: '0000',
      tasaISV: 15.0,
      tasaISVExento: 0.0,
      tasaISVAlto: 15.0,
      limiteExentoISV: 1000.0,
      emitirFacturaElectronica: false,
      regimenTributario: 'QR',
    );
  }

  factory FiscalConfig.fromJson(Map<String, dynamic> json) {
    return FiscalConfig(
      rtnEmpresa: json['rtn_empresa'] ?? '',
      nombreEmpresa: json['nombre_empresa'] ?? '',
      establecimiento: json['establecimiento'] ?? '0000',
      puntoEmision: json['punto_emision'] ?? '0000',
      cai: json['cai'],
      caiExpiration: json['cai_expiration'] != null 
          ? DateTime.parse(json['cai_expiration']) 
          : null,
      tasaISV: (json['tasa_isv'] as num?)?.toDouble() ?? 15.0,
      tasaISVExento: (json['tasa_isv_exento'] as num?)?.toDouble() ?? 0.0,
      tasaISVAlto: (json['tasa_isv_alto'] as num?)?.toDouble() ?? 15.0,
      limiteExentoISV: (json['limite_exento_isv'] as num?)?.toDouble() ?? 1000.0,
      emitirFacturaElectronica: json['emitir_factura_electronica'] ?? false,
      regimenTributario: json['regimen_tributario'] ?? 'QR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rtn_empresa': rtnEmpresa,
      'nombre_empresa': nombreEmpresa,
      'establecimiento': establecimiento,
      'punto_emision': puntoEmision,
      'cai': cai,
      'cai_expiration': caiExpiration?.toIso8601String(),
      'tasa_isv': tasaISV,
      'tasa_isv_exento': tasaISVExento,
      'tasa_isv_alto': tasaISVAlto,
      'limite_exento_isv': limiteExentoISV,
      'emitir_factura_electronica': emitirFacturaElectronica,
      'regimen_tributario': regimenTributario,
    };
  }

  FiscalConfig copyWith({
    String? rtnEmpresa,
    String? nombreEmpresa,
    String? establecimiento,
    String? puntoEmision,
    String? cai,
    DateTime? caiExpiration,
    double? tasaISV,
    double? tasaISVExento,
    double? tasaISVAlto,
    double? limiteExentoISV,
    bool? emitirFacturaElectronica,
    String? regimenTributario,
  }) {
    return FiscalConfig(
      rtnEmpresa: rtnEmpresa ?? this.rtnEmpresa,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      establecimiento: establecimiento ?? this.establecimiento,
      puntoEmision: puntoEmision ?? this.puntoEmision,
      cai: cai ?? this.cai,
      caiExpiration: caiExpiration ?? this.caiExpiration,
      tasaISV: tasaISV ?? this.tasaISV,
      tasaISVExento: tasaISVExento ?? this.tasaISVExento,
      tasaISVAlto: tasaISVAlto ?? this.tasaISVAlto,
      limiteExentoISV: limiteExentoISV ?? this.limiteExentoISV,
      emitirFacturaElectronica: emitirFacturaElectronica ?? this.emitirFacturaElectronica,
      regimenTributario: regimenTributario ?? this.regimenTributario,
    );
  }
}