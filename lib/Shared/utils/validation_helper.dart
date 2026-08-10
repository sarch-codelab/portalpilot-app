import 'package:flutter/material.dart';

/// Sistema de validación de datos robusto
class ValidationHelper {
  /// Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    
    return null;
  }

  /// Validar teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es requerido';
    }
    
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{8,20}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Teléfono inválido';
    }
    
    return null;
  }

  /// Validar número positivo
  static String? validatePositiveNumber(String? value, {String fieldName = 'Valor'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName debe ser un número';
    }
    
    if (number <= 0) {
      return '$fieldName debe ser positivo';
    }
    
    return null;
  }

  /// Validar precio
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'El precio es requerido';
    }
    
    final price = double.tryParse(value);
    if (price == null) {
      return 'Precio inválido';
    }
    
    if (price <= 0) {
      return 'El precio debe ser mayor a 0';
    }
    
    if (price > 1000000) {
      return 'El precio no puede exceder L.1,000,000';
    }
    
    return null;
  }

  /// Validar cantidad de stock
  static String? validateStock(String? value) {
    if (value == null || value.isEmpty) {
      return 'La cantidad es requerida';
    }
    
    final stock = int.tryParse(value);
    if (stock == null) {
      return 'Cantidad inválida';
    }
    
    if (stock < 0) {
      return 'La cantidad no puede ser negativa';
    }
    
    if (stock > 100000) {
      return 'La cantidad no puede exceder 100,000';
    }
    
    return null;
  }

  /// Validar porcentaje de descuento
  static String? validateDiscount(String? value) {
    if (value == null || value.isEmpty) {
      return 'El descuento es requerido';
    }
    
    final discount = double.tryParse(value);
    if (discount == null) {
      return 'Descuento inválido';
    }
    
    if (discount < 0) {
      return 'El descuento no puede ser negativo';
    }
    
    if (discount > 100) {
      return 'El descuento no puede exceder 100%';
    }
    
    return null;
  }

  /// Validar texto requerido
  static String? validateRequired(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  /// Validar longitud mínima
  static String? validateMinLength(String? value, int minLength, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    if (value.length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }
    
    return null;
  }

  /// Validar longitud máxima
  static String? validateMaxLength(String? value, int maxLength, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return null; // No requerido, pero si existe, validar longitud
    }
    
    if (value.length > maxLength) {
      return '$fieldName no puede exceder $maxLength caracteres';
    }
    
    return null;
  }

  /// Validar RTN (Registro Tributario Nacional - Honduras)
  static String? validateRTN(String? value) {
    if (value == null || value.isEmpty) {
      return 'El RTN es requerido';
    }
    
    // RTN formato: 14 dígitos
    final rtnRegex = RegExp(r'^\d{14}$');
    if (!rtnRegex.hasMatch(value)) {
      return 'RTN inválido (debe tener 14 dígitos)';
    }
    
    return null;
  }

  /// Validar fecha futura
  static String? validateFutureDate(DateTime? date, {String fieldName = 'Fecha'}) {
    if (date == null) {
      return '$fieldName es requerida';
    }
    
    if (date.isBefore(DateTime.now())) {
      return '$fieldName debe ser futura';
    }
    
    return null;
  }

  /// Validar fecha pasada
  static String? validatePastDate(DateTime? date, {String fieldName = 'Fecha'}) {
    if (date == null) {
      return '$fieldName es requerida';
    }
    
    if (date.isAfter(DateTime.now())) {
      return '$fieldName debe ser pasada';
    }
    
    return null;
  }
}

/// Manejador de errores robusto
class ErrorHandler {
  /// Mostrar error en SnackBar
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Mostrar éxito en SnackBar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Mostrar advertencia en SnackBar
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Manejar error genérico
  static String getErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }
    
    if (error.toString().contains('NetworkException')) {
      return 'Error de conexión. Verifica tu internet.';
    }
    
    if (error.toString().contains('TimeoutException')) {
      return 'Tiempo de espera agotado. Intenta nuevamente.';
    }
    
    if (error.toString().contains('FormatException')) {
      return 'Error en el formato de los datos.';
    }
    
    return 'Ocurrió un error inesperado. Intenta nuevamente.';
  }
}