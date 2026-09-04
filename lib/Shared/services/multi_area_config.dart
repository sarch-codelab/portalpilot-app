// lib/Shared/services/multi_area_config.dart
// Configuración Multi-Área: controla qué módulos/áreas están activos por
// empresa. Combina el área de negocio de la empresa (empresa.area_negocio)
// con feature flags por módulo, persistidos localmente por empresa.
//
// Jerarquía de resolución:
//   1. Si hay flags persistidos para la empresa, se respetan (el admin pudo
//      personalizarlos).
//   2. Si no, se siembran a partir del área de negocio de la empresa.
//   3. Si el área no está en el catálogo, se usan los módulos asignados por el
//      backend; si tampoco hay, se habilitan todos.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

/// Área de negocio de la empresa con sus módulos por defecto.
class AreaNegocio {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final Color color;
  final List<String> modulosPorDefecto;

  const AreaNegocio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.modulosPorDefecto,
  });
}

/// Catálogo estático de áreas de negocio soportadas (Honduras).
class AreasNegocio {
  static const String comercialGenerico = 'comercial_generico';
  static const String retail = 'retail';
  static const String membresias = 'membresias';
  static const String canalTradicional = 'canal_tradicional';
  static const String canalModerno = 'canal_moderno';
  static const String general = 'general';

  static List<String> get todosModulos =>
      Modulo.modulosDisponibles.map((m) => m.id).toList();

  static const List<AreaNegocio> catalogo = [
    AreaNegocio(
      id: comercialGenerico,
      nombre: 'Comercial Genérico',
      descripcion: 'Distribuidoras, mayoristas',
      icono: Icons.local_shipping_rounded,
      color: Color(0xFF6B7280),
      modulosPorDefecto: [
        'comercial',
        'facturacion',
        'inventario',
        'contabilidad',
        'crm',
        'cotizaciones',
      ],
    ),
    AreaNegocio(
      id: retail,
      nombre: 'Retail',
      descripcion: 'Pulperías, abarroterías, supers',
      icono: Icons.store_rounded,
      color: Color(0xFFF59E0B),
      modulosPorDefecto: [
        'pos',
        'facturacion',
        'inventario',
        'crm',
        'contabilidad',
      ],
    ),
    AreaNegocio(
      id: membresias,
      nombre: 'Membresías',
      descripcion: 'PriceSmart, clubes de compra',
      icono: Icons.card_membership_rounded,
      color: Color(0xFF8B5CF6),
      modulosPorDefecto: [
        'membresias',
        'pos',
        'facturacion',
        'inventario',
        'crm',
      ],
    ),
    AreaNegocio(
      id: canalTradicional,
      nombre: 'Canal Tradicional',
      descripcion: 'Mercaditos barrio, fiado',
      icono: Icons.storefront_rounded,
      color: Color(0xFF10B981),
      modulosPorDefecto: [
        'pos',
        'facturacion',
        'crm',
        'inventario',
      ],
    ),
    AreaNegocio(
      id: canalModerno,
      nombre: 'Canal Moderno',
      descripcion: 'Cadenas, multi-sucursal',
      icono: Icons.business_rounded,
      color: Color(0xFF3B82F6),
      modulosPorDefecto: [
        'pos',
        'facturacion',
        'inventario',
        'contabilidad',
        'crm',
      ],
    ),
    AreaNegocio(
      id: general,
      nombre: 'General',
      descripcion: 'Todos los módulos habilitados',
      icono: Icons.grid_view_rounded,
      color: Color(0xFFEC4899),
      modulosPorDefecto: [
        'facturacion',
        'inventario',
        'contabilidad',
        'rrhh',
        'crm',
        'pos',
        'comercial',
        'membresias',
        'cotizaciones',
      ],
    ),
  ];

