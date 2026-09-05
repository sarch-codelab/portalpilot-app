import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// Tarjeta de resumen (KPI) responsiva de Portal Pilot.
///
/// - Desktop: layout horizontal compacto.
/// - Móvil: layout vertical con icono arriba.
/// Se adapta a pantallas compactas (< 360) ajustando tipografía.
class PPStatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool trendUp;
  final VoidCallback? onTap;

  const PPStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final isMobile = MobileUtils.isMobile(context);
    final compact = MobileUtils.isCompact(context);

    final card = Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trendUp ? palette.successGreen : palette.errorRed).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend!,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trendUp ? palette.successGreen : palette.errorRed,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.syne(
                fontSize: compact ? 17 : (isMobile ? 20 : 22),
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: isMobile ? 11 : 12,
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// Grid de tarjetas KPI responsivo a cualquier ancho.
class PPStatsGrid extends StatelessWidget {
  final List<PPStatsCard> cards;
  final int? columnsMobile;
  final int? columnsDesktop;

  const PPStatsGrid({
    super.key,
    required this.cards,
    this.columnsMobile,
    this.columnsDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MobileUtils.isMobile(context);
    final columns = isMobile ? (columnsMobile ?? 2) : (columnsDesktop ?? 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas muy pequeñas, garantizar 1 columna para 1-2 tarjetas
        final safeColumns = constraints.maxWidth < 340 && columns > 2 ? 1 : columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: safeColumns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: isMobile ? 132 : 148,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        );
      },
    );
  }
}