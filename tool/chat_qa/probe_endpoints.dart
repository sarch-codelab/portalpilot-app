// Sondeo de TODOS los endpoints que la app llama, contra PRODUCCIÓN.
// Revela cuáles faltan (404/501) y cuál devuelve el error de columna isv.
import 'dart:io';
import 'dart:convert';

Future<dynamic> req(String method, String path, String? token, [Map<String, dynamic>? body]) async {
  final url = Uri.parse('https://portal-pilot.vercel.app$path');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final rq = await client.openUrl(method, url);
  rq.headers.set('Content-Type', 'application/json');
  if (token != null) rq.headers.set('Authorization', 'Bearer $token');
  if (body != null) rq.write(jsonEncode(body));
  final rs = await rq.close();
  final text = await rs.transform(utf8.decoder).join();
  client.close();
  return {'status': rs.statusCode, 'body': text};
}

Future<void> main() async {
  // Login QA
  final login = await req('POST', '/api/login', null,
      {'email': 'qa.chat@portalpilot-test.hn', 'password': 'QaChat2026!'});
  if (login['status'] != 200) {
    print('LOGIN FALLÓ: $login');
    exit(1);
  }
  final token = jsonDecode(login['body'] as String)['token'] as String;
  print('✅ login OK\n');

  final empresa = 'PP-48GX-Q8ME';
  final gets = [
    '/api/facturas?empresaCodigo=$empresa',
    '/api/facturas/resumen?empresaCodigo=$empresa',
    '/api/productos',
    '/api/bodegas',
    '/api/kardex?limit=200',
    '/api/pos/ventas/resumen',
    '/api/clientes',
    '/api/proveedores',
    '/api/cotizaciones',
    '/api/ordenes-compra',
    '/api/compras',
    '/api/transacciones',
    '/api/empleados',
    '/api/nomina',
    '/api/rutas',
    '/api/fiado/abonos',
    '/api/sucursales',
    '/api/transferencias',
    '/api/membresias',
    '/api/socios',
    '/api/pos/arqueo',
    '/api/pos/promociones',
    '/api/pos/cliente-credito',
    '/api/pos/config',
    '/api/arqueos',
    '/api/categorias',
  ];
  for (final p in gets) {
    final r = await req('GET', p, token);
    final s = r['status'];
    final marca = s == 200 ? '✅' : (s == 404 || s == 501 ? '❌' : '⚠️ ');
    print('$marca $s  $p');
    if (s != 200) {
      final b = (r['body'] as String);
      print('      ${b.length > 220 ? '${b.substring(0, 220)}…' : b}');
    }
  }

  // POST factura con isv_15/isv_18 (lo que manda la app) → ¿algún 42703?
  final post = await req('POST', '/api/facturas', token, {
    'empresa_codigo': empresa,
    'factura': {
      'correlativo': 'QA-ISV-TEST-1',
      'cliente_nombre': 'QA Probe',
      'subtotal': 100.0,
      'isv_15': 15.0,
      'isv_18': 0,
      'descuento': 0,
      'total': 115.0,
      'tipo_documento': 'Factura',
      'metodo_pago': 'Contado',
      'notas': 'prueba QA',
    },
  });
  print('\nPOST /api/facturas → ${post['status']}');
  final pb = post['body'] as String;
  print('      ${pb.length > 400 ? '${pb.substring(0, 400)}…' : pb}');
}
