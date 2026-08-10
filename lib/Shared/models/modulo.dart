import 'package:flutter/material.dart';

class Modulo {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String ruta;
  final bool activo;
  final Map<String, dynamic>? configuracion;

  const Modulo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.ruta,
    this.activo = true,
    this.configuracion,
  });

  factory Modulo.fromJson(Map<String, dynamic> json) {
    return Modulo(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      icono: _iconoFromId(json['id'] ?? ''),
      color: _colorFromId(json['id'] ?? ''),
      ruta: json['ruta'] ?? '',
      activo: json['activo'] ?? true,
      configuracion: json['configuracion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'ruta': ruta,
      'activo': activo,
      'configuracion': configuracion,
    };
  }

  static IconData _iconoFromId(String id) {
    switch (id) {
      case 'educacion':
        return Icons.school_rounded;
      case 'facturacion':
        return Icons.receipt_long_rounded;
      case 'inventario':
        return Icons.inventory_2_rounded;
      case 'contabilidad':
        return Icons.account_balance_rounded;
      case 'rrhh':
        return Icons.people_rounded;
      case 'crm':
        return Icons.contacts_rounded;
      case 'pos':
        return Icons.point_of_sale_rounded;
      case 'compras_proveedores':
        return Icons.shopping_cart_rounded;
      case 'cotizaciones':
        return Icons.request_quote_rounded;
      case 'membresias':
        return Icons.card_membership_rounded;
      case 'canal_moderno':
        return Icons.account_balance_rounded;
      case 'canal_tradicional':
        return Icons.route_rounded;
      case 'comercial':
        return Icons.storefront_rounded;
      case 'sector_retail':
        return Icons.store_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'supply_chain':
        return Icons.local_shipping_rounded;
      case 'crm_advanced':
        return Icons.groups_rounded;
      case 'fiscal_advanced':
        return Icons.gavel_rounded;
      case 'seguridad':
        return Icons.security_rounded;
      case 'multi_empresa':
        return Icons.business_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  static Color _colorFromId(String id) {
    switch (id) {
      case 'educacion':
        return const Color(0xFF8B5CF6);
      case 'facturacion':
        return const Color(0xFF10B981);
      case 'inventario':
        return const Color(0xFFF59E0B);
      case 'contabilidad':
        return const Color(0xFF3B82F6);
      case 'rrhh':
        return const Color(0xFFEC4899);
      case 'crm':
        return const Color(0xFF06B6D4);
      case 'pos':
        return const Color(0xFFF97316);
      case 'compras_proveedores':
        return const Color(0xFF14B8A6);
      case 'cotizaciones':
        return const Color(0xFFF43F5E);
      case 'membresias':
        return const Color(0xFF8B5CF6);
      case 'canal_moderno':
        return const Color(0xFF3B82F6);
      case 'canal_tradicional':
        return const Color(0xFF8B5CF6);
      case 'comercial':
        return const Color(0xFF6B7280);
      case 'sector_retail':
        return const Color(0xFFEC4899);
      case 'settings':
        return const Color(0xFF6B7280);
      case 'analytics':
        return const Color(0xFF6366F1);
      case 'supply_chain':
        return const Color(0xFF14B8A6);
      case 'crm_advanced':
        return const Color(0xFF8B5CF6);
      case 'fiscal_advanced':
        return const Color(0xFFDC2626);
      case 'seguridad':
        return const Color(0xFF6366F1);
      case 'multi_empresa':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6366F1);
    }
  }

  static List<Modulo> modulosDisponibles = const [
    Modulo(
      id: 'educacion',
      nombre: 'Educación',
      descripcion: 'Notas, matrícula, asistencia',
      icono: Icons.school_rounded,
      color: Color(0xFF8B5CF6),
      ruta: '/modules/educacion',
    ),
    Modulo(
      id: 'facturacion',
      nombre: 'Facturación',
      descripcion: 'Facturación SAR electrónica',
      icono: Icons.receipt_long_rounded,
      color: Color(0xFF10B981),
      ruta: '/modules/facturacion',
    ),
    Modulo(
      id: 'inventario',
      nombre: 'Inventario',
      descripcion: 'Productos, kardex, bodegas',
      icono: Icons.inventory_2_rounded,
      color: Color(0xFFF59E0B),
      ruta: '/modules/inventario',
    ),
    Modulo(
      id: 'contabilidad',
      nombre: 'Contabilidad',
      descripcion: 'Estados financieros, transacciones',
      icono: Icons.account_balance_rounded,
      color: Color(0xFF3B82F6),
      ruta: '/modules/contabilidad',
    ),
    Modulo(
      id: 'rrhh',
      nombre: 'RRHH / Nómina',
      descripcion: 'Empleados, planilla, beneficios',
      icono: Icons.people_rounded,
      color: Color(0xFFEC4899),
      ruta: '/modules/rrhh',
    ),
    Modulo(
      id: 'crm',
      nombre: 'CRM',
      descripcion: 'Clientes, ventas, seguimiento',
      icono: Icons.contacts_rounded,
      color: Color(0xFF06B6D4),
      ruta: '/modules/crm',
    ),
    Modulo(
      id: 'pos',
      nombre: 'Punto de Venta',
      descripcion: 'POS, cobros, código de barras',
      icono: Icons.point_of_sale_rounded,
      color: Color(0xFFF97316),
      ruta: '/modules/pos',
    ),
    Modulo(
      id: 'comercial',
      nombre: 'Comercial',
      descripcion: 'Compras, proveedores, cotizaciones, OC',
      icono: Icons.storefront_rounded,
      color: Color(0xFF6B7280),
      ruta: '/modules/comercial',
    ),
    Modulo(
      id: 'membresias',
      nombre: 'Membresías',
      descripcion: 'Socios, precios preferenciales, vigencias',
      icono: Icons.card_membership_rounded,
      color: Color(0xFF8B5CF6),
      ruta: '/modules/membresias',
    ),
    Modulo(
      id: 'canal_moderno',
      nombre: 'Canal Moderno',
      descripcion: 'Multi-sucursal, transferencias, consolidado',
      icono: Icons.account_balance_rounded,
      color: Color(0xFF3B82F6),
      ruta: '/modules/canal_moderno',
    ),
    Modulo(
      id: 'canal_tradicional',
      nombre: 'Canal Tradicional',
      descripcion: 'Fiado, rutas de reparto',
      icono: Icons.route_rounded,
      color: Color(0xFF8B5CF6),
      ruta: '/modules/canal_tradicional',
    ),
    Modulo(
      id: 'cotizaciones',
      nombre: 'Cotizaciones',
      descripcion: 'Cotizaciones a clientes, conversión a ventas',
      icono: Icons.request_quote_rounded,
      color: Color(0xFFF43F5E),
      ruta: '/modules/cotizaciones',
    ),
    Modulo(
      id: 'compras_proveedores',
      nombre: 'Compras y Proveedores',
      descripcion: 'Órdenes de compra, recepción, costeo',
      icono: Icons.shopping_cart_rounded,
      color: Color(0xFF14B8A6),
      ruta: '/modules/compras_proveedores',
    ),
    Modulo(
      id: 'sector_retail',
      nombre: 'Sector Retail',
      descripcion: 'Precios por canal, promociones, inventario por tienda',
      icono: Icons.store_rounded,
      color: Color(0xFFEC4899),
      ruta: '/modules/sector_retail',
    ),
    Modulo(
      id: 'settings',
      nombre: 'Configuración',
      descripcion: 'Configuración fiscal, backups, logs del sistema',
      icono: Icons.settings_rounded,
      color: Color(0xFF6B7280),
      ruta: '/modules/settings',
    ),
    Modulo(
      id: 'analytics',
      nombre: 'Analytics & BI',
      descripcion: 'Dashboards gerenciales, KPIs, forecasting',
      icono: Icons.analytics_rounded,
      color: Color(0xFF6366F1),
      ruta: '/modules/analytics',
    ),
    Modulo(
      id: 'supply_chain',
      nombre: 'Cadena de Suministro',
      descripcion: 'Recepción, trazabilidad, multi-bodega',
      icono: Icons.local_shipping_rounded,
      color: Color(0xFF14B8A6),
      ruta: '/modules/supply_chain',
    ),
    Modulo(
      id: 'crm_advanced',
      nombre: 'CRM Avanzado',
      descripcion: 'Leads, oportunidades, campañas, segmentación',
      icono: Icons.groups_rounded,
      color: Color(0xFF8B5CF6),
      ruta: '/modules/crm_advanced',
    ),
    Modulo(
      id: 'fiscal_advanced',
      nombre: 'Fiscal Avanzado',
      descripcion: 'Retenciones, libros contables, facturación electrónica',
      icono: Icons.gavel_rounded,
      color: Color(0xFFDC2626),
      ruta: '/modules/fiscal_advanced',
    ),
    Modulo(
      id: 'seguridad',
      nombre: 'Seguridad',
      descripcion: 'Roles granulares, auditoría, 2FA',
      icono: Icons.security_rounded,
      color: Color(0xFF6366F1),
      ruta: '/modules/seguridad',
    ),
    Modulo(
      id: 'multi_empresa',
      nombre: 'Multi-Empresa',
      descripcion: 'Holding, filiales, consolidado, tipo de cambio',
      icono: Icons.business_rounded,
      color: Color(0xFFEC4899),
      ruta: '/modules/multi_empresa',
    ),
  ];
}
