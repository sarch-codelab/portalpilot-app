import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/membresia_service.dart';

/// Registro de socios y sus membresías.
class SocioScreen extends StatefulWidget {
  const SocioScreen({super.key});

  @override
  State<SocioScreen> createState() => _SocioScreenState();
}

class _SocioScreenState extends State<SocioScreen> {
  final _service = MembresiaService.instance;

  bool _cargando = true;
  List<SocioFila> _socios = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final socios = await _service.getSociosFila();
    if (!mounted) return;
    setState(() {
      _socios = socios;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'SOCIOS',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _crearSocio(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nuevo Socio',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF8B5CF6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_socios.isEmpty)
                    _buildVacio()
                  else
                    ..._socios.map(
                      (sf) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildSocioCard(sf),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }

  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin socios',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Registrá socios para asignarles membresías y precios preferenciales.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildSocioCard(SocioFila sf) {
    final s = sf.socio;
    final a = sf.afiliacionActiva;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _SocioDetalleScreen(socioId: s.id)),
        );
        _cargar();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !s.activo
                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                : const Color(0xFF262626),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: a != null
                      ? const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]
                      : const [Color(0xFF262626), Color(0xFF1A1A1A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _iniciales(s.nombre),
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: a != null ? Colors.white : const Color(0xFF737373),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nombre,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (a != null)
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFF8B5CF6), size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${a.membresiaNombre} · vence ${_fecha(a.fechaFin)}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _detalleSocio(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
  }

  String _detalleSocio(Socio s) {
    final datos = <String>[];
    if (s.telefono?.trim().isNotEmpty == true) datos.add(s.telefono!);
    if (s.documento?.trim().isNotEmpty == true) datos.add(s.documento!);
    if (s.email?.trim().isNotEmpty == true) datos.add(s.email!);
    if (datos.isEmpty) return 'Sin membresía';
    return datos.join(' · ');
  }

  Future<void> _crearSocio() async {
    final resultado = await _dialogSocio(null);
    if (resultado == null) return;
    try {
      await _service.crearSocio(
        nombre: resultado['nombre'],
        telefono: resultado['telefono'],
        email: resultado['email'],
        documento: resultado['documento'],
        direccion: resultado['direccion'],
        notas: resultado['notas'],
      );
      _snack('Socio creado.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogSocio(Map<String, dynamic>? inicial) async {
    final nombreController = TextEditingController(text: inicial?['nombre'] ?? '');
    final telefonoController = TextEditingController(text: inicial?['telefono'] ?? '');
    final emailController = TextEditingController(text: inicial?['email'] ?? '');
    final documentoController = TextEditingController(text: inicial?['documento'] ?? '');
    final direccionController = TextEditingController(text: inicial?['direccion'] ?? '');
    final notasController = TextEditingController(text: inicial?['notas'] ?? '');
    bool activo = inicial?['activo'] ?? true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          inicial == null ? 'Nuevo socio' : 'Editar socio',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Nombre completo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Teléfono'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: documentoController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Documento (DNI / RTN)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Dirección'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Notas'),
                ),
                if (inicial != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: activo,
                    activeTrackColor: const Color(0xFF8B5CF6),
                    title: Text(
                      'Activo',
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                    ),
                    onChanged: (v) => setDialogState(() => activo = v),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(ctx, {
                'nombre': nombre,
                'telefono': _vacio(telefonoController.text),
                'email': _vacio(emailController.text),
                'documento': _vacio(documentoController.text),
                'direccion': _vacio(direccionController.text),
                'notas': _vacio(notasController.text),
                'activo': activo,
              });
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _vacio(String s) => s.trim().isEmpty ? null : s.trim();

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
      filled: true,
      fillColor: const Color(0xFF0F0F0F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  String _fecha(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year}';
  }

  void _snack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.dmSans()),
        backgroundColor: color,
      ),
    );
  }
}

