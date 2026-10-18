// Puente entre la forma legacy de RRHH (SharedPreferences) y la forma real de
// la tabla `empleados` / `nomina` en el servidor.
//
// Antes de esta capa cada pantalla leía y escribía `prefs['empleados']` a su
// manera: RRHH guardaba datos locales sin empresa ni tenant, así que dos
// cuentas en el mismo dispositivo se mezclaban y nada se sincronizaba. Las
// pantallas siguen recibiendo la forma que ya saben leer (`salario`, `activo`,
// `cargo`); el traductor vive aquí y es el único sitio que conoce los nombres
// reales de las columnas.
import 'package:portal_pilot_app/Shared/services/modulos_avanzados_service.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _texto(dynamic v) => v == null ? '' : v.toString();

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

bool _activo(dynamic v) {
  if (v is bool) return v;
  final s = _texto(v).toLowerCase().trim();
  if (s.isEmpty) return true;
  return s == 'activo' || s == 'true' || s == '1';
}

/// Separa `nombre`/`apellido` sin perder nada si el servidor solo tiene el
/// nombre completo (filas antiguas, o creadas por otra app).
List<String> _partirNombre(String completo, String apellido) {
  final base = completo.trim();
  final ap = apellido.trim();
  if (ap.isEmpty) return [base, ''];
  if (base.toLowerCase() == ap.toLowerCase()) return ['', base];
  if (base.toLowerCase().endsWith(' ${ap.toLowerCase()}')) {
    return [base.substring(0, base.length - ap.length).trim(), ap];
  }
  return [base, ap];
}

// ─────────────────────────────────────────────────────────────────────────────
// servidor → pantalla
// ─────────────────────────────────────────────────────────────────────────────

