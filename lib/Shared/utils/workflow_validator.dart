import 'package:flutter/material.dart';

/// Validación de flujos de trabajo específicos por canal
class WorkflowValidator {
  /// Validar flujo de trabajo Canal Tradicional
  static Map<String, String> validateCanalTradicionalWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar que el cliente tenga crédito disponible
    if (data['credito_disponible'] != null && data['monto'] != null) {
      final creditoDisponible = data['credito_disponible'] as double;
      final monto = data['monto'] as double;
      
      if (monto > creditoDisponible) {
        errors['credito'] = 'El monto excede el crédito disponible del cliente';
      }
    }

    // Validar que la ruta esté asignada
    if (data['ruta_id'] == null) {
      errors['ruta'] = 'El cliente debe estar asignado a una ruta de reparto';
    }

    // Validar periodicidad de cobro
    if (data['periodicidad_cobro'] == null) {
      errors['periodicidad'] = 'Debe definir la periodicidad de cobro';
    }

    return errors;
  }

  /// Validar flujo de trabajo Canal Moderno
  static Map<String, String> validateCanalModernoWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar que la sucursal esté activa
    if (data['sucursal_activa'] != null && !(data['sucursal_activa'] as bool)) {
      errors['sucursal'] = 'La sucursal debe estar activa para realizar operaciones';
    }

    // Validar stock disponible en sucursal
    if (data['stock_sucursal'] != null && data['cantidad'] != null) {
      final stockSucursal = data['stock_sucursal'] as int;
      final cantidad = data['cantidad'] as int;
      
      if (cantidad > stockSucursal) {
        errors['stock'] = 'Cantidad excede el stock disponible en la sucursal';
      }
    }

    // Validar autorización de transferencia
    if (data['tipo_operacion'] == 'transferencia' && data['autorizacion'] == null) {
      errors['autorizacion'] = 'Las transferencias requieren autorización';
    }

    // Validar centralización de precios
    if (data['precios_centralizados'] != null && (data['precios_centralizados'] as bool)) {
      if (data['precio'] != null && data['precio_base'] != null) {
        final precio = data['precio'] as double;
        final precioBase = data['precio_base'] as double;
        
        if (precio != precioBase) {
          errors['precio'] = 'El precio debe coincidir con el precio centralizado';
        }
      }
    }

    return errors;
  }

  /// Validar flujo de trabajo Sector Retail
  static Map<String, String> validateSectorRetailWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar precios por canal
    if (data['precios_canal'] != null) {
      final precios = data['precios_canal'] as Map<String, dynamic>;
      
      // Validar que existan precios para todos los canales configurados
      final canalesRequeridos = ['pulperia', 'supermercado', 'membresia'];
      for (final canal in canalesRequeridos) {
        if (!precios.containsKey(canal) || precios[canal] == null) {
          errors['precio_$canal'] = 'Falta precio para el canal $canal';
        }
      }

      // Validar coherencia de precios
      if (precios['pulperia'] != null && precios['supermercado'] != null) {
        final precioPulperia = precios['pulperia'] as double;
        final precioSuper = precios['supermercado'] as double;
        
        if (precioPulperia <= precioSuper) {
          errors['precios'] = 'El precio de pulpería debe ser mayor al de supermercado';
        }
      }
    }

    // Validar promociones activas
    if (data['promocion_activa'] != null && (data['promocion_activa'] as bool)) {
      if (data['descuento'] == null) {
        errors['promocion'] = 'Las promociones activas deben tener un descuento definido';
      }
      
      if (data['descuento'] != null) {
        final descuento = data['descuento'] as double;
        if (descuento < 0 || descuento > 100) {
          errors['descuento'] = 'El descuento debe estar entre 0% y 100%';
        }
      }
    }

    // Validar inventario por tienda
    if (data['inventario_tienda'] != null) {
      final inventario = data['inventario_tienda'] as Map<String, dynamic>;
      
      for (final tienda in inventario.keys) {
        final stock = inventario[tienda] as int?;
        if (stock == null || stock < 0) {
          errors['inventario_$tienda'] = 'Stock inválido para tienda $tienda';
        }
      }
    }

    return errors;
  }

  /// Validar flujo de trabajo Membresías
  static Map<String, String> validateMembresiasWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar puntos disponibles
    if (data['puntos_disponibles'] != null && data['puntos_requeridos'] != null) {
      final puntosDisponibles = data['puntos_disponibles'] as int;
      final puntosRequeridos = data['puntos_requeridos'] as int;
      
      if (puntosRequeridos > puntosDisponibles) {
        errors['puntos'] = 'Puntos insuficientes para esta operación';
      }
    }

    // Validar nivel de membresía
    if (data['nivel_actual'] != null && data['nivel_requerido'] != null) {
      final nivelActual = data['nivel_actual'] as String;
      final nivelRequerido = data['nivel_requerido'] as String;
      
      final niveles = ['bronce', 'plata', 'oro'];
      final indiceActual = niveles.indexOf(nivelActual.toLowerCase());
      final indiceRequerido = niveles.indexOf(nivelRequerido.toLowerCase());
      
      if (indiceActual < indiceRequerido) {
        errors['nivel'] = 'Nivel de membresía insuficiente';
      }
    }

    // Validar renovación automática
    if (data['auto_renovar'] != null && (data['auto_renovar'] as bool)) {
      if (data['metodo_pago'] == null) {
        errors['metodo_pago'] = 'Las renovaciones automáticas requieren un método de pago';
      }
      
      if (data['vencimiento'] != null) {
        final vencimiento = DateTime.parse(data['vencimiento'] as String);
        final diasParaVencimiento = vencimiento.difference(DateTime.now()).inDays;
        
        if (diasParaVencimiento < 3) {
          errors['vencimiento'] = 'La membresía vence pronto, revisar renovación';
        }
      }
    }

    return errors;
  }

  /// Validar flujo de trabajo POS
  static Map<String, String> validatePOSWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar carrito no vacío
    if (data['carrito'] == null || (data['carrito'] as List).isEmpty) {
      errors['carrito'] = 'El carrito está vacío';
    }

    // Validar stock disponible
    if (data['carrito'] != null) {
      final carrito = data['carrito'] as List;
      for (final item in carrito) {
        if (item is Map<String, dynamic>) {
          final cantidad = item['cantidad'] as int?;
          final stock = item['stock'] as int?;
          
          if (cantidad != null && stock != null && cantidad > stock) {
            errors['stock_${item['producto_id']}'] = 'Stock insuficiente para ${item['nombre']}';
          }
        }
      }
    }

    // Validar método de pago
    if (data['metodo_pago'] == null) {
      errors['metodo_pago'] = 'Debe seleccionar un método de pago';
    }

    // Validar monto total
    if (data['monto_total'] != null) {
      final montoTotal = data['monto_total'] as double;
      if (montoTotal <= 0) {
        errors['monto'] = 'El monto total debe ser mayor a 0';
      }
    }

    return errors;
  }

  /// Validar flujo de trabajo Facturación
  static Map<String, dynamic> validateFacturacionWorkflow(Map<String, dynamic> data) {
    final errors = <String, String>{};
    final warnings = <String, String>{};

    // Validar datos fiscales del cliente
    if (data['cliente_rtn'] != null && data['cliente_rtn'].toString().isNotEmpty) {
      final rtn = data['cliente_rtn'] as String;
      if (rtn.length != 14) {
        errors['rtn'] = 'RTN debe tener 14 dígitos';
      }
    }

    // Validar CAI
    if (data['cai'] == null || data['cai'].toString().isEmpty) {
      errors['cai'] = 'CAI es requerido para facturación';
    }

    // Validar cálculo de ISV
    if (data['subtotal'] != null && data['isv'] != null) {
      final subtotal = data['subtotal'] as double;
      final isv = data['isv'] as double;
      final tasaISV = 0.15; // 15%
      final isvCalculado = subtotal * tasaISV;
      
      if ((isv - isvCalculado).abs() > 0.01) {
        warnings['isv'] = 'El ISV calculado difiere del esperado';
      }
    }

    // Validar número de factura
    if (data['numero_factura'] != null) {
      final numeroFactura = data['numero_factura'] as String;
      final regex = RegExp(r'^\d{4}-\d{4}-\d{8}$');
      if (!regex.hasMatch(numeroFactura)) {
        errors['numero_factura'] = 'Formato de número de factura inválido';
      }
    }

    return {'errors': errors, 'warnings': warnings};
  }

  /// Mostrar errores de validación
  static void showValidationErrors(BuildContext context, Map<String, String> errors) {
    if (errors.isEmpty) return;

    final errorMessages = errors.entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Errores de Validación', style: TextStyle(color: Colors.white)),
        content: Text(errorMessages, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Mostrar advertencias de validación
  static void showValidationWarnings(BuildContext context, Map<String, String> warnings) {
    if (warnings.isEmpty) return;

    final warningMessages = warnings.entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange[900],
        title: const Text('Advertencias', style: TextStyle(color: Colors.white)),
        content: Text(warningMessages, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}