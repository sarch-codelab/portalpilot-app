// lib/Shared/services/catalogos_service.dart
// Catalogos maestro del tenant (categorias, marcas y pasillos).
//
// Estos listados reemplazan las listas fijas que vivian dentro de las
// pantallas: el backend es la fuente de verdad y cada registro esta acotado
// por empresa, asi que un usuario nunca ve categorias de otro tenant.
//
// Reglas:
//  - Un fallo (sin red, timeout, 403 por plan, 500) devuelve lista vacia.
//    La pantalla decide si eso es un error visible o un simple "aun no hay".
//  - `id` es el UUID de la fila; `null` significa opcion suelta/offline que
//    todavia no existe en el catalogo del servidor.

import 'package:portal_pilot_app/Shared/services/api_service.dart';

/// Una opcion de catalogo lista para pintar en un selector.
class OpcionCatalogo {
  final String? id;
  final String nombre;

  const OpcionCatalogo({this.id, required this.nombre});

  factory OpcionCatalogo.desdeFila(Map<String, dynamic> fila, String clave) {
    final nombre = (fila[clave] ?? fila['nombre'] ?? '').toString().trim();
    final id = fila['id']?.toString();
    return OpcionCatalogo(
      id: (id == null || id.isEmpty || id == 'null') ? null : id,
      nombre: nombre.isEmpty ? 'Sin nombre' : nombre,
    );
  }
}

class CatalogosService {
  CatalogosService._privateConstructor();
  static final CatalogosService instance = CatalogosService._privateConstructor();

  /// Lee un catalogo del servidor. [envoltura] es la clave del JSON porque no
  /// todos los endpoints devuelven la misma: los catalogos maestro usan
  /// `catalogo` y los pasillos usan `pasillos`.
  Future<List<OpcionCatalogo>> _leer(
    String ruta, {
    required String envoltura,
    String clave = 'nombre',
  }) async {
    try {
      final data = await ApiService.instance.get(
        '/api/$ruta',
        queryParams: {'todos': '1'},
      );
      final lista = data[envoltura];
      if (lista is! List) return const [];

      final out = <OpcionCatalogo>[];
      for (final item in lista) {
        if (item is Map) {
          out.add(OpcionCatalogo.desdeFila(Map<String, dynamic>.from(item), clave));
        }
      }
      out.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return out;
    } catch (e) {
      return const [];
    }
  }

  Future<List<OpcionCatalogo>> categorias() =>
      _leer('categorias', envoltura: 'catalogo');

  Future<List<OpcionCatalogo>> marcas() => _leer('marcas', envoltura: 'catalogo');

  /// Requiere el feature `retail_pasillos`; sin el devuelve vacia.
  Future<List<OpcionCatalogo>> pasillos() =>
      _leer('pasillos', envoltura: 'pasillos', clave: 'nombre');
}