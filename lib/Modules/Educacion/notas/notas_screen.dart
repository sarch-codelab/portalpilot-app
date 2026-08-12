import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// Áreas/Educacion/Notas/notas.dart
// Sistema de Calificaciones con Roles, Rúbricas y Auditoría
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════

/// Representa un componente de evaluación (tarea, examen, proyecto, etc.)
class RubroEvaluacion {
  final String id;
  final String nombre;
  final double porcentaje; // 0.0 a 1.0
  final double notaMaxima;
  final int orden;

  const RubroEvaluacion({
    required this.id,
    required this.nombre,
    required this.porcentaje,
    required this.notaMaxima,
    required this.orden,
  });
}

/// Representa la configuración de rúbrica de una asignatura
class RubricaAsignatura {
  final String id;
  final String asignaturaId;
  final String periodoId;
  final List<RubroEvaluacion> rubros;
  final bool requiereRecuperacion;
  final double notaMinimaAprobacion;
  final double notaMaximaRecuperacion;

  const RubricaAsignatura({
    required this.id,
    required this.asignaturaId,
    required this.periodoId,
    required this.rubros,
    this.requiereRecuperacion = true,
    this.notaMinimaAprobacion = 60.0,
    this.notaMaximaRecuperacion = 80.0,
  });

  /// Calcula el peso total de todos los rubros
  double get pesoTotal => rubros.fold(0.0, (sum, r) => sum + r.porcentaje);
}

/// Estado especial de una nota (NSP, Retirado, etc.)
enum EstadoNotaEspecial {
  normal,
  noSePresento,
  retirado,
  eximido,
  enProceso,
}

/// Registro individual de nota de un alumno en un rubro específico
class NotaRegistro {
  final String id;
  final String matriculaId;
  final String asignaturaId;
  final String periodoId;
  final String rubroId;
  double? calificacion;
  EstadoNotaEspecial estadoEspecial;
  bool esRecuperacion;
  final DateTime fechaRegistro;
  final String usuarioRegistro;
  final String? justificacion;

  NotaRegistro({
    required this.id,
    required this.matriculaId,
    required this.asignaturaId,
    required this.periodoId,
    required this.rubroId,
    this.calificacion,
    this.estadoEspecial = EstadoNotaEspecial.normal,
    this.esRecuperacion = false,
    required this.fechaRegistro,
    required this.usuarioRegistro,
    this.justificacion,
  });

  /// Calcula la nota ponderada según el porcentaje del rubro
  double? get notaPonderada {
    if (calificacion == null) return null;
    if (estadoEspecial != EstadoNotaEspecial.normal) return null;
    return calificacion; // El peso se aplica al calcular el promedio
  }
}

/// Log de auditoría para cambios de notas
class NotaAuditoriaLog {
  final String id;
  final String notaId;
  final String usuarioId;
  final String usuarioNombre;
  final double? valorAnterior;
  final double? valorNuevo;
  final String accion; // 'crear', 'modificar', 'eliminar', 'recuperacion'
  final String? justificacion;
  final DateTime fecha;

  const NotaAuditoriaLog({
    required this.id,
    required this.notaId,
    required this.usuarioId,
    required this.usuarioNombre,
    this.valorAnterior,
    this.valorNuevo,
    required this.accion,
    this.justificacion,
    required this.fecha,
  });
}

/// Periodo académico (trimestre, cuatrimestre, etc.)
class PeriodoAcademico {
  final String id;
  final String nombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool estaCerrado;
  final String empresaCodigo;

  const PeriodoAcademico({
    required this.id,
    required this.nombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estaCerrado,
    required this.empresaCodigo,
  });
}

/// Datos consolidados de un alumno para mostrar en boleta
class BoletaAlumno {
  final String matriculaId;
  final String nombreAlumno;
  final String grado;
  final String seccion;
  final Map<String, List<NotaRegistro>> notasPorAsignatura;
  final Map<String, RubricaAsignatura> rubricas;

  BoletaAlumno({
    required this.matriculaId,
    required this.nombreAlumno,
    required this.grado,
    required this.seccion,
    required this.notasPorAsignatura,
    required this.rubricas,
  });

  /// Calcula el promedio general del alumno
  double get promedioGeneral {
    if (notasPorAsignatura.isEmpty) return 0.0;
    double suma = 0.0;
    int count = 0;
    for (final entry in notasPorAsignatura.entries) {
      final promedio = calcularPromedioAsignatura(entry.key, entry.value);
      if (promedio != null) {
        suma += promedio;
        count++;
      }
    }
    return count > 0 ? suma / count : 0.0;
  }

  /// Calcula el promedio de una asignatura específica
  double? calcularPromedioAsignatura(String asignaturaId, List<NotaRegistro> notas) {
    final rubrica = rubricas[asignaturaId];
    if (rubrica == null || notas.isEmpty) return null;

    double sumaPonderada = 0.0;
    double pesoTotalUsado = 0.0;

    for (final rubro in rubrica.rubros) {
      // Buscar la nota del alumno en este rubro (preferir recuperación si existe)
      final notasRubro = notas.where((n) => n.rubroId == rubro.id).toList();
      NotaRegistro? notaFinal;
      
      if (notasRubro.any((n) => n.esRecuperacion)) {
        notaFinal = notasRubro.firstWhere((n) => n.esRecuperacion);
      } else if (notasRubro.isNotEmpty) {
        notaFinal = notasRubro.first;
      }

      if (notaFinal != null && notaFinal.calificacion != null && 
          notaFinal.estadoEspecial == EstadoNotaEspecial.normal) {
        sumaPonderada += notaFinal.calificacion! * rubro.porcentaje;
        pesoTotalUsado += rubro.porcentaje;
      }
    }

    return pesoTotalUsado > 0 ? sumaPonderada / pesoTotalUsado : null;
  }

