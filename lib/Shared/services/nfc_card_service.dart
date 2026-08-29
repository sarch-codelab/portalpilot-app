// Detección de tarjetas de crédito por NFC (chip/contactless) estilo POS.
// IMPORTANTE: SOLO detecta e identifica la tarjeta (EMV PPSE + AIDs). NO
// realiza ningún cobro ni transmite datos a un banco.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TarjetaDetectada {
  final String marca;
  final String? ultimos4;
  final String uid;
  final String tecnologia;
  final List<String> aids;
  final String? ats;

  const TarjetaDetectada({
    required this.marca,
    this.ultimos4,
    required this.uid,
    required this.tecnologia,
    this.aids = const [],
    this.ats,
  });

  factory TarjetaDetectada.desdeMapa(Map<Object?, Object?> m) {
    final aids = (m['aids'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return TarjetaDetectada(
      marca: (m['marca'] as String?) ?? 'DESCONOCIDA',
      ultimos4: m['ultimos4'] as String?,
      uid: (m['uid'] as String?) ?? '',
      tecnologia: (m['tecnologia'] as String?) ?? 'NFC',
      aids: aids,
      ats: m['ats'] as String?,
    );
  }

  String get ultimos4Visibles {
    if (ultimos4 != null) return ultimos4!;
    if (uid.length >= 4) return uid.substring(uid.length - 4);
    return '????';
  }
}

class NfcException implements Exception {
  final String mensaje;
  const NfcException(this.mensaje);

  @override
  String toString() => mensaje;
}

class NfcCardService {
  NfcCardService._();
  static final NfcCardService instance = NfcCardService._();

  static const MethodChannel _channel = MethodChannel('portal_pilot/nfc_card');
  static const Duration _timeout = Duration(seconds: 40);

  bool get soportePosible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Verifica que el dispositivo tenga NFC y esté activado.
  Future<bool> nfcListo() async {
    if (!soportePosible) return false;
    try {
      return await _channel.invokeMethod<bool>('nfc_ready') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelar() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Espera el contacto de una tarjeta y devuelve la información del chip.
  Future<TarjetaDetectada> detectar() async {
    if (!soportePosible) {
      throw const NfcException(
        'La lectura por chip requiere un teléfono Android con NFC. '
        'En este equipo solo puedes registrar tarjeta manualmente.',
      );
    }
    final listo = await nfcListo();
    if (!listo) {
      throw const NfcException(
        'El NFC está apagado o no disponible. Actívalo en Ajustes > Conexiones.',
      );
    }

    Map<Object?, Object?>? res;
    try {
      res = await _channel
          .invokeMethod<Map<Object?, Object?>>('detect')
          .timeout(_timeout, onTimeout: () {
        cancelar();
        throw const NfcException(
          'No se detectó ninguna tarjeta. Acerca el chip/banda al teléfono e intenta de nuevo.',
        );
      });
    } on PlatformException catch (e) {
      throw NfcException(e.message ?? 'Error de NFC: ${e.code}');
    }

    if (res == null) throw const NfcException('No se pudo leer la tarjeta.');
    return TarjetaDetectada.desdeMapa(res);
  }
}