/// Detalle de un socio: afiliaciones (vigencias) y precios preferenciales.
class _SocioDetalleScreen extends StatefulWidget {
  final String socioId;
  const _SocioDetalleScreen({required this.socioId});

  @override
  State<_SocioDetalleScreen> createState() => _SocioDetalleScreenState();
}

class _SocioDetalleScreenState extends State<_SocioDetalleScreen> {
  final _service = MembresiaService.instance;

  bool _cargando = true;
  SocioDetalle? _detalle;
  List<Membresia> _planes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final detalle = await _service.getSocioDetalle(widget.socioId);
    final planes = await _service.getMembresias();
    if (!mounted) return;
    setState(() {
      _detalle = detalle;
      _planes = planes;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOCIO',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF8B5CF6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando || detalle == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildHeader(detalle),
                  const SizedBox(height: 20),
                  _buildMembresiaActual(detalle),
                  const SizedBox(height: 20),
                  Text(
                    'HISTORIAL DE MEMBRESÍAS',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF525252),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detalle.afiliaciones.isEmpty)
                    _buildSinHistorial()
                  else
                    ...detalle.afiliaciones.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildAfiliacionCard(a),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'PRECIOS PREFERENCIALES',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF525252),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detalle.precios.isEmpty)
                    _buildSinPrecios()
                  else
                    ...detalle.precios.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildPrecioCard(p),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
      ),
      floatingActionButton: detalle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _agregarPrecio(detalle),
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
              label: Text(
                'Precio Pref.',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildHeader(SocioDetalle d) {
    final s = d.socio;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _iniciales(s.nombre),
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.nombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (s.telefono?.trim().isNotEmpty == true)
                  _buildDato(Icons.phone_rounded, s.telefono!),
                if (s.email?.trim().isNotEmpty == true)
                  _buildDato(Icons.email_rounded, s.email!),
                if (s.documento?.trim().isNotEmpty == true)
                  _buildDato(Icons.badge_rounded, s.documento!),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF1A1A1A),
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF737373), size: 20),
            onSelected: (v) {
              if (v == 'editar') _editarSocio(s);
              if (v == 'eliminar') _eliminarSocio(s);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDato(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF737373), size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFA3A3A3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembresiaActual(SocioDetalle d) {
    final vigente = d.afiliacionVigente;
    if (vigente == null) {
      final ultima = d.afiliaciones.isEmpty ? null : d.afiliaciones.first;
      final estadoUltima = ultima == null ? null : _service.estadoEfectivo(ultima);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estadoUltima == EstadoAfiliacion.vencida
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : const Color(0xFF262626),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  estadoUltima == EstadoAfiliacion.vencida
                      ? Icons.error_outline_rounded
                      : Icons.workspace_premium_rounded,
                  color: estadoUltima == EstadoAfiliacion.vencida
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF8B5CF6),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'SIN MEMBRESÍA VIGENTE',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              estadoUltima == EstadoAfiliacion.vencida
                  ? 'La membresía anterior venció. Asigná un plan para reactivar beneficios.'
                  : 'Este socio aún no tiene una membresía activa.',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 14),
            if (_planes.isEmpty)
              _buildAvisoSinPlanes()
            else
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _asignarMembresia(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Asignar Membresía',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final vencePronto = vigente.fechaFin
        .isBefore(DateTime.now().add(const Duration(days: 7)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vigente.membresiaNombre,
                  style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (vencePronto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'VENCE PRONTO',
                    style: GoogleFonts.dmSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildBeneficio('Descuento', '${vigente.descuentoPorcentaje.toStringAsFixed(0)}%'),
              const SizedBox(width: 12),
              _buildBeneficio('Pagó', 'L.${vigente.precioPagado.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Vigencia: ${_fecha(vigente.fechaInicio)} → ${_fecha(vigente.fechaFin)}',
            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _botonBlanco('Renovar', () => _renovarMembresia(d, vigente)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botonBlanco('Cancelar', () => _cancelarMembresia(d, vigente)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficio(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _botonBlanco(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAvisoSinPlanes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'No hay planes activos. Creá un plan en la sección Planes.',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
      ),
    );
  }

  Widget _buildSinHistorial() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Text(
        'Sin afiliaciones registradas.',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
      ),
    );
  }

  Widget _buildAfiliacionCard(SocioMembresia a) {
    final estado = _service.estadoEfectivo(a);
    final color = estado == EstadoAfiliacion.activa
        ? const Color(0xFF10B981)
        : estado == EstadoAfiliacion.vencida
            ? const Color(0xFFF97316)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              estado == EstadoAfiliacion.cancelada
                  ? Icons.block_rounded
                  : Icons.event_available_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.membresiaNombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fecha(a.fechaInicio)} → ${_fecha(a.fechaFin)} · '
                  'L.${a.precioPagado.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              EstadoAfiliacion.etiqueta(estado).toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinPrecios() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Text(
        'Sin precios preferenciales. Usá "Precio Pref." para asignar uno.',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
      ),
    );
  }

  Widget _buildPrecioCard(SocioPrecio p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.productoNombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Precio preferencial: L.${p.precioPreferencial.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _quitarPrecio(p),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════

  Future<void> _asignarMembresia(SocioDetalle d) async {
    final resultado = await _dialogAsignar(d.socio, _planes.where((p) => p.activo).toList());
    if (resultado == null) return;
    try {
      await _service.asignarMembresia(
        socioId: d.socio.id,
        membresiaId: resultado['membresiaId'],
        precioPagado: resultado['precio'],
        notas: resultado['notas'],
      );
      _snack('Membresía asignada.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogAsignar(Socio socio, List<Membresia> planes) async {
    if (planes.isEmpty) return null;
    String? membresiaId = planes.first.id;
    final precioController = TextEditingController(
      text: planes.first.precio.toStringAsFixed(2),
    );
    final notasController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Asignar membresía',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  socio.nombre,
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: membresiaId,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Plan'),
                  items: planes
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.nombre} · L.${p.precio.toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    membresiaId = v;
                    final plan = planes.firstWhere((p) => p.id == v);
                    precioController.text = plan.precio.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Precio pagado (L.)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Notas'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {
                'membresiaId': membresiaId,
                'precio': double.tryParse(precioController.text.trim().replaceAll(',', '')) ?? 0,
                'notas': notasController.text.trim().isEmpty ? null : notasController.text.trim(),
              }),
              child: Text(
                'Asignar',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renovarMembresia(SocioDetalle d, SocioMembresia vigente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Renovar membresía',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Extender "${vigente.membresiaNombre}" desde ${_fecha(vigente.fechaFin)} '
          'por ${_mesesDe(vigente)} mes(es)?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, renovar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.renovarMembresia(afiliacionId: vigente.id);
      _snack('Membresía renovada.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  int _mesesDe(SocioMembresia a) {
    for (final p in _planes) {
      if (p.id == a.membresiaId) return p.vigenciaMeses;
    }
    return 1;
  }

  Future<void> _cancelarMembresia(SocioDetalle d, SocioMembresia vigente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancelar membresía',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Cancelar la membresía "${vigente.membresiaNombre}" de ${d.socio.nombre}?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, cancelar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.cancelarAfiliacion(vigente.id);
      _snack('Membresía cancelada.', const Color(0xFFEF4444));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<void> _agregarPrecio(SocioDetalle d) async {
    final productos = await LocalDatabaseService.instance
        .getProductos(AuthController.instance.empresaCodigo);
    if (!mounted) return;
    if (productos.isEmpty) {
      _snack('No hay productos disponibles.', const Color(0xFFEF4444));
      return;
    }
    final resultado = await _dialogPrecio(productos);
    if (resultado == null) return;
    try {
      await _service.asignarPrecioPreferencial(
        socioId: d.socio.id,
        producto: resultado['producto'],
        precio: resultado['precio'],
      );
      _snack('Precio preferencial asignado.', const Color(0xFF10B981));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogPrecio(List<Producto> productos) async {
    Producto? producto;
    final precioController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Precio preferencial',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: null,
                  hint: Text('Seleccionar producto',
                      style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373))),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Producto'),
                  items: productos
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.nombre} · L.${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    producto = productos.firstWhere((p) => p.id == v);
                    if (precioController.text.trim().isEmpty) {
                      precioController.text = producto!.precioVenta.toStringAsFixed(2);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Precio (L.)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
            ),
            TextButton(
              onPressed: () {
                final precio = double.tryParse(precioController.text.trim().replaceAll(',', ''));
                if (producto == null || precio == null || precio <= 0) return;
                Navigator.pop(ctx, {'producto': producto, 'precio': precio});
              },
              child: Text(
                'Guardar',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quitarPrecio(SocioPrecio p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quitar precio',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Quitar el precio preferencial de "${p.productoNombre}"?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, quitar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.eliminarPrecioPreferencial(p.id);
      _snack('Precio preferencial eliminado.', const Color(0xFFEF4444));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<void> _editarSocio(Socio s) async {
    final inicial = {
      'nombre': s.nombre,
      'telefono': s.telefono,
      'email': s.email,
      'documento': s.documento,
      'direccion': s.direccion,
      'notas': s.notas,
      'activo': s.activo,
    };
    final resultado = await _dialogSocioEditar(inicial);
    if (resultado == null) return;
    try {
      await _service.actualizarSocio(
        id: s.id,
        nombre: resultado['nombre'],
        telefono: resultado['telefono'],
        email: resultado['email'],
        documento: resultado['documento'],
        direccion: resultado['direccion'],
        notas: resultado['notas'],
        activo: resultado['activo'],
      );
      _snack('Socio actualizado.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogSocioEditar(Map<String, dynamic> inicial) async {
    final nombreController = TextEditingController(text: inicial['nombre'] ?? '');
    final telefonoController = TextEditingController(text: inicial['telefono'] ?? '');
    final emailController = TextEditingController(text: inicial['email'] ?? '');
    final documentoController = TextEditingController(text: inicial['documento'] ?? '');
    final direccionController = TextEditingController(text: inicial['direccion'] ?? '');
    final notasController = TextEditingController(text: inicial['notas'] ?? '');
    bool activo = inicial['activo'] ?? true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Editar socio',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Nombre completo')),
                const SizedBox(height: 12),
                TextField(controller: telefonoController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Teléfono')),
                const SizedBox(height: 12),
                TextField(controller: emailController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Email')),
                const SizedBox(height: 12),
                TextField(controller: documentoController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Documento (DNI / RTN)')),
                const SizedBox(height: 12),
                TextField(controller: direccionController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Dirección')),
                const SizedBox(height: 12),
                TextField(controller: notasController, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white), decoration: _inputDecoration('Notas')),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: activo,
                  activeTrackColor: const Color(0xFF8B5CF6),
                  title: Text('Activo', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
            TextButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) return;
                Navigator.pop(ctx, {
                  'nombre': nombre,
                  'telefono': _vacio(telefonoController.text),
                  'email': _vacio(emailController.text),
                  'documento': _vacio(documentoController.text),
                  'direccion': _vacio(direccionController.text),
                  'notas': _vacio(notasController.text),
                  'activo': activo,
                });
              },
              child: Text('Guardar', style: GoogleFonts.dmSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarSocio(Socio s) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar socio',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Eliminar a "${s.nombre}"?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _service.eliminarSocio(s.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
  }

  String? _vacio(String s) => s.trim().isEmpty ? null : s.trim();

  String _fecha(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year}';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
      filled: true,
      fillColor: const Color(0xFF0F0F0F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  String _mensajeError(Object e) {
    var msg = e.toString();
    msg = msg.replaceFirst('Bad state: ', '');
    msg = msg.replaceFirst('Invalid argument(s): ', '');
    return msg;
  }

  void _snack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.dmSans()),
        backgroundColor: color,
      ),
    );
  }
}
