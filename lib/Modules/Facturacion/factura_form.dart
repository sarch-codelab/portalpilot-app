import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/Facturacion/factura_detalle.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';

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

  List<Map<String, dynamic>> _clientesGuardados = [];
  Map<String, dynamic>? _clienteSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    if (widget.facturaExistente != null) {
      _cargarFacturaExistente(widget.facturaExistente!);
    }
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    final clientesJson = prefs.getString('clientes_facturacion') ?? '[]';
    setState(() {
      _cai = prefs.getString('empresa_cai') ?? '';
      _empresaNombre = prefs.getString('empresa_nombre') ?? '';
      _rtn = prefs.getString('empresa_rtn') ?? '';
      _rangoInicio = prefs.getString('empresa_rango_inicio') ?? '001-001-01-00000001';
      _clientesGuardados = List<Map<String, dynamic>>.from(jsonDecode(clientesJson));
    });
    _calcularSiguienteCorrelativo();
  }

  Future<void> _calcularSiguienteCorrelativo() async {
    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    final List<dynamic> facturas = jsonDecode(facturasJson);

    if (facturas.isEmpty) {
      final partes = _rangoInicio.split('-');
      if (partes.length == 4) {
        final num = int.tryParse(partes[3]) ?? 1;
        setState(() {
          _siguienteCorrelativo = '${partes[0]}-${partes[1]}-${partes[2]}-${num.toString().padLeft(8, '0')}';
        });
      } else {
        setState(() {
          _siguienteCorrelativo = '001-001-01-00000001';
        });
      }
    } else {
      final ultima = facturas.last;
      final partes = (ultima['correlativo'] ?? '001-001-01-00000001').split('-');
      if (partes.length == 4) {
        final num = (int.tryParse(partes[3]) ?? 0) + 1;
        setState(() {
          _siguienteCorrelativo = '${partes[0]}-${partes[1]}-${partes[2]}-${num.toString().padLeft(8, '0')}';
        });
      }
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
    _recalcular();
  }

  void _recalcular() {
    double sub = 0.0;
    double isv15 = 0.0;
    double isv18 = 0.0;

    for (final item in _items) {
      final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0;
      final isvRate = (item['isv'] as num?)?.toDouble() ?? 15.0;
      final exento = item['exento'] == true;

      final lineaSubtotal = cantidad * precio;
      sub += lineaSubtotal;

      if (!exento) {
        if (isvRate == 18.0) {
          isv18 += lineaSubtotal * 0.18;
        } else {
          isv15 += lineaSubtotal * 0.15;
        }
      }
    }

    final totalIsv = isv15 + isv18;
    final totalAntes = sub + totalIsv;

    setState(() {
      _subtotal = sub;
      _isv15 = isv15;
      _isv18 = isv18;
      _total = totalAntes - _descuento;
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
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
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
                        Expanded(child: _buildModalTextField('Cantidad', cantidadController, keyboard: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildModalTextField('Precio Unitario (L.)', precioController, keyboard: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ISV', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F0F),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF262626)),
                                ),
                                child: DropdownButton<String>(
                                  value: isvSeleccionado,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1A1A1A),
                                  underline: const SizedBox(),
                                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                                  items: [
                                    DropdownMenuItem(value: '15', child: Text('15% (Bien)')),
                                    DropdownMenuItem(value: '18', child: Text('18% (Bebida/Tabaco)')),
                                    DropdownMenuItem(value: '0', child: Text('0% (Exento)')),
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
                          if (nombreController.text.isNotEmpty && precioController.text.isNotEmpty) {
                            setState(() {
                              _items.add({
                                'descripcion': nombreController.text,
                                'cantidad': int.tryParse(cantidadController.text) ?? 1,
                                'precio': double.tryParse(precioController.text) ?? 0,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Agregar Concepto',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
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
                  width: 40, height: 4,
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
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          child: Text(
                            (c['nombre'] ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ),
                        title: Text(
                          c['nombre'] ?? '',
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'RTN: ${c['rtn'] ?? 'N/A'}',
                          style: GoogleFonts.dmMono(color: const Color(0xFF737373), fontSize: 11),
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
    if (_cai.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configurá tu CAI primero', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agregá al menos un concepto', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    final List<dynamic> facturas = jsonDecode(facturasJson);

    final factura = {
      'id': widget.facturaExistente != null
          ? widget.facturaExistente!['id']
          : DateTime.now().millisecondsSinceEpoch.toString(),
      'correlativo': widget.facturaExistente != null
          ? widget.facturaExistente!['correlativo']
          : _siguienteCorrelativo,
      'tipo_documento': _tipoDocumento,
      'fecha': widget.facturaExistente != null
          ? widget.facturaExistente!['fecha']
          : DateTime.now().toIso8601String(),
      'cai': _cai,
      'empresa_nombre': _empresaNombre,
      'empresa_rtn': _rtn,
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
    };

    if (widget.facturaExistente != null) {
      final idx = facturas.indexWhere((f) => f['id'] == factura['id']);
      if (idx >= 0) facturas[idx] = factura;
    } else {
      facturas.add(factura);
    }

    await prefs.setString('facturas', jsonEncode(facturas));

    try {
      final empresa = prefs.getString('company_code') ?? '';
      if (empresa.isNotEmpty) {
        await PortalPilotDB.insertFactura(factura: factura, empresaCodigo: empresa);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Factura $_siguienteCorrelativo guardada', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FacturaDetalle(factura: factura),
        ),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
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
            const SizedBox(height: 16),
            _buildSection('Tipo de Documento'),
            const SizedBox(height: 8),
            _buildDocumentTypeSelector(),
            const SizedBox(height: 16),
            _buildSection('Datos del Cliente'),
            const SizedBox(height: 8),
            _buildClienteSelector(),
            const SizedBox(height: 12),
            _buildFormTextField('Nombre / Razón Social', _clienteNombreController),
            const SizedBox(height: 12),
            _buildFormTextField('RTN del Cliente', _clienteRTNController, hint: '0801-1999-12345'),
            const SizedBox(height: 12),
            _buildFormTextField('Dirección', _clienteDireccionController),
            const SizedBox(height: 12),
            _buildFormTextField('Condición de Pago', _condicionPagoController),
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
                    const Icon(Icons.add_rounded, color: Color(0xFF10B981), size: 20),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  widget.facturaExistente != null ? 'Actualizar Factura' : 'Emitir Factura',
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
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
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
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
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
        ],
      ),
    );
  }

  Widget _buildDocumentTypeSelector() {
    return Row(
      children: [
        _buildChip('Factura', _tipoDocumento == 'Factura', () => setState(() => _tipoDocumento = 'Factura')),
        const SizedBox(width: 8),
        _buildChip('Nota Crédito', _tipoDocumento == 'Nota Crédito', () => setState(() => _tipoDocumento = 'Nota Crédito')),
        const SizedBox(width: 8),
        _buildChip('Nota Débito', _tipoDocumento == 'Nota Débito', () => setState(() => _tipoDocumento = 'Nota Débito')),
      ],
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF141414),
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
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
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
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF525252)),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_items.length, (i) {
        final item = _items[i];
        final subtotal = (item['cantidad'] as num).toDouble() * (item['precio'] as num).toDouble();
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
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['cantidad']} x L.${(item['precio'] as num).toStringAsFixed(2)}  •  ISV ${isvRate.toInt()}%',
                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'L.${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _items.removeAt(i));
                  _recalcular();
                },
                child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
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
          _buildSummaryRow('Subtotal', 'L.${_subtotal.toStringAsFixed(2)}', const Color(0xFFA3A3A3)),
          const SizedBox(height: 6),
          _buildSummaryRow('ISV 15%', 'L.${_isv15.toStringAsFixed(2)}', const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          _buildSummaryRow('ISV 18%', 'L.${_isv18.toStringAsFixed(2)}', const Color(0xFFF59E0B)),
          if (_descuento > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow('Descuento', '-L.${_descuento.toStringAsFixed(2)}', const Color(0xFFEF4444)),
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

  Widget _buildFormTextField(String label, TextEditingController controller, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildModalTextField(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373))),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFA3A3A3))),
        Text(value, style: GoogleFonts.dmMono(fontSize: 13, color: color)),
      ],
    );
  }
}
