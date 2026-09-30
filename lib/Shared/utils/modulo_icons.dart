// lib/Shared/utils/modulo_icons.dart
// Iconos de marca (PNG) por módulo. Devuelve null si el módulo aún no tiene
// un PNG propio y debe seguir usando el IconData de Material.

String? moduloIconAsset(String moduleId) {
  switch (moduleId) {
    case 'inventario':
      return 'img/Iconos/Inventario.png';
    case 'pos':
      return 'img/Iconos/punto_de_venta.png';
    case 'contabilidad':
      return 'img/Iconos/Contabilidad.png';
  }
  return null;
}