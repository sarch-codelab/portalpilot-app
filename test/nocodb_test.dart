import 'package:portalpilot/services/nocodb_service.dart';

void main() async {
  print('🔌 Probando conexión con NocoDB...');

  final service = NocoDBService();

  // 1. Crear empresa de prueba
  final empresa = await service.createEmpresa(
    nombre: 'Tech Solutions',
    codigo: 'TECH01',
    plan: 'Pro',
  );

  if (empresa != null) {
    print('✅ Empresa creada con ID: ${empresa['Id']}');

    // 2. Crear usuario para esa empresa
    final usuario = await service.createUsuario(
      nombre: 'Admin Tech',
      email: 'admin@techsolutions.com',
      password: 'Tech123!',
      rol: 'admin',
      empresaId: empresa['Id'],
    );

    if (usuario != null) {
      print('✅ Usuario creado: ${usuario['email']}');
    }
  }

  // 3. Probar login
  final login = await service.login(
    email: 'admin@techsolutions.com',
    password: 'Tech123!',
    empresaCodigo: 'TECH01',
  );

  print('Login exitoso: ${login?['success']}');
  if (login?['success'] == true) {
    print('👤 Usuario: ${login?['usuario']['nombre']}');
    print('🏢 Empresa: ${login?['empresa']['nombre']}');
  } else {
    print('❌ Error: ${login?['error']}');
  }
}
