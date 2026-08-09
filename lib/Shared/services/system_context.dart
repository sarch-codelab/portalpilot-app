import 'dart:io';

class SystemContext {
  SystemContext._();
  static final instance = SystemContext._();

  String? _cachedContext;

  Future<void> clearCache() async {
    _cachedContext = null;
  }

  Future<String> getFullContext() async {
    if (_cachedContext != null) return _cachedContext!;
    _cachedContext = await _buildContext();
    return _cachedContext!;
  }

  Future<String> _buildContext() async {
    final buffer = StringBuffer();
    buffer.writeln('## 🖥️ CONTEXTO DEL SISTEMA DEL USUARIO');
    buffer.writeln('*Información capturada automáticamente del equipo*\n');

    await _addOperatingSystem(buffer);
    await _addHardware(buffer);
    await _addNetwork(buffer);
    await _addDisk(buffer);
    await _addEnvironment(buffer);
    await _addRecentFiles(buffer);
    await _addRunningProcesses(buffer);

    return buffer.toString();
  }

  Future<void> _addOperatingSystem(StringBuffer buffer) async {
    buffer.writeln('### Sistema Operativo');
    buffer.writeln('- **OS:** ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('- **Hostname:** ${Platform.localHostname}');
    buffer.writeln('- **Arquitectura:** ${Platform.version}');
    buffer.writeln('- **Número de procesadores:** ${Platform.numberOfProcessors}');
    buffer.writeln('');
  }

  Future<void> _addHardware(StringBuffer buffer) async {
    buffer.writeln('### Hardware');

    if (Platform.isWindows) {
      try {
        final result = await Process.run('wmic', ['cpu', 'get', 'Name,NumberOfCores,NumberOfLogicalProcessors', '/format:list']);
        final output = result.stdout.toString();
        final name = _extractWmicValue(output, 'Name');
        final cores = _extractWmicValue(output, 'NumberOfCores');
        final logical = _extractWmicValue(output, 'NumberOfLogicalProcessors');
        if (name.isNotEmpty) buffer.writeln('- **CPU:** $name');
        if (cores.isNotEmpty) buffer.writeln('- **Núcleos físicos:** $cores');
        if (logical.isNotEmpty) buffer.writeln('- **Hilos lógicos:** $logical');
      } catch (_) {}

      try {
        final result = await Process.run('wmic', ['memorychip', 'get', 'Capacity', '/format:list']);
        final output = result.stdout.toString();
        final capacity = _extractWmicValue(output, 'Capacity');
        if (capacity.isNotEmpty) {
          final gb = int.tryParse(capacity);
          if (gb != null) buffer.writeln('- **RAM total:** ${(gb / 1073741824).toStringAsFixed(1)} GB');
        }
      } catch (_) {}

      try {
        final result = await Process.run('systeminfo', []);
        final output = result.stdout.toString();
        if (output.contains('System Manufacturer')) {
          final lines = output.split('\n');
          for (final line in lines) {
            if (line.contains('System Manufacturer:') || line.contains('Fabricante del sistema:')) {
              final value = line.split(':').last.trim();
              if (value.isNotEmpty) buffer.writeln('- **Fabricante:** $value');
            }
            if (line.contains('System Model:') || line.contains('Modelo del sistema:')) {
              final value = line.split(':').last.trim();
              if (value.isNotEmpty) buffer.writeln('- **Modelo:** $value');
            }
          }
        }
      } catch (_) {}
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result = await Process.run('uname', ['-a']);
        buffer.writeln('- **Info:** ${result.stdout.toString().trim()}');
      } catch (_) {}
    }

    buffer.writeln('');
  }

