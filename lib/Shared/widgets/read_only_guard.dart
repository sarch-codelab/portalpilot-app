import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

/// Bloquea acciones de registro/escritura cuando la empresa está en modo
/// solo lectura (trial vencido).
///
/// Uso: al inicio del handler de un botón que crea/edita datos:
/// ```dart
/// if (ReadOnlyGuard.bloqueado(context)) return;
/// ```
/// Devuelve `true` si la acción fue bloqueada (ya mostró el aviso).
class ReadOnlyGuard {
  ReadOnlyGuard._();

  static bool bloqueado(BuildContext context) {
    if (!AuthController.instance.soloLectura) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Modo solo lectura: tu prueba de 15 días venció. '
            'Puedes consultar y exportar tus datos, pero no registrar '
            'movimientos nuevos. Renueva tu plan para continuar.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return true;
  }
}