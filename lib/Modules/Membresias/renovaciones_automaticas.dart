import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class RenovacionesAutomaticas extends StatefulWidget {
  const RenovacionesAutomaticas({super.key});

  @override
  State<RenovacionesAutomaticas> createState() =>
      _RenovacionesAutomaticasState();
}

class _RenovacionesAutomaticasState extends State<RenovacionesAutomaticas> {
  List<Map<String, dynamic>> _membresias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarMembresias();
  }

  Future<void> _cargarMembresias() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/membresias/socios');
      if (api.isSuccess(result)) {
        final data = result['socios'] ?? [];
        if (data is List && mounted) {
          setState(() {
            _membresias = data.map<Map<String, dynamic>>((s) {
              final socio = Map<String, dynamic>.from(s);
              return {
                'id': socio['id']?.toString() ?? '',
                'socio': socio['nombre'] ?? 'Sin nombre',
                'plan': socio['nivel'] ?? socio['plan_nombre'] ?? 'Básico',
                'vencimiento':
                    socio['vencimiento'] ?? socio['fecha_vencimiento'] ?? 'N/A',
                'auto_renovar': socio['auto_renovar'] ?? false,
                'metodo_pago': socio['metodo_pago'] ?? 'Efectivo',
              };
            }).toList();
            _cargando = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando renovaciones: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF3B82F6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Renovaciones Automáticas',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF3B82F6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : _membresias.isEmpty
          ? Center(
              child: Text(
                'No hay membresías registradas',
                style: GoogleFonts.dmSans(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF3B82F6),
              onRefresh: _cargarMembresias,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _membresias.length,
                itemBuilder: (context, index) {
                  final membresia = _membresias[index];
                  return _buildMembresiaCard(membresia, palette);
                },
              ),
            ),
    );
  }

  Widget _buildMembresiaCard(
    Map<String, dynamic> membresia,
    ThemePalette palette,
  ) {
    final planColor = membresia['plan'] == 'Oro'
        ? const Color(0xFFF59E0B)
        : membresia['plan'] == 'Plata'
        ? const Color(0xFF9CA3AF)
        : const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membresia['socio'],
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: appThemeNotifier.isDark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: planColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            membresia['plan'],
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: planColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vence: ${membresia['vencimiento']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: appThemeNotifier.isDark
                                ? const Color(0xFFA3A3A3)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: membresia['auto_renovar'],
                onChanged: (value) {
                  setState(() {
                    membresia['auto_renovar'] = value;
                  });
                },
                activeThumbColor: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                membresia['metodo_pago'] == 'Tarjeta'
                    ? Icons.credit_card_rounded
                    : membresia['metodo_pago'] == 'Transferencia'
                    ? Icons.account_balance_rounded
                    : Icons.payments_rounded,
                size: 16,
                color: appThemeNotifier.isDark
                    ? const Color(0xFFA3A3A3)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                membresia['metodo_pago'],
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          if (membresia['auto_renovar']) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.autorenew_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Renovación automática activada',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
