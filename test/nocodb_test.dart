import 'package:portalpilot/services/nocodb_service.dart';

void main() async {
  print('🔌 Probando conexión con NocoDB...');

  final service = NocoDBService();

  // Probar crear empresa
  final empresa = await service.createEmpresa(
    nombre: 'Tech Solutions',
    codigo: 'TECH01',
    plan: 'Pro',
  );

  if (empresa != null) {
    print('✅ Empresa creada: ${empresa['Id']}');
  }

  // Probar login
  final login = await service.login(
    email: 'admin@techsolutions.com',
    password: 'admin123',
    empresaCodigo: 'TECH01',
  );

  print('Login: ${login?['success']}');
}
