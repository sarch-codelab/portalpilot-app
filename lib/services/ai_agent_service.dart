import 'dart:io';
import 'action_service.dart';
import 'vision_service.dart';

class AIAgentService {
  final ActionService _actions = ActionService();
  final VisionService _vision = VisionService();

  Future<String> processCommand(String userCommand) async {
    final lower = userCommand.toLowerCase();

    // Mover mouse
    if (lower.contains('mover') && lower.contains('mouse')) {
      final match = RegExp(r'(\d+).*?(\d+)').firstMatch(userCommand);
      if (match != null) {
        final x = int.parse(match.group(1)!);
        final y = int.parse(match.group(2)!);
        await _actions.moveMouseTo(x, y);
        return '✅ Mouse movido a ($x, $y)';
      } else {
        await _actions.moveMouseTo(500, 500);
        return '✅ Mouse movido al centro (500, 500)';
      }
    }

    // Clic
    if (lower.contains('clic') && !lower.contains('doble')) {
      await _actions.click();
      return '✅ Clic realizado';
    }

    // Doble clic
    if (lower.contains('doble clic')) {
      await _actions.doubleClick();
      return '✅ Doble clic realizado';
    }

    // Clic derecho
    if (lower.contains('clic derecho')) {
      await _actions.rightClick();
      return '✅ Clic derecho realizado';
    }

    // Escribir
    if (lower.contains('escribir')) {
      final match = RegExp(r'escribir[:\s]+(.+)', caseSensitive: false)
          .firstMatch(userCommand);
      if (match != null) {
        await _actions.typeText(match.group(1)!);
        return '✅ Texto escrito: "${match.group(1)}"';
      }
      return '❌ Ejemplo: "Escribir: Hola mundo"';
    }

    // Presionar tecla
    if (lower.contains('presionar')) {
      final match = RegExp(r'presionar[:\s]+(.+)', caseSensitive: false)
          .firstMatch(userCommand);
      if (match != null) {
        await _actions.pressKey(match.group(1)!.toUpperCase());
        return '✅ Tecla presionada: ${match.group(1)}';
      }
      return '❌ Ejemplo: "Presionar: ENTER"';
    }

    // Capturar pantalla
    if (lower.contains('capturar')) {
      final dir = await _getScreenshotsDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$dir/screenshot_$timestamp.png';
      await _vision.saveScreenshot(path);
      return '✅ Captura guardada en: $path';
    }

    // Estado
    if (lower.contains('estado')) {
      return _getStatus();
    }

    // Ayuda
    if (lower.contains('ayuda')) {
      return _getHelp();
    }

    return _getHelp();
  }

  Future<String> _getScreenshotsDir() async {
    final appData = Platform.environment['APPDATA'] ?? '.';
    final dir = Directory('$appData/PortalPilot/screenshots');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  String _getStatus() {
    return '''
📊 **Estado de PortalPilot**

• IA: ✅ Activa (modo demostración)
• Comandos disponibles: ✅
• Escribe "Ayuda" para ver la lista
''';
  }

  String _getHelp() {
    return '''
📋 **PortalPilot - Comandos disponibles**

🖱️ **Mouse:**
• "Mover mouse a 500 300"
• "Clic"
• "Doble clic"
• "Clic derecho"

⌨️ **Teclado:**
• "Escribir: Hola mundo"
• "Presionar: ENTER"

📸 **Sistema:**
• "Capturar pantalla"
• "Estado"

❓ **Ayuda:**
• "Ayuda" - Muestra este mensaje
''';
  }
}
