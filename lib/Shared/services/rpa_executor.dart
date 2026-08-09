import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActionResult {
  final bool success;
  final String message;
  final String? filePath;
  final dynamic data;

  ActionResult({
    required this.success,
    required this.message,
    this.filePath,
    this.data,
  });
}

class RPAExecutor {
  RPAExecutor._();
  static final instance = RPAExecutor._();

  String _resolvePath(String rawPath) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    final resolved = rawPath
        .replaceAll('~', home)
        .replaceAll('\${USERPROFILE}', home)
        .replaceAll('\${HOME}', home);
    return resolved;
  }

  bool _isAbsolute(String path) {
    return path.contains(r':\') || path.startsWith('/') || path.startsWith(r'\\');
  }

  Future<String> _getDownloadsPath() async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) return '$home\\Downloads';
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> _resolveTarget(Map<String, dynamic> action) async {
    final rawPath = action['path'] as String? ?? '';
    final name = action['name'] as String? ?? '';

    if (rawPath.isNotEmpty) {
      final resolved = _resolvePath(rawPath);
      if (_isAbsolute(resolved)) return resolved;
      final downloads = await _getDownloadsPath();
      return '$downloads\\$resolved';
    }

    if (name.isNotEmpty && _isAbsolute(name)) return name;

    final downloads = await _getDownloadsPath();
    final folder = action['folder'] as String?;
    if (folder != null && folder.isNotEmpty) {
      return '$downloads\\$folder\\$name';
    }
    return '$downloads\\$name';
  }

  Future<ActionResult> execute(Map<String, dynamic> action) async {
    final type = action['type'] as String? ?? '';

    switch (type) {
      case 'create_file': return _createFile(action);
      case 'create_html': return _createHtmlDocument(action);
      case 'create_csv': return _createCsv(action);
      case 'create_directory': return _createDirectory(action);
      case 'run_command': return _runCommand(action);
      case 'read_file': return _readFile(action);
      case 'list_directory': return _listDirectory(action);
      case 'delete_file': return _deleteFile(action);
      case 'move_file': return _moveFile(action);
      case 'rename_file': return _renameFile(action);
      case 'copy_file': return _copyFile(action);
      case 'search_files': return _searchFiles(action);
      case 'organize_folder': return _organizeFolder(action);
      case 'get_disk_info': return _getDiskInfo(action);
      case 'save_to_downloads': return _saveToDownloads(action);
      default:
        return ActionResult(success: false, message: 'Acción desconocida: $type');
    }
  }

  Future<ActionResult> _createFile(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final content = action['content'] as String? ?? '';

      final dir = Directory(targetPath.substring(0, targetPath.lastIndexOf(Platform.pathSeparator)));
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(targetPath);
      await file.writeAsString(content);
      _trackFile(file.path);

      return ActionResult(success: true, message: 'Archivo creado: $targetPath', filePath: file.path);
    } catch (e) {
      return ActionResult(success: false, message: 'Error al crear archivo: $e');
    }
  }

  Future<ActionResult> _createHtmlDocument(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final title = action['title'] as String? ?? 'Documento';
      final body = action['body'] as String? ?? '';
      final styles = action['styles'] as String? ?? '';

      final html = '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f7; color: #1a1a2e; padding: 40px; line-height: 1.6; }
    .container { max-width: 800px; margin: 0 auto; background: white; padding: 48px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    h1 { font-size: 28px; color: #8B5CF6; margin-bottom: 8px; }
    h2 { font-size: 20px; color: #6D28D9; margin: 24px 0 12px; }
    p { margin-bottom: 12px; color: #374151; }
    table { width: 100%; border-collapse: collapse; margin: 16px 0; }
    th { background: #8B5CF6; color: white; padding: 12px; text-align: left; }
    td { padding: 10px 12px; border-bottom: 1px solid #e5e7eb; }
    tr:hover td { background: #f3f4f6; }
    ul, ol { padding-left: 24px; margin: 12px 0; }
    li { margin-bottom: 6px; color: #374151; }
    .footer { margin-top: 32px; padding-top: 16px; border-top: 2px solid #e5e7eb; color: #9ca3af; font-size: 12px; text-align: center; }
    $styles
  </style>
</head>
<body>
  <div class="container">
    <h1>$title</h1>
    $body
    <div class="footer">Generado por Portal Pilot IA · ${DateTime.now().toString().substring(0, 16)}</div>
  </div>
</body>
</html>''';

      final dir = Directory(targetPath.substring(0, targetPath.lastIndexOf(Platform.pathSeparator)));
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(targetPath);
      await file.writeAsString(html);
      _trackFile(file.path);

      return ActionResult(success: true, message: 'Documento HTML creado: $targetPath', filePath: file.path);
    } catch (e) {
      return ActionResult(success: false, message: 'Error al crear HTML: $e');
    }
  }

  Future<ActionResult> _createCsv(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final headers = List<String>.from(action['headers'] ?? []);
      final rows = (action['rows'] as List? ?? []).map((r) => List<String>.from(r)).toList();

      final buffer = StringBuffer();
      if (headers.isNotEmpty) buffer.writeln(headers.join(','));
      for (final row in rows) {
        buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
      }

      final dir = Directory(targetPath.substring(0, targetPath.lastIndexOf(Platform.pathSeparator)));
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(targetPath);
      await file.writeAsString('\uFEFF${buffer.toString()}');
      _trackFile(file.path);

      return ActionResult(success: true, message: 'CSV creado: $targetPath', filePath: file.path);
    } catch (e) {
      return ActionResult(success: false, message: 'Error al crear CSV: $e');
    }
  }

  Future<ActionResult> _createDirectory(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final dir = Directory(targetPath);
      await dir.create(recursive: true);

      return ActionResult(success: true, message: 'Carpeta creada: $targetPath', filePath: dir.path);
    } catch (e) {
      return ActionResult(success: false, message: 'Error al crear carpeta: $e');
    }
  }

  Future<ActionResult> _runCommand(Map<String, dynamic> action) async {
    try {
      final command = action['command'] as String? ?? '';
      final args = List<String>.from(action['args'] ?? []);
      final workingDir = action['working_dir'] as String?;

      final result = await Process.run(command, args, workingDirectory: workingDir, runInShell: true);

      return ActionResult(
        success: result.exitCode == 0,
        message: result.exitCode == 0 ? 'Comando ejecutado' : 'Error: ${result.stderr}',
        data: {'stdout': result.stdout.toString(), 'stderr': result.stderr.toString(), 'exitCode': result.exitCode},
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Error al ejecutar: $e');
    }
  }

  Future<ActionResult> _readFile(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final file = File(targetPath);
      if (!await file.exists()) return ActionResult(success: false, message: 'Archivo no encontrado: $targetPath');

      final content = await file.readAsString();
      return ActionResult(success: true, message: 'Archivo leído', filePath: targetPath, data: {'content': content});
    } catch (e) {
      return ActionResult(success: false, message: 'Error al leer: $e');
    }
  }

  Future<ActionResult> _listDirectory(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final dir = Directory(targetPath);
      if (!await dir.exists()) return ActionResult(success: false, message: 'Carpeta no encontrada: $targetPath');

      final items = <Map<String, dynamic>>[];
      await for (final entity in dir.list()) {
        final stat = await entity.stat();
        items.add({
          'name': entity.path.split(Platform.pathSeparator).last,
          'type': stat.type == FileSystemEntityType.directory ? 'folder' : 'file',
          'size': stat.size,
          'modified': stat.modified.toString().substring(0, 16),
          'extension': entity.path.split('.').last.toLowerCase(),
        });
      }

      return ActionResult(success: true, message: '${items.length} elementos en $targetPath', data: {'items': items, 'path': targetPath});
    } catch (e) {
      return ActionResult(success: false, message: 'Error al listar: $e');
    }
  }

  Future<ActionResult> _deleteFile(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);

      final file = File(targetPath);
      if (await file.exists()) {
        await file.delete();
        return ActionResult(success: true, message: 'Archivo eliminado: $targetPath');
      }

      final dir = Directory(targetPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return ActionResult(success: true, message: 'Carpeta eliminada: $targetPath');
      }

      return ActionResult(success: false, message: 'No encontrado: $targetPath');
    } catch (e) {
      return ActionResult(success: false, message: 'Error al eliminar: $e');
    }
  }

  Future<ActionResult> _moveFile(Map<String, dynamic> action) async {
    try {
      final source = _resolvePath(action['source'] as String? ?? '');
      final dest = _resolvePath(action['destination'] as String? ?? '');

      final srcFile = File(source);
      if (!await srcFile.exists()) return ActionResult(success: false, message: 'Archivo origen no encontrado: $source');

      final destDir = Directory(dest.substring(0, dest.lastIndexOf(Platform.pathSeparator)));
      if (!await destDir.exists()) await destDir.create(recursive: true);

      await srcFile.rename(dest);
      return ActionResult(success: true, message: 'Movido: $source → $dest');
    } catch (e) {
      return ActionResult(success: false, message: 'Error al mover: $e');
    }
  }

  Future<ActionResult> _renameFile(Map<String, dynamic> action) async {
    try {
      final targetPath = _resolvePath(action['path'] as String? ?? '');
      final newName = action['new_name'] as String? ?? '';

      final file = File(targetPath);
      if (!await file.exists()) return ActionResult(success: false, message: 'No encontrado: $targetPath');

      final dir = targetPath.substring(0, targetPath.lastIndexOf(Platform.pathSeparator));
      await file.rename('$dir\\$newName');
      return ActionResult(success: true, message: 'Renombrado: $newName');
    } catch (e) {
      return ActionResult(success: false, message: 'Error al renombrar: $e');
    }
  }

  Future<ActionResult> _copyFile(Map<String, dynamic> action) async {
    try {
      final source = _resolvePath(action['source'] as String? ?? '');
      final dest = _resolvePath(action['destination'] as String? ?? '');

      final srcFile = File(source);
      if (!await srcFile.exists()) return ActionResult(success: false, message: 'Archivo origen no encontrado: $source');

      final destDir = Directory(dest.substring(0, dest.lastIndexOf(Platform.pathSeparator)));
      if (!await destDir.exists()) await destDir.create(recursive: true);

      await srcFile.copy(dest);
      return ActionResult(success: true, message: 'Copiado: $source → $dest');
    } catch (e) {
      return ActionResult(success: false, message: 'Error al copiar: $e');
    }
  }

  Future<ActionResult> _searchFiles(Map<String, dynamic> action) async {
    try {
      final searchPath = await _resolveTarget(action);
      final pattern = action['pattern'] as String? ?? '*.*';
      final extension = action['extension'] as String?;
      final nameContains = action['name_contains'] as String?;

      final dir = Directory(searchPath);
      if (!await dir.exists()) return ActionResult(success: false, message: 'Carpeta no encontrada: $searchPath');

      final results = <Map<String, dynamic>>[];
      await for (final entity in dir.list(recursive: true)) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is! File) continue;

        bool matches = true;
        if (extension != null && !name.toLowerCase().endsWith(extension.toLowerCase())) matches = false;
        if (nameContains != null && !name.toLowerCase().contains(nameContains.toLowerCase())) matches = false;
        if (pattern != '*.*' && !name.toLowerCase().contains(pattern.toLowerCase())) matches = false;

        if (matches) {
          final stat = await entity.stat();
          results.add({
            'name': name,
            'path': entity.path,
            'size': stat.size,
            'modified': stat.modified.toString().substring(0, 16),
          });
          if (results.length >= 100) break;
        }
      }

      return ActionResult(
        success: true,
        message: '${results.length} archivos encontrados',
        data: {'results': results, 'search_path': searchPath},
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Error al buscar: $e');
    }
  }

  Future<ActionResult> _organizeFolder(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final method = action['method'] as String? ?? 'type';
      final createSubfolders = action['create_subfolders'] as bool? ?? true;

      final dir = Directory(targetPath);
      if (!await dir.exists()) return ActionResult(success: false, message: 'Carpeta no encontrada: $targetPath');

      final categoryMap = <String, List<String>>{};

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        final ext = name.split('.').last.toLowerCase();

        String category;
        if (method == 'type') {
          category = _getCategoryByExtension(ext);
        } else if (method == 'date') {
          final stat = await entity.stat();
          category = '${stat.modified.year}-${stat.modified.month.toString().padLeft(2, '0')}';
        } else if (method == 'name') {
          category = name.substring(0, 1).toUpperCase();
        } else {
          category = 'otros';
        }

        categoryMap.putIfAbsent(category, () => []).add(entity.path);
      }

      int movedCount = 0;
      for (final entry in categoryMap.entries) {
        if (entry.value.length < 2 && !createSubfolders) continue;

        final categoryDir = Directory('$targetPath\\${entry.key}');
        if (!await categoryDir.exists()) await categoryDir.create();

        for (final filePath in entry.value) {
          final file = File(filePath);
          final fileName = filePath.split(Platform.pathSeparator).last;
          final newPath = '$targetPath\\${entry.key}\\$fileName';

          if (filePath != newPath) {
            try {
              await file.rename(newPath);
              movedCount++;
            } catch (_) {}
          }
        }
      }

      final summary = StringBuffer();
      summary.writeln('Organización por **${method == 'type' ? 'tipo de archivo' : method == 'date' ? 'fecha' : 'nombre'}** completada.');
      summary.writeln('');
      summary.writeln('**Resultado:**');
      for (final entry in categoryMap.entries) {
        summary.writeln('- 📁 ${entry.key}: ${entry.value.length} archivos');
      }
      summary.writeln('');
      summary.writeln('**Total movidos:** $movedCount archivos');

      return ActionResult(
        success: true,
        message: summary.toString(),
        data: {'moved': movedCount, 'categories': categoryMap.map((k, v) => MapEntry(k, v.length))},
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Error al organizar: $e');
    }
  }

  String _getCategoryByExtension(String ext) {
    const categories = {
      'images': ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff'],
      'documents': ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'md'],
      'spreadsheets': ['xls', 'xlsx', 'csv', 'ods'],
      'presentations': ['ppt', 'pptx', 'odp', 'key'],
      'videos': ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'],
      'music': ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'],
      'archives': ['zip', 'rar', '7z', 'tar', 'gz', 'bz2'],
      'code': ['js', 'ts', 'dart', 'py', 'java', 'cpp', 'c', 'html', 'css', 'json', 'xml'],
      'installers': ['exe', 'msi', 'dmg', 'deb', 'rpm', 'apk'],
    };

    for (final entry in categories.entries) {
      if (entry.value.contains(ext)) return entry.key;
    }
    return 'otros';
  }

  Future<ActionResult> _getDiskInfo(Map<String, dynamic> action) async {
    try {
      final info = StringBuffer();

      if (Platform.isWindows) {
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
            info.writeln('**$id** ($fs): ${totalGB != null ? '${(totalGB / 1073741824).toStringAsFixed(1)} GB' : '?'} total, ${freeGB != null ? '${(freeGB / 1073741824).toStringAsFixed(1)} GB' : '?'} libre');
          }
        }
      }

      return ActionResult(success: true, message: info.toString());
    } catch (e) {
      return ActionResult(success: false, message: 'Error: $e');
    }
  }

  String _extractWmicValue(String output, String key) {
    final pattern = RegExp('$key=(.*?)(?:\\r?\\n|\$)', caseSensitive: false);
    final match = pattern.firstMatch(output);
    return match?.group(1)?.trim() ?? '';
  }

  Future<ActionResult> _saveToDownloads(Map<String, dynamic> action) async {
    try {
      final targetPath = await _resolveTarget(action);
      final content = action['content'] as String? ?? '';
      final encoding = action['encoding'] as String? ?? 'utf-8';

      final dir = Directory(targetPath.substring(0, targetPath.lastIndexOf(Platform.pathSeparator)));
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(targetPath);
      if (encoding == 'base64') {
        await file.writeAsBytes(base64Decode(content));
      } else {
        await file.writeAsString(content);
      }

      _trackFile(file.path);
      return ActionResult(success: true, message: 'Guardado: $targetPath', filePath: file.path);
    } catch (e) {
      return ActionResult(success: false, message: 'Error al guardar: $e');
    }
  }

  Future<void> _trackFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_files') ?? [];
    recent.remove(path);
    recent.insert(0, path);
    if (recent.length > 50) recent.removeRange(50, recent.length);
    await prefs.setStringList('recent_files', recent);
  }

  String getActionSchema() {
    return '''
## ACCIONES RPA DISPONIBLES

### Archivos y Carpetas
- **create_file**: {"type": "create_file", "name": "archivo.txt", "content": "contenido", "folder": "subcarpeta"}
- **create_html**: {"type": "create_html", "name": "doc.html", "title": "Título", "body": "<h2>Sección</h2>"}
- **create_csv**: {"type": "create_csv", "name": "datos.csv", "headers": ["Col1"], "rows": [["val1"]]}
- **create_directory**: {"type": "create_directory", "name": "NombreCarpeta"} o {"type": "create_directory", "path": "C:\\\\Users\\\\User\\\\Desktop\\\\Carpeta"}

### Gestión de Archivos
- **move_file**: {"type": "move_file", "source": "ruta_origen", "destination": "ruta_destino"}
- **rename_file**: {"type": "rename_file", "path": "ruta", "new_name": "nuevo_nombre.ext"}
- **copy_file**: {"type": "copy_file", "source": "ruta_origen", "destination": "ruta_destino"}
- **delete_file**: {"type": "delete_file", "path": "ruta"}

### Búsqueda y Lectura
- **search_files**: {"type": "search_files", "path": "C:\\\\Users\\\\User\\\\Downloads", "extension": "pdf", "name_contains": "examen"}
- **list_directory**: {"type": "list_directory", "path": "C:\\\\Users\\\\User\\\\Desktop"}
- **read_file**: {"type": "read_file", "path": "ruta_archivo"}

### Organización Automática
- **organize_folder**: {"type": "organize_folder", "path": "C:\\\\Users\\\\User\\\\Downloads", "method": "type"}
  - method: "type" (por extensión), "date" (por mes), "name" (por letra)

### Sistema
- **get_disk_info**: {"type": "get_disk_info"}
- **run_command**: {"type": "run_command", "command": "cmd", "args": ["/c", "dir"]}
- **save_to_downloads**: {"type": "save_to_downloads", "name": "archivo.txt", "content": "contenido"}

### IMPORTANTE
- Las rutas absolutas se usan tal cual: "C:\\\\Users\\\\Sami\\\\Desktop\\\\"
- Las rutas relativas se resuelven respecto a Descargas
- Usa ~ para la carpeta del usuario: "~/Desktop" = "C:\\Users\\Sami\\Desktop"
- Puedes ejecutar múltiples acciones en un array JSON: [{"type": "...", ...}, {"type": "...", ...}]
''';
  }
}
