import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String apiToken = 'nc_pat_zawRZGjBBt71tyamIeQP9G1lEnS3ZzO5Ggxtk_3T';
  const String baseId = 'px82297mndrc9ur';
  const String baseUrl = 'https://app.nocodb.com';

  final headers = {
    'xc-token': apiToken,
    'Content-Type': 'application/json',
  };

  print('🔍 Diagnosticando tablas en NocoDB...\n');

  // Endpoint para obtener todas las tablas
  final url = Uri.parse('$baseUrl/api/v2/meta/bases/$baseId/tables');
  print('📡 GET: $url');
  
  final response = await http.get(url, headers: headers);
  
  print('📥 Status: ${response.statusCode}\n');
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('📋 TABLAS ENCONTRADAS:');
    print('=' * 50);
    
    for (var table in data['list']) {
      print('┌─────────────────────────────────────────');
      print('│ Nombre: ${table['title']}');
      print('│ TABLE ID (USA ESTE): ${table['id']}');
      print('│ Tipo: ${table['type']}');
      print('└─────────────────────────────────────────\n');
    }
  } else {
    print('❌ Error: ${response.body}');
  }
}