  Future<void> _addNetwork(StringBuffer buffer) async {
    buffer.writeln('### Red');

    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        if (iface.name.toLowerCase().contains('loopback') || iface.name.toLowerCase().contains('lo')) continue;
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.address.startsWith('127.')) {
            buffer.writeln('- **${iface.name}:** ${addr.address}');
          }
        }
      }
    } catch (_) {}

    if (Platform.isWindows) {
      try {
        final result = await Process.run('nslookup', ['google.com']);
        final output = result.stdout.toString();
        if (output.contains('Address:')) {
          final lines = output.split('\n');
          for (final line in lines) {
            if (line.contains('Address:') && !line.contains('#')) {
              final parts = line.split('Address:').last.trim();
              if (parts.isNotEmpty && !parts.contains('.') && parts.length > 5) {
                buffer.writeln('- **DNS:** $parts');
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    buffer.writeln('');
  }

  Future<void> _addDisk(StringBuffer buffer) async {
    buffer.writeln('### Almacenamiento');

    if (Platform.isWindows) {
      try {
        final result = await Process.run('wmic', ['logicaldisk', 'get', 'DeviceID,FreeSpace,Size,FileSystem', '/format:list']);
        final output = result.stdout.toString();
        final disks = output.split('\r\n\r\n');
        for (final disk in disks) {
          if (disk.trim().isEmpty) continue;
          final id = _extractWmicValue(disk, 'DeviceID');
          final free = _extractWmicValue(disk, 'FreeSpace');
          final total = _extractWmicValue(disk, 'Size');
          final fs = _extractWmicValue(disk, 'FileSystem');
          if (id.isNotEmpty && total.isNotEmpty) {
            final totalGB = int.tryParse(total);
            final freeGB = int.tryParse(free);
            final usedGB = (totalGB != null && freeGB != null) ? totalGB - freeGB : 0;
            buffer.writeln('- **$id** ($fs): ${(totalGB != null ? (totalGB / 1073741824).toStringAsFixed(1) : '?')} GB total, '
                '${(freeGB != null ? (freeGB / 1073741824).toStringAsFixed(1) : '?')} GB libre, '
                '${(usedGB / 1073741824).toStringAsFixed(1)} GB usado');
          }
        }
      } catch (_) {}
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result = await Process.run('df', ['-h']);
        buffer.writeln('```\n${result.stdout.toString().trim()}\n```');
      } catch (_) {}
    }

    buffer.writeln('');
  }

  Future<void> _addEnvironment(StringBuffer buffer) async {
    buffer.writeln('### Variables de Entorno Relevantes');

    final envVars = [
      'USERPROFILE', 'HOME', 'APPDATA', 'TEMP', 'COMPUTERNAME',
      'NUMBER_OF_PROCESSORS', 'PROCESSOR_ARCHITECTURE', 'OS',
      'SYSTEMDRIVE', 'SystemRoot', 'ProgramFiles', 'ProgramFiles(x86)',
      'USERNAME', 'HOMEDRIVE', 'HOMEPATH',
    ];

    final env = Platform.environment;
    for (final key in envVars) {
      final value = env[key];
      if (value != null && value.isNotEmpty) {
        buffer.writeln('- **$key:** $value');
      }
    }

    buffer.writeln('');
  }

  Future<void> _addRecentFiles(StringBuffer buffer) async {
    buffer.writeln('### Archivos Recientes');

    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) {
      final downloads = Directory('$home\\Downloads');
      if (await downloads.exists()) {
        buffer.writeln('\n**Descargas:**');
        int count = 0;
        await for (final entity in downloads.list().take(20)) {
          if (count >= 10) break;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) {
            try {
              final stat = await entity.stat();
              buffer.writeln('- $name (${_formatSize(stat.size)})');
            } catch (_) {
              buffer.writeln('- $name');
            }
            count++;
          }
        }
      }

      final desktop = Directory('$home\\Desktop');
      if (await desktop.exists()) {
        buffer.writeln('\n**Escritorio:**');
        int count = 0;
        await for (final entity in desktop.list().take(10)) {
          if (count >= 5) break;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) {
            buffer.writeln('- $name');
            count++;
          }
        }
      }

      final docs = Directory('$home\\Documents');
      if (await docs.exists()) {
        buffer.writeln('\n**Documentos:**');
        int count = 0;
        await for (final entity in docs.list().take(15)) {
          if (count >= 5) break;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) {
            buffer.writeln('- $name');
            count++;
          }
        }
      }
    }

    buffer.writeln('');
  }

  Future<void> _addRunningProcesses(StringBuffer buffer) async {
    buffer.writeln('### Procesos en Ejecución');

    if (Platform.isWindows) {
      try {
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        final output = result.stdout.toString();
        final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final importantProcesses = <String>[];
        for (final line in lines) {
          final name = line.split('"').length > 1 ? line.split('"')[1] : '';
          if (name.isNotEmpty && !name.toLowerCase().contains('svchost') &&
              !name.toLowerCase().contains('system') && !name.toLowerCase().contains('idle') &&
              !name.toLowerCase().contains('csrss') && !name.toLowerCase().contains('smss') &&
              !name.toLowerCase().contains('lsass') && !name.toLowerCase().contains('services') &&
              !name.toLowerCase().contains('wininit') && !name.toLowerCase().contains('winlogon')) {
            if (importantProcesses.length < 15 && !importantProcesses.contains(name)) {
              importantProcesses.add(name);
            }
          }
        }
        if (importantProcesses.isNotEmpty) {
          buffer.writeln('- Procesos de usuario: ${importantProcesses.join(', ')}');
        }
      } catch (_) {}
    }

    buffer.writeln('');
  }

  String _extractWmicValue(String output, String key) {
    final pattern = RegExp('$key=(.*?)(?:\\r?\\n|\$)', caseSensitive: false);
    final match = pattern.firstMatch(output);
    return match?.group(1)?.trim() ?? '';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
}
