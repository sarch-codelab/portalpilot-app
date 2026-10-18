import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/module_registry.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

/// Gestor central de módulos: sincroniza suscripción (WEB) ↔ módulos activos (APP)
///
/// Funciones:
/// - Recibe lista de webIds activos desde la WEB (cotizador, backend, Supabase)
/// - Los traduce a módulos app reales usando ModuleRegistry
/// - Controla visibilidad en HomeScreen, navegación y permisos
/// - Persiste estado local para modo offline
/// - Notifica cambios a listeners (HomeScreen, menús, etc.)

class ModuleManager extends ChangeNotifier {
  ModuleManager._();
  static final ModuleManager instance = ModuleManager._();

  static const String _prefsKeyActiveWebModules = 'active_web_module_ids';
  static const String _prefsKeySubscriptionData = 'subscription_data';
  static const String _prefsKeyLastSync = 'modules_last_sync';

  // Estado interno
  Set<String> _activeWebModuleIds = {};
  // IDs de app del backend sin equivalente web (ej. 'settings'): se conservan
  // aparte porque no pueden representarse en el set de webIds.
  Set<String> _extraAppModuleIds = {};
  Map<String, dynamic> _subscriptionData = {};
  DateTime? _lastSync;
  bool _initialized = false;

  // Getters públicos
  Set<String> get activeWebModuleIds => Set.unmodifiable(_activeWebModuleIds);
  Set<String> get activeExtraAppModuleIds =>
      Set.unmodifiable(_extraAppModuleIds);
  Map<String, dynamic> get subscriptionData =>
      Map.unmodifiable(_subscriptionData);
  DateTime? get lastSync => _lastSync;
  bool get isInitialized => _initialized;

  /// Módulos app actualmente activos (derivados de webIds + extras)
  List<Modulo> get activeAppModules {
    final appIds = activeAppModuleIds;
    return Modulo.modulosDisponibles
        .where((m) => appIds.contains(m.id))
        .toList();
  }

  /// IDs de módulos app activos
  Set<String> get activeAppModuleIds {
    final ids = _activeWebModuleIds
        .map(ModuleRegistry.getAppId)
        .whereType<String>()
        .toSet();
    ids.addAll(_extraAppModuleIds);
    return ids;
  }

  /// Verifica si un módulo web está activo
  bool isWebModuleActive(String webId) => _activeWebModuleIds.contains(webId);

  /// Verifica si un módulo app está activo
  bool isAppModuleActive(String appId) => activeAppModuleIds.contains(appId);

  /// El acceso se basa en módulos asignados, no en fallbacks de presentación.
  /// Los módulos de soporte y diagnóstico están disponibles en todos los planes.
  bool isAppModuleAllowed(String appId) {
    if (AuthController.instance.esRoot) return true;
    if (const {'settings', 'soporte', 'estado_sistema'}.contains(appId)) {
      return true;
    }
    final requiredFeature = moduloFeatureRequerida[appId];
    return isAppModuleActive(appId) &&
        (requiredFeature == null ||
            AuthController.instance.tieneFeature(requiredFeature));
  }

  /// Verifica si un módulo web está disponible Y activo
  bool isWebModuleAvailableAndActive(String webId) {
    return ModuleRegistry.isWebModuleAvailable(webId) &&
        isWebModuleActive(webId);
  }

