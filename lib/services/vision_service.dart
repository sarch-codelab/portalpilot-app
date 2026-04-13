import 'dart:io';

class VisionService {
  Future<void> saveScreenshot(String path) async {
    print('📸 SIMULADO: Captura guardada en: $path');
    // Simular que se guarda un archivo
    final file = File(path);
    await file.writeAsString('Screenshot simulada');
  }

  Future<String> getScreenshotsDir() async {
    final appData = Platform.environment['APPDATA'] ?? '.';
    final dir = '$appData/PortalPilot/screenshots';
    return dir;
  }
}