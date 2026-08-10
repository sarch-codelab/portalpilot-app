import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_tradicional_service.dart';

/// Fiado / cuentas por cobrar del Canal Tradicional.
/// Permite ver saldos, registrar abonos, configurar límites de crédito
/// y activar cuentas para clientes nuevos.
class FiadoScreen extends StatefulWidget {
  const FiadoScreen({super.key});

  @override
  State<FiadoScreen> createState() => _FiadoScreenState();
}

class _FiadoScreenState extends State<FiadoScreen> {
  final _service = CanalTradicionalService.instance;

  bool _cargando = true;
  List<FiadoCuenta> _cuentas = [];
  String _filtro = 'todas';

  static const Map<String, String> _filtros = {
    'Todas': 'todas',
    'Con saldo': 'saldo',
    'Vencidas': 'vencidas',
  };

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
    final cuentas = await _service.getCuentasFiado();
    if (!mounted) return;
    setState(() {
      _cuentas = cuentas;
      _cargando = false;
    });
  }

  List<FiadoCuenta> get _filtradas {
    switch (_filtro) {
      case 'vencidas':
        return _cuentas.where((c) => c.estado == EstadoFiado.vencido).toList();
      case 'saldo':
        return _cuentas.where((c) => c.saldo > 0).toList();
      default:
        return _cuentas;
    }
  }

  double get _totalPorCobrar =>
      _cuentas.fold<double>(0, (s, c) => s + c.saldo);

  int get _vencidas =>
      _cuentas.where((c) => c.estado == EstadoFiado.vencido).length;

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

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
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'FIADO · CxC',
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
        onPressed: _crearCuenta,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.person_add_alt_1_rounded,
            color: Colors.white, size: 20),
        label: Text(
          'Nueva Cuenta',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildResumen(),
                  const SizedBox(height: 16),
                  _buildFiltros(),
                  const SizedBox(height: 10),
                  if (filtradas.isEmpty)
                    _buildVacio()
                  else
                    ...filtradas.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildCuentaCard(c),
                        )),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }

  Widget _buildResumen() {
    return Row(
      children: [
        _buildResumenCard(
          'Por cobrar',
          'L.${_format(_totalPorCobrar)}',
          Icons.payments_rounded,
          const Color(0xFF10B981),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'Cuentas',
          '${_cuentas.length}',
          Icons.groups_rounded,
          const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'Vencidas',
          '$_vencidas',
          Icons.warning_amber_rounded,
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildResumenCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Row(
      children: _filtros.entries.map((e) {
        final activo = _filtro == e.value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filtro = e.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activo ? const Color(0xFF10B981) : const Color(0xFF141414),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo
                      ? const Color(0xFF10B981)
                      : const Color(0xFF262626),
                ),
              ),
              child: Text(
                e.key,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : const Color(0xFFA3A3A3),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
          const Icon(Icons.inbox_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin cuentas por cobrar',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las ventas al crédito que registres aparecerán aquí.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildCuentaCard(FiadoCuenta c) {
    final colorEstado = _colorEstado(c.estado);
    return GestureDetector(
      onTap: () => _detalleCuenta(c),
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
                    color: colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _iniciales(c.nombre),
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorEstado,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.limite > 0
                            ? 'Límite L.${_format(c.limite)} · vence a los ${c.diasVencimiento} días'
                            : 'Sin límite de crédito configurado',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                ),
                _badgeEstado(c.estado),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: const Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'L.${_format(c.saldo)}',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: c.saldo > 0 ? const Color(0xFFF97316) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _accionCorta(
                      Icons.payments_rounded,
                      'Abonar',
                      () => _abonar(c),
                    ),
                    const SizedBox(width: 8),
                    _accionCorta(
                      Icons.tune_rounded,
                      'Config.',
                      () => _configurar(c),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accionCorta(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeEstado(String estado) {
    final color = _colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        EstadoFiado.etiqueta(estado).toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case EstadoFiado.vencido:
        return const Color(0xFFEF4444);
      case EstadoFiado.porVencer:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _detalleCuenta(FiadoCuenta c) async {
    final abonos = await _service.getAbonosCliente(c.credito.clienteId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                c.nombre,
                style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Saldo: L.${_format(c.saldo)}  ·  Límite: L.${_format(c.limite)}',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
              ),
              const SizedBox(height: 18),
              Text(
                'HISTORIAL DE ABONOS',
                style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFA3A3A3), letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              if (abonos.isEmpty)
                Text(
                  'Sin abonos registrados.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
                )
              else
                ...abonos.take(8).map((a) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1F1F1F)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatFecha(a.fecha),
                            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
                          ),
                          Text(
                            'L.${_format(a.monto)}',
                            style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _botonAccion(
                      Icons.payments_rounded,
                      'Abonar',
                      const Color(0xFF10B981),
                      () {
                        Navigator.pop(ctx);
                        _abonar(c);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _botonAccion(
                      Icons.tune_rounded,
                      'Configurar',
                      const Color(0xFF3B82F6),
                      () {
                        Navigator.pop(ctx);
                        _configurar(c);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonAccion(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abonar(FiadoCuenta c) async {
    final montoController = TextEditingController();
    String metodo = 'efectivo';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Registrar abono',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.nombre} · Saldo L.${_format(c.saldo)}',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: _inputDecoration('Monto del abono (L.)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodo,
                dropdownColor: const Color(0xFF1A1A1A),
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: _inputDecoration('Método de pago'),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'billetera', child: Text('Billetera electrónica')),
                ],
                onChanged: (v) => setDialogState(() => metodo = v ?? 'efectivo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Registrar', style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    final monto = double.tryParse(montoController.text.trim().replaceAll(',', ''));
    if (monto == null || monto <= 0) {
      _snack('Ingresá un monto válido mayor a cero.', const Color(0xFFEF4444));
      return;
    }

    try {
      await _service.registrarAbono(
        clienteId: c.credito.clienteId,
        clienteNombre: c.nombre,
        monto: monto,
        metodoPago: metodo,
      );
      _snack('Abono registrado correctamente.', const Color(0xFF10B981));
      _cargar();
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst('Bad state: ', '')}', const Color(0xFFEF4444));
    }
  }

  Future<void> _configurar(FiadoCuenta c) async {
    final limiteController = TextEditingController(
      text: c.limite > 0 ? c.limite.toStringAsFixed(0) : '',
    );
    final diasController = TextEditingController(
      text: '${c.diasVencimiento}',
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Configurar crédito',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.nombre,
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limiteController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
              decoration: _inputDecoration('Límite de crédito (L.)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: diasController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
              decoration: _inputDecoration('Días para vencimiento'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Guardar', style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    final limite = double.tryParse(limiteController.text.trim().replaceAll(',', ''));
    final dias = int.tryParse(diasController.text.trim());
    if (limite == null || limite < 0 || dias == null || dias <= 0) {
      _snack('Límite y días deben ser válidos.', const Color(0xFFEF4444));
      return;
    }

    await _service.configurarCuentaFiado(
      clienteId: c.credito.clienteId,
      clienteNombre: c.nombre,
      limiteCredito: limite,
      diasVencimiento: dias,
    );
    _snack('Cuenta configurada.', const Color(0xFF10B981));
    _cargar();
  }

  Future<void> _crearCuenta() async {
    final clientes = await _service.getClientes();
    if (!mounted) return;
    if (clientes.isEmpty) {
      _snack('Primero registrá clientes en el CRM.', const Color(0xFFF59E0B));
      return;
    }

    Cliente? seleccionado;
    final limiteController = TextEditingController();
    final diasController = TextEditingController(text: '30');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nueva cuenta de fiado',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Cliente>(
                value: seleccionado,
                dropdownColor: const Color(0xFF1A1A1A),
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: _inputDecoration('Cliente'),
                items: clientes
                    .map((cl) => DropdownMenuItem(
                          value: cl,
                          child: Text(cl.nombre),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => seleccionado = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limiteController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: _inputDecoration('Límite de crédito (L.)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diasController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: _inputDecoration('Días para vencimiento'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Crear', style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmar != true || seleccionado == null) return;
    final limite = double.tryParse(limiteController.text.trim().replaceAll(',', ''));
    final dias = int.tryParse(diasController.text.trim()) ?? 30;
    if (limite == null || limite < 0 || dias <= 0) {
      _snack('Límite y días deben ser válidos.', const Color(0xFFEF4444));
      return;
    }

    await _service.configurarCuentaFiado(
      clienteId: seleccionado!.id,
      clienteNombre: seleccionado!.nombre,
      limiteCredito: limite,
      diasVencimiento: dias,
    );
    _snack('Cuenta de fiado creada.', const Color(0xFF10B981));
    _cargar();
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
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
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

  String _format(double v) => v.toStringAsFixed(2);

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final iniciales = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return iniciales;
  }

  String _formatFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }
}
