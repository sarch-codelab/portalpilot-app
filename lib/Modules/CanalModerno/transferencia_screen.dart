import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_moderno_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Gestión de transferencias de inventario entre sucursales.
class TransferenciaScreen extends StatefulWidget {
  const TransferenciaScreen({super.key});

  @override
  State<TransferenciaScreen> createState() => _TransferenciaScreenState();
}

class _TransferenciaScreenState extends State<TransferenciaScreen> {
  final _service = CanalModernoService.instance;

  bool _cargando = true;
  List<Transferencia> _transferencias = [];

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
    final transferencias = await _service.getTransferencias();
    if (!mounted) return;
    setState(() {
      _transferencias = transferencias;
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
            color: Color(0xFFF97316),
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
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'TRANSFERENCIAS',
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
        onPressed: () => _nuevaTransferencia(),
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Transferir',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFFF97316),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_transferencias.isEmpty)
                    _buildVacio()
                  else
                    ..._transferencias.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildTransferenciaCard(t),
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
          const Icon(Icons.swap_horiz_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin transferencias',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trasladá inventario entre tus sucursales para mantener stock en cada punto de venta.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'en_transito':
        return const Color(0xFFF97316);
      case 'recibida':
        return const Color(0xFF10B981);
      case 'cancelada':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Widget _buildTransferenciaCard(Transferencia t) {
    final color = _colorEstado(t.estado);
    return GestureDetector(
      onTap: () => _detalleTransferencia(t),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    t.estado == 'en_transito'
                        ? Icons.local_shipping_rounded
                        : Icons.swap_horiz_rounded,
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
                        t.correlativo ?? 'Transferencia',
                        style: GoogleFonts.syne(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatoFecha(t.createdAt),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
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
                    EstadoTransferencia.etiqueta(t.estado).toUpperCase(),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRuta('Origen', t.origenNombre, const Color(0xFF3B82F6)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF404040), size: 18),
                ),
                Expanded(
                  child: _buildRuta('Destino', t.destinoNombre, const Color(0xFF10B981)),
                ),
              ],
            ),
            if (t.estado == 'pendiente' || t.estado == 'en_transito') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (t.estado == 'pendiente') ...[
                    Expanded(
                      child: _botonEstado(
                        'Enviar',
                        Icons.send_rounded,
                        const Color(0xFF3B82F6),
                        () => _enviar(t),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (t.estado == 'en_transito') ...[
                    Expanded(
                      child: _botonEstado(
                        'Recibir',
                        Icons.inventory_2_rounded,
                        const Color(0xFF10B981),
                        () => _recibir(t),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _botonEstado(
                      'Cancelar',
                      Icons.close_rounded,
                      const Color(0xFFEF4444),
                      () => _cancelar(t),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRuta(String label, String nombre, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: const Color(0xFF525252),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          nombre,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _botonEstado(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar(Transferencia t) async {
    final confirmar = await _confirmarAccion('Enviar', t);
    if (confirmar != true) return;
    try {
      await _service.enviarTransferencia(t.id);
      _snack('Transferencia enviada. Stock descontado de ${t.origenNombre}.',
          const Color(0xFF3B82F6));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<void> _recibir(Transferencia t) async {
    final confirmar = await _confirmarAccion('Recibir', t);
    if (confirmar != true) return;
    try {
      await _service.recibirTransferencia(t.id);
      _snack('Transferencia recibida. Stock ingresó a ${t.destinoNombre}.',
          const Color(0xFF10B981));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<void> _cancelar(Transferencia t) async {
    final confirmar = await _confirmarAccion('Cancelar', t);
    if (confirmar != true) return;
    try {
      await _service.cancelarTransferencia(t.id);
      _snack('Transferencia cancelada.', const Color(0xFFEF4444));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<bool?> _confirmarAccion(String accion, Transferencia t) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$accion transferencia',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿$accion la transferencia ${t.correlativo ?? ''}?\n'
          '${t.origenNombre} → ${t.destinoNombre}',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No',
                style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, $accion',
              style: GoogleFonts.dmSans(
                color: accion == 'Cancelar'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF97316),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _detalleTransferencia(Transferencia t) async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final detalle = await _service.getTransferencia(t.id);
    if (detalle == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              detalle.transferencia.correlativo ?? 'Transferencia',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${detalle.transferencia.origenNombre} → '
              '${detalle.transferencia.destinoNombre} · '
              '${_formatoFecha(detalle.transferencia.createdAt)}',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
            ),
            const SizedBox(height: 16),
            Text(
              'PRODUCTOS (${detalle.totalUnidades} uds)',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFF525252),
              ),
            ),
            const SizedBox(height: 8),
            ...detalle.items.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.productoNombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '×${i.cantidad}',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevaTransferencia() async {
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _NuevaTransferenciaPage()),
    );
    if (creada == true) _cargar();
  }

  String _mensajeError(Object e) {
    var msg = e.toString();
    msg = msg.replaceFirst('Bad state: ', '');
    msg = msg.replaceFirst('Invalid argument(s): ', '');
    return msg;
  }

  String _formatoFecha(DateTime dt) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
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

/// Página de creación de una transferencia (paso a paso).
class _NuevaTransferenciaPage extends StatefulWidget {
  const _NuevaTransferenciaPage();

  @override
  State<_NuevaTransferenciaPage> createState() => _NuevaTransferenciaPageState();
}

class _NuevaTransferenciaPageState extends State<_NuevaTransferenciaPage> {
  final _service = CanalModernoService.instance;

  List<Sucursale> _sucursales = [];
  List<Producto> _productos = [];
  final Map<String, int> _cantidades = {};
  String? _origenId;
  String? _destinoId;
  final TextEditingController _observacionesController = TextEditingController();
  bool _guardando = false;

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
    final sucursales = await _service.getSucursales();
    final productos =
        await LocalDatabaseService.instance.getProductos(AuthController.instance.empresaCodigo);
    if (!mounted) return;
    setState(() {
      _sucursales = sucursales.where((s) => s.activo).toList();
      _productos = productos;
    });
  }

  List<Sucursale> get _destinos {
    return _sucursales.where((s) => s.id != _origenId).toList();
  }

  String? get _bodegaOrigen {
    final o = _sucursalPorId(_origenId);
    return o != null ? _service.bodegaDe(o) : null;
  }

  Sucursale? _sucursalPorId(String? id) {
    if (id == null) return null;
    for (final s in _sucursales) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Producto> get _productosOrigen {
    final b = _bodegaOrigen;
    if (b == null) return const [];
    return _productos.where((p) => p.bodega == b).toList();
  }

  int get _totalUnidades =>
      _cantidades.values.fold<int>(0, (s, c) => s + c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFFF97316), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NUEVA TRANSFERENCIA',
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            'ORIGEN',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF525252),
            ),
          ),
          const SizedBox(height: 8),
          _buildSucursalSelector(
            _sucursales,
            _origenId,
            'Sucursal de origen',
            (id) => setState(() {
              _origenId = id;
              if (_destinoId == id) _destinoId = null;
              _cantidades.clear();
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'DESTINO',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF525252),
            ),
          ),
          const SizedBox(height: 8),
          _buildSucursalSelector(
            _destinos,
            _destinoId,
            'Sucursal de destino',
            (id) => setState(() => _destinoId = id),
          ),
          if (_bodegaOrigen != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRODUCTOS ($_totalUnidades uds)',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: const Color(0xFF525252),
                  ),
                ),
                Text(
                  'Bodega: $_bodegaOrigen',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_productosOrigen.isEmpty)
              _buildSinProductos()
            else
              ..._productosOrigen.map((p) => _buildProductoRow(p)),
            const SizedBox(height: 16),
            TextField(
              controller: _observacionesController,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observaciones',
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
                  borderSide: const BorderSide(color: Color(0xFFF97316)),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                disabledBackgroundColor: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Crear transferencia',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  Widget _buildSucursalSelector(
    List<Sucursale> opciones,
    String? seleccionado,
    String hint,
    ValueChanged<String> onSeleccion,
  ) {
    return GestureDetector(
      onTap: () {
        if (opciones.isEmpty) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF141414),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: opciones
                  .map(
                    (s) => ListTile(
                      leading: Icon(
                        s.esPrincipal
                            ? Icons.star_rounded
                            : Icons.storefront_rounded,
                        color: const Color(0xFFF97316),
                      ),
                      title: Text(
                        s.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Bodega: ${_service.bodegaDe(s)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSeleccion(s.id);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Icon(
              seleccionado != null
                  ? Icons.check_circle_rounded
                  : Icons.storefront_rounded,
              color: seleccionado != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFF404040),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: seleccionado == null
                  ? Text(
                      hint,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    )
                  : Text(
                      _sucursalPorId(seleccionado)?.nombre ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSinProductos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Text(
        'La sucursal de origen no tiene productos con inventario.',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
      ),
    );
  }

  Widget _buildProductoRow(Producto p) {
    final cantidad = _cantidades[p.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${p.stockActual} ${p.unidadMedida} · '
                      'L.${p.precioVenta.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              _stepper(p, cantidad),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper(Producto p, int cantidad) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperBoton(
          Icons.remove_rounded,
          onTap: () {
            if (cantidad <= 0) return;
            setState(() => _cantidades[p.id] = cantidad - 1);
          },
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$cantidad',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        _stepperBoton(
          Icons.add_rounded,
          onTap: () {
            if (cantidad >= p.stockActual) return;
            setState(() => _cantidades[p.id] = cantidad + 1);
          },
        ),
      ],
    );
  }

  Widget _stepperBoton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFF97316), size: 16),
      ),
    );
  }

  Future<void> _guardar() async {
    if (_origenId == null) {
      _snack('Seleccioná la sucursal de origen.', const Color(0xFFEF4444));
      return;
    }
    if (_destinoId == null) {
      _snack('Seleccioná la sucursal de destino.', const Color(0xFFEF4444));
      return;
    }
    final items = <(Producto, int)>[];
    for (final p in _productosOrigen) {
      final c = _cantidades[p.id] ?? 0;
      if (c > 0) items.add((p, c));
    }
    if (items.isEmpty) {
      _snack('Agregá al menos un producto con cantidad mayor a cero.',
          const Color(0xFFEF4444));
      return;
    }

    setState(() => _guardando = true);
    try {
      await _service.crearTransferencia(
        origenId: _origenId!,
        destinoId: _destinoId!,
        items: items,
        observaciones: _observacionesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
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
