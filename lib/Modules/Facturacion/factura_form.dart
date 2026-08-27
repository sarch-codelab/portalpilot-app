import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/Facturacion/factura_detalle.dart';
import 'package:portal_pilot_app/Modules/Facturacion/sar_config_screen.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_tradicional_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/factura_pdf_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';

class FacturaForm extends StatefulWidget {
  final Map<String, dynamic>? facturaExistente;

  const FacturaForm({super.key, this.facturaExistente});

  @override
  State<FacturaForm> createState() => _FacturaFormState();
}

class _FacturaFormState extends State<FacturaForm> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNombreController = TextEditingController();
  final _clienteRTNController = TextEditingController();
  final _clienteDireccionController = TextEditingController();
  final _condicionPagoController = TextEditingController(text: 'Contado');

  String _tipoDocumento = 'Factura';
  String _tipoVenta = 'Gravada';
  List<Map<String, dynamic>> _items = [];
  double _descuento = 0.0;
  double _subtotal = 0.0;
  double _isv15 = 0.0;
  double _isv18 = 0.0;
  double _total = 0.0;
  String _cai = '';
  String _siguienteCorrelativo = '';
  String _empresaNombre = '';
  String _rtn = '';
  String _rangoInicio = '';
  String _rangoFin = '';
  String _resolucion = '';
  DateTime? _fechaLimite;
  bool _contingenciaActiva = false;
  String? _motivoContingencia;
  EstadoSAR? _estadoSAR;
  bool _regimenSimplificado = false;

  List<Map<String, dynamic>> _clientesGuardados = [];
  Map<String, dynamic>? _clienteSeleccionado;

  String get _tipoCodigo => SarTipoDocumento.codigoPorNombre(_tipoDocumento);

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    if (widget.facturaExistente != null) {
      _cargarFacturaExistente(widget.facturaExistente!);
    }
  }

  Future<void> _cargarConfiguracion() async {
    SarService.instance.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    CanalTradicionalService.instance.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );

    final config = await SarService.instance.getConfiguracion();
    final row = await SarService.instance.getCorrelativoPorTipo(_tipoCodigo);
    final estado = await SarService.instance.obtenerEstadoSAR(
      tipoDocumento: _tipoCodigo,
    );

    final prefs = await SharedPreferences.getInstance();
    final clientesJson = prefs.getString('clientes_facturacion') ?? '[]';
    final regimenSimplificado = config?.regimen == 'simplificado';

    setState(() {
      _empresaNombre =
          config?.razonSocial ??
          config?.nombreComercial ??
          prefs.getString('empresa_nombre') ??
          '';
      _rtn = config?.rtn ?? prefs.getString('empresa_rtn') ?? '';
      _cai = row.cai ?? '';
      _rangoInicio = row.rangoInicio ?? '001-001-01-00000001';
      _rangoFin = row.rangoFin ?? '';
      _resolucion = row.numeroResolucion ?? '';
      _fechaLimite = row.fechaLimiteEmision;
      _contingenciaActiva = estado.contingenciaActiva;
      _estadoSAR = estado;
      _regimenSimplificado = regimenSimplificado;
      if (regimenSimplificado &&
          widget.facturaExistente == null &&
          _tipoDocumento == 'Factura') {
        _tipoDocumento = 'Comprobante Fiscal (RST)';
        _cai = '';
      }
      _clientesGuardados = List<Map<String, dynamic>>.from(
        jsonDecode(clientesJson),
      );
    });

    if (widget.facturaExistente == null) {
      await _actualizarPreviewCorrelativo();
    }
  }

  Future<void> _actualizarPreviewCorrelativo() async {
    final preview = await SarService.instance.correlativoPreview(_tipoCodigo);
    if (mounted) {
      setState(() => _siguienteCorrelativo = preview);
    }
  }

  void _cargarFacturaExistente(Map<String, dynamic> factura) {
    _clienteNombreController.text = factura['cliente_nombre'] ?? '';
    _clienteRTNController.text = factura['cliente_rtn'] ?? '';
    _clienteDireccionController.text = factura['cliente_direccion'] ?? '';
    _condicionPagoController.text = factura['condicion_pago'] ?? 'Contado';
    _tipoDocumento = factura['tipo_documento'] ?? 'Factura';
    _tipoVenta = factura['tipo_venta'] ?? 'Gravada';
    _items = List<Map<String, dynamic>>.from(factura['items'] ?? []);
    _descuento = (factura['descuento'] as num?)?.toDouble() ?? 0.0;
    _contingenciaActiva = factura['contingencia'] == true;
    _siguienteCorrelativo = factura['correlativo'] ?? '';
    _recalcular();
  }

  void _recalcular() {
    final tot = SarService.calcularTotales(_items, descuentoGlobal: _descuento);
    setState(() {
      _subtotal = tot.subtotal;
      _isv15 = tot.isv15;
      _isv18 = tot.isv18;
      _total = tot.total;
    });
  }

  void _agregarItem() {
    final nombreController = TextEditingController();
    final cantidadController = TextEditingController(text: '1');
    final precioController = TextEditingController();
    String isvSeleccionado = '15';
    bool exento = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF404040),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Agregar Concepto',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModalTextField('Descripción', nombreController),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalTextField(
                            'Cantidad',
                            cantidadController,
                            keyboard: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModalTextField(
                            'Precio Unitario (L.)',
                            precioController,
                            keyboard: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISV',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF737373),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F0F),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF262626),
                                  ),
                                ),
                                child: DropdownButton<String>(
                                  value: isvSeleccionado,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1A1A1A),
                                  underline: const SizedBox(),
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: '15',
                                      child: Text('15% (Bien)'),
                                    ),
                                    DropdownMenuItem(
                                      value: '18',
                                      child: Text('18% (Bebida/Tabaco)'),
                                    ),
                                    DropdownMenuItem(
                                      value: '0',
                                      child: Text('0% (Exento)'),
                                    ),
                                  ],
                                  onChanged: (v) => setModalState(() {
                                    isvSeleccionado = v ?? '15';
                                    exento = v == '0';
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nombreController.text.isNotEmpty &&
                              precioController.text.isNotEmpty) {
                            setState(() {
                              _items.add({
                                'descripcion': nombreController.text,
                                'cantidad':
                                    int.tryParse(cantidadController.text) ?? 1,
                                'precio':
                                    double.tryParse(precioController.text) ?? 0,
                                'isv': double.tryParse(isvSeleccionado) ?? 15.0,
                                'exento': exento,
                              });
                            });
                            _recalcular();
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Agregar Concepto',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _seleccionarCliente(Map<String, dynamic> cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
      _clienteNombreController.text = cliente['nombre'] ?? '';
      _clienteRTNController.text = cliente['rtn'] ?? '';
      _clienteDireccionController.text = cliente['direccion'] ?? '';
    });
    Navigator.pop(context);
  }

  /// Identificador de cliente usado para las cuentas por cobrar (fiado).
  String? _clienteIdParaFiado() {
    final id = _clienteSeleccionado?['id'] as String?;
    if (id != null && id.trim().isNotEmpty) return id.trim();
    final rtn = _clienteRTNController.text.replaceAll(RegExp(r'[-\s]'), '');
    if (rtn.isNotEmpty) return 'RTN:$rtn';
    return null;
  }

  void _mostrarListaClientes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF404040),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seleccionar Cliente',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (_clientesGuardados.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No hay clientes guardados',
                      style: GoogleFonts.dmSans(color: const Color(0xFF737373)),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _clientesGuardados.length,
                    itemBuilder: (_, i) {
                      final c = _clientesGuardados[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            (c['nombre'] ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          c['nombre'] ?? '',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'RTN: ${c['rtn'] ?? 'N/A'}',
                          style: GoogleFonts.dmMono(
                            color: const Color(0xFF737373),
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => _seleccionarCliente(c),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _guardarFactura() async {
    final esEdicion = widget.facturaExistente != null;

    if (!esEdicion && _cai.isEmpty && !_regimenSimplificado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configurá tu CAI primero',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agregá al menos un concepto',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final esCredito = _condicionPagoController.text == 'Crédito';
    String? clienteIdFiado;
    if (esCredito && !esEdicion) {
      clienteIdFiado = _clienteIdParaFiado();
      if (clienteIdFiado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Para ventas al crédito seleccioná un cliente guardado o con RTN.',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
      final exceso = await CanalTradicionalService.instance
          .validarLimiteCredito(clienteId: clienteIdFiado, monto: _total);
      if (!mounted) return;
      if (exceso != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exceso, style: GoogleFonts.dmSans()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    if (!esEdicion) {
      final validacion = await SarService.instance.validarEmision(_tipoCodigo);
      if (!validacion.ok) {
        final accion = await _mostrarBloqueoFacturacion(validacion);
        if (accion == 'configurar') {
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SarConfigScreen()),
            );
          }
          await _cargarConfiguracion();
          return;
        }
        if (accion != 'contingencia') return;

        await SarService.instance.activarContingencia(
          motivo: validacion.mensaje,
        );
        setState(() {
          _contingenciaActiva = true;
          _motivoContingencia = validacion.mensaje;
        });
      }
    }

    final contingenciaActiva = await SarService.instance.esContingenciaActiva();

    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    final List<dynamic> facturas = jsonDecode(facturasJson);

    String correlativo;
    if (esEdicion) {
      correlativo = widget.facturaExistente!['correlativo'];
    } else if (contingenciaActiva) {
      correlativo = await SarService.instance.siguienteCorrelativoContingencia(
        _tipoCodigo,
      );
      await SarService.instance.registrarContingencia(
        tipoDocumento: _tipoCodigo,
        correlativo: correlativo,
        monto: _total,
        motivo: _motivoContingencia ?? 'Modo contingencia',
        referencia: widget.facturaExistente?['id'],
      );
    } else {
      correlativo = await SarService.instance.siguienteCorrelativo(_tipoCodigo);
    }

    final factura = {
      'id': widget.facturaExistente != null
          ? widget.facturaExistente!['id']
          : DateTime.now().millisecondsSinceEpoch.toString(),
      'correlativo': correlativo,
      'tipo_documento': _tipoDocumento,
      'fecha': widget.facturaExistente != null
          ? widget.facturaExistente!['fecha']
          : DateTime.now().toIso8601String(),
      'cai': _cai,
      'resolucion': _resolucion,
      'rango_inicio': _rangoInicio,
      'rango_fin': _rangoFin,
      'fecha_limite_emision': _fechaLimite?.toIso8601String(),
      'empresa_nombre': _empresaNombre,
      'empresa_rtn': _rtn,
      'regimen': _regimenSimplificado ? 'simplificado' : 'general',
      'cliente_nombre': _clienteNombreController.text,
      'cliente_rtn': _clienteRTNController.text,
      'cliente_direccion': _clienteDireccionController.text,
      'condicion_pago': _condicionPagoController.text,
      'tipo_venta': _tipoVenta,
      'items': _items,
      'subtotal': _subtotal,
      'isv_15': _isv15,
      'isv_18': _isv18,
      'descuento': _descuento,
      'total': _total,
      'estado': 'emitida',
      'contingencia': contingenciaActiva,
      'notas': contingenciaActiva
          ? (_motivoContingencia ?? 'Modo contingencia')
          : null,
    };

    if (esEdicion) {
      final idx = facturas.indexWhere((f) => f['id'] == factura['id']);
      if (idx >= 0) facturas[idx] = factura;
    } else {
      facturas.add(factura);
    }

    await prefs.setString('facturas', jsonEncode(facturas));

    // Enviar factura al backend
    try {
      final api = ApiService.instance;
      final body = {
        'correlativo': correlativo,
        'cliente_nombre': _clienteNombreController.text,
        'cliente_rtn': _clienteRTNController.text,
        'cliente_email': '',
        'subtotal': _subtotal,
        'isv': _isv15 + _isv18,
        'descuento': _descuento,
        'total': _total,
        'tipo_documento': _tipoDocumento,
        'metodo_pago': _condicionPagoController.text,
        'notas': factura['notas'] ?? '',
      };
      if (esEdicion && widget.facturaExistente?['id'] != null) {
        await api.patch(
          '/api/facturas/${widget.facturaExistente!['id']}',
          body: body,
        );
      } else {
        await api.post('/api/facturas', body: body);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo sincronizar factura con backend: $e');
    }

    try {
      await LocalDatabaseService.instance.insertFacturaLocal(
        id: factura['id'],
        empresaId: AuthController.instance.empresaCodigo,
        usuarioId: AuthController.instance.email,
        correlativo: correlativo,
        tipoDocumento: _tipoDocumento,
        cai: _cai,
        rangoInicio: _rangoInicio,
        rangoFin: _rangoFin,
        fechaLimiteEmision: _fechaLimite,
        clienteNombre: _clienteNombreController.text,
        clienteRtn: _clienteRTNController.text,
        clienteDireccion: _clienteDireccionController.text,
        condicionPago: _condicionPagoController.text,
        tipoVenta: _tipoVenta,
        items: {'items': _items},
        subtotal: _subtotal,
        isv15: _isv15,
        isv18: _isv18,
        descuento: _descuento,
        total: _total,
        estado: 'emitida',
        notas: factura['notas'],
      );
    } catch (_) {}

    // Ventas al crédito: actualizar la cuenta por cobrar del cliente.
    if (esCredito && !esEdicion && clienteIdFiado != null) {
      try {
        await CanalTradicionalService.instance.cargarVentaACuenta(
          clienteId: clienteIdFiado,
          clienteNombre: _clienteNombreController.text,
          monto: _total,
          facturaId: factura['id'],
        );
      } catch (_) {}
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Factura $correlativo guardada${contingenciaActiva ? ' (contingencia)' : ''}',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    await _mostrarOpcionesPostGuardar(factura);
  }

  Future<String?> _mostrarBloqueoFacturacion(SarValidacion validacion) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'No se puede facturar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  validacion.mensaje,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSheetAction(
                  label: 'Usar contingencia',
                  icon: Icons.cloud_off_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.pop(ctx, 'contingencia'),
                ),
                const SizedBox(height: 8),
                _buildSheetAction(
                  label: 'Configurar CAI / resolución',
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.pop(ctx, 'configurar'),
                ),
                const SizedBox(height: 8),
                _buildSheetAction(
                  label: 'Cancelar',
                  icon: Icons.close_rounded,
                  color: const Color(0xFF525252),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarOpcionesPostGuardar(Map<String, dynamic> factura) async {
    final config = await SarService.instance.getConfiguracion();
    if (config == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => FacturaDetalle(factura: factura)),
        );
      }
      return;
    }

    final row = await SarService.instance.getCorrelativoPorTipo(_tipoCodigo);
    if (!mounted) return;

    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Factura guardada',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  factura['correlativo'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmMono(
                    color: const Color(0xFF10B981),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSheetAction(
                  label: 'Imprimir PDF',
                  icon: Icons.print_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.pop(ctx, 'imprimir'),
                ),
                const SizedBox(height: 8),
                _buildSheetAction(
                  label: 'Ver factura',
                  icon: Icons.visibility_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => Navigator.pop(ctx, 'ver'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (accion == 'imprimir') {
      try {
        await FacturaPdfService.instance.imprimir(
          factura: factura,
          config: config,
          correlativo: row,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo imprimir, abrí la factura para reintentar',
                style: GoogleFonts.dmSans(),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FacturaDetalle(factura: factura)),
      );
    }
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
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.facturaExistente != null ? 'EDITAR FACTURA' : 'NUEVA FACTURA',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCorrelativoBanner(),
            const SizedBox(height: 10),
            _buildSarStatusBanner(),
            const SizedBox(height: 16),
            _buildSection('Tipo de Documento'),
            const SizedBox(height: 8),
            _buildDocumentTypeSelector(),
            const SizedBox(height: 16),
            _buildSection('Datos del Cliente'),
            const SizedBox(height: 8),
            _buildClienteSelector(),
            const SizedBox(height: 12),
            _buildFormTextField(
              'Nombre / Razón Social',
              _clienteNombreController,
            ),
            const SizedBox(height: 12),
            _buildFormTextField(
              'RTN del Cliente',
              _clienteRTNController,
              hint: '0801-1999-12345',
            ),
            const SizedBox(height: 12),
            _buildFormTextField('Dirección', _clienteDireccionController),
            const SizedBox(height: 12),
            _buildCondicionPagoSelector(),
            const SizedBox(height: 20),
            _buildSection('Conceptos'),
            const SizedBox(height: 8),
            _buildItemsList(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _agregarItem,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Agregar Concepto',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildResumenFinanciero(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardarFactura,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.facturaExistente != null
                      ? 'Actualizar Factura'
                      : 'Emitir Factura',
                  style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelativoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag_rounded, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correlativo',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                ),
                Text(
                  widget.facturaExistente != null
                      ? widget.facturaExistente!['correlativo'] ?? ''
                      : _siguienteCorrelativo,
                  style: GoogleFonts.dmMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_contingenciaActiva)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'CONTINGENCIA',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSarStatusBanner() {
    final estado = _estadoSAR;
    final mensajes = <String>[];

    if (estado != null) {
      final limite = DateTime.tryParse(estado.fechaLimite ?? '');
      if (estado.caiVencido) {
        final txt = limite != null
            ? 'CAI vencido el ${limite.day}/${limite.month}/${limite.year}.'
            : 'CAI vencido.';
        mensajes.add(txt);
      }
      if (!estado.caiVencido &&
          estado.diasRestantes > 0 &&
          estado.diasRestantes <= 30) {
        mensajes.add('CAI vence pronto (${estado.diasRestantes} días).');
      }
      if (estado.rangoAgotado) {
        mensajes.add('Rango agotado, configurá el siguiente rango.');
      }
      if (estado.caiConfigurado && !estado.rtnValido) {
        mensajes.add('El RTN configurado no es válido, revisá los datos SAR.');
      }
    } else {
      mensajes.add('No hay datos del CAI configurado.');
    }

    if (_contingenciaActiva) {
      mensajes.add(
        'Modo contingencia activo: la factura no será numerada en el rango del CAI.',
      );
    }

    if (_regimenSimplificado) {
      mensajes.add(
        'Régimen Simplificado activo: se emite Comprobante Fiscal (CF) sin CAI.',
      );
    }

    if (mensajes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in mensajes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      m,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFFEAB308),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _cambiarTipoDocumento(String tipo) {
    setState(() => _tipoDocumento = tipo);
    if (widget.facturaExistente == null) {
      _actualizarPreviewCorrelativo();
    }
  }

  Widget _buildDocumentTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(
          'Factura',
          _tipoDocumento == 'Factura',
          () => _cambiarTipoDocumento('Factura'),
        ),
        _buildChip(
          'Nota Crédito',
          _tipoDocumento == 'Nota Crédito',
          () => _cambiarTipoDocumento('Nota Crédito'),
        ),
        _buildChip(
          'Nota Débito',
          _tipoDocumento == 'Nota Débito',
          () => _cambiarTipoDocumento('Nota Débito'),
        ),
        if (_regimenSimplificado)
          _buildChip(
            'Comprobante Fiscal (RST)',
            _tipoDocumento == 'Comprobante Fiscal (RST)',
            () => _cambiarTipoDocumento('Comprobante Fiscal (RST)'),
          ),
      ],
    );
  }

  Widget _buildCondicionPagoSelector() {
    final esCredito = _condicionPagoController.text == 'Crédito';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condición de Pago',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildChip(
                'Contado',
                !esCredito,
                () => setState(
                  () => _condicionPagoController.text = 'Contado',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChip(
                'Crédito (fiado)',
                esCredito,
                () => setState(
                  () => _condicionPagoController.text = 'Crédito',
                ),
              ),
            ),
          ],
        ),
        if (esCredito)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'La venta se suma a la cuenta por cobrar del cliente. '
              'Se gestiona en Fiado / Cuentas por Cobrar.',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFF262626),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF10B981) : const Color(0xFF737373),
          ),
        ),
      ),
    );
  }

  Widget _buildClienteSelector() {
    return GestureDetector(
      onTap: _mostrarListaClientes,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _clienteSeleccionado != null
              ? const Color(0xFF10B981).withValues(alpha: 0.06)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _clienteSeleccionado != null
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFF262626),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search_rounded,
              color: _clienteSeleccionado != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFF737373),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _clienteSeleccionado != null
                    ? '${_clienteSeleccionado!['nombre']} — RTN: ${_clienteSeleccionado!['rtn'] ?? 'N/A'}'
                    : 'Seleccionar cliente existente o escribir manualmente',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _clienteSeleccionado != null
                      ? Colors.white
                      : const Color(0xFF737373),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF404040),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Center(
          child: Text(
            'Sin conceptos agregados',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF525252),
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_items.length, (i) {
        final item = _items[i];
        final subtotal =
            (item['cantidad'] as num).toDouble() *
            (item['precio'] as num).toDouble();
        final isvRate = (item['isv'] as num?)?.toDouble() ?? 15.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['descripcion'] ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['cantidad']} x L.${(item['precio'] as num).toStringAsFixed(2)}  •  ISV ${isvRate.toInt()}%',
                      style: GoogleFonts.dmMono(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'L.${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _items.removeAt(i));
                  _recalcular();
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildResumenFinanciero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Subtotal',
            'L.${_subtotal.toStringAsFixed(2)}',
            const Color(0xFFA3A3A3),
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            'ISV 15%',
            'L.${_isv15.toStringAsFixed(2)}',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            'ISV 18%',
            'L.${_isv18.toStringAsFixed(2)}',
            const Color(0xFFF59E0B),
          ),
          if (_descuento > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              'Descuento',
              '-L.${_descuento.toStringAsFixed(2)}',
              const Color(0xFFEF4444),
            ),
          ],
          const Divider(color: Color(0xFF262626), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                'L.${_total.toStringAsFixed(2)}',
                style: GoogleFonts.dmMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF737373),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFormTextField(
    String label,
    TextEditingController controller, {
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF404040)),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFFA3A3A3),
          ),
        ),
        Text(value, style: GoogleFonts.dmMono(fontSize: 13, color: color)),
      ],
    );
  }
}