  /// Determina si el alumno está aprobado
  bool get estaAprobado => promedioGeneral >= 60.0;

  /// Obtiene asignaturas reprobadas
  List<String> get asignaturasReprobadas {
    final reprobadas = <String>[];
    for (final entry in notasPorAsignatura.entries) {
      final promedio = calcularPromedioAsignatura(entry.key, entry.value);
      if (promedio != null && promedio < 60.0) {
        reprobadas.add(entry.key);
      }
    }
    return reprobadas;
  }
}

// ═══════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE NOTAS
// ═══════════════════════════════════════════════════════════

class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> with TickerProviderStateMixin {
  // ── DATOS DEL USUARIO ──
  String _nombreUsuario = 'Usuario';
  String _rolUsuario = 'profesor';
  String _empresaCodigo = 'ROOT';
  bool _isUserLoaded = false;

  // ── FILTROS EN CASCADA ──
  String? _periodoSeleccionado;
  String? _gradoSeleccionado;
  String? _seccionSeleccionada;
  String? _asignaturaSeleccionada;

  // ── DATOS DE LA TABLA ──
  List<Map<String, dynamic>> _alumnos = [];
  List<RubroEvaluacion> _rubrosActuales = [];
  Map<String, Map<String, double?>> _notasEditadas = {}; // alumnoId -> rubroId -> nota
  Map<String, dynamic> _notasPersistidas = {}; // clave -> snapshot guardado
  bool _periodoCerrado = false;

  // ── VISTA ACTUAL ──
  bool _esVistaProfesor = true;

  // ── DATOS DE PRUEBA ──
  final List<PeriodoAcademico> _periodos = [
    PeriodoAcademico(
      id: 'p1',
      nombre: '1er Trimestre 2026',
      fechaInicio: DateTime(2026, 1, 15),
      fechaFin: DateTime(2026, 4, 15),
      estaCerrado: true,
      empresaCodigo: 'ROOT',
    ),
    PeriodoAcademico(
      id: 'p2',
      nombre: '2do Trimestre 2026',
      fechaInicio: DateTime(2026, 4, 16),
      fechaFin: DateTime(2026, 7, 15),
      estaCerrado: false,
      empresaCodigo: 'ROOT',
    ),
    PeriodoAcademico(
      id: 'p3',
      nombre: '3er Trimestre 2026',
      fechaInicio: DateTime(2026, 7, 16),
      fechaFin: DateTime(2026, 11, 15),
      estaCerrado: false,
      empresaCodigo: 'ROOT',
    ),
  ];

  final List<String> _grados = ['1° Grado', '2° Grado', '3° Grado', '4° Grado', '5° Grado', '6° Grado'];
  final List<String> _secciones = ['Sección A', 'Sección B', 'Sección Única'];
  final List<String> _asignaturas = ['Matemáticas', 'Español', 'Ciencias Naturales', 'Estudios Sociales', 'Inglés'];

  // ── ALUMNOS DE PRUEBA ──
  final List<Map<String, dynamic>> _alumnosPrueba = [
    {'id': 'm1', 'nombre': 'Carlos Mendoza López', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm2', 'nombre': 'Ana Sofía Ramírez Torres', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm3', 'nombre': 'Diego Hernández Ruiz', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm4', 'nombre': 'Valentina García Morales', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm5', 'nombre': 'Mateo Sánchez Flores', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm6', 'nombre': 'Isabella Torres Ruiz', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm7', 'nombre': 'Sebastián Morales Vargas', 'grado': '5° Grado', 'seccion': 'A'},
    {'id': 'm8', 'nombre': 'Renata Jiménez Castro', 'grado': '5° Grado', 'seccion': 'A'},
  ];

  // ── RÚBRICA POR DEFECTO ──
  final List<RubroEvaluacion> _rubrosDefault = [
    const RubroEvaluacion(id: 'r1', nombre: 'Tareas', porcentaje: 0.30, notaMaxima: 100, orden: 1),
    const RubroEvaluacion(id: 'r2', nombre: 'Proyectos', porcentaje: 0.20, notaMaxima: 100, orden: 2),
    const RubroEvaluacion(id: 'r3', nombre: 'Examen', porcentaje: 0.50, notaMaxima: 100, orden: 3),
  ];

