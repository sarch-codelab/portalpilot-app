import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// Layout Master-Detail responsivo.
///
/// - **Desktop/Tablet ancho**: dos paneles lado a lado (lista + detalle).
/// - **Móvil**: solo el panel maestro; el detalle se abre como pantalla.
///
/// Uso típico: listas de facturas, clientes, productos con formulario/detalle.
class PPMasterDetail extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final bool showDetail;
  final double masterWidth;
  final Color? dividerColor;

  const PPMasterDetail({
    super.key,
    required this.master,
    this.detail,
    this.showDetail = true,
    this.masterWidth = 380,
    this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MobileUtils.isDesktop(context);
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final showDetailPane = isDesktop && showDetail && detail != null;

    if (!showDetailPane) {
      return master;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: masterWidth,
          child: master,
        ),
        VerticalDivider(
          width: 1,
          color: dividerColor ?? palette.borderLight,
        ),
        Expanded(
          child: detail!,
        ),
      ],
    );
  }
}