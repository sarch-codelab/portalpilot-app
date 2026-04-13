import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'dashboard_screen.dart';
import 'login_empresa.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  
  String _status = "Verificando sistema...";
  double _progress = 0.0;
  String _currentTask = "";
  bool _isProcessing = false;
  bool _isComplete = false;
  bool _ollamaInstalled = false;
  bool _modelInstalled = false;
  
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _checkExistingInstallation();
  }

  Future<void> _checkExistingInstallation() async {
    _addLog("🔍 Verificando instalación existente...");
    
    // Verificar Ollama
    _ollamaInstalled = await _isOllamaInstalled();
    if (_ollamaInstalled) {
      _addLog("✅ Ollama ya está instalado");
    } else {
      _addLog("⚠️ Ollama no encontrado");
    }
    
    // Verificar modelo Phi-3
    _modelInstalled = await _isPhi3Installed();
    if (_modelInstalled) {
      _addLog("✅ Modelo Phi-3 Mini ya está descargado");
    } else {
      _addLog("⚠️ Modelo Phi-3 Mini no encontrado");
    }
    
    setState(() {});
  }

  Future<bool> _isOllamaInstalled() async {
    try {
      final result = await Process.run('ollama', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isPhi3Installed() async {
    try {
      final result = await Process.run('ollama', ['list']);
      final output = result.stdout.toString();
      return output.contains('phi3');
    } catch (e) {
      return false;
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, "${DateTime.now().toString().substring(11, 19)} - $message");
      if (_logs.length > 10) _logs.removeLast();
    });
  }

  Future<void> _startInstallation() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _logs.clear();
    });

    // Paso 1: Instalar Ollama si no existe
    if (!_ollamaInstalled) {
      await _downloadAndInstallOllama();
    } else {
      _addLog("⏭️ Saltando instalación de Ollama (ya instalado)");
      setState(() => _progress = 0.5);
    }
    
    // Paso 2: Descargar modelo si no existe
    if (!_modelInstalled) {
      await _downloadPhi3Model();
    } else {
      _addLog("⏭️ Saltando descarga de modelo (ya descargado)");
      setState(() => _progress = 1.0);
    }
    
    // Finalizar
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    
    setState(() {
      _isProcessing = false;
      _isComplete = true;
      _status = "¡Instalación completa!";
    });
    
    await Future.delayed(const Duration(seconds: 2));
    _goToNextScreen();
  }

  Future<void> _downloadAndInstallOllama() async {
    setState(() {
      _status = "Instalando Ollama...";
      _currentTask = "Descargando Ollama";
    });
    _addLog("📥 Iniciando descarga de Ollama...");
    
    const url = 'https://ollama.com/download/OllamaSetup.exe';
    final client = http.Client();
    final request = await client.send(http.Request('GET', Uri.parse(url)));
    
    final totalBytes = request.contentLength;
    var receivedBytes = 0;
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/OllamaSetup.exe');
    final sink = file.openWrite();
    
    await for (final chunk in request.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes != null) {
        final progress = receivedBytes / totalBytes;
        setState(() {
          _progress = progress * 0.4;
          _currentTask = "Descargando Ollama... ${(progress * 100).toStringAsFixed(1)}%";
        });
      }
    }
    
    await sink.close();
    client.close();
    _addLog("✅ Ollama descargado correctamente");
    
    setState(() {
      _currentTask = "Instalando Ollama...";
      _progress = 0.4;
    });
    _addLog("⚙️ Ejecutando instalador de Ollama...");
    
    await Process.run('${dir.path}/OllamaSetup.exe', ['/S']);
    await Future.delayed(const Duration(seconds: 5));
    
    _addLog("✅ Ollama instalado correctamente");
    _ollamaInstalled = true;
    
    setState(() => _progress = 0.5);
  }

  Future<void> _downloadPhi3Model() async {
    setState(() {
      _status = "Descargando modelo Phi-3 Mini...";
      _currentTask = "Iniciando descarga del modelo";
      _progress = 0.5;
    });
    _addLog("🤖 Iniciando descarga de Phi-3 Mini (2.2GB)...");
    
    await _startOllamaService();
    
    final process = await Process.start('ollama', ['pull', 'phi3:mini']);
    
    await for (var event in process.stdout) {
      final line = String.fromCharCodes(event);
      _addLog(line.trim());
      
      if (line.contains('downloading')) {
        final match = RegExp(r'(\d+)%').firstMatch(line);
        if (match != null) {
          final percent = int.parse(match.group(1)!);
          setState(() {
            _progress = 0.5 + percent / 100 * 0.5;
            _currentTask = "Descargando Phi-3 Mini... $percent%";
          });
        }
      }
    }
    
    await process.stderr.drain();
    await process.exitCode;
    
    _addLog("✅ Modelo Phi-3 Mini descargado correctamente");
    _modelInstalled = true;
    
    setState(() => _progress = 1.0);
  }

  Future<void> _startOllamaService() async {
    _addLog("🚀 Iniciando servicio de Ollama...");
    await Process.start('ollama', ['serve'], runInShell: true);
    await Future.delayed(const Duration(seconds: 3));
    _addLog("✅ Servicio de Ollama iniciado");
  }

  void _goToNextScreen() {
    final prefs = SharedPreferences.getInstance();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginEmpresaScreen()),
    );
  }

  void _skipToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginEmpresaScreen()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              const Color(0xFF7C3AED).withOpacity(0.1),
              const Color(0xFF0A0B0F),
              const Color(0xFF0A0B0F),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animado
                  AnimatedBuilder(
                    animation: _rotateController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateController.value * 2 * 3.14159,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.downloading, size: 50, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  
                  // Título
                  const Text(
                    "PortalPilot",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtítulo
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  
                  // Barra de progreso
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: _progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Porcentaje
                  Text(
                    "${(_progress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tarea actual
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentTask,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Panel de logs
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _logs[index],
                            style: TextStyle(
                              color: _logs[index].contains('✅') 
                                  ? Colors.green 
                                  : (_logs[index].contains('⚠️') ? Colors.orange : Colors.white54),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Botones de acción
                  if (!_isProcessing && !_isComplete)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _startInstallation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "INSTALAR COMPONENTES",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  if (!_isProcessing && !_isComplete)
                    const SizedBox(height: 12),
                  
                  if (!_isProcessing && !_isComplete)
                    TextButton(
                      onPressed: _skipToLogin,
                      child: const Text(
                        "Omitir instalación (usar modo básico)",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  
                  if (_isProcessing)
                    const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  
                  if (_isComplete)
                    FadeInUp(
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          SizedBox(width: 12),
                          Text(
                            "¡Instalación completada!",
                            style: TextStyle(color: Colors.green, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}