/// Fila de `empleados` → forma que leen `rrhh_home`, `empleado_list`,
/// `empleado_form` y `nomina_home`.
Map<String, dynamic> empleadoDesdeServidor(Map<String, dynamic> s) {
  final [nombre, apellido] = _partirNombre(
    _texto(s['nombre']),
    _texto(s['apellido']),
  );
  final completo = [nombre, apellido].where((p) => p.isNotEmpty).join(' ');
  return <String, dynamic>{
    'id': s['id'],
    'nombre': nombre,
    'apellido': apellido,
    'nombre_completo': completo.isNotEmpty ? completo : 'Sin nombre',
    'email': _texto(s['email']),
    'telefono': _texto(s['telefono']),
    'cargo': _texto(s['puesto']),
    'departamento': _texto(s['departamento']),
    'salario': _num(s['salario_base']),
    'contacto_emergencia': _texto(s['contacto_emergencia']),
    'telefono_emergencia': _texto(s['telefono_emergencia']),
    'direccion': _texto(s['direccion']),
    'banco': _texto(s['banco']),
    'cuenta_bancaria': _texto(s['cuenta_bancaria']),
    'identidad': _texto(s['identidad']),
    'rtn': _texto(s['rtn']),
    'notas': _texto(s['notas']),
    'activo': _activo(s['estado']),
    'estado': _texto(s['estado']).isEmpty ? 'activo' : _texto(s['estado']),
    'fecha_ingreso': _texto(s['fecha_ingreso']),
    'created_at': _texto(s['created_at']),
    'es_remoto': true,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// pantalla → servidor
// ─────────────────────────────────────────────────────────────────────────────

/// Forma de pantalla → payload de `POST /api/rrhh/empleados`.
///
/// `nombre` en el servidor es el nombre completo: la app tiene el apellido en
/// un campo aparte y hay que mandarlo junto para que una fila no dependa de
/// quién la haya creado.
Map<String, dynamic> empleadoParaServidor(Map<String, dynamic> p) {
  final nombre = _texto(p['nombre']).trim();
  final apellido = _texto(p['apellido']).trim();
  final completo = [nombre, apellido].where((v) => v.isNotEmpty).join(' ');
  return <String, dynamic>{
    'nombre': completo.isEmpty ? nombre : completo,
    'apellido': apellido,
    'email': _texto(p['email']).trim(),
    'telefono': _texto(p['telefono']).trim(),
    'puesto': _texto(p['cargo']).trim(),
    'departamento': _texto(p['departamento']).trim(),
    'salario_base': _num(p['salario']),
    'estado': _activo(p['activo']) ? 'activo' : 'inactivo',
    'contacto_emergencia': _texto(p['contacto_emergencia']).trim(),
    'telefono_emergencia': _texto(p['telefono_emergencia']).trim(),
    'direccion': _texto(p['direccion']).trim(),
    'banco': _texto(p['banco']).trim(),
    'cuenta_bancaria': _texto(p['cuenta_bancaria']).trim(),
    'identidad': _texto(p['identidad']).trim(),
    'rtn': _texto(p['rtn']).trim(),
    'notas': _texto(p['notas']).trim(),
    if (_texto(p['fecha_ingreso']).isNotEmpty) 'fecha_ingreso': _texto(p['fecha_ingreso']),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// nómina
// ─────────────────────────────────────────────────────────────────────────────

/// Fila de `nomina` → forma que renderiza `ReciboNomina`.
///
/// La tabla usa nombres de columna propios (`neta`, `isss`, `rap`) y no guarda
/// el nombre ni el cargo del trabajador, así que se resuelven con la lista de
/// empleados. Sin esto el recibo se imprime en blanco.
Map<String, dynamic> reciboDesdeServidor(
  Map<String, dynamic> r, {
  Map<String, dynamic>? empleado,
}) {
  final e = empleado;
  final mes = r['mes'] is num ? (r['mes'] as num).toInt() : 1;
  final anio = r['anio'] is num ? (r['anio'] as num).toInt() : 0;
  return <String, dynamic>{
    'id': r['id'],
    'empleado_id': r['empleado_id'],
    'empleado_nombre': _texto(e?['nombre_completo']).isNotEmpty
        ? e!['nombre_completo']
        : _texto(r['empleado_nombre']),
    'cargo': _texto(e?['cargo']).isNotEmpty ? e!['cargo'] : _texto(r['cargo']),
    'mes': mes,
    'anio': anio,
    'salario_bruto': _num(r['salario_base']) + _num(r['bonos']),
    'bonos': _num(r['bonos']),
    'horas_extra': _num(r['horas_extra']),
    'ihss_empleado': _num(r['isss']),
    'rap_empleado': _num(r['rap']),
    'inpcafam': _num(r['inpcafam']),
    'deducciones_otras': _num(r['deducciones']) -
        _num(r['isss']) -
        _num(r['rap']) -
        _num(r['inpcafam']),
    'total_deducciones': _num(r['deducciones']),
    'salario_neto': _num(r['neta']),
    'ihss_empleador': _num(r['ihss_empleador']),
    'rpv_empleador': _num(r['rpv']),
    'total_costo_empleador': _num(r['costo_total_empleador']),
    'pagado': r['pagado'] == true,
    'fecha_pago': _texto(r['fecha_pago']),
    'fecha_generacion': _texto(r['created_at']),
    'comentarios': _texto(r['comentarios']),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Migración de los datos locales
// ─────────────────────────────────────────────────────────────────────────────

/// Sube a la empresa del token los empleados que estaban solo en este
/// dispositivo.
///
/// Reglas:
///  * Idempotente: se marca con un flag; si ya se importó no vuelve a tocar
///    nada.
///  * Nunca borra la clave local `empleados`. Sigue siendo el respaldo de este
///    dispositivo y `BackupManager` la incluye en sus copias.
///  * Si no hay conexión o el plan no incluye RRHH, NO marca el flag, para
///    reintentar en la próxima apertura.
///  * No importa `recibos_nomina` local: son el cálculo de esos empleados y el
///    servidor los vuelve a generar con `POST /api/rrhh/nomina/calcular`.
///    Los recibos pagados ya viven en la tabla `nomina` y nunca se tocan.
class MigracionRRHHLocal {
  MigracionRRHHLocal._();

  static const String _flag = 'rrhh_importado_al_servidor_v1';
  static const String _claveLocal = 'empleados';

  /// Devuelve la cantidad de empleados subidos, o `null` si no se intentó
  /// (sin conexión, plan sin RRHH o error del servidor).
  static Future<int?> importarSiPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flag) == true) return 0;

    final local = JsonGuard.safeListOfMaps(
      prefs.getString(_claveLocal) ?? '[]',
      source: 'RRHH/importacion',
    );
    if (local.isEmpty) {
      await prefs.setBool(_flag, true);
      return 0;
    }

    try {
      final svc = ModulosAvanzadosService.instance;
      final remotos = await svc.empleados();
      // Plan sin RRHH o sin red: se reintenta en la próxima apertura.
      if (!remotos.ok || remotos.datos == null) return null;

      final existentes = remotos.datos!
          .map(empleadoDesdeServidor)
          .toList(growable: false);
      final clavesExistentes = existentes.map(_clave).toSet();

      var subidos = 0;
      for (final e in local) {
        if (clavesExistentes.contains(_clave(e))) continue;
        final r = await svc.guardarEmpleado(empleadoParaServidor(e));
        if (r.ok) subidos++;
      }

      // La clave local queda intacta como respaldo; el flag evita repetir.
      await prefs.setBool(_flag, true);
      return subidos;
    } catch (_) {
      // Cualquier fallo deja el flag sin marcar para reintentar luego.
      return null;
    }
  }

  /// Identidad de un empleado para no duplicarlo al importar.
  static String _clave(Map<String, dynamic> e) {
    final email = _texto(e['email']).toLowerCase().trim();
    if (email.isNotEmpty) return 'email:$email';
    final nombre = _texto(e['nombre_completo']).isNotEmpty
        ? _texto(e['nombre_completo'])
        : '${_texto(e['nombre'])} ${_texto(e['apellido'])}'.trim();
    final cargo = _texto(e['cargo']).toLowerCase().trim();
    return 'nom:${nombre.toLowerCase()}|$cargo';
  }

  /// Solo para pruebas / depuración: permite volver a intentar la subida.
  static Future<void> reiniciar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_flag);
  }
}
