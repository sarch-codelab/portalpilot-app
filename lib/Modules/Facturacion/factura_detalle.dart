import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FacturaDetalle extends StatelessWidget {
  final Map<String, dynamic> factura;

  const FacturaDetalle({super.key, required this.factura});

  @override
  Widget build(BuildContext context) {
    final estado = factura['estado'] ?? 'emitida';
    final total = (factura['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (factura['subtotal'] as num?)?.toDouble() ?? 0.0;
    final isv15 = (factura['isv_15'] as num?)?.toDouble() ?? 0.0;
    final isv18 = (factura['isv_18'] as num?)?.toDouble() ?? 0.0;
    final descuento = (factura['descuento'] as num?)?.toDouble() ?? 0.0;
    final items = List<Map<String, dynamic>>.from(factura['items'] ?? []);
    final fecha = factura['fecha'] ?? '';
    final dt = DateTime.tryParse(fecha);

    Color estadoColor;
    switch (estado) {
      case 'anulada':
        estadoColor = const Color(0xFFEF4444);
        break;
      case 'pendiente':
        estadoColor = const Color(0xFFF59E0B);
        break;
      default:
        estadoColor = const Color(0xFF10B981);
    }

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
          factura['correlativo'] ?? 'FACTURA',
          style: GoogleFonts.dmMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DOCUMENTO FISCAL',
                      style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estado.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: estadoColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Tipo', factura['tipo_documento'] ?? 'Factura'),
                _buildInfoRow('Correlativo', factura['correlativo'] ?? ''),
                _buildInfoRow('Fecha', dt != null
                    ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                    : fecha),
                const Divider(color: Color(0xFF262626), height: 20),
                _buildInfoRow('Empresa', factura['empresa_nombre'] ?? ''),
                _buildInfoRow('RTN Empresa', factura['empresa_rtn'] ?? ''),
                _buildInfoRow('CAI', factura['cai'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENTE',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Nombre', factura['cliente_nombre'] ?? 'Cliente general'),
                _buildInfoRow('RTN', factura['cliente_rtn'] ?? 'N/A'),
                _buildInfoRow('Dirección', factura['cliente_direccion'] ?? 'N/A'),
                _buildInfoRow('Condición de Pago', factura['condicion_pago'] ?? 'Contado'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONCEPTOS',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Text('Sin conceptos', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))
                else
                  ...items.map((item) {
                    final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
                    final precio = (item['precio'] as num?)?.toDouble() ?? 0;
                    final lineaTotal = cantidad * precio;
                    final isvRate = (item['isv'] as num?)?.toDouble() ?? 15.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(8),
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
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cantidad.toInt()} x L.${precio.toStringAsFixed(2)}  •  ISV ${isvRate.toInt()}%',
                                  style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'L.${lineaTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.dmMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', 'L.${subtotal.toStringAsFixed(2)}', const Color(0xFFA3A3A3)),
                const SizedBox(height: 6),
                _buildSummaryRow('ISV 15%', 'L.${isv15.toStringAsFixed(2)}', const Color(0xFF3B82F6)),
                const SizedBox(height: 6),
                _buildSummaryRow('ISV 18%', 'L.${isv18.toStringAsFixed(2)}', const Color(0xFFF59E0B)),
                if (descuento > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('Descuento', '-L.${descuento.toStringAsFixed(2)}', const Color(0xFFEF4444)),
                ],
                const Divider(color: Color(0xFF262626), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'L.${total.toStringAsFixed(2)}',
                      style: GoogleFonts.dmMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
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
