import 'package:flutter/material.dart';

/// Marca oficial de la app: la imagen real `img/Iconos/Portal Pilot.png`.
///
/// El PNG original es BLANCO (monocromo con transparencia). Sobre fondos
/// claros se tiñe a negro con BlendMode.srcIn para que nunca desaparezca;
/// sobre fondos oscuros se muestra tal cual.
class PortalPilotLogo extends StatelessWidget {
  final double height;
  final bool forceWhite;

  const PortalPilotLogo({
    super.key,
    this.height = 20,
    this.forceWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = forceWhite || Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'img/Iconos/Portal Pilot.png',
      height: height,
      fit: BoxFit.contain,
      // Logo blanco nativo: en claro se tiñe a negro para conservar el
      // contraste; en oscuro se deja intacto.
      color: isDark ? null : Colors.black,
      colorBlendMode: isDark ? null : BlendMode.srcIn,
      errorBuilder: (_, _, _) => Text(
        'Portal Pilot',
        style: TextStyle(
          fontSize: height * 0.78,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