  /// Inicializa: carga estado persistido y aplica suscripción actual del AuthController
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadFromPrefs();
    await _applyCurrentSubscription();
    _initialized = true;
    notifyListeners();
  }

  /// Carga estado desde SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final webIdsJson = prefs.getString(_prefsKeyActiveWebModules);
      if (webIdsJson != null) {
        final List<dynamic> decoded = jsonDecode(webIdsJson);
        _activeWebModuleIds = decoded.cast<String>().toSet();
      }
      final subJson = prefs.getString(_prefsKeySubscriptionData);
      if (subJson != null) {
        _subscriptionData = Map<String, dynamic>.from(jsonDecode(subJson));
        final extras = _subscriptionData['modulosAppExtra'];
        if (extras is List) _extraAppModuleIds = extras.cast<String>().toSet();
      }
      final lastSyncStr = prefs.getString(_prefsKeyLastSync);
      if (lastSyncStr != null) {
        _lastSync = DateTime.tryParse(lastSyncStr);
      }
    } catch (e) {
      debugPrint('⚠️ ModuleManager: Error cargando prefs: $e');
    }
  }

  /// Guarda estado en SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyActiveWebModules,
        jsonEncode(_activeWebModuleIds.toList()),
      );
      await prefs.setString(
        _prefsKeySubscriptionData,
        jsonEncode(_subscriptionData),
      );
      if (_lastSync != null) {
        await prefs.setString(_prefsKeyLastSync, _lastSync!.toIso8601String());
      }
    } catch (e) {
      debugPrint('⚠️ ModuleManager: Error guardando prefs: $e');
    }
  }

  /// Aplica la suscripción actual desde AuthController (source of truth)
  Future<void> _applyCurrentSubscription() async {
    final auth = AuthController.instance;
    // AuthController no tiene propiedad 'inicializado', pero restore() se llama al arranque
    // Si modulos está vacío, puede que la sesión no se haya restaurado aún
    if (auth.modulos.isEmpty && auth.isLoggedIn) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Obtener módulos desde AuthController (vienen del backend/Supabase)
    final List<String> modulosBackend = auth.modulos.isNotEmpty
        ? auth.modulos
        : auth.esRoot
        ? ModuleRegistry.webModuleIdsInOrder
        : const [];

    // El backend entrega IDs de APP (pos, canal_tradicional, contabilidad...)
    // mientras que este manager trabaja con IDs WEB (pos_caja, cuentas_por_cobrar...).
    // Se aceptan los dos: si es un webId válido se toma tal cual; si es un appId
    // se traduce a sus webIds; y si no tiene equivalente web (ej. 'settings')
    // se conserva como extra. Sin esta traducción el set quedaba vacío y el Home
    // caía al fallback hardcodeado, ocultando los módulos contratados.
    final validWebIds = <String>{};
    final extraAppIds = <String>{};
    for (final id in modulosBackend) {
      if (ModuleRegistry.isWebModuleAvailable(id)) {
        validWebIds.add(id);
        continue;
      }
      final webIds = ModuleRegistry.getWebIds(
        id,
      ).where(ModuleRegistry.isWebModuleAvailable).toList();
      if (webIds.isNotEmpty) {
        validWebIds.addAll(webIds);
      } else if (Modulo.modulosDisponibles.any((m) => m.id == id)) {
        extraAppIds.add(id);
      }
    }

    final changed =
        !_setsEqual(_activeWebModuleIds, validWebIds) ||
        !_setsEqual(_extraAppModuleIds, extraAppIds);
    _activeWebModuleIds = validWebIds;
    _extraAppModuleIds = extraAppIds;

    if (changed) {
      _subscriptionData = {
        'plan': auth.empresaPlan,
        'features': auth.features,
        'esRoot': auth.esRoot,
        'empresaCodigo': auth.empresaCodigo,
        'modulosAppExtra': _extraAppModuleIds.toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      _lastSync = DateTime.now();
      await _saveToPrefs();
      notifyListeners();
      debugPrint(
        '✅ ModuleManager: Suscripción aplicada - '
        '${_activeWebModuleIds.length} web + ${_extraAppModuleIds.length} extra activos',
      );
    }
  }

  /// Sincroniza forzadamente con el backend (llamar tras login, cambio de plan, webhook)
  Future<void> syncWithBackend() async {
    await _applyCurrentSubscription();
  }

  /// Activa módulos web manualmente (para testing, admin, cotizador local)
  Future<void> activateWebModules(Iterable<String> webIds) async {
    final validIds = webIds.where(ModuleRegistry.isWebModuleAvailable).toSet();
    if (!_setsEqual(_activeWebModuleIds, validIds)) {
      _activeWebModuleIds = validIds;
      _lastSync = DateTime.now();
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Desactiva módulos web
  Future<void> deactivateWebModules(Iterable<String> webIds) async {
    final toRemove = webIds.toSet();
    _activeWebModuleIds.removeAll(toRemove);
    _lastSync = DateTime.now();
    await _saveToPrefs();
    notifyListeners();
  }

  /// Activa/desactiva un solo módulo web
  Future<void> toggleWebModule(String webId, {required bool active}) async {
    if (!ModuleRegistry.isWebModuleAvailable(webId)) return;
    if (active) {
      _activeWebModuleIds.add(webId);
    } else {
      _activeWebModuleIds.remove(webId);
    }
    _lastSync = DateTime.now();
    await _saveToPrefs();
    notifyListeners();
  }

  /// Aplica preset de plan (pulperia, tienda, club, all, none)
  Future<void> applyPreset(String preset) async {
    Set<String> newWebIds = {};

    switch (preset) {
      case 'pulperia':
        newWebIds = {
          'pos_caja',
          'cuentas_por_cobrar',
          'inventario_basico',
          'facturacion_sar',
          'contabilidad_pyme',
        };
        break;
      case 'tienda':
        newWebIds = {
          'pos_caja',
          'retail_pasillos',
          'control_caja',
          'facturacion_sar',
          'inventario_basico',
          'clientes_proveedores',
          'cotizaciones',
          'reportes_comerciales',
        };
        break;
      case 'club':
        newWebIds = {
          'pos_caja',
          'gestion_membresias',
          'control_caja',
          'facturacion_sar',
          'inventario_basico',
          'fidelizacion_puntos',
          'seguridad_2fa',
        };
        break;
      case 'all':
        newWebIds = ModuleRegistry.webModuleIdsInOrder.toSet();
        break;
      case 'none':
        newWebIds = {};
        break;
    }

    // Filtrar solo disponibles
    newWebIds = newWebIds.where(ModuleRegistry.isWebModuleAvailable).toSet();

    if (!_setsEqual(_activeWebModuleIds, newWebIds)) {
      _activeWebModuleIds = newWebIds;
      _lastSync = DateTime.now();
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Obtiene módulos app activos ordenados para HomeScreen
  List<Modulo> getActiveModulesForHome() {
    final activeIds = activeAppModuleIds;
    return Modulo.modulosDisponibles
        .where((m) => activeIds.contains(m.id))
        .toList();
  }

  /// Filtra módulos disponibles según suscripción actual (para HomeScreen._applySession)
  List<Modulo> filterModulesForSubscription(List<Modulo> allModules) {
    final activeIds = activeAppModuleIds;
    return allModules.where((m) => activeIds.contains(m.id)).toList();
  }

  /// Obtiene resumen para dock de cotización (compatibilidad con planes.html)
  Map<String, dynamic> getQuotationSummary() {
    final count = _activeWebModuleIds.length;
    final total = ModuleRegistry.webModuleIdsInOrder.length;

    // Calcular precio mensual basado en precios de planes.html
    int modulesSum = 0;
    for (final webId in _activeWebModuleIds) {
      modulesSum += _getWebModulePrice(webId);
    }

    const int basePrice = 150; // L. 150 base cloud
    int discountRate = 0;
    if (count >= 16) {
      discountRate = 25;
    } else if (count >= 10) {
      discountRate = 15;
    } else if (count >= 5) {
      discountRate = 10;
    }

    final discountAmount = (modulesSum * discountRate / 100).round();
    final monthlyFinal = basePrice + modulesSum - discountAmount;

    return {
      'count': count,
      'total': total,
      'modulesSum': modulesSum,
      'basePrice': basePrice,
      'discountRate': discountRate,
      'discountAmount': discountAmount,
      'monthlyTotal': monthlyFinal,
      'annualTotal': monthlyFinal * 10, // 10 meses = 1 año
    };
  }

  /// Precios mensuales de modules.html (en Lempiras)
  int _getWebModulePrice(String webId) {
    const prices = <String, int>{
      'pos_caja': 45,
      'cuentas_por_cobrar': 35,
      'control_caja': 40,
      'facturacion_sar': 70,
      'inventario_basico': 65,
      'retail_pasillos': 60,
      'gestion_membresias': 95,
      'clientes_proveedores': 60,
      'cotizaciones': 35,
      'crm_clientes': 40,
      'fidelizacion_puntos': 55,
      'contabilidad_pyme': 85,
      'rrhh_planillas': 85,
      'rutas_delivery': 90,
      'transferencias_bodega': 85,
      'multi_sucursal': 110,
      'chat_ia_groq': 120,
      'reportes_comerciales': 55,
      'analytics_ventas': 95,
      'seguridad_2fa': 50,
      'automatizacion_alertas': 65,
    };
    return prices[webId] ?? 0;
  }

  /// Exporta configuración para sincronizar con WEB (planes.html)
  Map<String, dynamic> exportForWeb() {
    return {
      'activeWebModuleIds': _activeWebModuleIds.toList(),
      'subscriptionData': _subscriptionData,
      'lastSync': _lastSync?.toIso8601String(),
      'quotationSummary': getQuotationSummary(),
      'appModuleIds': activeAppModuleIds.toList(),
    };
  }

  /// Importa configuración desde WEB (planes.html, backend, webhook)
  Future<void> importFromWeb(Map<String, dynamic> data) async {
    if (data['activeWebModuleIds'] is List) {
      final List<String> webIds = (data['activeWebModuleIds'] as List)
          .cast<String>();
      await activateWebModules(webIds);
    }
    if (data['subscriptionData'] is Map) {
      _subscriptionData = Map<String, dynamic>.from(data['subscriptionData']);
    }
    if (data['lastSync'] is String) {
      _lastSync = DateTime.tryParse(data['lastSync']);
    }
    await _saveToPrefs();
    notifyListeners();
  }

  /// Limpia todo (logout, reset)
  Future<void> clear() async {
    _activeWebModuleIds.clear();
    _extraAppModuleIds.clear();
    _subscriptionData.clear();
    _lastSync = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyActiveWebModules);
    await prefs.remove(_prefsKeySubscriptionData);
    await prefs.remove(_prefsKeyLastSync);
    notifyListeners();
  }

  bool _setsEqual<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
