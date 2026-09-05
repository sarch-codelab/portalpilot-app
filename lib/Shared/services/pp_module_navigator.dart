import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/haptic_service.dart';
import 'package:portal_pilot_app/Shared/widgets/page_transitions.dart';
import 'package:portal_pilot_app/Modules/Analytics/analytics_home.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/canal_moderno_home.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/canal_tradicional_home.dart';
import 'package:portal_pilot_app/Modules/ChatIA/chat_ia_home.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_home.dart';
import 'package:portal_pilot_app/Modules/ComprasProveedores/compras_proveedores_home.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/contabilidad_home.dart';
import 'package:portal_pilot_app/Modules/Cotizaciones/cotizaciones_home.dart';
import 'package:portal_pilot_app/Modules/CRM/crm_home.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/crm_advanced_home.dart';
import 'package:portal_pilot_app/Modules/Facturacion/facturacion_home.dart';
import 'package:portal_pilot_app/Modules/FiscalAdvanced/fiscal_advanced_home.dart';
import 'package:portal_pilot_app/Modules/Inventario/inventario_home.dart';
import 'package:portal_pilot_app/Modules/Membresias/membresia_home.dart';
import 'package:portal_pilot_app/Modules/MultiEmpresa/multi_empresa_home.dart';
import 'package:portal_pilot_app/Modules/POS/pos_home.dart';
import 'package:portal_pilot_app/Modules/RRHH/rrhh_home.dart';
import 'package:portal_pilot_app/Modules/SectorRetail/sector_retail_home.dart';
import 'package:portal_pilot_app/Modules/Seguridad/seguridad_home.dart';
import 'package:portal_pilot_app/Modules/Settings/settings_home.dart';
import 'package:portal_pilot_app/Modules/Soporte/soporte_home.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/supply_chain_home.dart';

/// Navegador central de módulos de Portal Pilot.
///
/// Permite abrir un módulo por su [Modulo] desde cualquier pantalla,
/// manteniendo transiciones consistentes y haptic feedback.
class PPModuleNavigator {
  /// Devuelve el widget del módulo, o `null` si no es reconocido.
  static Widget? buildWidget(String moduleId) {
    switch (moduleId) {
      case 'contabilidad':
        return ContabilidadHome();
      case 'facturacion':
        return FacturacionHome();
      case 'inventario':
        return const InventarioHome();
      case 'rrhh':
        return const RrhhHome();
      case 'crm':
        return const CrmHome();
      case 'pos':
        return const PosHome();
      case 'comercial':
        return const ComercialHome();
      case 'membresias':
        return const MembresiaHome();
      case 'canal_moderno':
        return const CanalModernoHome();
      case 'cotizaciones':
        return const CotizacionesHome();
      case 'compras_proveedores':
        return const ComprasProveedoresHome();
      case 'sector_retail':
        return const SectorRetailHome();
      case 'canal_tradicional':
        return const CanalTradicionalHome();
      case 'settings':
        return const SettingsHome();
      case 'chat_ia':
        return const ChatIAHome();
      case 'analytics':
        return const AnalyticsHome();
      case 'supply_chain':
        return const SupplyChainHome();
      case 'crm_advanced':
        return const CRMAdvancedHome();
      case 'fiscal_advanced':
        return const FiscalAdvancedHome();
      case 'seguridad':
        return const SeguridadHome();
      case 'multi_empresa':
        return const MultiEmpresaHome();
      case 'soporte':
        return const SoporteHome();
      default:
        return null;
    }
  }

  /// Abre un módulo empujando una ruta con transición consistente.
  static Future<void> push(
    BuildContext context,
    Modulo modulo,
  ) async {
    final destination = buildWidget(modulo.id);
    if (destination == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${modulo.nombre} — próximamente'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    HapticService.instance.mediumImpact();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      SharedAxisTransition(
        child: destination,
        type: SharedAxisTransitionType.horizontal,
      ),
    );
  }

  static Future<void> pushById(BuildContext context, String moduleId) async {
    for (final m in Modulo.modulosDisponibles) {
      if (m.id == moduleId) {
        await push(context, m);
        return;
      }
    }
  }
}