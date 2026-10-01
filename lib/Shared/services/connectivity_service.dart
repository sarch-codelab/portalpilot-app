import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectivityController;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  String _lastConnectivityType = 'unknown';

  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }

  bool get isOnline => _isOnline;
  String get connectivityType => _lastConnectivityType;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
    
    // Realizar ping inicial para verificar conexión real
    _performRealConnectivityCheck();
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    
    final types = results.map((e) => e.name).join(', ');
    _lastConnectivityType = types.isNotEmpty ? types : 'none';

    if (wasOnline != _isOnline) {
      debugPrint('🌐 Connectivity changed: $_isOnline (type: $_lastConnectivityType)');
      _connectivityController?.add(_isOnline);
      
      // Si detectamos conexión, verificar si es real
      if (_isOnline) {
        _performRealConnectivityCheck();
      }
    }
  }

  Future<void> _performRealConnectivityCheck() async {
    try {
      // No dependas de un único DNS público: si Google está bloqueado pero
      // el backend de Portal Pilot sí responde, la cola debe poder reanudarse.
      final checks = await Future.wait([
        for (final host in ['portal-pilot.vercel.app', 'example.com', 'google.com'])
          InternetAddress.lookup(host)
              .then((addresses) => addresses.any((a) => a.rawAddress.isNotEmpty))
              .catchError((_) => false),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => <bool>[]);

      if (checks.any((reachable) => reachable)) {
        if (!_isOnline) {
          _isOnline = true;
          debugPrint('🌐 Real connectivity confirmed');
          _connectivityController?.add(true);
        }
      }
    } catch (e) {
      debugPrint('🌐 Real connectivity check failed: $e');
      if (_isOnline) {
        _isOnline = false;
        _connectivityController?.add(false);
      }
    }
  }

  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    
    if (_isOnline) {
      await _performRealConnectivityCheck();
    }
    
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (_connectivityController != null && !_connectivityController!.isClosed) {
      _connectivityController!.close();
    }
    // Anular la referencia es OBLIGATORIO: si solo la cerramos (sin anular),
    // cualquier listener nuevo recibe un stream zombie ya cerrado (onDone
    // inmediato, 0 eventos) y `_updateConnectivity` revienta con StateError
    // ("Cannot add event after closing").
    _connectivityController = null;
  }
}
