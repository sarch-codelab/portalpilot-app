import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class StockConsolidado extends StatefulWidget {
  const StockConsolidado({super.key});

  @override
  State<StockConsolidado> createState() => _StockConsolidadoState();
}

class _StockConsolidadoState extends State<StockConsolidado> {
  List<Map<String, dynamic>> _productos = [
    {
      'id': '1',
      'nombre': 'Arroz Premium 5kg',
      'stock_tradicional': 450,
      'stock_moderno': 1200,
      'stock_membresia': 380,
      'total': 2030,
    },
    {
      'id': '2',
      'nombre': 'Frijol Negro 1kg',
      'stock_tradicional': 320,
      'stock_moderno': 890,
      'stock_membresia': 250,
      'total': 1460,
    },
    {
      'id': '3',
      'nombre': 'AzÃºcar 5kg',
      'stock_tradicional': 280,
      'stock_moderno': 750,
      'stock_membresia': 210,
      'total': 1240,
    },
  ];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
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
          'Stock Consolidado',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productos.length,
        itemBuilder: (context, index) {
          final producto = _productos[index];
          return _buildProductCard(producto, palette);
        },
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> producto,
    ThemePalette palette,
  ) {
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
              Text(
                producto['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total: ${producto['total']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildChannelStock(
            'Canal Tradicional',
            producto['stock_tradicional'],
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 8),
          _buildChannelStock(
            'Canal Moderno',
            producto['stock_moderno'],
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildChannelStock(
            'MembresÃ­as',
            producto['stock_membresia'],
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelStock(String canal, int stock, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          canal,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: appThemeNotifier.isDark
                ? const Color(0xFFA3A3A3)
                : const Color(0xFF6B7280),
          ),
        ),
        Row(
          children: [
            Container(
              width: 100,
              height: 6,
              decoration: BoxDecoration(
                color: appThemeNotifier.isDark
                    ? const Color(0xFF262626)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: stock / 1500,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stock.toString(),
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