  // ── NOTAS DE PRUEBA ──
  final Map<String, Map<String, double?>> _notasPrueba = {
    'm1': {'r1': 85, 'r2': 90, 'r3': 78},
    'm2': {'r1': 92, 'r2': 88, 'r3': 95},
    'm3': {'r1': 65, 'r2': 70, 'r3': 55},
    'm4': {'r1': 78, 'r2': 82, 'r3': 75},
    'm5': {'r1': 45, 'r2': 50, 'r3': 40},
    'm6': {'r1': 88, 'r2': 92, 'r3': 85},
    'm7': {'r1': 72, 'r2': 68, 'r3': 70},
    'm8': {'r1': 95, 'r2': 98, 'r3': 92},
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    await AuthController.instance.restore();
    setState(() {
      _nombreUsuario = AuthController.instance.nombreCompleto;
      _rolUsuario = AuthController.instance.rol;
      _empresaCodigo = AuthController.instance.empresaCodigo;
      _esVistaProfesor = _rolUsuario.toLowerCase() == 'profesor' ||
          _rolUsuario.toLowerCase() == 'admin';
      _isUserLoaded = true;

      // Abre el editor directamente en el periodo activo (abierto) para que
      // la tabla de calificaciones aparezca sin pasar por un estado bloqueado.
      if (_periodoSeleccionado == null) {
        final abierto = _periodos.indexWhere((per) => !per.estaCerrado);
        if (abierto >= 0) {
          _periodoSeleccionado = _periodos[abierto].id;
          _periodoCerrado = false;
        } else {
          _periodoSeleccionado = _periodos.first.id;
          _periodoCerrado = _periodos.first.estaCerrado;
        }
        _gradoSeleccionado = _grados.first;
        _seccionSeleccionada = _secciones.first;
        _asignaturaSeleccionada = _asignaturas.first;
        _rubrosActuales = _rubrosDefault;
        _alumnos = _alumnosPrueba;
        _notasEditadas = _notasDesdePersistencia();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    try {
      final persistidas = prefs.getString('notas_persistidas');
      if (persistidas != null) {
        _notasPersistidas = Map<String, dynamic>.from(jsonDecode(persistidas));
        if (_asignaturaSeleccionada != null) {
          setState(() => _notasEditadas = _notasDesdePersistencia());
        }
      }
    } catch (_) {}

    _cargarNotasRemotas();
  }

  /// Clave única para el snapshot actual: periodo|grado|seccion|asignatura
  String get _claveNotas =>
      '$_periodoSeleccionado|$_gradoSeleccionado|$_seccionSeleccionada|$_asignaturaSeleccionada';

  /// Carga el snapshot guardado localmente para la selección actual,
  /// o las notas de prueba si no existe.
  Map<String, Map<String, double?>> _notasDesdePersistencia() {
    final snapshot = _notasPersistidas[_claveNotas];
    if (snapshot is Map && snapshot['notas'] is Map) {
      final raw = snapshot['notas'] as Map;
      return raw.map((k, v) {
        final inner = v is Map
            ? v.map((rk, rv) => MapEntry(rk.toString(), (rv as num?)?.toDouble()))
            : <String, double?>{};
        return MapEntry(k.toString(), inner);
      });
    }
    return Map.from(_notasPrueba);
  }

  /// Consulta el snapshot en Supabase para la selección actual (best-effort).
  Future<void> _cargarNotasRemotas() async {
    if (_empresaCodigo.isEmpty || _empresaCodigo == 'ROOT') return;
    try {
      final remoto = await PortalPilotDB.getNotas(_empresaCodigo, _claveNotas);
      if (remoto == null) return;
      final datos = remoto['datos'];
      if (datos is Map && datos['notas'] is Map) {
        final raw = datos['notas'] as Map;
        final notas = raw.map((k, v) {
          final inner = v is Map
              ? v.map((rk, rv) => MapEntry(rk.toString(), (rv as num?)?.toDouble()))
              : <String, double?>{};
          return MapEntry(k.toString(), inner);
        });
        setState(() => _notasEditadas = notas);
        _notasPersistidas[_claveNotas] = datos;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('notas_persistidas', jsonEncode(_notasPersistidas));
      }
    } catch (_) {}
  }

  ThemePalette _palette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ThemePalette(isDark: isDark);
  }

  // ═══════════════════════════════════════════════════════════
  // COLORES CONDICIONALES PARA NOTAS
  // ═══════════════════════════════════════════════════════════

  Color _getColorNota(double? nota, ThemePalette p) {
    if (nota == null) return p.textMuted;
    if (nota >= 90) return const Color(0xFF10B981); // Excelente - verde
    if (nota >= 80) return const Color(0xFF3B82F6); // Muy bueno - azul
    if (nota >= 70) return const Color(0xFF8B5CF6); // Bueno - púrpura
    if (nota >= 60) return const Color(0xFFF59E0B); // Regular - ámbar
    return const Color(0xFFEF4444); // Reprobado - rojo
  }

  String _getEstadoNota(double? nota) {
    if (nota == null) return 'Sin calificar';
    if (nota >= 90) return 'Excelente';
    if (nota >= 80) return 'Muy Bueno';
    if (nota >= 70) return 'Bueno';
    if (nota >= 60) return 'Regular';
    return 'Reprobado';
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);

    if (!_isUserLoaded) {
      return Scaffold(
        backgroundColor: p.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: p.accentPurple)),
      );
    }