  /// Devuelve el área por id (o retail por defecto si no existe).
  static AreaNegocio porId(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    for (final area in catalogo) {
      if (area.id == normalized) return area;
    }
    // Fallback a retail para Honduras
    return catalogo.firstWhere((a) => a.id == retail, orElse: () => catalogo.first);
  }

  /// Devuelve los módulos por defecto de un área; lista vacía si es desconocida.
  static List<String> modulosPorDefecto(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    for (final area in catalogo) {
      if (area.id == normalized) {
        return List.unmodifiable(area.modulosPorDefecto);
      }
    }
    return const [];
  }
}

/// Controlador central de la configuración multi-área por empresa.
class MultiAreaConfig extends ChangeNotifier {
  MultiAreaConfig._();
  static final MultiAreaConfig instance = MultiAreaConfig._();

  String _empresaCodigo = '';
  String _areaNegocio = AreasNegocio.retail;
  Set<String> _modulosActivos = {};
  bool _inicializado = false;

  String get empresaCodigo => _empresaCodigo;
  String get areaNegocio => _areaNegocio;
  AreaNegocio get areaInfo => AreasNegocio.porId(_areaNegocio);
  bool get inicializado => _inicializado;
  List<String> get modulosActivos => List.unmodifiable(_modulosActivos);

  String _key(String sufijo) =>
      'multiarea_${_empresaCodigo.toUpperCase()}$sufijo';

  bool moduloActivo(String id) => _modulosActivos.contains(id);

  /// Carga la configuración de la empresa. Si no existe, siembra los defaults
  /// a partir de empresa.area_negocio (o de los módulos asignados).
  Future<void> cargar({
    String? empresaCodigo,
    String? areaNegocio,
    List<String>? modulosAsignados,
  }) async {
    _empresaCodigo = (empresaCodigo ?? AuthController.instance.empresaCodigo)
        .toUpperCase();
    final area = areaNegocio ?? AuthController.instance.empresaAreaNegocio;

    final prefs = await SharedPreferences.getInstance();
    final persistedArea = prefs.getString(_key('_area'));
    final persistedMods = prefs.getString(_key('_mods'));

    if (persistedArea != null && persistedMods != null) {
      _areaNegocio = persistedArea;
      _modulosActivos = persistedMods
          .split(',')
          .where((m) => m.isNotEmpty)
          .toSet();
    } else {
      _areaNegocio = area.trim().toLowerCase();
      final defaults = AreasNegocio.modulosPorDefecto(_areaNegocio);
      if (defaults.isNotEmpty) {
        _modulosActivos = defaults.toSet();
      } else {
        final asignados = (modulosAsignados ?? AuthController.instance.modulos)
            .where(AreasNegocio.todosModulos.contains)
            .toSet();
        _modulosActivos = asignados.isEmpty
            ? AreasNegocio.todosModulos.toSet()
            : asignados;
      }
      await _persist(prefs);
    }

    _inicializado = true;
    notifyListeners();
  }

  /// Cambia el área de negocio y restablece los módulos por defecto del área.
  Future<void> setAreaNegocio(String id) async {
    final area = AreasNegocio.porId(id);
    _areaNegocio = area.id;
    _modulosActivos = area.modulosPorDefecto.toSet();
    await _persist();
    notifyListeners();
  }

  /// Activa o desactiva un módulo (feature flag).
  Future<void> setModuloActivo(String id, bool activo) async {
    if (activo) {
      _modulosActivos.add(id);
    } else {
      _modulosActivos.remove(id);
    }
    await _persist();
    notifyListeners();
  }

  /// Restablece los flags a los módulos por defecto del área actual.
  Future<void> restablecerPorArea() async {
    _modulosActivos = AreasNegocio.modulosPorDefecto(_areaNegocio).toSet();
    if (_modulosActivos.isEmpty) {
      _modulosActivos = AreasNegocio.todosModulos.toSet();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_key('_area'), _areaNegocio);
    await p.setString(_key('_mods'), _modulosActivos.join(','));
  }
}
