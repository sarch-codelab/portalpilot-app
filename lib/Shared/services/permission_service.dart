import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  Future<bool> requestCameraPermission() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<bool> requestStoragePermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Android 13+ usa photos
        final photosStatus = await Permission.photos.request();
        return photosStatus.isGranted;
      }
      return status.isGranted;
    } else if (!kIsWeb && Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<bool> requestLocationPermission() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.location.request();
      return status.isGranted;
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<bool> requestBluetoothPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        return scanStatus.isGranted && connectStatus.isGranted;
      }
      return status.isGranted;
    } else if (!kIsWeb && Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<bool> requestMultiplePermissions(List<Permission> permissions) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final statuses = await permissions.request();
      return statuses.values.every((status) => status.isGranted);
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<bool> checkPermission(Permission permission) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await permission.status;
      return status.isGranted;
    }
    return true; // En Windows/desktop no requiere permisos
  }

  Future<void> openAppSettings() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await openAppSettings();
    }
  }

  String getPermissionStatusMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Permiso concedido';
      case PermissionStatus.denied:
        return 'Permiso denegado';
      case PermissionStatus.restricted:
        return 'Permiso restringido';
      case PermissionStatus.limited:
        return 'Permiso limitado';
      case PermissionStatus.permanentlyDenied:
        return 'Permiso permanentemente denegado';
      case PermissionStatus.provisional:
        return 'Permiso provisional';
    }
  }
}