    return Scaffold(
      backgroundColor: p.bgPrimary,
      appBar: AppBar(
        backgroundColor: p.bgSecondary,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.accentPurple, p.accentPurpleDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.grade_rounded, color: p.textPrimary, size: 16),
            ),
            const SizedBox(width: 12),
            Text('SISTEMA DE NOTAS',
                style: GoogleFonts.syne(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: p.textPrimary, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          // Toggle vista profesor/alumno
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.accentPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_esVistaProfesor ? Icons.school_rounded : Icons.badge_rounded, 
                    color: p.accentPurple, size: 14),
                const SizedBox(width: 4),
                Text(_esVistaProfesor ? 'PROFESOR' : 'ALUMNO',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.bold, color: p.accentPurple)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: p.accentPurple,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
              if (mounted) setState(() {});
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.accentPurple, width: 2),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: p.bgTertiary,
              child: Text(_nombreUsuario.substring(0, 2).toUpperCase(), 
                  style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              p.accentPurple.withValues(alpha: p.isDark ? 0.03 : 0.06),
              p.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: _esVistaProfesor ? _buildVistaProfesor(p) : _buildVistaAlumno(p),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTA PROFESOR (Tabla tipo Excel)
  // ═══════════════════════════════════════════════════════════

  Widget _buildVistaProfesor(ThemePalette p) {
    return Column(
      children: [
        // ── HEADER ──
        _buildHeader('Registro de Calificaciones', 'Ingrese las notas de los alumnos por rubro de evaluación',
            icon: Icons.edit_note_rounded, p: p),
        
        // ── FILTROS EN CASCADA ──
        _buildFiltrosCascada(p),
        
        // ── INDICADOR DE PERIODO CERRADO ──
        if (_periodoSeleccionado != null && _periodos.firstWhere((per) => per.id == _periodoSeleccionado).estaCerrado)
          _buildPeriodoCerradoBanner(p),
        
        // ── RÚBRICA ACTUAL ──
        if (_asignaturaSeleccionada != null) _buildRubricaBanner(p),
        
        // ── TABLA DE NOTAS ──
        Expanded(
          child: _asignaturaSeleccionada != null
              ? _buildTablaNotas(p)
              : _buildPlaceholderFiltros(p),
        ),
        
        // ── BOTONES DE ACCIÓN ──
        if (_asignaturaSeleccionada != null && !_periodoCerrado)
          _buildBotonesAccion(p),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle, {required IconData icon, required ThemePalette p}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accentPurple, p.accentPurpleDark],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: p.accentPurple.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900,
                        color: p.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FILTROS EN CASCADA
  // ═══════════════════════════════════════════════════════════

  Widget _buildFiltrosCascada(ThemePalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(36, 0, 36, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, color: p.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text('FILTROS DE VISUALIZACIÓN',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold,
                      color: p.textMuted, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownFiltro(
                  label: 'Periodo Académico',
                  icon: Icons.calendar_today_rounded,
                  items: _periodos.map((per) => per.nombre).toList(),
                  value: _periodoSeleccionado != null
                      ? _periodos.firstWhere((per) => per.id == _periodoSeleccionado).nombre
                      : null,
                  onChanged: (v) {
                    setState(() {
                      _periodoSeleccionado = _periodos.firstWhere((per) => per.nombre == v).id;
                      _gradoSeleccionado = null;
                      _seccionSeleccionada = null;
                      _asignaturaSeleccionada = null;
                      _periodoCerrado = _periodos.firstWhere((per) => per.id == _periodoSeleccionado).estaCerrado;
                    });
                  },
                  p: p,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFiltro(
                  label: 'Grado / Curso',
                  icon: Icons.school_rounded,
                  items: _gradoSeleccionado != null || _periodoSeleccionado != null ? _grados : [],
                  value: _gradoSeleccionado,
                  enabled: _periodoSeleccionado != null,
                  onChanged: (v) {
                    setState(() {
                      _gradoSeleccionado = v;
                      _seccionSeleccionada = null;
                      _asignaturaSeleccionada = null;
                    });
                  },
                  p: p,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFiltro(
                  label: 'Sección',
                  icon: Icons.view_column_rounded,
                  items: _seccionSeleccionada != null || _gradoSeleccionado != null ? _secciones : [],
                  value: _seccionSeleccionada,
                  enabled: _gradoSeleccionado != null,
                  onChanged: (v) {
                    setState(() {
                      _seccionSeleccionada = v;
                      _asignaturaSeleccionada = null;
                    });
                  },
                  p: p,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFiltro(
                  label: 'Asignatura',
                  icon: Icons.menu_book_rounded,
                  items: _asignaturaSeleccionada != null || _seccionSeleccionada != null ? _asignaturas : [],
                  value: _asignaturaSeleccionada,
                  enabled: _seccionSeleccionada != null,
                  onChanged: (v) {
                    setState(() {
                      _asignaturaSeleccionada = v;
                      _rubrosActuales = _rubrosDefault;
                      _alumnos = _alumnosPrueba;
                      _notasEditadas = _notasDesdePersistencia();
                    });
                    _cargarNotasRemotas();
                    _cargarRubricasPersistidas();
                  },
                  p: p,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFiltro({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    required ThemePalette p,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold,
                color: p.textDark, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? p.bgTertiary : p.bgSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: enabled ? p.borderLight : p.borderLight.withValues(alpha: 0.5)),
          ),
          child: DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: value,
            dropdownColor: p.bgTertiary,
            style: GoogleFonts.dmSans(fontSize: 12, color: p.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: enabled ? p.accentPurple : p.textMuted, size: 16),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: p.textMuted, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: GoogleFonts.dmSans(fontSize: 12, color: p.textPrimary)),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BANNER DE PERIODO CERRADO
  // ═══════════════════════════════════════════════════════════

  Widget _buildPeriodoCerradoBanner(ThemePalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(36, 0, 36, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.errorRed.withValues(alpha: 0.15), p.errorRed.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.errorRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: p.errorRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERIODO CERRADO',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold,
                        color: p.errorRed, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text('Las notas de este periodo están bloqueadas. Contacte a dirección para modificaciones.',
                    style: GoogleFonts.dmSans(fontSize: 11, color: p.errorRed)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('ðŸ“§ Solicitud enviada a dirección'),
                  backgroundColor: p.accentPurple,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('SOLICITAR CAMBIO',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: p.errorRed)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BANNER DE RÚBRICA
  // ═══════════════════════════════════════════════════════════

  Widget _buildRubricaBanner(ThemePalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(36, 0, 36, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: p.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text('RÚBRICA DE EVALUACIÓN',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold,
                      color: p.textMuted, letterSpacing: 1.5)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _mostrarConfigRubrica(p),
                icon: Icon(Icons.edit_rounded, size: 14, color: p.accentPurple),
                label: Text('Configurar',
                    style: GoogleFonts.dmSans(fontSize: 11, color: p.accentPurple, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _rubrosActuales.map((rubro) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.accentPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.accentPurple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(rubro.nombre,
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: p.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${(rubro.porcentaje * 100).toInt()}%',
                          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: p.accentPurple)),
                      Text('Máx: ${rubro.notaMaxima.toInt()}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 9, color: p.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _mostrarConfigRubrica(ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.tune_rounded, color: p.accentPurple),
            const SizedBox(width: 10),
            Text('Configurar Rúbrica',
                style: GoogleFonts.dmSans(color: p.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._rubrosActuales.map((rubro) {
              return ListTile(
                leading: Icon(Icons.label_rounded, color: p.accentPurple),
                title: Text(rubro.nombre, style: GoogleFonts.dmSans(color: p.textPrimary)),
                subtitle: Text('Peso: ${(rubro.porcentaje * 100).toInt()}% · Máx: ${rubro.notaMaxima.toInt()}',
                    style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: p.errorRed, size: 18),
                      onPressed: () {
                        Navigator.pop(context);
                        _eliminarRubro(rubro, p);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_rounded, color: p.accentPurple, size: 18),
                      onPressed: () {
                        Navigator.pop(context);
                        _editarRubro(rubro, p);
                      },
                    ),
                  ],
                ),
              );
            }),
            if (_rubrosActuales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin rubros configurados. Agrega uno nuevo.',
                    style: GoogleFonts.dmSans(color: p.textMuted)),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _agregarRubro(p);
            },
            icon: Icon(Icons.add_rounded, color: p.successGreen, size: 18),
            label: Text('Agregar rubro', style: GoogleFonts.dmSans(color: p.successGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.dmSans(color: p.textMuted)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EDITOR DE RÚBRICAS (agregar / editar / eliminar rubros)
  // ═══════════════════════════════════════════════════════════

  Future<void> _persistirRubricas() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'rubricas_$_asignaturaSeleccionada';
    final rubrosJson = _rubrosActuales
        .map((r) => {
              'id': r.id,
              'nombre': r.nombre,
              'porcentaje': r.porcentaje,
              'nota_maxima': r.notaMaxima,
              'orden': r.orden,
            })
        .toList();
    await prefs.setString(key, jsonEncode(rubrosJson));
  }

  Future<void> _cargarRubricasPersistidas() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'rubricas_$_asignaturaSeleccionada';
    final json = prefs.getString(key);
    if (json == null) return;
    try {
      final List<dynamic> lista = jsonDecode(json);
      final rubros = lista.map<RubroEvaluacion>((r) {
        return RubroEvaluacion(
          id: r['id'] ?? 'r${DateTime.now().microsecondsSinceEpoch}',
          nombre: r['nombre'] ?? 'Rubro',
          porcentaje: (r['porcentaje'] as num?)?.toDouble() ?? 0.25,
          notaMaxima: (r['nota_maxima'] as num?)?.toDouble() ?? 100,
          orden: (r['orden'] as num?)?.toInt() ?? 1,
        );
      }).toList();
      if (mounted && rubros.isNotEmpty) {
        setState(() => _rubrosActuales = rubros);
      }
    } catch (_) {}
  }

  void _agregarRubro(ThemePalette p) {
    _editarDialogo(p, esNuevo: true);
  }

  void _editarRubro(RubroEvaluacion rubro, ThemePalette p) {
    _editarDialogo(p, rubro: rubro);
  }

  void _editarDialogo(ThemePalette p, {RubroEvaluacion? rubro, bool esNuevo = false}) {
    final esEdicion = rubro != null;
    final nombreController = TextEditingController(text: esEdicion ? rubro.nombre : '');
    final porcentajeController = TextEditingController(
      text: esEdicion ? ((rubro.porcentaje * 100).toStringAsFixed(1)) : '25.0',
    );
    final notaMaxController = TextEditingController(
      text: esEdicion ? rubro.notaMaxima.toStringAsFixed(0) : '100',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(esNuevo ? Icons.add_chart_rounded : Icons.edit_rounded, color: p.accentPurple),
            const SizedBox(width: 10),
            Text(esNuevo ? 'Nuevo Rubro' : 'Editar Rubro',
                style: GoogleFonts.dmSans(color: p.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: GoogleFonts.dmSans(color: p.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre del rubro',
                  labelStyle: GoogleFonts.dmSans(color: p.textMuted),
                  hintText: 'Ej: Examen parcial, Tareas, Proyecto...',
                  hintStyle: GoogleFonts.dmSans(color: p.textDark),
                  filled: true,
                  fillColor: p.bgSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: porcentajeController,
                style: GoogleFonts.dmSans(color: p.textPrimary),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso (%)',
                  labelStyle: GoogleFonts.dmSans(color: p.textMuted),
                  hintText: 'Ej: 30.0',
                  hintStyle: GoogleFonts.dmSans(color: p.textDark),
                  filled: true,
                  fillColor: p.bgSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notaMaxController,
                style: GoogleFonts.dmSans(color: p.textPrimary),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Nota máxima',
                  labelStyle: GoogleFonts.dmSans(color: p.textMuted),
                  hintText: 'Ej: 100',
                  hintStyle: GoogleFonts.dmSans(color: p.textDark),
                  filled: true,
                  fillColor: p.bgSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.borderLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              const SizedBox(height: 8),
              if (esEdicion)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('El peso total de la rúbrica debe sumar 100%.',
                      style: GoogleFonts.dmSans(fontSize: 11, color: p.textMuted)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: p.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final nombre = nombreController.text.trim();
              final porcentaje = double.tryParse(porcentajeController.text.trim().replaceAll(',', '.')) ?? 0;
              final notaMax = double.tryParse(notaMaxController.text.trim().replaceAll(',', '.')) ?? 100;
              if (nombre.isEmpty || porcentaje <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ingrese un nombre y peso válido', style: GoogleFonts.dmSans()),
                    backgroundColor: p.errorRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              setState(() {
                if (esEdicion) {
                  _rubrosActuales = _rubrosActuales.map((r) {
                    if (r.id == rubro.id) {
                      return RubroEvaluacion(
                        id: rubro.id,
                        nombre: nombre,
                        porcentaje: porcentaje / 100,
                        notaMaxima: notaMax,
                        orden: rubro.orden,
                      );
                    }
                    return r;
                  }).toList();
                } else {
                  final nuevoId = 'r${DateTime.now().microsecondsSinceEpoch}';
                  _rubrosActuales = [
                    ..._rubrosActuales,
                    RubroEvaluacion(
                      id: nuevoId,
                      nombre: nombre,
                      porcentaje: porcentaje / 100,
                      notaMaxima: notaMax,
                      orden: _rubrosActuales.length + 1,
                    ),
                  ];
                }
              });
              _persistirRubricas();
            },
            child: Text(esNuevo ? 'Agregar' : 'Guardar',
                style: GoogleFonts.dmSans(color: p.accentPurple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _eliminarRubro(RubroEvaluacion rubro, ThemePalette p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: p.errorRed),
            const SizedBox(width: 10),
            Text('Eliminar rubro', style: GoogleFonts.dmSans(color: p.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Eliminar "${rubro.nombre}" de la rúbrica?',
            style: GoogleFonts.dmSans(color: p.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: p.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _rubrosActuales = _rubrosActuales.where((r) => r.id != rubro.id).toList();
              });
              _persistirRubricas();
            },
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: p.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TABLA DE NOTAS (TIPO EXCEL)
  // ═══════════════════════════════════════════════════════════

  Widget _buildTablaNotas(ThemePalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(36, 0, 36, 16),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // ── HEADER DE LA TABLA ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: p.borderLight)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_chart_rounded, color: p.accentPurple, size: 18),
                const SizedBox(width: 8),
                Text('$_asignaturaSeleccionada · ${_alumnos.length} alumnos',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: p.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text('NOTA MÁX: 100',
                      style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                          color: p.successGreen, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          
          // ── CONTENIDO DE LA TABLA ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Fila de encabezados
                    Container(
                      decoration: BoxDecoration(
                        color: p.bgTertiary,
                        border: Border(bottom: BorderSide(color: p.borderLight)),
                      ),
                      child: Row(
                        children: [
                          // Columna de alumno
                          Container(
                            width: 220,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: p.borderLight)),
                            ),
                            child: Text('#',
                                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: p.textMuted, letterSpacing: 1)),
                          ),
                          Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: p.borderLight)),
                            ),
                            child: Text('ALUMNO',
                                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: p.textMuted, letterSpacing: 1)),
                          ),
                          // Columnas de rubros
                          ..._rubrosActuales.map((rubro) {
                            return Container(
                              width: 110,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: p.borderLight)),
                              ),
                              child: Column(
                                children: [
                                  Text(rubro.nombre.toUpperCase(),
                                      style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                                          color: p.accentPurple, letterSpacing: 0.8)),
                                  const SizedBox(height: 2),
                                  Text('${(rubro.porcentaje * 100).toInt()}%',
                                      style: GoogleFonts.spaceGrotesk(fontSize: 9, color: p.textMuted)),
                                ],
                              ),
                            );
                          }),
                          // Columna de promedio
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [p.accentPurple.withValues(alpha: 0.15), p.accentPurple.withValues(alpha: 0.05)]),
                              border: Border(left: BorderSide(color: p.accentPurple.withValues(alpha: 0.3))),
                            ),
                            child: Column(
                              children: [
                                Text('PROMEDIO',
                                    style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                                        color: p.accentPurple, letterSpacing: 1)),
                                const SizedBox(height: 2),
                                Text('100%',
                                    style: GoogleFonts.spaceGrotesk(fontSize: 9, color: p.textMuted)),
                              ],
                            ),
                          ),
                          // Columna de estado
                          Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: Text('ESTADO',
                                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: p.textMuted, letterSpacing: 1)),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filas de alumnos
                    ..._alumnos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final alumno = entry.value;
                      final alumnoId = alumno['id'] as String;
                      final notasAlumno = _notasEditadas[alumnoId] ?? {};
                      final promedio = _calcularPromedioAlumno(alumnoId, notasAlumno);
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: index.isEven ? p.cardColor : p.bgTertiary.withValues(alpha: 0.3),
                          border: Border(bottom: BorderSide(color: p.borderLight)),
                        ),
                        child: Row(
                          children: [
                            // Número
                            Container(
                              width: 220,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: p.borderLight)),
                              ),
                              child: Text('${index + 1}',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: p.textMuted)),
                            ),
                            // Nombre
                            Container(
                              width: 200,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: p.borderLight)),
                              ),
                              child: Text(alumno['nombre'] as String,
                                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: p.textPrimary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            // Notas por rubro
                            ..._rubrosActuales.map((rubro) {
                              final nota = notasAlumno[rubro.id];
                              return Container(
                                width: 110,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: p.borderLight)),
                                ),
                                child: _buildCeldaNota(
                                  nota: nota,
                                  notaMaxima: rubro.notaMaxima,
                                  alumnoId: alumnoId,
                                  rubroId: rubro.id,
                                  p: p,
                                ),
                              );
                            }),
                            // Promedio
                            Container(
                              width: 120,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  _getColorNota(promedio, p).withValues(alpha: 0.15),
                                  _getColorNota(promedio, p).withValues(alpha: 0.05),
                                ]),
                                border: Border(left: BorderSide(color: p.accentPurple.withValues(alpha: 0.3))),
                              ),
                              child: Center(
                                child: Text(
                                  promedio != null ? promedio.toStringAsFixed(1) : '-',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getColorNota(promedio, p),
                                  ),
                                ),
                              ),
                            ),
                            // Estado
                            Container(
                              width: 110,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getColorNota(promedio, p).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getColorNota(promedio, p).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    promedio != null ? _getEstadoNota(promedio) : 'Sin datos',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getColorNota(promedio, p),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeldaNota({
    required double? nota,
    required double notaMaxima,
    required String alumnoId,
    required String rubroId,
    required ThemePalette p,
  }) {
    final controller = TextEditingController(text: nota?.toString() ?? '');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: nota != null ? _getColorNota(nota, p).withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nota != null ? _getColorNota(nota, p).withValues(alpha: 0.3) : p.borderLight,
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: !_periodoCerrado,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: nota != null ? _getColorNota(nota, p) : p.textMuted,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
          _NotaMaximaInputFormatter(notaMaxima: notaMaxima),
        ],
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          isDense: true,
        ),
        onChanged: (value) {
          final nuevaNota = value.isEmpty ? null : double.tryParse(value);
          setState(() {
            _notasEditadas.putIfAbsent(alumnoId, () => {});
            _notasEditadas[alumnoId]![rubroId] = nuevaNota;
          });
        },
        onTap: () {
          if (_periodoCerrado) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('ðŸ”’ Periodo cerrado. No se puede modificar.'),
                backgroundColor: p.errorRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  double? _calcularPromedioAlumno(String alumnoId, Map<String, double?> notas) {
    double sumaPonderada = 0.0;
    double pesoTotal = 0.0;

    for (final rubro in _rubrosActuales) {
      final nota = notas[rubro.id];
      if (nota != null) {
        sumaPonderada += nota * rubro.porcentaje;
        pesoTotal += rubro.porcentaje;
      }
    }

    return pesoTotal > 0 ? sumaPonderada / pesoTotal : null;
  }

  // ═══════════════════════════════════════════════════════════
  // BOTONES DE ACCIÓN
  // ═══════════════════════════════════════════════════════════

  Widget _buildBotonesAccion(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.bgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.borderLight),
              ),
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ðŸ“‹ Reporte generado'),
                      backgroundColor: p.accentPurple,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(Icons.file_download_rounded, size: 18, color: p.textPrimary),
                label: Text('Generar Reporte',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: p.textPrimary)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.accentPurple, p.accentPurpleDark]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: p.accentPurple.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _guardarNotas,
                icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                label: Text('Guardar Calificaciones',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarNotas() async {
    if (_asignaturaSeleccionada == null || _notasEditadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay calificaciones para guardar', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final snapshot = {
      'notas': _notasEditadas,
      'periodo': _periodoSeleccionado,
      'grado': _gradoSeleccionado,
      'seccion': _seccionSeleccionada,
      'asignatura': _asignaturaSeleccionada,
      'guardado_en': DateTime.now().toIso8601String(),
    };

    // Persistencia local (SharedPreferences)
    _notasPersistidas[_claveNotas] = snapshot;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notas_persistidas', jsonEncode(_notasPersistidas));

    // Sync a Supabase (best-effort)
    var sincronizado = false;
    if (_empresaCodigo.isNotEmpty && _empresaCodigo != 'ROOT') {
      try {
        sincronizado = await PortalPilotDB.saveNotas(
          empresaCodigo: _empresaCodigo,
          clave: _claveNotas,
          datos: snapshot,
        );
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sincronizado
                      ? '✓ ${_notasEditadas.length} calificaciones guardadas y sincronizadas'
                      : '✓ ${_notasEditadas.length} calificaciones guardadas localmente',
                  style: GoogleFonts.dmSans(),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PLACEHOLDER CUANDO NO HAY FILTROS
  // ═══════════════════════════════════════════════════════════

  Widget _buildPlaceholderFiltros(ThemePalette p) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.accentPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.filter_list_rounded, color: p.accentPurple, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Seleccione todos los filtros',
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: p.textPrimary)),
          const SizedBox(height: 8),
          Text('Periodo → Grado → Sección → Asignatura',
              style: GoogleFonts.dmSans(fontSize: 13, color: p.textMuted)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISTA ALUMNO (BOLETA DE CALIFICACIONES)
  // ═══════════════════════════════════════════════════════════

  Widget _buildVistaAlumno(ThemePalette p) {
    // Datos simulados del alumno
    final nombreAlumno = _nombreUsuario;
    final grado = '5° Grado';
    final seccion = 'Sección A';
    final periodo = '2do Trimestre 2026';
    
    // Calificaciones por asignatura
    final calificaciones = {
      'Matemáticas': {'Tareas': 85.0, 'Proyectos': 90.0, 'Examen': 78.0, 'peso': [0.3, 0.2, 0.5]},
      'Español': {'Tareas': 92.0, 'Proyectos': 88.0, 'Examen': 95.0, 'peso': [0.3, 0.2, 0.5]},
      'Ciencias Naturales': {'Tareas': 78.0, 'Proyectos': 82.0, 'Examen': 75.0, 'peso': [0.3, 0.2, 0.5]},
      'Estudios Sociales': {'Tareas': 88.0, 'Proyectos': 92.0, 'Examen': 85.0, 'peso': [0.3, 0.2, 0.5]},
      'Inglés': {'Tareas': 95.0, 'Proyectos': 98.0, 'Examen': 92.0, 'peso': [0.3, 0.2, 0.5]},
    };

    // Calcular promedios
    final promedios = <String, double>{};
    for (final entry in calificaciones.entries) {
      final notas = entry.value;
      final pesos = notas['peso'] as List<double>;
      double suma = 0.0;
      int i = 0;
      for (final key in ['Tareas', 'Proyectos', 'Examen']) {
        suma += (notas[key] as double) * pesos[i];
        i++;
      }
      promedios[entry.key] = suma;
    }

    final promedioGeneral = promedios.values.fold(0.0, (a, b) => a + b) / promedios.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          _buildHeader('Boleta de Calificaciones', 'Reporte oficial del desempeño académico',
              icon: Icons.receipt_long_rounded, p: p),
          
          // ── TARJETA DE INFORMACIÓN DEL ALUMNO ──
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accentPurple.withValues(alpha: 0.15), p.accentPurpleDark.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.accentPurple, p.accentPurpleDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: p.accentPurple.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Center(
                    child: Text(nombreAlumno.substring(0, 2).toUpperCase(),
                        style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombreAlumno,
                          style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w900, color: p.textPrimary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip('$grado · $seccion', Icons.school_rounded, p.accentPurple, p),
                          _buildInfoChip(periodo, Icons.calendar_today_rounded, p.infoBlue, p),
                        ],
                      ),
                    ],
                  ),
                ),
                // Promedio general
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getColorNota(promedioGeneral, p).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getColorNota(promedioGeneral, p).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text('PROMEDIO',
                          style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold,
                              color: p.textMuted, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text(promedioGeneral.toStringAsFixed(1),
                          style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold,
                              color: _getColorNota(promedioGeneral, p))),
                      Text(_getEstadoNota(promedioGeneral),
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold,
                              color: _getColorNota(promedioGeneral, p))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── DETALLE POR ASIGNATURA ──
          Text('DETALLE POR ASIGNATURA',
              style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold,
                  color: p.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          ...calificaciones.entries.map((entry) {
            final asignatura = entry.key;
            final notas = entry.value;
            final promedio = promedios[asignatura]!;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getColorNota(promedio, p).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.menu_book_rounded, color: _getColorNota(promedio, p), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(asignatura,
                            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: p.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _getColorNota(promedio, p).withValues(alpha: 0.2),
                            _getColorNota(promedio, p).withValues(alpha: 0.05),
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getColorNota(promedio, p).withValues(alpha: 0.4)),
                        ),
                        child: Text(promedio.toStringAsFixed(1),
                            style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold,
                                color: _getColorNota(promedio, p))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final rubro in ['Tareas', 'Proyectos', 'Examen'])
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: p.bgTertiary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(rubro,
                                    style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold,
                                        color: p.textMuted, letterSpacing: 0.8)),
                                const SizedBox(height: 4),
                                Text((notas[rubro] as double).toStringAsFixed(0),
                                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold,
                                        color: _getColorNota(notas[rubro] as double, p))),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── RESUMEN FINAL ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  promedioGeneral >= 60 
                      ? p.successGreen.withValues(alpha: 0.15)
                      : p.errorRed.withValues(alpha: 0.15),
                  (promedioGeneral >= 60 ? p.successGreen : p.errorRed).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (promedioGeneral >= 60 ? p.successGreen : p.errorRed).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  promedioGeneral >= 60 ? Icons.emoji_events_rounded : Icons.warning_rounded,
                  color: promedioGeneral >= 60 ? p.successGreen : p.errorRed,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promedioGeneral >= 60 ? '¡ALUMNO APROBADO!' : 'ALUMNO EN RIESGO',
                        style: GoogleFonts.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: promedioGeneral >= 60 ? p.successGreen : p.errorRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        promedioGeneral >= 60 
                            ? 'Felicidades, has aprobado el periodo con un promedio de ${promedioGeneral.toStringAsFixed(1)}'
                            : 'Tu promedio actual es ${promedioGeneral.toStringAsFixed(1)}. Necesitas mejorar para aprobar.',
                        style: GoogleFonts.dmSans(fontSize: 12, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, Color color, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// INPUT FORMATTER PARA LIMITAR NOTA MÁXIMA
// ═══════════════════════════════════════════════════════════

class _NotaMaximaInputFormatter extends TextInputFormatter {
  final double notaMaxima;

  _NotaMaximaInputFormatter({required this.notaMaxima});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final valor = double.tryParse(text);
    if (valor == null) return oldValue;

    if (valor > notaMaxima) {
      return TextEditingValue(
        text: notaMaxima.toStringAsFixed(valor.toString().contains('.') ? 1 : 0),
        selection: TextSelection.collapsed(offset: notaMaxima.toString().length),
      );
    }

    return newValue;
  }
}

// ═══════════════════════════════════════════════════════════
// THEME PALETTE (LOCAL PARA ESTE ARCHIVO)
// ═══════════════════════════════════════════════════════════

class ThemePalette {
  final bool isDark;
  ThemePalette({required this.isDark});

  Color get bgPrimary => isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  Color get bgSecondary => isDark ? const Color(0xFF080808) : const Color(0xFFEDEDED);
  Color get bgTertiary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE5E5EA);
  Color get cardColor => isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);

  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textSecondary => isDark ? const Color(0xFFE5E5E5) : const Color(0xFF334155);
  Color get textMuted => isDark ? const Color(0xFFA3A3A3) : const Color(0xFF64748B);
  Color get textDark => isDark ? const Color(0xFF525252) : const Color(0xFF94A3B8);

  Color get successGreen => const Color(0xFF10B981);
  Color get errorRed => const Color(0xFFEF4444);
  Color get warningAmber => const Color(0xFFF59E0B);
  Color get infoBlue => const Color(0xFF3B82F6);

  Color get borderLight => isDark ? const Color(0x29FFFFFF) : const Color(0x1A000000);
}