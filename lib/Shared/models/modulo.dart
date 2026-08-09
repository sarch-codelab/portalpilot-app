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
  ];
}
