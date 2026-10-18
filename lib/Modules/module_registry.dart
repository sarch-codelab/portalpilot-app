import 'package:portal_pilot_app/Shared/models/modulo.dart';

/// Registro único que conecta los 21 módulos de la WEB (planes.html)
/// con los módulos REALES implementados en la APP (lib/Modules/).
///
/// La WEB usa IDs de marketing (pos_caja, facturacion_sar, etc.)
/// La APP usa IDs técnicos (pos, facturacion, etc.)
/// Este registro es la ÚNICA fuente de verdad para el mapeo.

class ModuleRegistry {
  ModuleRegistry._();
  static final ModuleRegistry instance = ModuleRegistry._();

  /// Mapa: Web ID (de planes.html) → App Module ID (de modulo.dart)
  static const Map<String, String> webToAppId = {
    // Módulos base - mapeo directo 1:1
    'pos_caja': 'pos',
    'cuentas_por_cobrar': 'canal_tradicional',
    'control_caja': 'pos', // El control de caja está dentro del POS
    'facturacion_sar': 'facturacion',
    'inventario_basico': 'inventario',
    'retail_pasillos': 'canal_moderno', // Canal Moderno = Sector Retail + Retail
    'gestion_membresias': 'membresias',
    'clientes_proveedores': 'compras_proveedores',
    'cotizaciones': 'cotizaciones',
    'crm_clientes': 'crm', // CRM básico; CRMAdvanced es módulo separado
    'fidelizacion_puntos': 'membresias', // Fidelización vive dentro de Membresías
    'contabilidad_pyme': 'contabilidad',
    'rrhh_planillas': 'rrhh',
    'rutas_delivery': 'supply_chain', // Rutas = parte de SupplyChain
    'transferencias_bodega': 'supply_chain', // Transferencias = parte de SupplyChain
    'multi_sucursal': 'multi_empresa',
    'chat_ia_groq': 'chat_ia',
    'reportes_comerciales': 'analytics', // Reportes comerciales = Analytics
    'analytics_ventas': 'analytics', // BI = Analytics
    'seguridad_2fa': 'seguridad',
    'automatizacion_alertas': 'comercial', // Automatizaciones viven en Comercial/Analytics
    // NUEVO: Google Sheets (no está en planes.html original, es módulo de integración)
    'sheets': 'google_sheets',
  };

  /// Mapa inverso: App Module ID → Web IDs (para sincronizar desde la app)
  static const Map<String, List<String>> appToWebIds = {
    'pos': ['pos_caja', 'control_caja'],
    'canal_tradicional': ['cuentas_por_cobrar'],
    'facturacion': ['facturacion_sar'],
    'inventario': ['inventario_basico'],
    'canal_moderno': ['retail_pasillos'],
    'membresias': ['gestion_membresias', 'fidelizacion_puntos'],
    'compras_proveedores': ['clientes_proveedores'],
    'cotizaciones': ['cotizaciones'],
    'crm': ['crm_clientes'],
    'contabilidad': ['contabilidad_pyme'],
    'rrhh': ['rrhh_planillas'],
    'supply_chain': ['rutas_delivery', 'transferencias_bodega'],
    'multi_empresa': ['multi_sucursal'],
    'chat_ia': ['chat_ia_groq'],
    'analytics': ['reportes_comerciales', 'analytics_ventas'],
    'seguridad': ['seguridad_2fa'],
    'comercial': ['automatizacion_alertas'],
    // NUEVO: Google Sheets
    'google_sheets': ['sheets'],
  };

  /// Obtiene el App Module ID desde un Web ID
  static String? getAppId(String webId) => webToAppId[webId];

  /// Obtiene los Web IDs que corresponden a un App Module ID
  static List<String> getWebIds(String appId) => appToWebIds[appId] ?? [];

  /// Verifica si un módulo web está disponible en la app
  static bool isWebModuleAvailable(String webId) {
    final appId = getAppId(webId);
    if (appId == null) return false;
    return Modulo.modulosDisponibles.any((m) => m.id == appId);
  }

  /// Obtiene el objeto Modulo real de la app desde un Web ID
  static Modulo? getAppModule(String webId) {
    final appId = getAppId(webId);
    if (appId == null) return null;
    try {
      return Modulo.modulosDisponibles.firstWhere((m) => m.id == appId);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene todos los módulos web que mapean a un módulo app específico
  static List<String> getWebModulesForAppModule(String appId) {
    return appToWebIds[appId] ?? [];
  }

  /// Verifica si un módulo app tiene módulos web asociados
  static bool appModuleHasWebMapping(String appId) {
    return appToWebIds.containsKey(appId) && appToWebIds[appId]!.isNotEmpty;
  }

  /// Obtiene la lista de los 21 web IDs en orden (para UI del cotizador)
  static const List<String> webModuleIdsInOrder = [
    'pos_caja',
    'cuentas_por_cobrar',
    'control_caja',
    'facturacion_sar',
    'inventario_basico',
    'retail_pasillos',
    'gestion_membresias',
    'clientes_proveedores',
    'cotizaciones',
    'crm_clientes',
    'fidelizacion_puntos',
    'contabilidad_pyme',
    'rrhh_planillas',
    'rutas_delivery',
    'transferencias_bodega',
    'multi_sucursal',
    'chat_ia_groq',
    'reportes_comerciales',
    'analytics_ventas',
    'seguridad_2fa',
    'automatizacion_alertas',
    // NUEVO: Google Sheets (módulo de integración)
    'sheets',
  ];

  /// Obtiene los módulos app únicos que cubren los 21 web modules
  static List<String> getUniqueAppModulesForWeb() {
    final Set<String> uniqueAppIds = {};
    for (final webId in webModuleIdsInOrder) {
      final appId = getAppId(webId);
      if (appId != null) uniqueAppIds.add(appId);
    }
    return uniqueAppIds.toList();
  }

  /// Genera configuración por defecto para un módulo web basada en su módulo app
  static Map<String, dynamic> defaultConfigForWebModule(String webId) {
    final appModule = getAppModule(webId);
    if (appModule == null) return {};
    return {
      'webId': webId,
      'appId': appModule.id,
      'enabled': true,
      'config': appModule.configuracion ?? {},
    };
  }
}

/// Extension para facilitar uso en UI
extension ModuleRegistryExt on String {
  /// Si este string es un webId, retorna el appId correspondiente
  String? get asAppId => ModuleRegistry.getAppId(this);

  /// Si este string es un appId, retorna los webIds correspondientes
  List<String> get asWebIds => ModuleRegistry.getWebIds(this);

  /// Retorna el Modulo real de la app
  Modulo? get asAppModule => ModuleRegistry.getAppModule(this);

  /// Verifica si está disponible en la app
  bool get isAvailableInApp => ModuleRegistry.isWebModuleAvailable(this);
}